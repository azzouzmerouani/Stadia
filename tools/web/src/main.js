// Stadia 3D viewer: stadium.glb + picking + camera fly-to + Flutter bridge.
// Modes (URL ?mode=): picker (default) | intro. Add &debug for stats and,
// in a plain browser, the dev harness in dev.js. At the buy step the camera
// sits in the chosen seat: the live, full-screen view from that seat.
import './compat.js';
import {
  AdditiveBlending,
  CanvasTexture,
  Fog,
  MathUtils,
  PerspectiveCamera,
  Raycaster,
  Scene,
  SRGBColorSpace,
  Sprite,
  SpriteMaterial,
  Vector2,
  Vector3,
  WebGLRenderer,
} from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { hasHost, onMessage, post, setReady } from './bridge.js';
import { azimuthLimits, boxCorners, dirFrom, easeInOutCubic, Rig } from './camera.js';
import { availColor, availCss, PALETTE } from './colors.js';
import { installDevHarness } from './dev.js';
import { Labels } from './labels.js';
import { loadStadium } from './model.js';
import { parseSeatId, SeatBlock } from './seats.js';
import { HORIZON, installSunFog, Sky } from './sky.js';

const params = new URLSearchParams(window.location.search);
const MODE = params.get('mode') === 'intro' ? 'intro' : 'picker';
const DEBUG = params.has('debug');
const SPIN = params.has('spin'); // perf testing: render every frame

const STEPS = ['stand', 'block', 'seat', 'buy'];
const DEFAULT_NAMES = { N: 'North Stand', E: 'East Stand', S: 'South Stand', W: 'West Stand' };

// ------------------------------------------------------------------ setup

const canvas = document.getElementById('stage');
const fadeEl = document.getElementById('fade');
const debugEl = document.getElementById('debug');

const renderer = new WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = SRGBColorSpace;
renderer.shadowMap.enabled = false;

installSunFog(); // before any material compiles
const scene = new Scene();
scene.background = HORIZON.clone();
// The city runs out to ~1.6 km: it fades into the horizon colour (warm
// towards the sunset, see installSunFog).
scene.fog = new Fog(HORIZON.clone(), 750, 2500);

const camera = new PerspectiveCamera(55, 1, 0.5, 3400);
const sky = new Sky(3000, renderer.getPixelRatio());
scene.add(sky.group);
const controls = new OrbitControls(camera, canvas);
controls.enableDamping = true;
controls.dampingFactor = 0.085;
controls.enablePan = false;
controls.rotateSpeed = 0.62;
controls.zoomSpeed = 0.9;

const rig = new Rig(camera, controls);
rig.interactive = MODE === 'picker';
const labels = new Labels(document.getElementById('labels'));

const S = {
  step: 'stand',
  stand: null,
  block: null,
  seat: null,
  standAvail: {},
  blockAvail: {},
  seatAvail: null, // {block, rows, seats, sold:Set}
  names: {},
  hover: null, // {level, id}
  press: null,
  external: null,
  seated: false, // buy step: first person from the seat, natural colours
};

let model = null;
let seatBlock = null;
let glows = [];
let dirty = true;
let roofOpacity = 1;
let lampLevel = MODE === 'intro' ? 0 : 1;
let intro = null;
let viewW = 1;
let viewH = 1;

// ----------------------------------------------------------------- layout

function resize() {
  viewW = window.innerWidth || 1;
  viewH = window.innerHeight || 1;
  renderer.setSize(viewW, viewH, false);
  camera.aspect = viewW / viewH;
  const vFov = 2 * Math.atan(Math.tan(MathUtils.degToRad(54 / 2)) / camera.aspect);
  camera.fov = MathUtils.clamp(MathUtils.radToDeg(vFov), 40, 62);
  rig.setSize(viewW, viewH);
  rig.applyProjection();
  dirty = true;
}

function updateNear() {
  const dist = camera.position.distanceTo(controls.target);
  const near = MathUtils.clamp(dist * 0.02, 0.2, 6);
  if (Math.abs(near - camera.near) / camera.near > 0.15) {
    camera.near = near;
    rig.applyProjection();
  }
}

// ------------------------------------------------------------------ views

