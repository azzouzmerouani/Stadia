// Per-seat InstancedMesh for the selected block. The merged Seats_* mesh
// from the glb is hidden while this is shown; the seat profile below is the
// same one tools/blender/build_stadium.py extrudes per row.
import {
  BufferGeometry,
  Color,
  DynamicDrawUsage,
  Float32BufferAttribute,
  InstancedMesh,
  Matrix4,
  MeshBasicMaterial,
  Quaternion,
  ShapeUtils,
  Vector2,
  Vector3,
} from 'three';
import { PALETTE } from './colors.js';

// (y = back, z = up) in the Seats node's Blender frame, relative to a row.
const PROFILE = [
  [0.14, 0.0],
  [0.14, 0.4],
  [0.5, 0.44],
  [0.58, 0.86],
  [0.68, 0.86],
  [0.68, 0.0],
];
const HALF_WIDTH = 0.2;
// Blender SUN (0.35, -0.55, 0.76) in glTF axes.
const SUN = new Vector3(0.35, 0.76, 0.55).normalize();

/** Blender-local (x, y, z) -> glTF-local (x, z, -y). */
const P = (x, y, z) => new Vector3(x, z, -y);

const bake = (n) => {
  const v = 0.42 + 0.4 * Math.max(0, n.dot(SUN)) + 0.18 * (0.5 + 0.5 * n.y);
  return Math.pow(Math.min(1, v), 1.35);
};

function seatGeometry(worldQuat) {
  const pos = [];
  const col = [];
  const ab = new Vector3();
  const ac = new Vector3();
  const tri = (a, b, c, outward) => {
    const n = ab.subVectors(b, a).cross(ac.subVectors(c, a)).normalize();
    if (n.dot(outward) < 0) {
      [b, c] = [c, b];
      n.negate();
    }
    const l = bake(n.clone().applyQuaternion(worldQuat));
    for (const p of [a, b, c]) {
      pos.push(p.x, p.y, p.z);
      col.push(l, l, l);
    }
  };

  let area = 0;
  for (let i = 0; i < PROFILE.length; i++) {
    const [ya, za] = PROFILE[i];
    const [yb, zb] = PROFILE[(i + 1) % PROFILE.length];
    area += ya * zb - yb * za;
  }
  const sign = area > 0 ? 1 : -1;
  for (let i = 0; i < PROFILE.length - 1; i++) { // last edge is the hidden bottom
    const [ya, za] = PROFILE[i];
    const [yb, zb] = PROFILE[i + 1];
    const out = P(0, sign * (zb - za), -sign * (yb - ya));
    const a = P(-HALF_WIDTH, ya, za);
    const b = P(HALF_WIDTH, ya, za);
    const c = P(HALF_WIDTH, yb, zb);
    const d = P(-HALF_WIDTH, yb, zb);
    tri(a, b, c, out);
    tri(a, c, d, out);
  }
  const contour = PROFILE.map(([y, z]) => new Vector2(y, z));
  const caps = ShapeUtils.triangulateShape(contour, []);
  for (const x of [-HALF_WIDTH, HALF_WIDTH]) {
    const out = new Vector3(Math.sign(x), 0, 0);
    for (const [i, j, k] of caps) {
      tri(P(x, ...PROFILE[i]), P(x, ...PROFILE[j]), P(x, ...PROFILE[k]), out);
    }
  }

  const g = new BufferGeometry();
  g.setAttribute('position', new Float32BufferAttribute(pos, 3));
  g.setAttribute('color', new Float32BufferAttribute(col, 3));
  g.computeBoundingSphere();
  return g;
}

const SEAT_RE = /^([A-Z]+_\d+)_R(\d+)_S(\d+)$/;

export function parseSeatId(id) {
  const m = SEAT_RE.exec(String(id || ''));
  return m ? { block: m[1], row: Number(m[2]), seat: Number(m[3]) } : null;
}

