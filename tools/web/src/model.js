// Loads stadium.glb and turns it into something cheap to draw:
//  * every non-selectable mesh is baked (vertex colour x material colour)
//    into ONE static mesh; the roof and the floodlight lamps get their own
//    merged meshes so they can fade / switch on;
//  * selectable meshes (Stand_*, Block_*, Seats_*) keep their own unlit
//    material so they can be tinted for availability and highlights.
import { Box3, BufferGeometry, Color, Float32BufferAttribute, Mesh, MeshBasicMaterial, Vector3 } from 'three';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

const WHITE = new Color(1, 1, 1);

export async function loadStadium(url) {
  const draco = new DRACOLoader();
  draco.setDecoderPath('draco/');
  const loader = new GLTFLoader();
  loader.setDRACOLoader(draco);
  try {
    const gltf = await loader.loadAsync(url);
    return buildModel(gltf.scene);
  } finally {
    draco.dispose();
  }
}

function entityOf(obj) {
  for (let o = obj; o; o = o.parent) {
    if (o.userData && o.userData.stadia_kind) return o;
  }
  return null;
}

function topNode(obj, root) {
  let o = obj;
  while (o.parent && o.parent !== root) o = o.parent;
  return o;
}

/** World-space, non-indexed copy with colour = COLOR_0 x material colour. */
function baked(mesh) {
  const src = mesh.geometry;
  const g = src.index ? src.toNonIndexed() : src;
  const pos = g.getAttribute('position');
  const col = g.getAttribute('color');
  const mc = (mesh.material && mesh.material.color) || WHITE;
  const n = pos.count;
  const p = new Float32Array(n * 3);
  const c = new Float32Array(n * 3);
  const v = new Vector3();
  for (let i = 0; i < n; i++) {
    v.fromBufferAttribute(pos, i).applyMatrix4(mesh.matrixWorld);
    p[i * 3] = v.x;
    p[i * 3 + 1] = v.y;
    p[i * 3 + 2] = v.z;
    c[i * 3] = (col ? col.getX(i) : 1) * mc.r;
    c[i * 3 + 1] = (col ? col.getY(i) : 1) * mc.g;
    c[i * 3 + 2] = (col ? col.getZ(i) : 1) * mc.b;
  }
  if (g !== src) g.dispose();
  const out = new BufferGeometry();
  out.setAttribute('position', new Float32BufferAttribute(p, 3));
  out.setAttribute('color', new Float32BufferAttribute(c, 3));
  return out;
}

function merged(geoms, name, materialOptions = {}) {
  if (!geoms.length) return null;
  const g = mergeGeometries(geoms, false);
  for (const x of geoms) x.dispose();
  g.computeBoundingBox();
  g.computeBoundingSphere();
  const mesh = new Mesh(g, new MeshBasicMaterial({ vertexColors: true, ...materialOptions }));
  mesh.name = name;
  mesh.matrixAutoUpdate = false;
  return mesh;
}

function lampHeads(lamps) {
  if (!lamps) return [];
  const pos = lamps.geometry.getAttribute('position');
  const groups = new Map();
  const v = new Vector3();
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    const key = `${v.x > 0 ? 'E' : 'W'}${v.z > 0 ? 'S' : 'N'}`;
    const g = groups.get(key) || { sum: new Vector3(), n: 0 };
    g.sum.add(v);
    g.n++;
    groups.set(key, g);
  }
  return [...groups.values()].map((g) => g.sum.divideScalar(g.n));
}

