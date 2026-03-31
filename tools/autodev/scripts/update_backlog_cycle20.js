// Cycle 20 backlog update:
// 1. Mark T052 and T053 as done (were already done in cycle 19 but still listed as open)
// 2. Add T056 and T057 to completed
// 3. Add T058 (SFX implementation) and T059 (mobile layout) as new open tasks
const fs = require('fs');
const path = 'C:/Users/PGNK2128/Godot-MCP/web-demo/.studio/backlog.json';
const bl = JSON.parse(fs.readFileSync(path, 'utf8'));

bl.updated = "2026-04-01T00:10:00Z";

// Remove T052 and T053 from open tasks (they were done in cycle 19)
bl.tasks = bl.tasks.filter(t => t.id !== 'T052' && t.id !== 'T053');

// Add new open tasks
bl.tasks.unshift(
  {
    id: "T059",
    title: "Mobile layout pass — verify card overlay and minigame canvases fit on 375px viewport",
    priority: 3,
    status: "open",
    domain: "visual",
    est_tokens: 300,
    depends_on: ["T057"],
    tags: ["mobile", "ux"],
    notes: "T057 added touch support. Verify CSS on narrow screens: card-container 90% width OK, minigame canvases 380-400px may overflow 375px viewport. Add max-width:100% on canvas, responsive font-size for minigame titles."
  },
  {
    id: "T058",
    title: "SFX implementation — hook Web Audio API tones to merlin_sfx event bus",
    priority: 3,
    status: "open",
    domain: "gameplay",
    est_tokens: 400,
    depends_on: ["T056"],
    tags: ["audio", "ux"],
    notes: "T056 event bus wired. Create src/audio/SFXManager.ts listening to window 'merlin_sfx'. Procedural Web Audio API only — no external assets. flip: short ping. win: ascending arpeggio. lose: descending tone. unlock: bell chord. end: sustained fade."
  }
);

// Add completed entries for T052, T053, T056, T057
bl.completed.unshift(
  {
    id: "T057",
    title: "Mobile touch support — pointerdown on mg_runes+mg_traces, touch-action:none on canvas",
    domain: "gameplay",
    completed_cycle: 20,
    completed_at: "2026-04-01T00:10:00Z"
  },
  {
    id: "T056",
    title: "SFX event bus — playSound() dispatches merlin_sfx CustomEvent, wired at flip/win/lose/unlock/end",
    domain: "gameplay",
    completed_cycle: 20,
    completed_at: "2026-04-01T00:10:00Z"
  },
  {
    id: "T053",
    title: "Persist meta state to localStorage — oghamsUnlocked, factionRep, totalRuns",
    domain: "gameplay",
    completed_cycle: 19,
    completed_at: "2026-03-31T23:45:00Z"
  },
  {
    id: "T052",
    title: "Ogham panel locked/unlocked state — grey out locked oghams, show rep threshold hint",
    domain: "gameplay",
    completed_cycle: 19,
    completed_at: "2026-03-31T23:45:00Z"
  }
);

fs.writeFileSync(path, JSON.stringify(bl, null, 2));
console.log('Backlog updated. Open tasks:', bl.tasks.filter(t => t.status === 'open').map(t => t.id));
