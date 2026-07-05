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

## CAHIER DES CHARGES V1.0 (2026-07-04, plan approuvé)
- [x] Questionnaire 200 questions tous métiers PERSISTÉ : docs/cdc_v1_questionnaire.md
      (40 GD / 25 BAL / 30 NAR / 20 DA / 20 AUD / 25 UX / 20 TEC / 20 PRO — options A-D + RECO
      argumentée par question, ancrées R1-R137 + mesures soak ; 12 ⚠ structurantes en tête).
      Convention : le user annote `> RÉPONSE : X` ; non annotée = RECO adoptée.
- [x] Les 12 structurantes TRANCHÉES en interactif (toutes = RECO) : fin du Graal jouable,
      12 fragments, seuil onirique complet, réputation 3 effets, Fusion ~12 fragments (gabarits
      main + coda LLM), artworks par quête, musique réactive 2 couches, streaming résolution,
      export gaté dès V4, whitelist obligatoire, DoD composite, itch.io gratuit (578f6da3).
- [x] USER : « Adopte toutes les recos pour la suite, go » — les 188 restantes = RECO adoptée.
- [~] EN COURS (3 agents parallèles, 2026-07-04) :
      (1) Consolidation docs/cdc_v1.md (200 règles CDC-XX-NN traçables + objectifs mesurables +
          roadmap V4→v0.9→v1.0 + renvois d'amendements BIBLE) — agent acc676e9cf3190c2e.
      (2) v1.0-V4a recalibrage §K multi-leviers DANS L'ORDRE avec soak 300 après CHAQUE levier :
          whitelist branchée au jeu réel → climax 2+1 → drafts garantis (transition + ouverture) →
          éclatante (clause retirée, +1 Intégrité) → dé 17/33/50/67 si morts OK → contre-pression
          §E en dernier. Gates par archétype en dur (optimal ≤10/greedy-chaotic ≤30/corrompu ≤25).
          — agent a2bc1026fbbd1a419 (task #50).
      (3) v1.0-V4b export Windows : preset + résolution chemin GGUF hors éditeur + commande
          export_gate (build exporté DOIT passer 1 autoplay) — agent a75f2eb61ca16fcf2 (task #51).
- [ ] Au retour : commits par chantier (gates R109), BIBLE R138 (CDC adopté) + amendements
      listés par le CDC, puis suite roadmap V4 (fleet QA task #45, purge legacy PRO-19).


---

# task_plan — v1.0-V4a « recalibrage §K multi-leviers » (2026-07-04)

> Cahier des charges docs/cdc_v1_questionnaire.md — méthode PRO-17-A : 1 levier → soak 300 → tableau §K.

## Baseline (soak 300) : échec 25,3 (cible 3-8) · partiel 28,5 IN · réussite 43,4 (45-55) ·
## éclatante 2,8 (8-15) · morts mixte 36,6 / optimal 0 · climax plein 1,1 (45-55) · drafts 2,69 (5-6)

| # | Levier | Fichiers | Statut |
|---|--------|----------|--------|
| 1 | Whitelist branchée au jeu réel (BAL-14-A/TEC-17-A) | merlin_scenario, merlin_prompt_builder, probe_soak (selftest chemin jeu) | pending |
| 2 | Climax 2+1 : REQ_GAP_BY_DIFF[3]=2 (BAL-13-A) | merlin_scenario | pending |
| 3 | Drafts garantis : transition de quête + ouverture (BAL-11-B/GD-27) | merlin_game, probe_soak | pending |
| 4 | Éclatante : porte sans clause trait-couvre + delta +1 (BAL-02-B+BAL-25) | merlin_resolution | pending |
| 5 | Dé re-serré 17/33/50/67 (BAL-12-B) SI morts optimal ≤10 et mixte en baisse | merlin_resolution, probe_soak | pending |
| 6 | Contre-pression §E : quête 3 + greffes ≥3 → 3 requis (GD-32-B) | merlin_scenario, merlin_game, probe_soak | pending |
| 7 | Assertions dures : gates morts/archétype + 4 bandes si atteintes | probe_soak | pending |

Gates finaux : validate_step0 0/0 → smoke MerlinGame+MerlinMenu → soak 200 → soak 300 (tableau §K) → autoplay 3/3. JAMAIS committer.

## Clôture V4a (2026-07-05) — VAGUE VERTE, commit 4562371b
- 8 leviers mesurés (L5 dé 17/33/50/67 REJETÉ par mesure — repli 33/50/67/83 ; L7 couverture
  retag 4 traits + biais greffés ; L8 barème échec par difficulté −2/−2/−3 via resolve(diff)).
- §K final : réussite 50,1 IN · éclatante 11,1 IN · corruption 5,63 IN · 0 hors-pool DUR ·
  gates morts archétype TOUS PASS (0/0/9,3/0). OUT logués BAL-20-B : échec 18,9 · partiel 19,9 ·
  climax 12,2 · morts 4,6 sous-bande (sur-amorti L7+L8 — re-serrage par répit BAL-06, pas barème).
- BIBLE R139 posée. Autoplay budget 600→960 s (faux rouge deadline sur chaîne 3 quêtes).
- Reste tracé : bug pré-existant resume beat 0 (chip spawn_task task_65ee520d).

---

# task_plan — #52 fix « Invalid polygon data » MerlinEnd (2026-07-05)

- Cause : polygones AUTO-INTERSECTANTS dans merlin_scene_art._draw() — (a) rubans d'onde falaises
  (bords haut ±0.008h / bas +0.012h±0.006h se croisent au fil de _t) ; (b) creux de survol brume
  v10.21 cassait l'invariant v10.22 (bord haut poussé à 1.35×th sous le bord bas). Build exporté
  seulement : curseur réel + biome falaises hérité de la run.
- Fix : amplitudes bornées (invariant « bords ne se croisent jamais » par construction) +
  garde réutilisable MerlinVisual.polygon_drawable() sur les 7 polygones générés par boucle.
- Gates : validate 0/0 · smoke MerlinEnd (forêt + falaises) + MerlinGame + MerlinMenu tous PASS,
  0 « triangulation failed ». Preuve build : export_gate biome falaises EN COURS (bnlw96nyj).

---

# task_plan — v11-N1 Narration JDR 2e personne présent (2026-07-05)

User (screenshot beat) : texte situationnel trop court/passif, « le Voyageur se demandait que faire »,
résolution générique 3e pers., pont « je continue le chemin ». Veut : 2e pers. présent (« Vous prenez… »),
situations riches PNJ-actif, résolution = action italique + le monde réagit, d20+arbre de talent (→ Vague 2).

Décisions verrouillées (AskUserQuestion ×2) : narratif d'abord / d20 superposé / talent in-run / greffes
étendues ; puis présent voix MJ / action italique + conséquence riche / pont supprimé / situations 3-4 ph.

Fait (moteur d6 INCHANGÉ, R135/R139/§K non touchés) :
- prompt_builder : SYSTEM_PREFIX MJ 2e pers présent (zéro « Voyageur »), resolution() action [i]…[/i] +
  monde réagit par degré, arc()/opening() 2e pers présent 3-4 ph PNJ-actif, faction_pilier_block « vous ».
- scenario : SITU_FALLBACKS/RESO_FALLBACKS(_LONG)/FALLBACK_ARCS/OPENING_FRAMES réécrits ; note_outcome
  gist « vous… » + bridge SUPPRIMÉ ; build_situation pont retiré + filet anti-filler étendu.
- game : ensure_italic_action sur l'issue ; PUSH_CODAS « Vous ».
- prose : ensure_italic_action() (garantit [i]1re phrase[/i], balises équilibrées).
- probe_prose : CATALOG_GATE déterministe (zéro 3e pers / filler, [i]Vous…, balises).
- BIBLE R140.

Gates : validate 0/0 · smoke Game/Menu/Selection/End PASS · CATALOG_GATE pass · soak 200/200 (iso R139) ·
autoplay 3/3 LLM ON [en cours] · capture d'œil ph4/ph6 [à faire post-autoplay].