export class SeatBlock {
  constructor(block) {
    const node = block.seats;
    const info = block.seatInfo;
    this.blockId = block.id;
    this.info = info;
    this.base = node.userData.base.clone();
    node.updateWorldMatrix(true, false);
    this.world = node.matrixWorld.clone();
    this.inverse = this.world.clone().invert();

    const q = new Quaternion();
    this.world.decompose(new Vector3(), q, new Vector3());
    const count = info.rows * info.seats;
    this.mesh = new InstancedMesh(seatGeometry(q), new MeshBasicMaterial({ vertexColors: true }), count);
    this.mesh.name = `SeatInstances_${block.id}`;
    this.mesh.matrixAutoUpdate = false;
    this.mesh.matrix.copy(this.world);
    this.mesh.matrixWorldNeedsUpdate = true;

    // Height-based AO, same curve as the Blender bake (applied before ^1.35).
    const baseY = this.world.elements[13];
    this.ao = new Float32Array(info.rows);
    for (let r = 0; r < info.rows; r++) {
      const h = baseY + r * info.rise + 0.4;
      this.ao[r] = Math.pow(0.78 + 0.22 * Math.min(1, Math.max(0, h / 26)), 1.35);
    }

    const m = new Matrix4();
    for (let r = 0; r < info.rows; r++) {
      for (let s = 0; s < info.seats; s++) {
        m.makeTranslation((s + 0.5) * info.w, r * info.rise, -r * info.d);
        this.mesh.setMatrixAt(r * info.seats + s, m);
      }
    }
    this.mesh.instanceMatrix.needsUpdate = true;
    this.mesh.setColorAt(0, this.base);
    this.mesh.instanceColor.setUsage(DynamicDrawUsage);
    this.mesh.computeBoundingSphere();
    this.paint({});
  }

  idOf(index) {
    const r = Math.floor(index / this.info.seats);
    const s = index % this.info.seats;
    return `${this.blockId}_R${r + 1}_S${s + 1}`;
  }

  indexOf(seatId) {
    const ref = parseSeatId(seatId);
    if (!ref || ref.block !== this.blockId) return -1;
    if (ref.row < 1 || ref.row > this.info.rows || ref.seat < 1 || ref.seat > this.info.seats) return -1;
    return (ref.row - 1) * this.info.seats + (ref.seat - 1);
  }

  /** Nearest seat to a world point on the block (forgiving taps). */
  idAtPoint(world) {
    const p = world.clone().applyMatrix4(this.inverse);
    const { rows, seats, w, d } = this.info;
    const s = Math.min(seats - 1, Math.max(0, Math.floor(p.x / w)));
    const r = Math.min(rows - 1, Math.max(0, Math.floor(-p.z / d)));
    return this.idOf(r * seats + s);
  }

  /** World position of a seat, `up` metres above its tread. */
  seatPosition(seatId, up = 0.6, target = new Vector3()) {
    const ref = parseSeatId(seatId);
    if (!ref) return null;
    const { w, d, rise } = this.info;
    return target
      .set((ref.seat - 0.5) * w, (ref.row - 1) * rise + up, -((ref.row - 1) * d + 0.42))
      .applyMatrix4(this.world);
  }

  paint({ sold = null, selected = null, hover = null }) {
    const c = new Color();
    const sel = selected ? this.indexOf(selected) : -1;
    const hov = hover ? this.indexOf(hover) : -1;
    const { rows, seats } = this.info;
    for (let r = 0; r < rows; r++) {
      for (let s = 0; s < seats; s++) {
        const i = r * seats + s;
        if (i === sel) c.copy(PALETTE.white);
        else if (i === hov) c.copy(PALETTE.focus);
        else if (!sold) c.copy(this.base);
        else c.copy(sold.has(i) ? PALETTE.sold : PALETTE.free);
        this.mesh.setColorAt(i, c.multiplyScalar(this.ao[r]));
      }
    }
    this.mesh.instanceColor.needsUpdate = true;
  }

  dispose() {
    this.mesh.removeFromParent();
    this.mesh.geometry.dispose();
    this.mesh.material.dispose();
    this.mesh.dispose();
  }
}
