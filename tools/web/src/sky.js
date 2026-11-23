// Matchday dusk: the sun setting in the west-south-west behind the main
// stand, a sunset sky with the first stars overhead and the moon rising in
// the east. The sky follows the camera, so it is always "at infinity". The
// fog is tinted towards the sun, so the far city melts into a warm haze on
// that side and into dusky purple on the other.
import {
  AdditiveBlending,
  BackSide,
  BufferGeometry,
  CanvasTexture,
  Color,
  Float32BufferAttribute,
  Group,
  Mesh,
  Points,
  PointsMaterial,
  ShaderChunk,
  ShaderMaterial,
  SphereGeometry,
  SRGBColorSpace,
  Sprite,
  SpriteMaterial,
  Vector3,
} from 'three';
import { Lensflare, LensflareElement } from 'three/addons/objects/Lensflare.js';

// Towards the sun, in viewer axes (+X east, +Y up, -Z north): azimuth 250
// deg, 20 deg up. Same as SUNSET in tools/blender/build_stadium.py, whose
// (x, y, z) maps to (x, z, -y) here.
export const SUN_DIR = new Vector3(-0.883, 0.342, 0.321).normalize();

export const HORIZON = new Color('#552062'); // fog and horizon away from the sun
const HAZE = new Color('#E07A52'); // fog and horizon towards the sun
const MID = new Color('#3A0E52');
const ZENITH = new Color('#120026');
const BAND = new Color('#E8457A'); // magenta band above the sunset
const ORANGE = new Color('#FF9A4A');
const GOLD = new Color('#FFD58A');

const v3 = (c) => `vec3(${c.r.toFixed(4)}, ${c.g.toFixed(4)}, ${c.b.toFixed(4)})`;
const dir3 = (v) => `vec3(${v.x.toFixed(4)}, ${v.y.toFixed(4)}, ${v.z.toFixed(4)})`;

/**
 * Tints the scene fog towards the sun. Patches three's fog chunks, so call
 * it once before anything is compiled.
 */
