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
    chunkSizeWarningLimit: 550, // three.js core is ~529KB, suppress known vendor warning
    reportCompressedSize: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'three-core': ['three'],
          // Minigames chunk: deferred until first run (dynamic import in createMinigame).
          // Listing them here groups all 14 files + base into one cache-friendly chunk
          // instead of 15 individual micro-requests.
          // Groups registry + base into a shared chunk; individual mg_*.ts files land in
          // their own micro-chunks (dynamically imported via createMinigame).
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
