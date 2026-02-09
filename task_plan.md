# Task Plan: M.E.R.L.I.N. — Le Jeu des Oghams

## Goal
Developper un JDR Parlant roguelite avec LLM local (Qwen2.5-3B Multi-Brain), systeme Triade (3 aspects x 3 etats), et narration procedurale.

## Current Phase
Phase 36 - Meta-Progression + Arbre de Vie + Flux (COMPLETE)

---

## Phases Recentes (2026-02-09)

### Phase 36: Meta-Progression + Arbre de Vie + Balance des Flux (COMPLETE)
- [x] 36.1 Backend: Constantes Flux + 28 TALENT_NODES + Evolution Bestiole dans merlin_constants.gd
- [x] 36.2 Backend: meta.talent_tree, bestiole_evolution, fonctions unlock/rewards dans merlin_store.gd
- [x] 36.3 Systeme de Flux cache in-run (3 axes, DC modifier, contexte LLM)
- [x] 36.4 Recompenses de fin de run (14 essences, fragments, liens, gloire)
- [x] 36.5 Arbre de Vie UI — 4eme onglet Hub (28 noeuds, deblocage, devises)
- [x] 36.6 Talents actifs dans gameplay (bonuses depart, boucliers, DC, reduction)
- [x] 36.7 Evolution Bestiole persistante (3 stades, affichage Hub)
- [x] 36.8 Validation + Documentation + Git Commit

### Phase 35: Project-Wide Resource Cleanup (COMPLETE)
- [x] 35.1 Supprimer fichiers junk racine (8 fichiers)
- [x] 35.2 Supprimer 19 scripts morts (3D/FPS/Reigns/anciens managers)
- [x] 35.3 Supprimer archive/artifacts/ (390 MB LLM builds)
- [x] 35.4 Archiver modeles 3D (Godot/ -> archive/3d_models/)
- [x] 35.5 Deplacer orange_brand_assets/ vers Bureau/Agents/Data/
- [x] 35.6 Nettoyer tools/ (15 JSON benchmark + 3 scripts one-time)
- [x] 35.7 Mettre a jour .gitignore (benchmark, node_modules, artifacts)
- [x] 35.8 Validation + Git Commit

### Phase 34: Mini-Jeux + Dual-Brain + Dice VFX + Resource Overhaul (COMPLETE)
- [x] 34.A Fix ressources + equilibrage (aspects [-3,+3], karma, benedictions, souffle regen)
- [x] 34.B Integration dual-brain (generate_parallel, GBNF gamemaster_choices, template)
- [x] 34.C Animation de 2D + VFX + audio (dice deceleration, CPUParticles2D, 5 SFX dice)
- [x] 34.D 15 mini-jeux (MiniGameBase, MiniGameRegistry, 5 champs lexicaux)
- [x] 34.E+F Choix critique + adaptation quete (DC+4, bordure doree, travel adaptatif)
- [x] 34.G Animations globales (hover/press SFX, card deparcheminement, jauges tween)

---

## Phases Recentes (2026-02-09)

### Phase 33: Documentation Cleanup v4.0
- [x] 33.1 Audit structure documentaire (120+ fichiers)
- [x] 33.2 Rewrite MASTER_DOCUMENT.md v4.0
- [x] 33.3 Update CLAUDE.md (LLM Multi-Brain, architecture)
- [x] 33.4 Rewrite docs/README.md v4.0 (129 fichiers indexes)
- [x] 33.5 Archive progress.md (4402 -> 504 lignes)
- [x] 33.6 Clean task_plan.md (supprimer obsolete)
- [x] 33.7 Dashboard Frontend (docs/dashboard.html)
- [x] 33.8 Move legacy docs to docs/old/ + corrections MOS/STATE
- [x] 33.9 Validation + Git Commit

### Phase 32: Multi-Brain + Worker Pool (COMPLETE)
2-4 instances Qwen2.5-3B avec worker pool adaptatif.
- [x] 32.A-F Dual-instance (Narrator + Game Master)
- [x] 32.G-I Multi-brain detection (1-4 cerveaux)
- [x] 32.J-N Worker Pool complet
- [x] 32.O-T Tests + QA + Optimizer + Knowledge Base
- [x] 32bis Bug fixes + TestBrainPool interactive quest
- [x] 32ter RPG mechanics (D20, travel fog, RAG context)
- [x] 32quater Buffer continu (3 cartes prefetch)

### Phase 31: Switch to Qwen2.5-3B-Instruct (COMPLETE)
- [x] Benchmark 5 modeles, Qwen2.5 gagne (83% comp, 100% logic, 726ms)
- [x] Suppression Trinity-Nano, recablage 10+ fichiers