export function buildModel(root) {
  root.updateMatrixWorld(true);
  const meshes = [];
  root.traverse((o) => {
    if (o.isMesh) meshes.push(o);
  });

  const statics = [];
  const roof = [];
  const lamp = [];
  const stands = new Map();
  const blocks = new Map();
  const pickables = [];
  const standOf = (id) => {
    let s = stands.get(id);
    if (!s) {
      s = { id, meshes: [], blocks: [] };
      stands.set(id, s);
    }
    return s;
  };
  const blockOf = (id) => {
    let b = blocks.get(id);
    if (!b) {
      b = { id };
      blocks.set(id, b);
    }
    return b;
  };

  for (const mesh of meshes) {
    const ent = entityOf(mesh);
    if (!ent) {
      const top = topNode(mesh, root).name;
      const mat = mesh.material && mesh.material.name;
      const bucket = top === 'Roof' ? roof : mat === 'M_Lamp' ? lamp : statics;
      bucket.push(baked(mesh));
      mesh.removeFromParent();
      mesh.geometry.dispose();
      mesh.material.dispose();
      continue;
    }

    const ex = ent.userData;
    const base = mesh.material.color.clone();
    mesh.material.dispose();
    mesh.material = new MeshBasicMaterial({ color: base.clone(), vertexColors: true });
    mesh.userData.base = base;
    mesh.userData.pick = { stand: ex.stadia_stand, block: ex.stadia_block || null };
    pickables.push(mesh);

    const st = standOf(ex.stadia_stand);
    if (ex.stadia_kind === 'stand') {
      st.meshes.push(mesh);
      if (!st.node) {
        st.node = ent;
        const o = ex.stadia_out; // Blender XY -> glTF (x, 0, -y)
        st.out = new Vector3(o[0], 0, -o[1]).normalize();
        st.side = new Vector3(-st.out.z, 0, st.out.x); // clockwise along the stand
        st.front = ent.getWorldPosition(new Vector3());
        st.length = ex.stadia_length;
        st.depth = ex.stadia_depth;
        st.height = ex.stadia_height;
      }
    } else {
      const b = blockOf(ex.stadia_block);
      b.stand = ex.stadia_stand;
      b.tier = ex.stadia_tier;
      b.number = String(ex.stadia_block).split('_')[1];
      if (ex.stadia_kind === 'block') {
        b.steps = mesh;
      } else if (ex.stadia_kind === 'seats') {
        b.seats = mesh;
        b.seatInfo = {
          rows: ex.stadia_rows,
          seats: ex.stadia_seats,
          w: ex.stadia_seat_width,
          d: ex.stadia_row_depth,
          rise: ex.stadia_row_rise,
        };
      }
    }
  }

  for (const b of blocks.values()) {
    standOf(b.stand).blocks.push(b);
    b.box = new Box3().setFromObject(b.steps || b.seats);
    if (b.seats) b.box.expandByObject(b.seats);
    b.centre = b.box.getCenter(new Vector3());
    b.labelPos = b.centre.clone().add(new Vector3(0, 2.4, 0));
  }

  const bowl = new Box3();
  for (const st of stands.values()) {
    st.blocks.sort((a, b) => (a.id < b.id ? -1 : 1));
    st.box = new Box3();
    for (const m of st.meshes) st.box.expandByObject(m);
    for (const b of st.blocks) st.box.union(b.box);
    st.pickMeshes = [...st.meshes, ...st.blocks.flatMap((b) => [b.steps, b.seats].filter(Boolean))];
    st.labelPos = st.front
      .clone()
      .addScaledVector(st.out, st.depth * 0.55)
      .add(new Vector3(0, st.height + 11, 0));
    bowl.union(st.box);
  }

  const staticMesh = merged(statics, 'Static');
  const roofMesh = merged(roof, 'Roof', { color: 0xc4ccd8 }); // keep the pitch the brightest thing
  const lampMesh = merged(lamp, 'Lamps', { color: 0xffffff });
  if (roofMesh) bowl.union(roofMesh.geometry.boundingBox);

  return {
    root,
    stands,
    blocks,
    pickables,
    staticMesh,
    roof: roofMesh,
    lamps: lampMesh,
    lampHeads: lampHeads(lampMesh),
    bowl,
  };
}
