# World Rules Tuning Sheet

Purpose
- Provide a quick reference of multipliers and expected impact
- Help design and balance without code changes

Baseline
- Base spawn rate: 1.00
- Base mystery rate: 1.00
- Base conflict: 0.30

Hourly Multipliers (snapshot)
- Aube (05:00-07:59): global ~1.05-1.08, ritual 1.10-1.15, fauna 1.05-1.20
- Jour (08:00-16:59): global ~1.00-1.05, craft 1.10-1.20, resource 1.05-1.15
- Crepuscule (17:00-19:59): global ~1.10-1.15, ritual 1.20-1.25, mystery 1.15-1.20
- Nuit (20:00-04:59): global ~1.10-1.25, spirit 1.28-1.40, mystery 1.12-1.35

Event Modifiers (typical ranges)
- spawn_mods: +0.10 to +0.40
- mystery_mod: +0.10 to +0.35
- conflict_mod: -0.15 to +0.20
- loot_mod: +0.10 to +0.20

Promise Impact (suggested)
- Success: favor +2, spawn bonus tags +0.20 for 2 days
- Failure: debt +1, conflict +0.15, spawn penalty -0.20 for 3 days
- Lying difficulty: base +2, ancient spirit +3, Merlin +6

Conflict Thresholds
- Calm <= 0.20: hostile 0.8, diplomacy 1.3
- Tense <= 0.50: hostile 1.0, diplomacy 1.0
- Riven >= 0.80: hostile 1.3, diplomacy 0.7, loot 1.15

Expected Outcomes (back of napkin)
- Night event + mystery: 1.25 hour * 1.25 event * (favor 1.10) ~= 1.72
- Day craft focus: 1.10 hour * 1.20 craft event ~= 1.32
- Promise debt active: base 1.00 * 0.80 penalty * 1.15 conflict ~= 0.92

Tuning Checklist
- Keep combined multipliers under ~2.0 except rare events
- Avoid stacking more than 2 conflict boosters at once
- Maintain at least one daytime event per week
- Avoid punishing casual players with >3 day debt stacks

Update Notes
- Update this sheet whenever hourly_facts or calendar_2026 changes