### Phase 30: GBNF Grammar + Two-Stage (COMPLETE)
- [x] GBNF grammar dans GDExtension
- [x] Two-stage fallback (100% JSON valid)
- [x] GDExtension rebuild

### Phase 29: Async Pipeline + UX Masking (COMPLETE)
- [x] Prefetch pipeline, thinking animation, JSON repair 4-stage

### Phase 28: RAG v2.0 + Guardrails (COMPLETE)
- [x] RAG priority-based, journal, guardrails FR/repetition/length

### Phase 27: Trinity-Nano Migration (COMPLETE)
- [x] Architecture LLM documentee

### Phase 26: LLM TRIADE Pipeline (COMPLETE)
- [x] LLM branche sur Triade, benchmark scene

### Phase 25: Paysage Pixel Emergent (COMPLETE)
- [x] 7 paysages proceduraux, 6 phases animation

> Phases 1-24: archivees dans `archive/progress_archive_2026-02-05_to_2026-02-08.md`

---

## BACKLOG PRIORISE (mis a jour 2026-02-09)

### P0 — CRITIQUE (Core Loop Jouable) — PARTIELLEMENT FAIT

| # | Item | Complexite | Statut |
|---|------|-----------|--------|
| P0.1 | Connecter LLM a Triade | L | FAIT (Phase 26) |
| P0.2 | Fallback Cards Triade (50+) | L | EN COURS (~10 cartes) |
| P0.3 | Mission System | L | A FAIRE |
| P0.4 | Ecran de Fin de Run | M | A FAIRE |
| P0.5 | Boucle Complete (5 parties sans crash) | M | A FAIRE |

### P1 — IMPORTANT (Features Gameplay)

| # | Item | Complexite | Statut |
|---|------|-----------|--------|
| P1.1 | Ogham Skills Actifs (roue radiale) | XL | SPEC FAITE (Bestiole Tool Wheel) |
| P1.2 | Bestiole Care Loop | L | A FAIRE |
| P1.3 | Biome Modifiers in-game | M | A FAIRE |
| P1.4 | Hidden Depth: Resonances | M | A FAIRE |
| P1.5 | Systeme de Twists | M | A FAIRE |
| P1.6 | Saison / Calendrier in-game | M | A FAIRE |
| P1.7 | Merlin Voice in Triade | M | PARTIELLEMENT (SFXManager existe) |
| P1.8 | Promise System Complet | S | A FAIRE |
| P1.9 | Hidden Depth: Player Profile | M | A FAIRE |
| P1.10 | Fin Secrete | S | A FAIRE |

### P2 — NICE-TO-HAVE (Polish, Contenu)

| # | Item | Complexite | Statut |
|---|------|-----------|--------|
| P2.1 | Meta-Progression Inter-Run | L | A FAIRE |
| P2.2 | Audio Procedural Ambiance | L | PARTIELLEMENT (SFXManager 30+ sons) |
| P2.3 | Animations Carte Triade | M | A FAIRE |
| P2.4 | Redesign Parchemin 3 scenes | M | A FAIRE |
| P2.5 | Narratives Merlin par Contexte | M | A FAIRE |
| P2.6 | PNJ et Factions | L | SPEC FAITE (11_LES_PNJ) |
| P2.7 | Indices Lore Progressifs | M | A FAIRE |
| P2.8 | Tutorial Implicite | S | A FAIRE |
| P2.9 | Scene Collection / Grimoire | M | A FAIRE |
| P2.10 | Shaders Biomes | M | A FAIRE |

### P3 — FUTUR (Post-MVP)

| # | Item | Complexite | Statut |
|---|------|-----------|--------|
| P3.1 | Ogham Synergies | M | A FAIRE |
| P3.2 | Inter-Run Echoes | L | A FAIRE |
| P3.3 | Lunar Cycles | S | A FAIRE |
| P3.4 | Bestiole Personality | M | A FAIRE |
| P3.5 | Hub Ameliore | L | PARTIELLEMENT (HubAntre existe) |
| P3.6 | Easter Egg 1000 Runs | S | A FAIRE |
| P3.7 | Narrative Debt System | M | A FAIRE |
| P3.8 | A/B Testing Framework | L | A FAIRE |
| P3.9 | Mode Defi Quotidien | M | A FAIRE |
| P3.10 | Export Mobile | XL | A FAIRE |

---

## Prochaines Priorites Suggerees

1. **P0.2** — Ecrire 40+ cartes fallback Triade supplementaires
2. **P0.3** — Mission system (objectif par run)
3. **P0.4** — Ecran de fin de run (narration + score)
4. **P0.5** — Test boucle complete (5 parties)
5. **P1.1** — Ogham Skills Actifs (roue radiale, spec prete)

---

*Updated: 2026-02-09 — Documentation Cleanup v4.0*
