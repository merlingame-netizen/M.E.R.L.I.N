import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
    chunkSizeWarningLimit: 550, // three.js core is ~531KB minified; suppress known vendor warning
    reportCompressedSize: true,
    rollupOptions: {
      output: {
        manualChunks: {
          // C35: explicit chunk keeps THREE.js separate from main for long-term CDN caching.
          // Named imports across all 9 source files are cleaner but THREE.js circular deps
          // prevent tree-shaking regardless — total gzip is identical either way (185-186KB).
          // Separate chunk means returning users only re-download main (~51KB) on code updates.
          'three-core': ['three'],
          // MinigameRegistry uses static imports of all 14 mg_*.ts files — Rollup pulls
          // them all into this chunk via static dependency resolution. The resulting
          // minigames-*.js (~120KB / 24KB gzip) is deferred until first run start.
          'minigames': [
            './src/minigames/MinigameRegistry.ts',
            './src/minigames/MinigameBase.ts',
          ],
        },
      },
    },
  },
  server: {
    port: 5173,
  },
});
