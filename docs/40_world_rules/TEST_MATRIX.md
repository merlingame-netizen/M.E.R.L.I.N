# World Rules Test Matrix

Purpose
- Validate time, season, promises, conflict, and achievements
- Provide QA coverage for core systems

Matrix

Time & Hours
- Verify hour multipliers never block spawns
- Check transitions at 04:59->05:00, 07:59->08:00, 16:59->17:00, 19:59->20:00
- Confirm night multipliers do not overwhelm day content
- Confirm hour tags match expected categories (ritual, spirit, craft, etc.)

Calendar & Seasons
- Validate event dates are valid and unique
- Confirm season_only events do not appear outside season
- Confirm at least one event per season has a night bonus
- Confirm events can overlap (if same date) without breaking spawns

Promises
- Success path: favor gain, spawn boost, duration correct
- Failure path: debt, conflict increase, spawn penalty, duration correct
- Lying: DC increases based on target (normal, ancient, Merlin)
- Clearing: ritual, transfer, buyout each removes debt correctly

Conflict
- Calm/tense/riven thresholds apply correctly
- Hostile and diplomacy multipliers switch at thresholds
- Conflict inversion on Nuit du Corbeau works for a single night

Mystery Rate
- Favor increases mystery rate linearly
- Debt decreases mystery rate linearly
- Mystery does not drop below minimum safe threshold

Achievements
- Points accumulate and unlock tiers at 5/12/25/40/60
- Achievements unlock correct tools/perks
- Event-based achievements reference valid event ids
- Seasonal witness counts one per season
- Trigger events are emitted with required fields (event, metric, window)

Economy & Utility
- Tool unlocks are utilitarian and improve QoL
- No tool soft-locks progress
- Daily/weekly rewards feel achievable

Regression Checklist
- After adding events, re-validate uniqueness
- After changing hourly multipliers, re-check nightly dominance
- After tuning promises, re-check debt stack limits

Sign-off
- Date:
- Owner:
- Notes:
