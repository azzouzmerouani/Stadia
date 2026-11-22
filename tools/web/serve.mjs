// Dev server mirroring the in-app loopback server:
//   /            -> assets/web/
//   /3d/<file>   -> assets/3d/<file>
// Open http://localhost:5175/index.html?mode=picker&debug
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { dirname, extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const assets = join(here, '../../assets');
const port = Number(process.env.PORT || process.argv[2] || 5175);
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.glb': 'model/gltf-binary',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
};

createServer(async (req, res) => {
  const path = normalize(decodeURIComponent(new URL(req.url, 'http://x').pathname));
  const file = path.startsWith('/3d/')
    ? join(assets, path)
    : join(assets, 'web', path === '/' ? 'index.html' : path);
  if (!file.startsWith(assets)) {
    res.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] || 'application/octet-stream',
      'cache-control': 'no-store',
    });
    res.end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
}).listen(port, '127.0.0.1', () => console.log(`stadia web on http://localhost:${port}`));
