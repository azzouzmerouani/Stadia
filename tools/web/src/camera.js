// Camera framing + animated fly-to on top of OrbitControls.
//
// The Flutter UI covers the top (progress card) and bottom (selection
// card / sheet) of the WebView. `insets` describes those in CSS px; the
// projection is shifted so the orbit target sits in the middle of the
// visible area, and views are fitted to that area only.
import { MathUtils, Spherical, Vector3 } from 'three';

export const UP = new Vector3(0, 1, 0);

export const easeInOutCubic = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

const sA = new Spherical();
const sB = new Spherical();
const off = new Vector3();
const tmp = new Vector3();

/** Unit vector from the target towards the camera. */
export function dirFrom(inward, side, elevation, azimuth) {
  return new Vector3()
    .addScaledVector(inward, Math.cos(elevation) * Math.cos(azimuth))
    .addScaledVector(side, Math.cos(elevation) * Math.sin(azimuth))
    .addScaledVector(UP, Math.sin(elevation))
    .normalize();
}

export function boxCorners(box) {
  const { min, max } = box;
  const pts = [];
  for (const x of [min.x, max.x]) {
    for (const y of [min.y, max.y]) {
      for (const z of [min.z, max.z]) pts.push(new Vector3(x, y, z));
    }
  }
  return pts;
}

/** OrbitControls azimuth (atan2(x, z)) limits around a direction. */
export function azimuthLimits(dir, spread) {
  const centre = Math.atan2(dir.x, dir.z);
  const wrap = (a) => Math.atan2(Math.sin(a), Math.cos(a));
  return { minAzimuth: wrap(centre - spread), maxAzimuth: wrap(centre + spread) };
}

export class Rig {
  constructor(camera, controls) {
    this.camera = camera;
    this.controls = controls;
    this.insets = { top: 210, bottom: 230 };
    this.w = 1;
    this.h = 1;
    this.flight = null;
    this.current = null;
    this.interactive = true;
    this.rotateSpeed = controls.rotateSpeed;
  }

  setSize(w, h) {
    this.w = w;
    this.h = h;
  }

  /** Visible area in NDC: vertical centre + half height, horizontal half width. */
  safe() {
    const h = Math.max(1, this.h);
    const top = Math.min(Math.max(0, this.insets.top), h * 0.45);
    const bottom = Math.min(Math.max(0, this.insets.bottom), h * 0.62);
    const yMax = 1 - (2 * top) / h;
    const yMin = -1 + (2 * bottom) / h;
    return { shift: (yMax + yMin) / 2, half: Math.max(0.12, (yMax - yMin) / 2) * 0.92, x: 0.9 };
  }

  applyProjection() {
    const cam = this.camera;
    cam.updateProjectionMatrix();
    cam.projectionMatrix.elements[9] = -this.safe().shift;
    cam.projectionMatrixInverse.copy(cam.projectionMatrix).invert();
  }

  /** Smallest distance along `dir` so every point lands in the safe area. */
  fit(target, dir, points) {
    const cam = this.camera;
    const s = this.safe();
    const fwd = dir.clone().negate();
    const right = new Vector3().crossVectors(fwd, UP).normalize();
    const up = new Vector3().crossVectors(right, fwd);
    const tanV = Math.tan(MathUtils.degToRad(cam.fov / 2));
    const tanH = tanV * cam.aspect;
    let dist = 1;
    for (const p of points) {
      tmp.subVectors(p, target);
      const along = tmp.dot(dir);
      dist = Math.max(
        dist,
        along + Math.abs(tmp.dot(right)) / (tanH * s.x),
        along + Math.abs(tmp.dot(up)) / (tanV * s.half),
      );
    }
    return dist;
  }

  view(target, dir, points, limits = {}, pad = 1) {
    const dist = this.fit(target, dir, points) * pad;
    return {
      target: target.clone(),
      position: target.clone().addScaledVector(dir, dist),
      dist,
      limits: typeof limits === 'function' ? limits(dist) : limits,
    };
  }

  relax() {
    const c = this.controls;
    c.minDistance = 0;
    c.maxDistance = Infinity;
    c.minPolarAngle = 0;
    c.maxPolarAngle = Math.PI;
    c.minAzimuthAngle = -Infinity;
    c.maxAzimuthAngle = Infinity;
  }

  applyLimits(view) {
    const c = this.controls;
    const l = view.limits || {};
    c.minDistance = l.minDistance ?? 0;
    c.maxDistance = l.maxDistance ?? Infinity;
    c.minPolarAngle = l.minPolar ?? 0;
    c.maxPolarAngle = l.maxPolar ?? Math.PI;
    c.minAzimuthAngle = l.minAzimuth ?? -Infinity;
    c.maxAzimuthAngle = l.maxAzimuth ?? Infinity;
    // First-person views turn the head instead of orbiting: no dolly, and
    // a negative speed so the drag "grabs" the stadium like a panorama.
    c.enableZoom = l.zoom ?? true;
    c.rotateSpeed = l.rotateSpeed ?? this.rotateSpeed;
  }

  jump(view) {
    this.flight = null;
    this.current = view;
    this.camera.position.copy(view.position);
    this.controls.target.copy(view.target);
    this.camera.lookAt(view.target);
    this.applyLimits(view);
    this.controls.enabled = this.interactive;
    this.controls.update();
  }

  flyTo(view, duration = 1100) {
    const c = this.controls;
    // Flush any orbit momentum so it does not resume after landing.
    c.enableDamping = false;
    c.update();
    c.enableDamping = true;
    c.enabled = false;
    this.relax();
    this.current = view;
    this.flight = {
      fromT: c.target.clone(),
      fromP: this.camera.position.clone(),
      view,
      t: 0,
      duration: Math.max(0.05, duration / 1000),
      travel: c.target.distanceTo(view.target),
    };
  }

  /** Swap the destination of a flight in progress (e.g. insets changed). */
  retarget(view) {
    if (this.flight) {
      this.flight.view = view;
      this.current = view;
    }
  }

  get flying() {
    return !!this.flight;
  }

  /** Advances a flight; returns true while the camera is moving. */
  update(dt) {
    const f = this.flight;
    if (!f) return false;
    f.t = Math.min(1, f.t + dt / f.duration);
    const e = easeInOutCubic(f.t);
    const target = tmp.lerpVectors(f.fromT, f.view.target, e);
    sA.setFromVector3(off.subVectors(f.fromP, f.fromT));
    sB.setFromVector3(off.subVectors(f.view.position, f.view.target));
    let dTheta = sB.theta - sA.theta;
    dTheta = Math.atan2(Math.sin(dTheta), Math.cos(dTheta));
    const lift = 1 + Math.min(0.3, f.travel / 420) * Math.sin(Math.PI * e);
    const radius = Math.exp(MathUtils.lerp(Math.log(sA.radius), Math.log(sB.radius), e)) * lift;
    const phi = MathUtils.lerp(sA.phi, sB.phi, e);
    this.camera.position.setFromSphericalCoords(radius, phi, sA.theta + dTheta * e).add(target);
    this.camera.lookAt(target);
    if (f.t >= 1) {
      this.flight = null;
      this.controls.target.copy(f.view.target);
      this.camera.position.copy(f.view.position);
      this.applyLimits(f.view);
      this.controls.enabled = this.interactive;
      this.controls.update();
    }
    return true;
  }
}
