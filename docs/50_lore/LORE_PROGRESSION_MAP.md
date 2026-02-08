# Lore Progression Map (No Calendar Gating)

This map defines when hints appear based on progression and event outcomes.
Calendar dates only add bonuses; they do not gate lore.

Progression Stages

Stage 1 - Awakening (early)
- Triggers: first promise made, first menhir visit, first mystery resolved
- Hints: repeated birds, soft fog patterns, short Merlin lines
- Rule: never mention "core" or imply hidden systems

Stage 2 - Drift (mid)
- Triggers: 3 promises resolved, 1 debt cleared, conflict reaches tense
- Hints: menhir glow, NPC memory slips, path closures after broken vows
- Rule: show world reaction, not explanation

Stage 3 - Weight (late)
- Triggers: 7 mysteries resolved, conflict dropped from riven to calm, long-night event completed
- Hints: Merlin mentions "weight" and "balance", fog acts like a veil
- Rule: still no direct exposition or modern terms

Trigger Examples
- Promise success -> add a short line about "stones remembering"
- Promise failure -> fog thickens + line about "land closing"
- Debt cleared -> menhir pulse + line about "breath"
- Conflict drop -> birds return + line about "silence lifting"

Implementation Notes (content only)
- Choose 1 hint per major milestone, not every time
- Keep a cap: max 1 hint per day
- Rotate hint pools to avoid repeats

QA Checks
- Hints appear with progression, not with calendar dates
- No hint uses banned words
- Late hints never fully explain the truth
