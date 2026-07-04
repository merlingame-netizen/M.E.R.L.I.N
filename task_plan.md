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
- [x] v10.23 (2026-07-04) : jet de dé animé fausse-3D + indice de dé + contribution lisible (566f6027) —
      gate R109 VERT en config propre (soak 200/200 + autoplay 3/3, 9 min, chaîne 14 beats).
      Leçon : ne PAS mesurer le gate en mode capture (fenêtre visible + I/O = runs 2-3× plus lents).

## v11 PIVOT (2026-07-04, user : « le jeu est trop complexe ») — EN COURS
Décisions verrouillées (AskUserQuestion) : 4 VERBES fixes évolutifs (PERCEVOIR/AGIR/PARLER/RESSENTIR,
tuiles permanentes) + TRAITS = qualités/manières (main ~4 repiochée chaque beat) + GREFFES par draft.
Gênes résolution confirmées : texte jaune géant + chips chiffrées + empilement.
- [x] Wave 0 quick-wins : phase « Expression » de la fusion SUPPRIMÉE (label jaune + aberration
      chromatique + zoom slow-mo → simple décrue glow/vignette) + chips chiffrées Intégrité/Corruption
      retirées de la vignette (les deltas vivent dans les ANNEAUX float_delta, un seul endroit §23).
      Incident : la purge python a emporté les statics Juice pack (`
func ` ≠ `static func`) —
      attrapé par SMOKE (pas validate_step0 !), restauré depuis HEAD. Gate R109 en mesure.
- [ ] Panel design v11 (wf wayiaqt56) : spec finale mapping 4 actions + ~16 traits, séquence de
      résolution, vagues incrémentales, guardrails migration (saves/probe_soak/autoplay).
- [x] Spec panel persistée : docs/spec_v11_pivot.md (eb34ee7a) — 4 vagues W1-W4, guardrails, cibles soak.
- [x] W1 résolution dégraissée (GATE VERT : soak 200/200 + autoplay 3/3, 7,2 min ; code-review 5
      findings corrigés dont 1 CRITICAL — done.emit manquant en reduced-motion = softlock du layer fx) : fusion 3 phases recapée {0,90/1,10/1,30/1,70 s} ×motion(),
      dé UNIQUE MerlinDice compressé (~1,15 s) lancé PAR fx en chevauchement sur la décrue (disque B8
      doublon supprimé), pill degré 170×48 (badge 58 px purgé), anneaux en commit différé post-typewriter
      (_gauges_deferred/_flush_gauges — fix « deltas sous le layer fx »), PARTIEL = ledger seul,
      sceau mort _slam_degree_seal purgé. Gate R109 + code-review en cours.
