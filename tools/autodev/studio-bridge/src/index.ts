import { Orchestrator } from './orchestrator.js';
import { CardGenerator } from './card-generator.js';
import type { BridgeConfig } from './types.js';

import { resolve } from 'path';

const root = process.env.MERLIN_PROJECT_ROOT || process.cwd();

const config: BridgeConfig = {
  projectRoot: root,
  statusDir: resolve(root, 'tools/autodev/status'),
  agentsDir: resolve(root, '.claude/agents'),
  agentCardsDir: resolve(root, 'tools/autodev/agent_cards'),
  maxParallelAgents: 3,
  cycleTimeout_minutes: 120,
  dryRun: process.argv.includes('--dry-run'),
  autoEvolve: !process.argv.includes('--no-evolve'),
  vercelProjectUrl: 'https://web-export-pi.vercel.app',
};

async function main(): Promise<void> {
  console.log(
    `[MERLIN Studio Bridge] Starting${config.dryRun ? ' (DRY RUN)' : ''}...`,
  );
  const orchestrator = new Orchestrator(config);
  await orchestrator.initialize();

  if (process.argv.includes('--status')) {
    await orchestrator.printStatus();
  } else if (process.argv.includes('--history')) {
    await orchestrator.printHistory();
  } else if (process.argv.includes('--generate-cards')) {
    const generator = new CardGenerator(config.agentsDir, config.agentCardsDir);
    console.log('[CARD-GEN] Generating missing agent cards...');
    const result = await generator.generateAll();
    console.log(`[CARD-GEN] Generated: ${result.generated}, Skipped: ${result.skipped}`);
    if (result.errors.length > 0) {
      console.log(`[CARD-GEN] Errors: ${result.errors.length}`);
      for (const err of result.errors) console.log(`  - ${err}`);
    }
    console.log('[CARD-GEN] Rebuilding registry...');
    const total = await generator.rebuildRegistry();
    console.log(`[CARD-GEN] Registry: ${total} agents indexed`);
  } else {
    await orchestrator.runCycle();
  }
}

main().catch((err) => {
  console.error('[FATAL]', err);
  process.exit(1);
});
