// Bundles src/ into assets/web/stadium.js (one classic script, works from
// any origin) and copies the Draco WASM decoder next to it.
import { build, context } from 'esbuild';
import { copyFileSync, mkdirSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '../../assets/web');
const watch = process.argv.includes('--watch');

const options = {
  entryPoints: [join(here, 'src/main.js')],
  bundle: true,
  format: 'iife',
  minify: !watch,
  sourcemap: false,
  target: ['es2020', 'safari15', 'chrome90'],
  outfile: join(out, 'stadium.js'),
  legalComments: 'eof',
  // three's DRACOLoader resolves default decoder URLs from import.meta.url,
  // which does not exist in an IIFE; we set the decoder path explicitly.
  define: { 'import.meta.url': 'document.baseURI' },
  logLevel: 'info',
};

mkdirSync(join(out, 'draco'), { recursive: true });
const draco = join(here, 'node_modules/three/examples/jsm/libs/draco/gltf');
for (const f of ['draco_decoder.wasm', 'draco_wasm_wrapper.js']) {
  copyFileSync(join(draco, f), join(out, 'draco', f));
}

if (watch) {
  const ctx = await context(options);
  await ctx.watch();
} else {
  await build(options);
  const kb = (statSync(options.outfile).size / 1024).toFixed(0);
  console.log(`stadium.js ${kb} KB`);
}