function overviewView() {
  const target = model.bowl.getCenter(new Vector3());
  target.y = 4;
  const dir = dirFrom(new Vector3(0, 0, 1), new Vector3(1, 0, 0), 0.92, 0.2);
  return rig.view(target, dir, boxCorners(model.bowl), (d) => ({
    minDistance: d * 0.45,
    maxDistance: d * 2.2, // far enough to see the city round the stadium
    minPolar: 0.12,
    maxPolar: 1.3,
  }));
}

function standView(st) {
  const inward = st.out.clone().negate();
  const target = st.box.getCenter(new Vector3());
  const dir = dirFrom(inward, st.side, 0.5, 0.82);
  return rig.view(target, dir, boxCorners(st.box), (d) => ({
    minDistance: d * 0.35,
    maxDistance: d * 1.45,
    minPolar: 0.15,
    maxPolar: 1.36,
    ...azimuthLimits(inward, 1.3),
  }));
}

function blockView(b) {
  const st = model.stands.get(b.stand);
  const inward = st.out.clone().negate();
  const dir = dirFrom(inward, st.side, 0.62, 0.1);
  return rig.view(b.centre, dir, boxCorners(b.box), (d) => ({
    minDistance: 5,
    maxDistance: d * 1.8,
    minPolar: 0.15,
    maxPolar: 1.4,
    ...azimuthLimits(inward, 1.15),
  }), 0.96);
}

// First person from the seat: a seated fan's eyes (EYE m above the tread),
// turning the head around a point LOOK m in front of them.
const EYE = 1.15;
const LOOK = 0.25;

/** The fan's eye position for a seat id, in world space. */
function eyeAt(seatId) {
  const ref = parseSeatId(seatId);
  const b = ref && model.blocks.get(ref.block);
  if (!b || !b.seats || !b.seatInfo) return null;
  const { w, d, rise } = b.seatInfo;
  b.seats.updateMatrixWorld();
  const eye = new Vector3((ref.seat - 0.5) * w, (ref.row - 1) * rise + EYE, -((ref.row - 1) * d + 0.44));
  return { eye: eye.applyMatrix4(b.seats.matrixWorld), stand: model.stands.get(b.stand) };
}

function seatView(seatId) {
  const at = eyeAt(seatId);
  if (!at || !at.stand) return null;
  const { eye, stand } = at;
  // Face the pitch: between the centre spot and the touchline ahead.
  const focus = eye.clone().addScaledVector(stand.out, -70).multiplyScalar(0.4).setY(1.2);
  const look = focus.sub(eye).normalize();
  const back = look.clone().negate(); // target -> camera, as OrbitControls sees it
  return {
    target: eye.clone().addScaledVector(look, LOOK),
    position: eye,
    dist: LOOK,
    limits: {
      minDistance: LOOK,
      maxDistance: LOOK,
      // Polar angle of target -> camera: below 90° looks down at the pitch.
      minPolar: Math.PI / 2 - 1.05,
      maxPolar: Math.PI / 2 + 0.5,
      ...azimuthLimits(new Vector3(back.x, 0, back.z).normalize(), 1.9),
      zoom: false,
      rotateSpeed: -0.34,
    },
  };
}

function viewForState() {
  if (S.step === 'block' && model.stands.has(S.stand)) return standView(model.stands.get(S.stand));
  if (S.step === 'seat' && model.blocks.has(S.block)) return blockView(model.blocks.get(S.block));
  if (S.step === 'buy') return seatView(S.seat) || (model.blocks.has(S.block) && blockView(model.blocks.get(S.block))) || overviewView();
  return overviewView();
}

// ----------------------------------------------------------------- colour

function tone(mesh, avail, dim, hover) {
  if (!mesh) return;
  const c = mesh.material.color.copy(mesh.userData.base);
  if (avail) c.lerp(avail, 0.86);
  if (dim) c.lerp(PALETTE.dim, dim);
  if (hover) c.lerp(PALETTE.white, hover);
}

function highlighted() {
  return S.seated ? null : S.press || S.hover || S.external;
}

