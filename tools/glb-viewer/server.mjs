// GLB Viewer — Local HTTP server
// Usage: node tools/glb-viewer/server.mjs
// Then open VS Code Simple Browser at: http://localhost:7743

import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '../..');
const PORT = 7743;

const MIME = {
  '.html': 'text/html',
  '.js':   'application/javascript',
  '.mjs':  'application/javascript',
  '.css':  'text/css',
  '.glb':  'model/gltf-binary',
  '.gltf': 'model/gltf+json',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.json': 'application/json',
};

function listGLBs(dir, base, results = []) {
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    const relPath  = path.join(base, entry.name).replace(/\\/g, '/');
    if (entry.isDirectory()) {
      listGLBs(fullPath, relPath, results);
    } else if (entry.name.endsWith('.glb')) {
      results.push(relPath);
    }
  }
  return results;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);

  // API: list all GLBs in project
  if (url.pathname === '/api/assets') {
    const glbs = [
      ...listGLBs(path.join(PROJECT_ROOT, 'assets/3d_models'), 'assets/3d_models'),
      ...listGLBs(path.join(PROJECT_ROOT, 'web-demo/dist/assets'), 'web-demo/dist/assets'),
      ...listGLBs(path.join(PROJECT_ROOT, 'web-demo/dist/assets/models'), 'web-demo/dist/assets/models'),
    ];
    res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
    res.end(JSON.stringify(glbs));
    return;
  }

  // Serve viewer HTML
  if (url.pathname === '/' || url.pathname === '/index.html') {
    const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(html);
    return;
  }

  // Serve project files (GLBs, etc.)
  const filePath = path.join(PROJECT_ROOT, url.pathname.slice(1));
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    const ext  = path.extname(filePath).toLowerCase();
    const mime = MIME[ext] || 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': mime,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'no-cache',
    });
    fs.createReadStream(filePath).pipe(res);
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`\n🔮 GLB Viewer ready → http://localhost:${PORT}`);
  console.log(`   VS Code: Ctrl+Shift+P → "Simple Browser: Show" → http://localhost:${PORT}\n`);
});