export function installSunFog() {
  ShaderChunk.fog_pars_vertex = `
#ifdef USE_FOG
  varying float vFogDepth;
  varying vec3 vFogDir;
#endif`;
  ShaderChunk.fog_vertex = `
#ifdef USE_FOG
  vFogDepth = - mvPosition.z;
  vFogDir = ( vec4( mvPosition.xyz, 0.0 ) * viewMatrix ).xyz; // world-space view ray
#endif`;
  ShaderChunk.fog_pars_fragment = `
#ifdef USE_FOG
  uniform vec3 fogColor;
  varying float vFogDepth;
  varying vec3 vFogDir;
  #ifdef FOG_EXP2
    uniform float fogDensity;
  #else
    uniform float fogNear;
    uniform float fogFar;
  #endif
#endif`;
  ShaderChunk.fog_fragment = `
#ifdef USE_FOG
  #ifdef FOG_EXP2
    float fogFactor = 1.0 - exp( - fogDensity * fogDensity * vFogDepth * vFogDepth );
  #else
    float fogFactor = smoothstep( fogNear, fogFar, vFogDepth );
  #endif
  float sunFog = pow( max( dot( normalize( vFogDir ), ${dir3(SUN_DIR)} ), 0.0 ), 3.0 );
  gl_FragColor.rgb = mix( gl_FragColor.rgb, mix( fogColor, ${v3(HAZE)}, sunFog * 0.85 ), fogFactor );
#endif`;
}

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
  const m = new Mesh(
    new SphereGeometry(radius, 48, 24),
    new ShaderMaterial({
      side: BackSide,
      depthWrite: false,
      depthTest: false,
      vertexShader: `
        varying vec3 vDir;
        void main() {
          vDir = position;
          gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
        }`,
      fragmentShader: `
        varying vec3 vDir;
        void main() {
          vec3 d = normalize( vDir );
          vec3 sun = ${dir3(SUN_DIR)};
          float h = d.y;
          float hp = max( h, 0.0 );
          float s = max( dot( d, sun ), 0.0 );
          float side = max( dot( normalize( d.xz + 1e-5 ), normalize( sun.xz ) ), 0.0 );

          vec3 col = mix( ${v3(HORIZON)}, ${v3(MID)}, smoothstep( 0.0, 0.3, hp ) );
          col = mix( col, ${v3(ZENITH)}, smoothstep( 0.25, 0.95, hp ) );
          float band = 1.0 - smoothstep( 0.0, 0.45, hp );
          col = mix( col, ${v3(BAND)}, band * pow( side, 1.6 ) * 0.7 );
          col = mix( col, ${v3(ORANGE)}, band * band * pow( side, 5.0 ) * 0.9 );
          col += ${v3(ORANGE)} * pow( s, 7.0 ) * 0.22 + ${v3(GOLD)} * ( pow( s, 28.0 ) * 0.4 + pow( s, 220.0 ) * 0.8 );
          col = mix( col, vec3( 1.0, 0.95, 0.84 ), smoothstep( 0.99955, 0.99975, s ) );

          // At and below the horizon, match the fog so the far ground blends in.
          float sunFog = pow( s, 3.0 );
          vec3 fog = mix( ${v3(HORIZON)}, ${v3(HAZE)}, sunFog * 0.85 );
          col = mix( fog, col, smoothstep( -0.02, 0.05, h ) );
          gl_FragColor = vec4( col, 1.0 );
          #include <colorspace_fragment>
        }`,
    }),
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
  let tries = 0;
  while (p.length < count * 3 && tries++ < count * 40) {
    v.set(rand() * 2 - 1, rand(), rand() * 2 - 1);
    const len = v.length();
    if (len > 1 || len < 0.2) continue;
    v.divideScalar(len);
    if (v.y < 0.18) continue;
    // Dusk: only the brighter stars, high up and away from the sunset.
    const away = 1 - Math.max(0, v.dot(SUN_DIR));
    const fade = Math.min(1, (v.y - 0.18) / 0.5) * away * away;
    const b = (0.25 + 0.75 * Math.pow(rand(), 2.4)) * fade;
    if (b < 0.12) continue;
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

function radialTexture(size, stops, disc = null) {
  const c = document.createElement('canvas');
  c.width = size;
  c.height = size;
  const g = c.getContext('2d');
  const h = size / 2;
  const grad = g.createRadialGradient(h, h, 0, h, h, h);
  for (const [at, colour] of stops) grad.addColorStop(at, colour);
  g.fillStyle = grad;
  g.fillRect(0, 0, size, size);
  if (disc) {
    g.fillStyle = disc.colour;
    g.beginPath();
    g.arc(h, h, disc.r, 0, Math.PI * 2);
    g.fill();
  }
  const tex = new CanvasTexture(c);
  tex.colorSpace = SRGBColorSpace;
  return tex;
}

function lensflare(dpr) {
  const glow = radialTexture(256, [
    [0, 'rgba(255,250,235,1)'],
    [0.08, 'rgba(255,236,190,0.9)'],
    [0.3, 'rgba(255,170,90,0.28)'],
    [1, 'rgba(255,120,80,0)'],
  ]);
  const ghost = radialTexture(64, [
    [0, 'rgba(255,255,255,0.5)'],
    [0.6, 'rgba(255,255,255,0.22)'],
    [1, 'rgba(255,255,255,0)'],
  ]);
  const ring = radialTexture(128, [
    [0, 'rgba(255,255,255,0)'],
    [0.72, 'rgba(255,255,255,0)'],
    [0.86, 'rgba(255,255,255,0.26)'],
    [1, 'rgba(255,255,255,0)'],
  ]);
  const flare = new Lensflare();
  flare.addElement(new LensflareElement(glow, 420 * dpr, 0, new Color(1, 0.9, 0.75)));
  flare.addElement(new LensflareElement(ring, 110 * dpr, 0.4, new Color(0.45, 0.95, 1)));
  flare.addElement(new LensflareElement(ghost, 46 * dpr, 0.58, new Color(0.62, 0.36, 1)));
  flare.addElement(new LensflareElement(ghost, 90 * dpr, 0.76, new Color(1, 0.35, 0.55)));
  flare.addElement(new LensflareElement(ring, 180 * dpr, 1.0, new Color(0.35, 1, 0.6)));
  flare.name = 'SunFlare';
  return flare;
}

/** The sky group; call follow(camera) before each render. */
export class Sky {
  constructor(radius, dpr = 1) {
    this.group = new Group();
    this.group.name = 'Sky';
    this.group.add(dome(radius));
    this.group.add(stars(radius * 0.96, 360));

    const moon = new Sprite(
      new SpriteMaterial({
        map: radialTexture(
          128,
          [
            [0, 'rgba(255,248,230,0.45)'],
            [0.3, 'rgba(220,200,255,0.12)'],
            [1, 'rgba(200,160,255,0)'],
          ],
          { r: 11, colour: '#FFF3E0' },
        ),
        fog: false,
        transparent: true,
        depthWrite: false,
        blending: AdditiveBlending,
      }),
    );
    // Rising in the east-north-east, opposite the sunset.
    moon.position.set(0.85, 0.2, -0.45).normalize().multiplyScalar(radius * 0.9);
    moon.scale.setScalar(radius * 0.1);
    moon.renderOrder = -1;
    this.group.add(moon);

    // The flare sits on the sun and hides when a stand or the roof covers it.
    const flare = lensflare(dpr);
    flare.position.copy(SUN_DIR).multiplyScalar(radius * 0.9);
    this.group.add(flare);
  }

  follow(camera) {
    this.group.position.copy(camera.position);
    this.group.updateMatrixWorld(true);
  }
}