function applyColors() {
  if (!model) return;
  const hl = highlighted();
  const picking = S.step === 'seat' || S.step === 'buy';
  for (const st of model.stands.values()) {
    const selected = st.id === S.stand;
    let dim = 0;
    if (S.seated) dim = 0;
    else if (S.step === 'stand') dim = S.standAvail[st.id] === 0 ? 0.7 : 0;
    else dim = selected ? 0 : S.step === 'block' ? 0.8 : 0.86;
    const standHover = hl && hl.level === 'stand' && hl.id === st.id ? 0.3 : 0;
    for (const m of st.meshes) tone(m, null, dim, standHover);
    for (const b of st.blocks) {
      const showAvail = !S.seated && selected && S.step !== 'stand';
      const avail = showAvail ? availColor(S.blockAvail[b.id]) : null;
      const bDim = !S.seated && selected && picking && b.id !== S.block ? 0.55 : dim;
      const bHover = hl && hl.level === 'block' && hl.id === b.id ? 0.32 : standHover;
      tone(b.steps, null, bDim, bHover);
      tone(b.seats, avail, bDim, bHover);
    }
  }
  dirty = true;
}

function syncSeatBlock() {
  if (!model) return;
  const want = !S.seated && S.step === 'seat' ? S.block : null;
  if (seatBlock && seatBlock.blockId !== want) {
    const old = model.blocks.get(seatBlock.blockId);
    if (old && old.seats) old.seats.visible = true;
    seatBlock.dispose();
    seatBlock = null;
  }
  if (want && !seatBlock) {
    const b = model.blocks.get(want);
    if (b && b.seats && b.seatInfo) {
      seatBlock = new SeatBlock(b);
      scene.add(seatBlock.mesh);
      b.seats.visible = false;
    }
  }
  if (seatBlock) {
    const hl = highlighted();
    const sold = S.seatAvail && S.seatAvail.block === seatBlock.blockId ? S.seatAvail.sold : null;
    seatBlock.paint({
      sold,
      selected: null,
      hover: hl && hl.level === 'seat' ? hl.id : null,
    });
  }
  dirty = true;
}

function setRoof(opacity) {
  if (!model || !model.roof) return;
  const m = model.roof.material;
  m.opacity = opacity;
  m.transparent = opacity < 0.999;
  m.depthWrite = opacity > 0.6;
  model.roof.visible = opacity > 0.01;
}

function setLamps(level) {
  if (model && model.lamps) {
    model.lamps.material.color.setScalar(0.22 + 0.78 * level);
  }
  for (const g of glows) g.material.opacity = 0.85 * level;
  dirty = true;
}

// ----------------------------------------------------------------- labels

function syncLabels() {
  const items = [];
  if (model && MODE === 'picker') {
    if (S.step === 'stand') {
      for (const st of model.stands.values()) {
        const r = S.standAvail[st.id];
        items.push({
          key: `st-${st.id}`,
          text: S.names[st.id] || DEFAULT_NAMES[st.id] || st.id,
          color: availCss(r),
          cls: `stand${r === 0 ? ' sold' : ''}`,
          pos: st.labelPos,
        });
      }
    } else if (S.step === 'block' && model.stands.has(S.stand)) {
      const hl = highlighted();
      for (const b of model.stands.get(S.stand).blocks) {
        const r = S.blockAvail[b.id];
        items.push({
          key: `b-${b.id}`,
          text: b.number,
          color: availCss(r),
          cls: `block${r === 0 ? ' sold' : ''}${hl && hl.id === b.id ? ' on' : ''}`,
          pos: b.labelPos,
        });
      }
    }
  }
  labels.set(items);
  dirty = true;
}

// ---------------------------------------------------------------- picking

const raycaster = new Raycaster();
const ndc = new Vector2();

function standFromPoint(p) {
  const ex = Math.max(1, (model.bowl.max.x - model.bowl.min.x) / 2);
  const ez = Math.max(1, (model.bowl.max.z - model.bowl.min.z) / 2);
  let best = null;
  let score = -Infinity;
  for (const st of model.stands.values()) {
    const s = (p.x * st.out.x) / ex + (p.z * st.out.z) / ez;
    if (s > score) {
      score = s;
      best = st.id;
    }
  }
  return best;
}