- [~] W2 EN COURS (étages) : (1) FAIT inline — moteur/données : merlin_card (family, make_actions 4
      verbes, starter_traits 16, is_action/is_corrupted_trait), merlin_resolution (_synergy v11 :
      +1 trait nourrit la famille canonique de l'action / -1 corrompu / 0 sinon + _card_family +
      porte éclatante unique : couverture pleine+coût 0+trait couvre+syn ou dé), merlin_run
      (actions permanentes, HAND_SIZE 4, redraw_hand cycle vrai, _enforce_hand_caps ≤1 corrompu,
      play_and_discard action-aware, SAVE_VERSION 2 invalidation propre + actions persistées).
      Parse 0/0. PAS ENCORE COMMITTÉ (guardrail : gate harnais réécrit d'abord).
      (2) Agent A (fond) : UI tuiles 260×116 + éventail 4 traits + suppression combo panel +
      merlin_action_view.gd + autoplay_run adapté. (3) Agent B (fond) : probe_soak action×trait
      5 archétypes + whitelist required_tags (scenario/prompt_builder). Gate final : validate +
      smoke 6 + soak 200/200 (assertions §K loguées) + autoplay 3/3 → UN commit W2.
- [ ] W3 greffes · W4 R131 remap/traits corrompus/BIBLE (spec §vagues).
- [ ] Fleet QA « agents humains » cohérence visuelle + gameplay (re-demandé par le user) — après Vague 1.

## v11 ÉCRAN STABLE « REIGNS » (2026-07-04, plan approuvé — docs/spec_v11_ecran_stable.md)
User : « animations ++, gameplay sommaire ET complexe, l'UI change trop entre phases, simplicité
REIGNS en lecture ». Verrouillé : écran stable / zéro modal / push en ligne / dé-jargonnage + tuto /
interventions 1/run / greffes V3 / transitions invisibles.
- [x] V1 : gate + commit W2 (143b03ac, 1409+/376-). Incidents gate corrigés : cap R113 dans les runs
      « pool anéanti » (assertion probe conditionnelle au cycle saturé + _draw_one_clean tampon) ;
      branche PACTE manquante dans autoplay (un pacte = spin deadline — verts passés = chance du
      tirage). Distribution §K transitoire (échec 28 %, éclatante 1,8 %) → recalibrage V3.
- [x] V2a LIVRÉE (gate vert : validate 0/0, smoke Game+Menu, soak 200/200, autoplay 3/3) : grille 6 zones fixes (encart 348 scroll_following, Z4 ligne d'état 72,
      décor 200, Résoudre permanent, _die_hint supprimé), swap_zone/set_zone_active,
      _choice_open, fix dim/fusion, suppression slide-up + beat_veil, chips dé-jargonnées,
      autoplay _choice_open même commit. Vigilances V2b : contraste chips sur BG_PAGE, cross-fade
      vignette↔push dans Z4 (114 px > 72), interstitiel à migrer, purger beat_veil/DUR_SLIDE_UP.
- [x] V2b LIVRÉE (gate vert : validate 0/0, smoke, soak 200/200, autoplay 3/3) : intro et draft/
      offrande DANS les zones (plus aucun modal), interstitiel sans WaitStage (attente inline +
      _interstitial_skip), push/pacte/vignette cross-fadés en Z4 (vignette du PARTIEL frappée APRÈS
      le choix), interventions 1/run, 2 hints tuto persistés [tuto], purges beat_veil/DUR_SLIDE_UP.
      Code-review : 6 findings corrigés (2 HIGH courses de tweens au double-clic — un seul
      propriétaire d'alpha par zone ; pacte en done-path — l'await sur _tw.finished perdait le
      pacte au skip ; skip d'interstitiel des outils capture ré-aligné).
- [x] V2 CLOSE : R136 au canon (70f6fb31), commits a87bdc9c (V2a) + 006fadc0 (V2b).
- [x] V3 GREFFES LIVRÉE (2026-07-04, task #48, gate vert : validate 0/0, smoke Game+Menu, soak
      200/200 + self-tests §E, autoplay 3/3 greffes réellement posées) : graft_banks 21 greffes
      (pilier_bank+enriched_pool convertis, lore conservé — Chœur gratuit / Être +1 one-shot /
      Compagnon +1 one-shot / Chevalier corr 0 / Enfant narratif ×1), champ grafts ADDITIF
      (refresh_from_grafts : tags=base+greffés, rarity=f(nb greffes), PAS de bump SAVE_VERSION),
      run.apply_graft (cap 3, prix one-shot, pas de save — atomicité _advance_to_next) +
      apply_graft_charges à la pose du verbe (chips vignette mutualisées), draft 2 GESTES
      (sélection levée+GOLD → Z4 re-titrée → tuiles éligibles await_pulse, dispatch
      _on_action_tile par _draft_active AVANT _state, 4 pleines = draft coupé), slots remplis
      dessinés (pastille famille / pip or / ✚n❖n✦n) + graft_pop + liseré re-dérivé.
      RECALIBRAGE mesuré : DIE_BANDS spec 17/33/50/67 → éclatante 2,3 %/morts 47,2 % (300 runs)
      → relâchée d'UN cran 33/50/67/83 → éclatante 2,9 %/morts 38,0 %, partiel IN. Distribution
      §K encore hors cible (échec 25,4 %, éclatante 2,9 %, morts 38 %, climax plein 1,1 %) —
      décision orchestrateur requise (le dé seul ne suffit pas ; voir vigilances V4).
- [ ] V4 : fleet QA captures 8 phases ×2 biomes (charte/anim/overlap/UX §23), purge banques legacy
      du chemin runtime, R137 + re-spec lore R49/R90/R92, tasks #45/#48 close.

