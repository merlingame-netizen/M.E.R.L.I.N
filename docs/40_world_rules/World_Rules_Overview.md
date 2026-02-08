# World Rules Overview (Bretagne Mystique)

This document describes the persistent world rules, calendar, promises, and progression.
It is content only (no code) and is designed for fast daily progress with long-term
completion, Animal Crossing style.

Goals
- Mystic tone with Breton lore
- Permanent world: days and seasons matter
- Promises have heavy consequences
- Hours never block spawns; they only modify chances
- Rewards are mostly utilitarian

Core Pillars
1) Time matters: day phases, hour bonuses, seasons, dated events
2) Promise pressure: high stakes, reputation, debt
3) Conflict flux: world tension changes encounters
4) Mystery magnet: favor increases mystic encounters
5) Utility progression: tools and perks unlock quality of life

Time Model
- Real day to game day ratio: 1:1
- Phases: aube, jour, crepuscule, nuit
- Hour modifiers are multipliers, never hard gates

Seasons and Events
- Seasons define exclusive events and gameplay bonuses (not lore gating)
- Events have: date, season, tags, hour_bonus, effects, notes
- Some events are season_only and cannot occur outside their season

Promises (Pactes)
- Stakes use DC: low 7, mid 9, high 11, major 13
- Lying is possible but harder; Merlin sees all (near-impossible)
- Success grants favor and spawn boosts for a short time
- Failure creates Ogham debt, conflict pressure, spawn penalties
- Promises can be cleared by ritual, transfer, or buyout

Conflict System
- Base conflict level: 0.3
- Thresholds: calm (<=0.2), tense (<=0.5), riven (>=0.8)
- Conflict changes encounter weights and diplomacy outcomes

Mystery System
- Base mystery rate: 1.0
- Favor increases mystery rate
- Debt decreases mystery rate

Progression
- Daily: 1 major goal, 2 minor goals
- Weekly: a grand rite day grants a major tool
- Seasonal: 1 arc chapter + 1 exclusive mystery
- Full completion targets multiple seasons (long tail)

Gloire (Achievements)
- Points unlock tiers and utilitarian tools/perks
- Unlocks focus on quality of life: tracking, travel, harvesting, access

Data Files (Source of Truth)
- world_rules.json: global rules, promise system, conflict, mystery
- hourly_facts.json: 24 hourly multipliers (bonuses only)
- calendar_2026.json: dated events for 2026 with hour bonuses and effects
- achievements.json: points, tiers, unlocks, achievements

Related Docs
- CALENDAR_2026_PRINT.md: printable date list
- EVENT_TAG_GLOSSARY.md: event tag meanings
- PROMISE_PLAYBOOK.md: promise examples and outcomes
- UTILITY_UNLOCK_MAP.md: achievement reward mapping
- KNOWN_RISKS.md: risks and mitigations

Qualification Checklist (Product/Design)
- Time: should missed days be simulated or skipped?
- Timezone: use local time, server time, or game time?
- Event overlap: how do multiple active events stack?
- Promise expiry: how many days to fulfill a promise?
- Consequences: how punitive is debt vs favor?
- Conflict: can players deliberately reduce conflict? how fast?
- Mystery: should mystery rate cap or scale infinitely?
- Rewards: which tools are mandatory vs optional?
- Accessibility: how to avoid punishing casual players?

Development Notes (Non-code)
- Stacking order suggestion: base rate -> hour mult -> event mult -> favor/debt -> conflict
- Use tags to match events to spawn categories
- Keep unique event ids and stable names for saves
- Log promise outcomes to support later narrative callbacks

Balancing Knobs
- Hour multipliers (hourly_facts.json)
- Event effects: spawn_mods, mystery_mod, conflict_mod
- Promise DCs and lie modifiers
- Favor and debt impact per point
- Achievement points per tier

QA / Validation
- All JSON files parse and are ASCII only
- Event ids are unique; dates are valid YYYY-MM-DD
- Season ranges cover all dates without gaps
- Hour ranges are valid and do not block spawns
- No negative multipliers below 0.1 unless intended
- Achievements reference valid event ids

Change Log
- See CHANGELOG.md in this folder