function hitAt(clientX, clientY) {
  if (!model) return null;
  const rect = canvas.getBoundingClientRect();
  ndc.set(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
  camera.updateMatrixWorld();
  raycaster.setFromCamera(ndc, camera);

  let targets;
  if (S.step === 'seat' || S.step === 'buy') {
    const st = model.stands.get(S.stand);
    targets = st ? st.pickMeshes.slice() : [];
    if (seatBlock) targets.unshift(seatBlock.mesh);
  } else {
    targets = model.pickables.slice();
    if (S.step === 'stand' && model.roof && model.roof.visible) targets.push(model.roof);
  }

  for (const h of raycaster.intersectObjects(targets, false)) {
    if (h.object === model.roof) return { stand: standFromPoint(h.point) };
    if (seatBlock && h.object === seatBlock.mesh) {
      return { stand: S.stand, block: seatBlock.blockId, seat: seatBlock.idOf(h.instanceId) };
    }
    const p = h.object.userData.pick;
    if (!p) continue;
    if (seatBlock && p.block === seatBlock.blockId) {
      return { stand: p.stand, block: p.block, seat: seatBlock.idAtPoint(h.point) };
    }
    return { stand: p.stand, block: p.block };
  }
  return null;
}

/** What a tap on `hit` selects at the current step (mirrors BookingMachine). */
function selectionFor(hit) {
  if (!hit) return null;
  switch (S.step) {
    case 'stand':
      return hit.stand ? { level: 'stand', id: hit.stand } : null;
    case 'block':
      if (hit.stand === S.stand && hit.block) return { level: 'block', id: hit.block };
      if (hit.stand && hit.stand !== S.stand) return { level: 'stand', id: hit.stand };
      return null;
    case 'seat':
      if (hit.block === S.block && hit.seat) return { level: 'seat', id: hit.seat };
      if (hit.stand === S.stand && hit.block && hit.block !== S.block) return { level: 'block', id: hit.block };
      return null;
    default:
      return null;
  }
}

function sameSel(a, b) {
  return (a && a.level) === (b && b.level) && (a && a.id) === (b && b.id);
}

function setHighlight(kind, sel) {
  if (sameSel(S[kind], sel)) return;
  S[kind] = sel;
  applyColors();
  syncSeatBlock();
  if (S.step === 'block') syncLabels();
}

let down = null;
let hoverQueued = null;

canvas.addEventListener('pointerdown', (e) => {
  if (!model || MODE !== 'picker' || rig.flying) return;
  if (down) {
    down.multi = true;
    setHighlight('press', null);
    return;
  }
  down = { id: e.pointerId, x: e.clientX, y: e.clientY, t: performance.now(), moved: false, multi: false };
  if (e.pointerType !== 'mouse') setHighlight('press', selectionFor(hitAt(e.clientX, e.clientY)));
});

window.addEventListener('pointermove', (e) => {
  if (down && e.pointerId === down.id) {
    if (!down.moved && Math.hypot(e.clientX - down.x, e.clientY - down.y) > 8) {
      down.moved = true;
      setHighlight('press', null);
    }
  } else if (!down && e.pointerType === 'mouse' && MODE === 'picker') {
    hoverQueued = { x: e.clientX, y: e.clientY };
  }
});

function endPointer(e, cancelled) {
  if (!down || e.pointerId !== down.id) return;
  const tap = !cancelled && !down.moved && !down.multi && performance.now() - down.t < 450;
  down = null;
  setHighlight('press', null);
  if (!tap || rig.flying) return;
  const sel = selectionFor(hitAt(e.clientX, e.clientY));
  if (sel) post({ type: 'select', level: sel.level, id: sel.id });
}

window.addEventListener('pointerup', (e) => endPointer(e, false));
window.addEventListener('pointercancel', (e) => endPointer(e, true));
canvas.addEventListener('pointerleave', () => {
  hoverQueued = null;
  setHighlight('hover', null);
});

function processHover() {
  if (!hoverQueued || rig.flying) return;
  const { x, y } = hoverQueued;
  hoverQueued = null;
  const sel = selectionFor(hitAt(x, y));
  canvas.style.cursor = sel ? 'pointer' : 'grab';
  setHighlight('hover', sel);
}

// --------------------------------------------------------------- messages

function onSetStep(m) {
  const prev = { step: S.step, stand: S.stand, block: S.block, seat: S.seat };
  S.step = STEPS.includes(m.step) ? m.step : 'stand';
  S.stand = m.stand || null;
  S.block = m.block || null;
  S.seat = m.seat || null;
  S.seated = S.step === 'buy' && !!S.seat;
  S.hover = null;
  S.press = null;
  syncSeatBlock();
  applyColors();
  syncLabels();
  const same = prev.step === S.step && prev.stand === S.stand && prev.block === S.block && prev.seat === S.seat;
  if (!same && MODE === 'picker') {
    // Into (or out of) the seat is a longer, lower flight.
    const seatMove = S.step === 'buy' || prev.step === 'buy';
    rig.flyTo(viewForState(), seatMove ? 1500 : prev.step === S.step ? 900 : 1150);
  }
}

function onAvailability(m) {
  if (m.level === 'stand') S.standAvail = m.items || {};
  else if (m.level === 'block') S.blockAvail = m.items || {};
  else if (m.level === 'seat') {
    S.seatAvail = { block: m.block, rows: m.rows, seats: m.seats, sold: new Set(m.sold || []) };
  }
  applyColors();
  syncSeatBlock();
  syncLabels();
}

function parseHighlight(id) {
  if (!id) return null;
  const clean = String(id).replace(/^(Stand|Block|Seats)_/, '');
  if (parseSeatId(clean)) return { level: 'seat', id: clean };
  return clean.includes('_') ? { level: 'block', id: clean } : { level: 'stand', id: clean };
}

function onInsets(m) {
  const next = { top: Number(m.top) || 0, bottom: Number(m.bottom) || 0 };
  const moved = Math.abs(next.top - rig.insets.top) > 2 || Math.abs(next.bottom - rig.insets.bottom) > 2;
  rig.insets = next;
  rig.applyProjection();
  dirty = true;
  if (!model || !moved || MODE !== 'picker') return;
  if (rig.flying) rig.retarget(viewForState());
  else rig.flyTo(viewForState(), 650);
}

onMessage((m) => {
  switch (m.type) {
    case 'setStep':
      onSetStep(m);
      break;
    case 'availability':
      onAvailability(m);
      break;
    case 'highlight':
      setHighlight('external', parseHighlight(m.id));
      break;
    case 'labels':
      S.names = m.items || {};
      syncLabels();
      break;
    case 'insets':
      onInsets(m);
      break;
    case 'skipIntro':
      finishIntro();
      break;
    default:
      break; // init and unknown types
  }
});

// ------------------------------------------------------------------ intro

const INTRO_SECONDS = 6.6;

function startIntro() {
  const end = overviewView();
  const target = end.target.clone();
  intro = { t: 0, target, dist: end.dist, done: false };
  controls.enabled = false;
  setLamps(0);
}

function updateIntro(dt) {
  intro.t += dt;
  const k = Math.min(1, intro.t / INTRO_SECONDS);
  const e = easeInOutCubic(k);
  const az = MathUtils.lerp(-1.25, 0.2, e) + (intro.done ? (intro.t - INTRO_SECONDS) * 0.03 : 0);
  const el = MathUtils.lerp(0.2, 0.86, e);
  const r = intro.dist * MathUtils.lerp(2.0, 1.0, e); // from over the city
  const dir = dirFrom(new Vector3(0, 0, 1), new Vector3(1, 0, 0), el, az);
  camera.position.copy(intro.target).addScaledVector(dir, r);
  camera.lookAt(intro.target);
  controls.target.copy(intro.target);
  // Floodlights flicker on, then hold.
  const t = intro.t;
  const lamp = t < 0.9 ? 0 : t < 1.0 ? 1 : t < 1.12 ? 0.25 : Math.min(1, 0.6 + (t - 1.12) * 2);
  if (lamp !== lampLevel) {
    lampLevel = lamp;
    setLamps(lamp);
  }
  if (k >= 1 && !intro.done) finishIntro();
}

function finishIntro() {
  if (!intro || intro.done) return;
  intro.done = true;
  intro.t = Math.max(intro.t, INTRO_SECONDS);
  lampLevel = 1;
  setLamps(1);
  post({ type: 'introDone' });
}

// ----------------------------------------------------------------- extras

function glowTexture() {
  const c = document.createElement('canvas');
  c.width = 64;
  c.height = 64;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, 'rgba(255,255,255,1)');
  grad.addColorStop(0.25, 'rgba(255,255,255,0.45)');
  grad.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 64, 64);
  const tex = new CanvasTexture(c);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

