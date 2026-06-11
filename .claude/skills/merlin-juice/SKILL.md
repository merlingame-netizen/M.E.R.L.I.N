---
name: merlin-juice
description: "Vocabulaire d'animation canon M.E.R.L.I.N. (BIBLE §21) + helpers MerlinFx/MerlinVisual. Timings, easings, patterns anti-tweens-orphelins, reduce-motion. Pour tout juice/animation/transition/feedback du jeu."
user-invokable: true
metadata:
  version: "1.0.0"
  validated: "2026-06-12"
  project: "merlin"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# Skill `merlin-juice` — Animations & Game Feel canon

> Mode d'emploi outillé de **BIBLE §21 (R116)**. Source de vérité code :
> `scripts/game/merlin_fx.gd` (helpers) + `scripts/game/merlin_visual.gd` (constantes DUR_*/TRANS_*).
> Si ce skill et la bible divergent → la bible gagne, corriger ce skill.

---

## Auto-Activation

- **Mots-clés** : `juice`, `animation`, `tween`, `transition`, `easing`, `feedback`, `shake`,
  `glow`, `pulse`, `stagger`, `hover`, `fade`, `anim`, `game feel`
- **Contexte** : projet Godot-MCP, toute modification visuelle dynamique
- **Exclusion** : la cinématique de FUSION (4 phases + sustain) est INTOUCHÉE sans décision user

---

## Vocabulaire canon (BIBLE §21 — utiliser CES noms et CES valeurs)

| Nom | Durée (s) | Trans/Ease | Usage |
|---|---|---|---|
| `tap` | 0.06 down / 0.10 up | QUAD out | press bouton (scale 0.97→1.0) |
| `fast` | 0.12 | CUBIC out | hover carte (1.18 + lift 30px), hover bouton (modulate 1.06) |
| `ui` | 0.22 | CUBIC in_out | vol de carte main↔combo (ghost, arc -18px) |
| `deal` | 0.24-0.28 | BACK out | distribution (stagger 0.05) |
| `discard` | 0.25 | QUAD in | défausse (slide -40px, rot -6°, fade, stagger 0.05) |
| `veil` | 0.20 in / 0.25 out | QUAD in/out | voile transition de beat (BG_PAGE 0→0.85→0) |
| `float_delta` | 0.9 | QUAD out | chiffre delta de jauge |
| `pulse` | 0.3 | SINE in_out | pulsation 1→1.3→1 |
| `fusion` | FUSION_DURATIONS | — | NE PAS TOUCHER |

Constantes code : `MerlinVisual.DUR_TAP_DOWN/DUR_TAP_UP/DUR_FAST/DUR_UI/DUR_DEAL/DUR_DISCARD/`
`DUR_VEIL_IN/DUR_VEIL_OUT`, `MerlinVisual.STAGGER`, `MerlinVisual.TRANS_UI/EASE_UI`,
`MerlinVisual.reduced_motion` (bool statique, alimenté par MerlinOptions).

## Helpers de référence (signatures exactes)

```gdscript
# EXISTANTS (merlin_fx.gd)
static func MerlinFx.shake(target: Control, amplitude: float, duration: float) -> void
func MerlinFx.spark_wave(center, color, count, life, dist_base, dist_var, scale_target, alpha_init) -> void  # instance

# JUICE PACK 1 (v10.13.1)
static func MerlinFx.ghost_flight(host: Control, from_rect: Rect2, to_center: Vector2, accent: Color, dur: float) -> void
static func MerlinFx.float_delta(host: Control, anchor: Vector2, delta_text: String, col: Color) -> void
static func MerlinFx.pulse(node: Control, peak: float = 1.3) -> void
static func MerlinFx.beat_veil(host: Control) -> Signal  # retourne le signal "mi-voile" (swap du contenu)
static func MerlinVisual.connect_button_feedback(btn: BaseButton) -> void
```

## Patterns OBLIGATOIRES

1. **Tween lié au node hôte** : `node.create_tween()` ou layer auto-détruit (pattern MerlinFx :
   « le layer EST le node »). Un tween ne survit JAMAIS à son node (bug fondateur v10.2).
2. **`kill()` avant re-tween** de la même propriété : garder le tween en membre `_tw`,
   `if _tw: _tw.kill()` (pattern `MerlinCardView`).
3. **`pivot_offset = size / 2.0` AVANT** tout tween de scale/rotation.
4. **`mouse_filter = Control.MOUSE_FILTER_IGNORE`** sur tout overlay décoratif — un effet ne
   vole JAMAIS un clic.
5. **Stagger 0.04-0.06s** pour les groupes (cartes, options de draft).
6. **Reduce-motion** : vérifier `MerlinVisual.reduced_motion` → durées ÷2, amplitudes ÷2,
   shake/tremblement OFF, **l'information reste** (indice statique conservé, R74/R75).
7. **Types explicites** : `var c: Color = MerlinVisual.GOLD` — JAMAIS `:=` avec CONST[index].

## Anti-patterns (REFUSER en revue)

- Anim UI > 0.5s hors fusion/veil.
- Anim **bloquante pendant la décision joueur** (main et combo répondent TOUJOURS au clic).
- `await` ajouté dans le flow logique de run pour du cosmétique (régression soak/autoplay R109).
- Polling `_process` pour animer (tweens only).
- Nouvelles particules pendant le sustain LLM (CPU réservé à la gen, R58) — cap sparks existant.
- Hex en dur (toujours `MerlinVisual.*`).
- Durée/easing inventés hors vocabulaire (sinon : proposer l'ajout au vocabulaire BIBLE §21 d'abord).

## Checklist de sortie (gate BIBLE §24)

```
[ ] python tools/cli.py godot validate_step0     → exit 0
[ ] python tools/cli.py godot smoke --scene <scènes touchées>  → passed=true
[ ] python tools/cli.py godot soak --runs 200 --autoplay true  → si le flow de run est touché (R109)
[ ] Capture avant/après (playtest visuel)
[ ] 4 piliers BIBLE §23 vérifiés (FACILE/ÉVIDENT/MINIMAL/TACTILE)
[ ] reduce-motion testé (option Options → toutes les anims atténuées, info conservée)
```
