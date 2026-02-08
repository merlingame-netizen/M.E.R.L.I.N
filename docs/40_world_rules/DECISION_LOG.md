# World Rules Decision Log

This log records design decisions for the persistent world rules.
Use short entries and link to the relevant docs in this folder.

Template
- Date: YYYY-MM-DD
- Decision: <short title>
- Context: <why this was needed>
- Options: <A/B/C>
- Choice: <picked option>
- Rationale: <why>
- Follow-ups: <data to add, tests to run>

## 2026-01-31
- Decision: World time model and promise stakes
- Context: Needed consistent rules for permanent world pacing
- Options: A) 1:1 day ratio, B) 2:1 day ratio, C) 1:2 day ratio
- Choice: A) 1:1 day ratio
- Rationale: Matches Animal Crossing style, encourages daily return
- Follow-ups: Validate with playtesters who skip days

- Decision: Promise severity
- Context: Player asked for heavy consequences, but ability to lie
- Options: A) Light consequences, B) Medium, C) Heavy with removal rituals
- Choice: C) Heavy with removal rituals
- Rationale: Supports Merlin judgment and long-term memory
- Follow-ups: Balance debt penalties to avoid casual churn

- Decision: Hour bonuses
- Context: Hours should not block spawns, only boost chances
- Options: A) Hard gates, B) Soft multipliers
- Choice: B) Soft multipliers
- Rationale: Avoids FOMO and keeps content accessible
- Follow-ups: Check that night bonuses do not eclipse day content

- Decision: Achievement triggers
- Context: Needed clear, testable conditions for unlocks and rewards
- Options: A) Vague counters, B) Explicit trigger spec with windows
- Choice: B) Explicit trigger spec with windows
- Rationale: Easier QA and balancing without code ambiguity
- Follow-ups: Align event tags and ensure trigger events are emitted
