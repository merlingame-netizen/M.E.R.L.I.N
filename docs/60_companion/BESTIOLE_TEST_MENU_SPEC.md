# Bestiole Test Menu - Dev Spec (for Claude)

Audience
- This document is for Claude (dev) to implement a dedicated test menu.

Goal
- Provide a simple debug menu to exercise Bestiole systems without full gameplay.
- Include buttons, simple animations, and readable feedback.
- Dev only: this menu is for quick testing. Final gameplay integrates these systems in a single main game flow.

Scene
- Name: BestioleTestMenu
- Location: dedicated menu entry or standalone test scene (dev only)
- Layout: left = controls, right = status + preview

UI Layout
Left Panel (Controls)
- Buttons (stacked):
  1) Spawn / Despawn Bestiole
  2) Feed
  3) Play
  4) Groom
  5) Rest
  6) Gift
  7) Toggle Form (cycle)
  8) Add Bond (+1)
  9) Add Mood (+1)
  10) Simulate Day (advance needs decay)
  11) Trigger Event (random from list)
  12) Trigger Combat Action (random legal)
  13) Toggle Night (day/night)
  14) Reset

Right Panel (Status)
- Bestiole portrait (placeholder sprite)
- Mood icon + text label
- Needs bars: Hunger, Energy, Mood, Cleanliness
- Bond ring or numeric
- Form label
- Last action log (multi-line text)

Behavior Requirements
- Buttons call mock methods (even if real system not wired yet)
- All actions update the UI immediately
- Logs show: action name, effects applied

Simple Animations
- Button hover: scale to 1.05, 0.12s
- Button press: scale to 0.95, 0.08s then return
- Bestiole portrait idle: slow pulse (scale 1.0 -> 1.02)
- Mood icon: bounce when mood changes
- Bars: tween value over 0.2s
- Log entries: fade-in 0.2s, max 8 lines

States & Mock Data
- Default state: hunger 70, energy 60, mood 65, cleanliness 70, bond 2
- Forms: Veil, Stone, Ember, River, Thorn, Gale, Root, Tide, Emberglass, Moss
- Events list: Spring Burrow, Oath Day, Drift Echo, Menhir Pulse
- Combat actions list: Guard, Scout, Mark, Nudge, Ward, Spur, Veil Step

No-Guilt UX
- Use neutral text (no red warnings)
- Use soft color palette (greens/blues/cream)

Acceptance Criteria
- All buttons visible and clickable
- Animations play on hover/press
- State updates are reflected instantly
- Log text updates on every action

Notes
- This menu is for iteration, not a final player UI.
- Keep assets placeholder-friendly.
- Final integration must live in the main game flow (no separate test menu for players).
