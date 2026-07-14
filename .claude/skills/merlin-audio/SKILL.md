---
name: merlin-audio
description: "Pipeline audio M.E.R.L.I.N. (BIBLE §22) : SFX procéduraux physical-modeling numpy/scipy (harpe Karplus-Strong, cloches modales, bol banded-waveguide, membrane bodhran, foley granulaire ; tools/sfx_forge.py) + normalisation loudness pyloudnorm (tools/sfx_normalize.py, true-peak -14 dBFS, byte-reproductible), stingers par degré, musique, bus/ducking, catalogue canon. Pour tout son/SFX/musique/stinger du jeu."
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

# Skill `merlin-audio` — Pipeline son 100% Claude

> Mode d'emploi outillé de **BIBLE §22 (R117)**, étend R30 (SFX feutrés organiques, Merlin
> texte-seul) et R76 (drone celtique sans mélodie, stems additifs, stingers samples).

---

## Auto-Activation

- **Mots-clés** : `sfx`, `son`, `audio`, `musique`, `stinger`, `bus`, `volume`, `ducking`,
  `nappe`, `drone`, `musicgen`, `wav`
- **Contexte** : projet Godot-MCP
- **Exclusion** : voix parlée / TTS (Merlin est texte-seul au MVP, R30)

---

## Architecture (BIBLE §22)

- **3 bus** : Master → Music, SFX (curseurs Options R74, mapping 1:1)
- **Autoload `MerlinAudio`** (cible v10.16) : `play_sfx(id: String)`, `play_stinger(degree: String)`,
  `set_corruption_layer(level: int)` — pré-chargement des WAV au boot
- **Ducking** : musique -6dB pendant un stinger, retour en 0.8s
- **Défauts** : Master 80% · Music 60% · SFX 80% · **loudness-match par catégorie + plafond true-peak -14 dBFS (GATE R156 ; tools/sfx_normalize.py + manifest.json)** ; note : sons ~8 dB plus doux qu'au peak-only, monter sfx_vol/bus à l'écoute si besoin

## Catalogue SFX v1 (ids CANON — BIBLE §22, ne pas inventer d'autres ids)

`card_pick` (papier glissé) · `card_play` (papier posé + souffle) · `card_discard` (froissé doux) ·
`deal` (éventail, pitch ±5%) · `button_tap` (bois mat) · `gauge_up` (goutte claire) ·
`gauge_down` (corde sourde) · `corruption_tick` (murmure granuleux) · `seal_stamp` (sceau de cire) ·
`beat_turn` (page tournée) · `draft_reveal` (carillon feutré) · `whisper_threshold` (souffle dissonant).

**Stingers** (≤2.5s, R76) : `stinger_echec` (corde frottée descendante) · `stinger_partiel`
(accord suspendu) · `stinger_reussite` (accord chaud résolu) · `stinger_eclatante`
(accord ouvert + harmonique). Joués à l'apparition du sceau (R112).

## Pipeline 1 — SFX procéduraux (`tools/sfx_forge.py`)

```bash
python tools/sfx_forge.py --list                 # recettes disponibles
python tools/sfx_forge.py --id card_pick         # génère audio/sfx/card_pick.wav
python tools/sfx_forge.py --all                  # tout le catalogue
```

- Sortie : `audio/sfx/<id>.wav` (WAV mono 44.1 kHz 16-bit), normalisé loudness (LUFS par catégorie, true-peak -14 dBFS) + `manifest.json`.
- Recettes = **modélisation physique** (R156) : Karplus-Strong harpe, banque modale cloches, banded-waveguide bol, membrane bodhran, bourdon frotté, foley granulaire ; anti-aliasing (oversampling 4x) ; `SYNTH_MIX` 0.15 (harpe/bol 100% acoustiques). Matière celtique feutrée, pas de bip 8-bit, pas de laser. Déterministe (seed fixe R119, byte-reproductible).
- Modifier une matière = éditer la recette dans `sfx_forge.py`, PAS remplacer par un sample
  externe sans décision user (100% local, génératif, rejouable).

## Pipeline 2 — Musique (MusicGen)

```bash
python tools/musicgen_theme.py        # thème menu (existant) — boucle crossfade equal-power
```

- Pattern : prompt celtique + crossfade equal-power pour boucle sans couture.
- **Run** (v10.16) : drone SANS mélodie (R76), 2 couches additives — basse permanente +
  granuleuse dissonante dont le volume suit le palier Corruption (R75 : +6dB par palier).
- JAMAIS de mélodie forte pendant la lecture de prose (la prose est reine).

## Intégration Godot

1. Importer les WAV (keep par défaut ; loop OFF pour SFX, ON pour nappes).
2. `MerlinAudio.play_sfx("card_play")` aux points de déclenchement du catalogue — UN SEUL
   son par événement (pilier MINIMAL : pas de cacophonie ; si deux events simultanés,
   le plus spécifique gagne).
3. Variation : pitch_scale aléatoire ±5% sur les SFX répétitifs (`deal`, `card_pick`).

## Checklist de sortie (gate BIBLE §24)

```
[ ] Peak ≤ -3dB sur chaque WAV généré (sfx_forge normalise — vérifier le rapport)
[ ] Écoute manuelle de chaque nouvel asset (matière feutrée-organique, pas synthétique-agressif)
[ ] 100% des déclencheurs du catalogue joués pendant un autoplay sans erreur
[ ] python tools/cli.py godot smoke --scene <scènes touchées> → passed=true
[ ] Curseurs Options fonctionnels (3 bus)
[ ] Pas de son pendant la décision joueur qui masque l'info (pilier ÉVIDENT)
```
