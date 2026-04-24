import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import fs from 'fs';

const STATUS_DIR = path.resolve(__dirname, '../status');

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'local-status-api',
      configureServer(server) {
        server.middlewares.use('/status', (req, res, _next) => {
          const filePath = path.join(STATUS_DIR, req.url || '');
          if (!filePath.startsWith(STATUS_DIR)) {
            res.statusCode = 403;
            res.end('Forbidden');
            return;
          }
          fs.readFile(filePath, 'utf-8', (err, data) => {
            if (err) {
              res.statusCode = 404;
              res.end('Not found');
              return;
            }
            const ext = path.extname(filePath);
            res.setHeader('Content-Type', ext === '.jsonl' ? 'text/plain' : 'application/json');
            res.setHeader('Access-Control-Allow-Origin', '*');
            res.end(data);
          });
        });

        server.middlewares.use('/api/feedback', (req, res) => {
          if (req.method !== 'POST') {
            res.statusCode = 405;
            res.end('Method not allowed');
            return;
          }
          let body = '';
          req.on('data', chunk => { body += chunk; });
          req.on('end', () => {
            try {
              const feedback = JSON.parse(body);
              const responsesPath = path.join(STATUS_DIR, 'feedback_responses.json');
              let existing: { responses: Array<Record<string, unknown>> } = { responses: [] };
              try {
                existing = JSON.parse(fs.readFileSync(responsesPath, 'utf-8'));
              } catch { /* file may not exist */ }
              existing.responses.push({
                ...feedback,
                timestamp: new Date().toISOString(),
              });
              fs.writeFileSync(responsesPath, JSON.stringify(existing, null, 2));
              res.setHeader('Content-Type', 'application/json');
              res.end(JSON.stringify({ ok: true }));
            } catch {
              res.statusCode = 400;
              res.end('Bad request');
            }
          });
        });
      },
    },
  ],
  server: {
    port: 4200,
  },
});
