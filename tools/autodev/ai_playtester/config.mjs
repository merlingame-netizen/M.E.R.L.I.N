// AI Playtester — Configuration
// Zero dependencies, all paths absolute for Windows compatibility

import { fileURLToPath } from 'url';
import path from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '../../..');

export const CONFIG = {
  projectRoot,
  capturesDir: path.join(projectRoot, 'tools/autodev/captures'),
  outputDir: path.join(projectRoot, 'tools/autodev/playtest_reports'),
  statusDir: path.join(projectRoot, 'tools/autodev/status'),

  // Ollama
  ollamaUrl: 'http://localhost:11434',
  ollamaModel: 'qwen3.5:4b',

  // Timing
  statePollMs: 2000,
  commandTimeoutMs: 5000,
  cardWaitTimeoutMs: 120_000,
  phaseWaitTimeoutMs: 60_000,
  launchWaitMs: 30_000,

  // Game
  maxCards: 50,
  historySize: 3,

  // Launch
  launchScript: path.join(projectRoot, 'tools/launch_game.ps1'),
  godotScene: 'res://scenes/BootstrapMerlinGame.tscn',
};
