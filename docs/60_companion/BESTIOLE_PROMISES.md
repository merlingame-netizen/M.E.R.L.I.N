# Bestiole and Promises (Integration)

Purpose
- Define how Bestiole reacts to promises and outcomes.

Promise Effects
- Promise kept: Mood +1, Bond +1, small fog clarity bonus
- Promise broken: Mood -1, Bond -1, fog thickens (visual only)
- Debt cleared: Mood +1, unlock a calming line

Bestiole Support
- If Bond >= 2, Bestiole can "Anchor" to slightly improve promise checks
- If Mood >= 2, Bestiole reduces the penalty of a single failed promise once per cycle

Event Hooks
- After promise success: Bestiole performs a short ritual animation
- After promise failure: Bestiole avoids eye contact and seeks rest

Design Notes
- Effects are soft, never hard gates.
- Bestiole reinforces the promise theme without punishing the player.
