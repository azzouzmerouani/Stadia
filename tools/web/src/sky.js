// Night sky: a gradient dome with stars and a moon over the sea. It follows
// the camera, so it is always "at infinity"; the fog uses the horizon
// colour, so the far city and the hills melt into it.
import {
  AdditiveBlending,
  BackSide,
  BufferGeometry,
  CanvasTexture,
  Color,
  Float32BufferAttribute,
  Group,
  Mesh,
  MeshBasicMaterial,
  Points,
  PointsMaterial,
  SphereGeometry,
  SRGBColorSpace,
  Sprite,
  SpriteMaterial,
  Vector3,
} from 'three';

export const HORIZON = new Color('#2A0A36');
const GLOW = new Color('#4A1A52'); // city light just above the horizon
const ZENITH = new Color('#0A0011');

function mulberry32(seed) {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function dome(radius) {
  const g = new SphereGeometry(radius, 48, 24);
  const pos = g.getAttribute('position');
  const colors = new Float32Array(pos.count * 3);
  const c = new Color();
  for (let i = 0; i < pos.count; i++) {
    const h = pos.getY(i) / radius; // -1 .. 1
    if (h <= 0) c.copy(HORIZON);
    else if (h < 0.08) c.copy(HORIZON).lerp(GLOW, Math.sin((h / 0.08) * Math.PI) * 0.6);
    else c.copy(HORIZON).lerp(ZENITH, Math.min(1, Math.pow((h - 0.08) / 0.62, 0.7)));
    c.toArray(colors, i * 3);
  }
  g.setAttribute('color', new Float32BufferAttribute(colors, 3));
  const m = new Mesh(
    g,
    new MeshBasicMaterial({ vertexColors: true, side: BackSide, fog: false, depthWrite: false, depthTest: false }),
  );
  m.renderOrder = -2;
  m.name = 'SkyDome';
  return m;
}

function stars(radius, count) {
  const rand = mulberry32(2026);
  const p = [];
  const col = [];
  const v = new Vector3();
  while (p.length < count * 3) {
    v.set(rand() * 2 - 1, rand(), rand() * 2 - 1);
    const len = v.length();
    if (len > 1 || len < 0.2) continue;
    v.divideScalar(len);
    if (v.y < 0.1) continue;
    const b = 0.35 + 0.65 * Math.pow(rand(), 2.2) * Math.min(1, v.y / 0.35 + 0.3);
    v.multiplyScalar(radius);
    p.push(v.x, v.y, v.z);
    const warm = rand() < 0.2;
    col.push(b, b * (warm ? 0.9 : 0.97), b * (warm ? 0.78 : 1));
  }
  const g = new BufferGeometry();
  g.setAttribute('position', new Float32BufferAttribute(p, 3));
  g.setAttribute('color', new Float32BufferAttribute(col, 3));
  const m = new Points(
    g,
    new PointsMaterial({
      size: 1.6,
      sizeAttenuation: false,
      vertexColors: true,
      fog: false,
      depthWrite: false,
    }),
  );
  m.renderOrder = -1; // opaque pass, right after the dome: the city covers it
  m.name = 'Stars';
  return m;
}

function moonTexture() {
  const c = document.createElement('canvas');
  c.width = 128;
  c.height = 128;
  const g = c.getContext('2d');
  const halo = g.createRadialGradient(64, 64, 8, 64, 64, 64);
  halo.addColorStop(0, 'rgba(255,248,230,0.55)');
  halo.addColorStop(0.3, 'rgba(220,200,255,0.16)');
  halo.addColorStop(1, 'rgba(200,160,255,0)');
  g.fillStyle = halo;
  g.fillRect(0, 0, 128, 128);
  g.fillStyle = '#FFF6E4';
  g.beginPath();
  g.arc(64, 64, 11, 0, Math.PI * 2);
  g.fill();
  const tex = new CanvasTexture(c);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

/** The sky group; call follow(camera) before each render. */
export class Sky {
  constructor(radius) {
    this.group = new Group();
    this.group.name = 'Sky';
    this.group.add(dome(radius));
    this.group.add(stars(radius * 0.96, 520));
    const moon = new Sprite(
      new SpriteMaterial({
        map: moonTexture(),
        fog: false,
        transparent: true,
        depthWrite: false,
        blending: AdditiveBlending,
      }),
    );
    // North-east, over the sea (glTF: +X east, -Z north).
    moon.position.set(0.5, 0.42, -0.76).normalize().multiplyScalar(radius * 0.9);
    moon.scale.setScalar(radius * 0.11);
    moon.renderOrder = -1;
    this.group.add(moon);
  }

  follow(camera) {
    this.group.position.copy(camera.position);
    this.group.updateMatrixWorld(true);
  }
}
