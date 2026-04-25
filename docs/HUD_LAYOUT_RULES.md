# HUD Layout Rules — M.E.R.L.I.N.

> Source de verite pour tous les overlays UI. À lire AVANT d'ajouter un nouveau Label/Panel/Notification.

## Regle d'or

**Aucun overlay HUD ne doit jamais se superposer a un autre.** Chaque element occupe une zone reservee. Pas de superposition meme partielle.

## Zones reservees (responsive — anchors only)

```
+----------------------------------------------------------+
|  [TOP_LEFT]  [TOP_CENTER]                  [TOP_RIGHT]   |  10% top
|                                                          |
|  [LEFT]                                       [RIGHT]    |  free zones
|                                                          |
|                  [CENTER_MODAL]                          |  20-60% (modal only)
|                                                          |
|                                                          |
|  [BOT_LEFT]                                  [BOT_RIGHT] |  ↑
|              [VO_BOX (bottom-center)]                    |  10% bottom
+----------------------------------------------------------+
```

| Zone | Owner | Anchors | Responsive rule |
|------|-------|---------|-----------------|
| **TOP_LEFT** | Stats (PV, Anam) | preset TOP_LEFT, offsets 16,16 | margin 16px scaled |
| **TOP_CENTER** | Title / biome name | preset TOP, anchor_left=0.4 right=0.6 | width = 20vw |
| **TOP_RIGHT** | Card count, Carte X/Y | preset TOP_RIGHT, offsets -16,-16 | margin 16px scaled |
| **LEFT** | Faction icons | anchor_left=0 anchor_top=0.3 anchor_bottom=0.7 | vertical strip |
| **RIGHT** | Ogham slots | anchor_right=1 anchor_top=0.3 anchor_bottom=0.7 | vertical strip |
| **CENTER_MODAL** | Encounter cards, parchment, choice buttons | preset CENTER, anchor 0.5 | reserves screen — locks input |
| **BOT_LEFT** | Tooltip / contextual hint | preset BOTTOM_LEFT, offsets 16,-80 | margin 16px |
| **BOT_RIGHT** | Crosshair / interaction prompt | preset CENTER for crosshair only | NO HUD elem here |
| **VO_BOX** | Merlin voice-over | preset BOTTOM_WIDE, offsets 80,-120 to -80,-40 | full-width minus margins |

## Mutual exclusion (mode-driven)

A scene MUST be in exactly ONE display mode at a time:

- `MODE_REVEAL` (tutorial intro) → only VO_BOX visible. Top stats / encounter / ogham / faction = HIDDEN.
- `MODE_GAMEPLAY` (normal run) → top stats + faction + ogham + crosshair visible. VO_BOX shown only when Merlin speaks (rare).
- `MODE_MODAL` (encounter card / parchment / dialogue) → CENTER_MODAL takes over. Top stats grayed (mouse_filter = IGNORE), VO_BOX hidden.
- `MODE_END` (post-run summary) → only CENTER_MODAL visible. Everything else hidden.

Transition between modes goes through a single helper `_set_hud_mode(mode: int)` that flips visibility on the right CanvasLayers. **No code outside that helper sets `.visible` on HUD elements.**

## Responsive rules

- **Anchors first**: never use absolute pixel offsets without an anchor. `set_anchors_preset()` then tune offsets.
- **Font size**: read from `MerlinResponsive.get_font_size(role)` — adapts to viewport DPI.
- **Min/max width**: every Container has `custom_minimum_size` AND a `size_flags_horizontal = SIZE_EXPAND_FILL` constraint where applicable.
- **Aspect ratio guard**: 16:9 minimum. If viewport is taller (mobile portrait), CENTER_MODAL must shrink horizontally — never let it overflow.
- **Pas de coordonnees codees en dur > 32px**: si une offset depasse 32px, c'est probablement une erreur (utiliser anchor + ratio).

## Anti-superposition test

Before merging any new HUD element:

1. Lister les ancres + offsets cibles
2. Verifier qu'aucun element existant ne partage la meme zone
3. Smoke test (capture frame) sur la scene cible — ouvrir le PNG, verifier visuellement
4. Si superposition — refondre en utilisant une autre zone OU en mutex (mode-driven hide)

## Anti-patterns

- ❌ Multiple labels at the same anchor preset (PRESET_BOTTOM_WIDE) sans offsets disjoints
- ❌ HUD element with `mouse_filter = STOP` while a CENTER_MODAL is active (blocks modal click)
- ❌ Hardcoded `position = Vector2(640, 360)` (breaks on resize)
- ❌ Adding a CanvasLayer with `layer >= layer_of_modal` without checking conflict
- ❌ Calling `.visible = true` from a non-mode helper (creates ghost overlays after a mode transition)

## CanvasLayer ordering

| Layer | Purpose |
|-------|---------|
| 0–9 | World 3D + 2D parallax |
| 10 | Gameplay HUD (top stats, faction, ogham) |
| 20 | VO box / Merlin whisper |
| 30 | Encounter card overlay |
| 40 | Parchment / book cinematic |
| 50 | Tutorial reveal overlay (intro VO) |
| 90 | ScreenDither / CRT filter |
| 100 | ScreenFrame |
| 101 | SceneSelector (debug) |

Never reuse a layer slot. New element → new slot in the gap.

---

*Mise a jour : 2026-04-26*
