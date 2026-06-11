---
name: merlin-artwork
description: "Artworks génératifs M.E.R.L.I.N. (BIBLE §24, style R29 gravure sépia) : 1 image d'ambiance par situation + portraits des 12 cartes canon. Cascade gratuite concept_art_generator.mjs, post-traitement duotone CREAM/INK, cache sha1 + manifest, intégration Godot async."
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

# Skill `merlin-artwork` — Images génératives canon

> Mode d'emploi outillé de **BIBLE §24 (R119)** pour le dégel artworks (roadmap v10.18).
> Étend R29 (gravure/encre sépia, natif async, sujet=situation) et R48 (1 image PAR situation).
> ⚠️ Statut : les artworks restent **post-MVP** — ce skill prépare et outille, le câblage
> en jeu n'arrive qu'en v10.18 (décision « polish d'abord », R114).

---

## Auto-Activation

- **Mots-clés** : `artwork`, `image carte`, `illustration`, `gravure`, `sépia`, `portrait carte`,
  `image situation`, `concept art 2d`
- **Contexte** : projet Godot-MCP
- **Exclusion** : assets 3D GLB (→ skill `asset-forge`), UI pure (→ art_direction)

---

## Style canon (R29 + BIBLE §20)

**Gravure / encre sépia monochrome** — burin, hachures, clair-obscur. Prompt de base :

```
engraved etching illustration, sepia monochrome ink, woodcut crosshatching,
celtic mystical forest of Broceliande, [SUJET DE LA SITUATION],
dark wondrous-unsettling tone, aged parchment texture, no text, no frame
```

- **Sujet = la situation** (R48) : l'image illustre le beat courant, pas un personnage générique.
- **Post-traitement OBLIGATOIRE** : duotone vers la palette (ombres → INK #2A2018,
  lumières → CREAM #E8DCC0) — l'image appartient au parchemin, jamais une photo plaquée.
- Portraits des 12 cartes canon (v10.18) : même style, cadrage resserré sur le concept de la carte.

## Pipeline (réutilise l'outillage asset-forge)

1. **Génération** : `tools/asset-forge/concept_art_generator.mjs` — cascade 4 tiers gratuite
   (Gemini → Pollinations → HF → Kaggle). Fallback : `python tools/cli.py nano-banana generate-image`.
2. **QA** : `tools/asset-forge/qa_checks.mjs` (5 checks) — score ≥3/5 requis.
3. **Post-traitement** : duotone CREAM/INK (script Python PIL — à créer au premier usage v10.18 :
   `tools/artwork_duotone.py`).
4. **Cache** : `assets/artwork/cache/<sha1(prompt)>.png` + entrée `manifest.json` :

```json
{ "hash": "ab12…", "prompt": "…", "model": "gemini|pollinations|sd", "date": "2026-06-12T00:00:00Z", "approved": false }
```

Toute génération est **rejouable et traçable** (R119). Jamais d'image hors cache en jeu.

## Intégration Godot (v10.18)

- Zone artwork réservée du panneau situation (R72 layout) — placeholder = panneau actuel.
- **Chargement async** : le texte s'affiche IMMÉDIATEMENT, l'image fade-in (0.4s) quand prête.
  L'image ne bloque JAMAIS le texte ni l'input (R29 « live », pilier MINIMAL).
- Fallback sans-image = strictement l'existant (aucune régression si la gen échoue).
- Clé de cache en jeu : sha1 du prompt de situation → hit = instantané, miss = gen en fond.

## Checklist de sortie (gate BIBLE §24)

```
[ ] QA ≥3/5 sur chaque image (qa_checks.mjs)
[ ] Duotone appliqué (aucune image couleur brute en jeu)
[ ] manifest.json à jour (hash, prompt, model, date, approved)
[ ] Chargement async vérifié : zéro hitch, texte jamais retardé
[ ] Fallback sans-image indistinguable de l'actuel
[ ] art_direction (agent) approuve le lot ; lisibilité auditée (l'image ne mange pas le texte)
```
