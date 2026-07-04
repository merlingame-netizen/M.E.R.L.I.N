# task_plan.md — v10.21 « Présences » : personnages, events, lisibilité, G1 (2026-06-30)

> Co-designé avec le joueur (2 rounds AskUserQuestion). Spec passée au panel adversarial
> (canon/UX/balance + audit). Tasks harness #30-35.

## Décisions verrouillées (user)
- Silhouette PAR PILIER dans le décor (pas de sigil), SEULEMENT aux beats du PNJ (Rencontre + retour + interventions)
- Ambiance signée complète : lumière/particules + nappe sonore + réaction œil-lune
- Interventions du pilier 1-2×/run, séquence scriptée ~1.5s skippable, les 3 mécanismes (bénir carte / altérer beat / don-prix)
- Lisibilité : les 4 axes (contraste décor-lecture, jauges pré-alerte + delta animé, cartes sans hover, beat map frontières)
- Overhaul = G1 : partiel → choix « Encaisser / Pousser » (+1 Corruption → Réussite), re-mesure soak

## Vagues (ordre d'exécution)
| Vague | Contenu | Fichiers principaux | Gate |
|---|---|---|---|
| Spec (#30) | Panel design adversarial | — | spec finale reçue |
| V (#31) | 5 silhouettes procédurales + particules signées + œil-lune | merlin_scene_art | validate+smoke+capture |
| I (#32) | Interventions (compteur R108, tag temp {card_id:tag} dans run, ligne signée via from_chars) | merlin_scenario, merlin_run, merlin_game, probe_soak | validate+smoke+soak 200/200 |
| L (#33) | 4 axes lisibilité | merlin_game (jauges), merlin_card_view, merlin_beat_map (bornes quêtes via setup), merlin_scene_art (focus lecture) | validate+smoke+captures |
| G (#34) | Encaisser/Pousser + politiques archétypes soak + cibles (partiel eff. 35-40%, corrompu ≤16-18%) | merlin_game, merlin_resolution, probe_soak, BIBLE R129 | soak 200/200 cibles + autoplay 3/3 |
| A (#35) | 5 pads sonores signés (forge) + canal pad unique | music_forge/sfx_forge, merlin_audio | validate+écoute |

## Acquis session (contexte)
- R127 factions/piliers (Waves A-D) · R128 résolution même-fil + attente enrichie
- Harnais autoplay RÉPARÉ : gate R109 vert (soak 200/200 + autoplay 3/3) · mode --slow QA
- Anti-répétition fallbacks (_fb_served)

## Progrès goal (2026-06-30, session courante)
- [x] Refonte décor organique (55be0d82) — QA 3 rounds captures
- [x] MERLIN détaillé + 5 silhouettes piliers + probe_pilier.gd (75a775c1) — QA probe plein écran
- [x] Hover décor : arbres/lune/menhir/herbe (d3c8dc14)
- [x] BIBLE R129 posée · spec panel persistée (docs/spec_v10.21_presences.md)
- [ ] PROCHAINE SESSION : Wave I (interventions — spec §I, miroir save R108 de pilier_offering_done),
      puis L (lisibilité), G (Encaisser/Pousser + soak cibles), A (pads), uniformisation Selection/End/Options.
- [x] Uniformisation scènes : MerlinEnd backdrop vivant + hover auto-alimenté partout (ae86e08a)
- [x] Wave L COMPLÈTE : (a) recul lecture (b) jauges pré-alerte+Emprise (c) cartes sans hover (d) chaîne quêtes map (561127cf, 8b02e522, 89bd12ef)
- [ ] RESTE (sessions suivantes, spec chiffrée docs/spec_v10.21_presences.md) : Wave I (interventions),
      Wave G (Encaisser/Pousser + soak cibles), Wave A (pads sonores par pilier).
- [x] Wave A COMPLÈTE : 5 nappes signées par pilier (forge + canal unique play_pad/stop_pad) (c9060742)
- [x] Hover++ : brume qui s'écarte, lucioles qui fuient, feuillage qui s'éclaire — 7 éléments réactifs (3b058573)
- [ ] RESTE : Wave I (interventions) + Wave G (Encaisser/Pousser) — gameplay systems, spec intégrale
      dans docs/spec_v10.21_presences.md §I et §G + regles_g1. Démarrer par I (miroir de pilier_offering_done).
- [x] Wave G COMPLÈTE : R130 Encaisser/Pousser + re-mesure (partiel eff. 31.6%, corrompu 14.5%) (f2c1de8a)
- [x] Wave I COMPLÈTE : R131 interventions (planning R108, bénédictions ✦, pactes opt-in, soak miroir) (6a59b791)
- [x] GOAL v10.21 : les 6 chantiers livrés. R109 final (autoplay 3/3) en re-mesure de clôture.
- [x] CLÔTURE GOAL v10.21 (2026-07-04) : gate R109 COMPLET VERT — soak 200/200 + autoplay 3/3, 0 SCRIPT
      ERROR, avec TOUS les systèmes exercés (pushes R130 dans les 2 branches, offrandes, chaînes 12 beats).
      2 régressions attrapées et corrigées par le gate lui-même (cast quests, harnais push-aware).

## v10.22 (2026-07-04, feedback playtest + screenshot) — livré
- [x] A/B hover subtil (fix jitter de phase) + Merlin sans chapeau (84a149e5)
- [x] C cartes de sélection à la charte (84a149e5) · E bulles identifiées + aléatoires (bc1f0ce7)
- [x] D préambule lore par biome (e9d9b044) · F 2 BIOMES + menu nu + pop progressif (59ac7e4d)
- [x] BIBLE R132 · gate R109 v10.22 en mesure
- [ ] G fleet QA (charte/anim/overlap/UX) — PROCHAINE SESSION avec captures fraîches des 2 biomes
- [x] GATE R109 v10.22 VERT (2026-07-04) : soak 200/200 + autoplay 3/3, 0 SCRIPT ERROR (budget 600s/2200s)
