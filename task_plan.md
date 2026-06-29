# Task Plan — MERLIN Game Development

> **Source**: `docs/BIBLE.md` v2.0 (canon unique — roadmap §19 ; l'ancien `DEV_PLAN_V2.5.md` est archivé dans `docs/archive/`).
> **Consumed by**: `tools/octogent/prompts/studio-director.md` Tier 1 backlog.
> **Last refresh**: 2026-06-29 (v10.18 boot cinematic).

## v10.18 — Boot Cinématique (intro 5 actes) [IN PROGRESS]

### Context
User 2026-06-29 : le boot doit être un **plan cinématique** —
1. **Acte 1 (Réveil)** : démarre DÉJÀ zoomé sur les yeux de Merlin ; ils se réveillent (ouverture + allumage).
2. **Acte 2 (Regard)** : les yeux regardent (gauche/droite/centre), toujours en gros plan.
3. **Acte 3 (Dezoom + décor)** : dézoom révélant Merlin entier + le décor APPARAÎT selon **saison** ET heure du jour.
4. **Acte 4 (Pause)** : scène complète → pause 0,5s.
5. **Acte 5 (Grondement + push)** : grondement + animation BRUSQUE comme si on poussait DE FORCE le menu depuis
   la GAUCHE ; le décor et les yeux sont ÉBAHIS — durée 1,3s — puis swap vers MerlinMenu.

### Pré-implémentation (en cours)
- Explore agent : facts audio (rumble SFX), entrance menu, transition, palette, shake, blast-radius MerlinSceneArt.
- Workflow design+faisabilité : timeline chronométrée + feel acte 5 + système saison + de-risk Godot.

### Implémentation prévue
- **MerlinSceneArt** : `set_decor_reveal(0..1)`, hooks cinématiques yeux (ouverture/luminosité/écartement/regard scripté),
  `set_season(saison)` (feuillage saisonnier dérivé palette canon, zéro hex).
- **merlin_boot.gd** : re-chorégraphie 5 actes — zoom (scale du Control autour du pivot yeux) → dezoom + décor →
  pause → grondement (shake + audio) + push panneau depuis la gauche + yeux ébahis → change_scene MerlinMenu.
  Gating sur `model_ready` (no-freeze préservé : modèle chargé en thread).

### Gates
- validate_step0 0 err ; smoke Boot/Menu/Game passed ; capture multi-frames des 5 actes ; review concurrence/feel.

---


## v10.16.2 — Audio Polish : SFX soft + gameplay music

### Context
SFX v10.16.1 trop durs (volume, attaques, timbre metallique). Gameplay sans musique dediee.

### Phase 1 — Soften SFX [DONE]
- PEAK_TARGET -3→-14 dB (fichiers WAV plus silencieux)
- Attaques ralenties x3-10 sur les 18 recettes
- FM mod_index reduit ~50% (moins metallique)
- Filtres cutoff abaisses, reverb augmentee
- `_soft_finish()` post-traitement global (fade + lowpass 5.5kHz)
- sfx_vol default 0.8→0.45, play_sfx volume_db 0→-3

### Phase 2 — Gameplay Music [IN PROGRESS]
- `music_forge.py` : generateur procedural ambient celtique
- `gameplay_calm.wav` : drone D + harpe pentatonique + vent + reverb (35s loop)
- Wire dans `merlin_game.gd` : `_setup_music()` (meme pattern que menu)
- Crossfade seamless (equal-power 3s)

### Phase 3 — Validation
- `python tools/sfx_forge.py --all` : regenerer 18 WAV
- `python tools/music_forge.py --all` : generer piste gameplay
- `python tools/cli.py godot validate_step0`
- Smoke MerlinMenu, MerlinGame, MerlinEnd

### Fichiers modifies
| Fichier | Action |
|---------|--------|
| tools/sfx_forge.py | v3 soft : PEAK -14, attaques, FM, _soft_finish |
| scripts/game/merlin_audio.gd | sfx_vol 0.45, volume_db -3 |
| tools/music_forge.py | NEW : generateur ambient procedural |
| scripts/game/merlin_game.gd | +_setup_music() gameplay |