function addExtras() {
  const tex = glowTexture();
  glows = model.lampHeads.map((p) => {
    const s = new Sprite(
      new SpriteMaterial({
        map: tex,
        color: PALETTE.lamp,
        transparent: true,
        blending: AdditiveBlending,
        depthWrite: false,
        opacity: 0,
      }),
    );
    s.position.copy(p).add(new Vector3(-p.x, 0, -p.z).normalize().multiplyScalar(2));
    s.scale.setScalar(34);
    scene.add(s);
    return s;
  });
}

// ------------------------------------------------------------------- loop

let last = performance.now();
let frames = 0;
let statsAt = performance.now();
let renderMs = 0;

function render() {
  const t0 = performance.now();
  sky.follow(camera);
  renderer.render(scene, camera);
  renderMs = performance.now() - t0;
  labels.update(camera, viewW, viewH);
  frames++;
}

function stats(now) {
  if (now - statsAt < 1000) return;
  const fps = Math.round((frames * 1000) / (now - statsAt));
  const info = renderer.info.render;
  frames = 0;
  statsAt = now;
  if (DEBUG) {
    debugEl.textContent = `${fps} fps (rendered) · ${renderMs.toFixed(1)} ms cpu\n${info.calls} calls · ${info.triangles} tris · dpr ${renderer.getPixelRatio()}\n${S.step} ${S.stand || ''} ${S.block || ''} ${S.seat || ''}`;
    if (hasHost()) post({ type: 'stats', fps, calls: info.calls, triangles: info.triangles });
  }
}

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  if (!model) return;
  let moving = false;
  if (intro) {
    updateIntro(dt);
    moving = true;
  } else if (rig.update(dt)) {
    moving = true;
  } else if (controls.enabled && controls.update()) {
    moving = true;
  }
  processHover();

  // Roof on for the overview, off while choosing, back on once seated (it
  // is part of the real view, so it returns after the flight lands).
  const roofTarget = MODE === 'intro' || S.step === 'stand' || (S.seated && !rig.flying) ? 1 : 0;
  if (Math.abs(roofTarget - roofOpacity) > 0.001) {
    roofOpacity += (roofTarget - roofOpacity) * Math.min(1, dt * 5);
    if (Math.abs(roofTarget - roofOpacity) < 0.01) roofOpacity = roofTarget;
    setRoof(roofOpacity);
    moving = true;
  }
  updateNear();

  if (moving || dirty || SPIN) {
    if (SPIN && !intro && !rig.flying) {
      controls.autoRotate = true;
      controls.autoRotateSpeed = 1.2;
    }
    render();
    dirty = false;
  }
  stats(now);
}

