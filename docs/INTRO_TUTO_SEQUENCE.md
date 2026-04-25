# Plan sequentiel — Intro CeltOS + First Run Tutoriel

> Source de verite pour le timing et l'ordre d'apparition.
> Toute modification du flow tuto DOIT mettre cette doc a jour AVANT le code.

---

## Vue d'ensemble

```
[T=0]   Boot CeltOS                        ~12-15s
[T=15]  Logo CeltOS 3D pivotant            ~4s
[T=19]  Fade out + transition Broceliande
[T=20]  Tuto Broceliande commence (mode _is_tutorial=true)
[T=20]  Phase 1: Black + Merlin VO
[T=24]  Phase 2: Reveal sky
[T=27]  Phase 3: Reveal forest
[T=30]  Phase 4: Quest parchment + drawn path
[T=37]  Phase 5: Reveal walker + start autowalk
[T=37+] Run guidee — 3 cartes scriptees aux 25/55/85% du chemin
[T=~150] Fin run → +50 Anam → MerlinCabinHub
```

---

## Regle d'or du sequencement

**Une voix a la fois. Un effet a la fois.**

L'ancienne version melangeait : Merlin parle ET le parchemin charge en meme temps.
La regle est : la phrase de Merlin est PRONONCEE D'ABORD, l'effet visuel est decleche APRES.

```
Merlin: "Voici ta quete. Lis-la bien."  → typewriter (~2s) + hold (~1s)
                                         ↓
                  Parchemin se materialise (5s lecture autonome, sans VO concurrente)
                                         ↓
Merlin: "Marche maintenant."             → typewriter (~2s) + hold (~1s)
                                         ↓
                  Walker apparait + autowalk demarre
```

---

## Sequence detaillee (Brocéliande tutoriel)

| Step | Duree | VO Merlin | Effet visuel post-VO |
|------|-------|-----------|----------------------|
| 1 | ~3s | "Voyageur. Tu es la, enfin." | (rien — black screen) |
| 2 | ~4s | "Regarde — je vais te montrer ce monde, fil par fil." | (rien) |
| 3 | ~3s | "Le ciel d'abord. La voute sous laquelle nous marchons." | **APRES la phrase** : sun_light.visible=true + WorldEnvironment.background restored |
| 4 | ~3s | "Puis la terre. Broceliande s'eveille a ton arrivee." | **APRES la phrase** : forest_root.visible=true |
| 5 | ~3s | "Et voici ta quete. Lis-la bien." | **APRES la phrase** : `_show_quest_parchment()` (~5s autonomes) |
| 6 | ~3s | "Marche maintenant. Trois epreuves, et tu seras pret." | **APRES la phrase** : player.visible=true + merlin_node.visible=true + autowalk start |

**Total Merlin VO** : ~19s + ~5s parchemin = **~24s** avant que la marche commence.

---

## Cartes scriptees

3 cartes aux waypoints **25%**, **55%**, **85%** du chemin (3 markers rouges du parchemin).

| # | Position | Titre | Contexte narratif |
|---|----------|-------|-------------------|
| 1 | 25% | Le Premier Souffle | Apprend la respiration calme |
| 2 | 55% | Le Carrefour des Eaux | Choix moral simple |
| 3 | 85% | Le Seuil de Merlin | Passage final |

Chaque carte = **3 choix neutres** (pas de mecanique faction/Ogham en tuto).
Pas de LLM, contenu en dur dans `TUTORIAL_CARDS`.

---

## Visibilite 3D — exigences

- **Camera FOV** : 70deg minimum (sinon tunnel vision)
- **Skybox** : `Environment.background_mode = BG_SKY` avec `PhysicalSkyMaterial` (sinon background noir = on voit rien)
- **Sun light** : `light_energy = 1.5+` (sinon ambiance trop sombre)
- **Fog** : `fog_enabled = true`, densite faible (0.005), couleur grise-bleue (atmosphere foret)
- **Ambient light** : `Environment.ambient_light_energy = 0.4+` (eviter "trop noir")

---

## Anti-patterns (ne JAMAIS faire)

- ❌ `await effet()` AVANT `await _vo_speak_line()` → l'effet bloque la voix
- ❌ Plusieurs VO concurrentes (deux Label qui typent en meme temps)
- ❌ Parchemin qui apparait sans phrase d'introduction prealable
- ❌ Walker visible des le black screen (rompt le "Merlin batit le monde")
- ❌ Carte qui s'ouvre au moment d'un autre fade in (cognitive overload)

---

## Captures pour QA visuelle

Lancer un capture run :
```bash
python tools/cli.py godot smoke --scene "res://scenes/BroceliandeForest3D.tscn" --duration 30 --capture 200
```

Genere `tools/autodev/captures/run_<timestamp>/frame_*.png` toutes les 200ms.
Verifier que **chaque frame est lisible** : un seul focus visuel a la fois.

---

*Mise a jour : 2026-04-25 — Version 1*
