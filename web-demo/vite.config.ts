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
          // THREE.js circular deps prevent tree-shaking regardless of named imports — separate
          // chunk means returning users only re-download main (~51KB) on code updates.
          // C147: bundle audit — total gzip ~215KB (three-core 135 + index 51 + minigames 26 +
          // CoastBiome 3KB lazy). Initial critical-path eager load: three-core + index = ~187KB
          // (under 200KB target). CoastBiome + minigames are lazy-loaded at run start.
          'three-core': ['three'],
          // MinigameRegistry uses static imports of all 14 mg_*.ts files — Rollup pulls
          // them all into this chunk via static dependency resolution. The resulting
          // minigames-*.js (~132KB / 26KB gzip) is deferred until first run start.
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