// ------------------------------------------------------------------- boot

canvas.addEventListener('webglcontextlost', (e) => {
  e.preventDefault();
  post({ type: 'error', message: 'The 3D view lost its graphics context' });
});
canvas.addEventListener('webglcontextrestored', () => window.location.reload());
window.addEventListener('resize', resize);

const T0 = performance.now();

async function boot() {
  resize();
  let tModel = 0;
  try {
    model = await loadStadium('3d/stadium.glb');
    tModel = performance.now();
  } catch (err) {
    console.error(err);
    post({ type: 'error', message: 'Could not load the stadium model' });
    return;
  }
  scene.add(model.root);
  if (model.staticMesh) scene.add(model.staticMesh);
  if (model.roof) scene.add(model.roof);
  if (model.lamps) scene.add(model.lamps);
  addExtras();
  setLamps(lampLevel);

  if (MODE === 'intro') startIntro();
  else rig.jump(overviewView());
  applyColors();
  syncLabels();
  if (DEBUG) {
    window.__stadia = {
      S,
      model,
      rig,
      camera,
      controls,
      renderer,
      scene,
      // Finish flights/fades now (background tabs throttle rAF).
      settle() {
        while (rig.flying) rig.update(0.1);
        roofOpacity = MODE === 'intro' || S.step === 'stand' || S.seated ? 1 : 0;
        setRoof(roofOpacity);
        updateNear();
        render();
        return { step: S.step, calls: renderer.info.render.calls };
      },
    };
    if (!hasHost()) installDevHarness(model, (t) => console.log('[dev]', t));
  }

  renderer.compile(scene, camera);
  if (intro) updateIntro(0);
  render();
  requestAnimationFrame((now) => {
    last = now;
    fadeEl.style.opacity = '0';
    setReady();
    const ms = (t) => Math.round(t);
    post({
      type: 'ready',
      // ms since navigation start: script start, model decoded, first frame
      timings: { script: ms(T0), model: ms(tModel), frame: ms(performance.now()) },
    });
    requestAnimationFrame(frame);
  });
}

boot();
