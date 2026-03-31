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
          'minigames': [
            './src/minigames/mg_traces.ts',
            './src/minigames/mg_runes.ts',
            './src/minigames/mg_equilibre.ts',
            './src/minigames/mg_herboristerie.ts',
            './src/minigames/mg_negociation.ts',
            './src/minigames/mg_combat_rituel.ts',
            './src/minigames/mg_apaisement.ts',
            './src/minigames/mg_sang_froid.ts',
            './src/minigames/mg_course.ts',
            './src/minigames/mg_fouille.ts',
            './src/minigames/mg_ombres.ts',
            './src/minigames/mg_volonte.ts',
            './src/minigames/mg_regard.ts',
            './src/minigames/mg_echo.ts',
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
