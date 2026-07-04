# SPEC v11 — ÉCRAN STABLE « REIGNS » (design agent + plan approuvé user, 2026-07-04)

> Feedback user : « l'UI/UX change trop lors des phases, je veux de la simplicité à la REIGNS en
> lecture ». Décisions verrouillées : UN écran stable · plus aucun modal · Encaisser/Pousser en ligne ·
> moins de concepts affichés (tuto 2 premiers beats) · interventions 1/run · greffes ensuite (V3) ·
> priorité animations = transitions invisibles.

## Règle unique

Chaque zone a une hauteur FIXE (`custom_minimum_size`, `SIZE_FILL`, zéro `SIZE_EXPAND_FILL` vertical),
existe 100 % du temps (`visible = true` toujours) et ne change que son CONTENU par cross-fade
`modulate` 0,18-0,25 s ×`motion()`. L'interactivité s'éteint par `mouse_filter`, jamais par `visible`.

## Grille 1920×1080 (marges 16 v / 28 h, séparations 8)

| Zone | H | Contenu permanent |
|---|---|---|
| Z1 HUD | 60 | anneaux Intégrité/Corruption + beat map (inchangé) |
| Z2 DÉCOR | 200 | `_scene_art` 280→200 (dessine relatif à `size`) |
| Z3 ENCART | 348 fixe | bordure teintée par phase (conservé). `_req_row` EN TÊTE, hauteur réservée 26 px (alpha-fade, plus de visible=false). `_situation_text` : `fit_content=false` + `scroll_active=true` + `scroll_following=true` (fil type VN — toute longueur tient sans reflow ; textes courts alignés haut, CenterContainer vertical supprimé). FS_NARRATIVE conservé |
| Z4 LIGNE D'ÉTAT | 72 fixe | HBox [slot central extensible + caret aligné droite]. Porte selon la phase : hint skip / caret « continuer » / bouton « Accepter ✦ » / vignette (pill 170×48 + chips) / Encaisser-Pousser 320×56 / pacte / titre + « Passer » du draft / hints tuto. `_res_block` de l'encart DISPARAÎT |
| Z5 ÉVENTAIL | 208 | `_hand_box` permanent (cartes 150×190 ; lift déborde sur Z4 : cosmétique assumé, clip_contents=false) |
| Z6 ACTIONS | 120 | 4 tuiles 260×116 + Résoudre 240×66 PERMANENT (désarmé = alpha 0.35 + disabled ; armé = alpha 1 + pulse — fini le reflow HBox). `_die_hint` SUPPRIMÉ |

Suppressions : slide-up +12 px de l'encart (`_present_current_beat`), `MerlinFx.beat_veil`
(cross-fades le remplacent — garder la garde `_beat_transition`), WaitStage plein écran de
l'interstitiel (caption + spark DANS l'encart).

Helpers `merlin_visual.gd` : `DUR_ZONE_FADE = 0.22` ; `swap_zone(zone, build: Callable)`
(fade-out 0.18 → rebuild contenu → fade-in 0.22, ×motion()) ; `set_zone_active(zone, on)`
(modulate 1.0/0.35 + mouse_filter récursif).

## Matrice phase → contenu (tout = cross-fade dans la zone ; « dim » = alpha 0.35 + souris off ; Z1/Z2 ne changent jamais)

| Phase | Z3 ENCART | Z4 ÉTAT | Z5 ÉVENTAIL | Z6 ACTIONS |
|---|---|---|---|---|
| Intro de quête | titre 40 px + pitch (typewriter) + objectif — DANS l'encart | « Accepter ✦ » centré (pulse) | main beat 1 dim (teaser) | tuiles dim (apprentissage passif) |
| Interstitiel | « Merlin raconte » ; attente LLM = caption + spark DANS l'encart | hint skip → caret | dim | dim |
| Situation | typewriter (fade 0.45→1.0, sans slide) | hint « ▶ clic pour passer » puis alpha 0 | dim | dim, sans feedforward |
| Choix | texte plein + pastilles requis (fade-in en tête) | hints tuto beats 1-2, sinon vide | ACTIF (deal_in conservé) | actives + feedforward + Résoudre 0.35→1.0 à la paire |
| Fusion | inchangé (MerlinFx overlay court assumé) | vide | dim | PLEINE alpha — Z6 ne s'estompe qu'APRÈS `await fx.run()` |
| Issue | même fil R128 | vignette fade-in (pill+chips) puis caret | dim | dim |
| Partiel | idem issue | Encaisser/Pousser (ledger) → après choix : cross-fade vignette + caret | dim | dim |
| Intervention/pacte | ligne signée à la suite | Accepter/Refuser du pacte | dim | badge ✦tag sur tuile bénie |
| Draft/Offrande | texte issue reste (contexte) | titre + « Passer » | cross-fade 4 traits → 3 cartes | (V3 : tuiles éligibles pulsent en attente de cible) |

## Dé-jargonnage (V2)

1. `_die_hint` supprimé (le liseré de tuile porte la qualité, R133).
2. Chips vignette : « ⚄ Le sort a souri » (chiffre retiré) ; chip « resta muet » SUPPRIMÉE ;
   chips effets ✚/❖/✦ conservées ; pill conservée.
3. Vocabulaire couleur final : GOLD = sélection/à toi · couleur de famille = tag · VIOLET =
   corruption · liseré tuile = chance du dé. Aucun mot synergie/couverture/rareté à l'écran.

## Micro-tuto (2 hints one-shot — labels passifs DIM_WARM dans Z4, MOUSE_FILTER_IGNORE)

- Hint A (beat 1, ouverture du choix) : « Choisis un *verbe* (tuile) et une *manière* (carte),
  puis Résous. » Désarmé à la première paire complète.
- Hint B (beat 2) : « La forêt réclame ● ● — les tuiles soulignées d'or y répondent. » Désarmé
  au premier clic de tuile du beat 2.
- Persistance : section `[tuto]` dans `user://options.cfg` via statics MerlinVisual (pattern
  `reduced_motion`).

## Interventions

`_maybe_intervention` : cap `pilier_interventions >= 2` → `>= 1` ; planification du 2e beat retirée.

## Découpage & harnais

V2a = grille + estompes + fix dim/fusion + suppression slide-up/beat_veil + chips.
V2b = modals→zones (intro, interstitiel, draft `_open_draft_zone` + flag `_draft_active`
remplaçant `_draft_layer` ; push/pacte/vignette re-ciblés Z4) + tuto + interventions 1/run.
`_set_choice_ui` → `set_zone_active` + flag `_choice_open` (garde anti-clic de
`_on_action_tile`/`_on_trait_card`).
**autoplay_run.gd MÊME COMMIT** : `_draft_layer != null` → `_draft_active` ;
`_hand_box.visible` → `_choice_open`. TOUS les autres noms conservés (`_accept_quest`,
`_intro_open`, `_interstitial_open/_wait`, `_end_interstitial`, `_push_pending/_push_row`,
`_pact_row`, `_on_push_choice`, `_state`, `_on_action_tile/_on_trait_card/_on_resolve`,
`_advance_to_next`, `_tw`, `_skip_typewriter`, `_can_advance`).
R108 : saves inchangées (champs identiques ; une save W2 avec 2 interventions planifiées reste
valide, le cap coupe à l'exécution).

## Gate V2

validate 0/0 → smoke 6 scènes → soak 200/200 → autoplay 3/3 → captures 8 phases
(MERLIN_CAPTURE_DIR, JAMAIS en mode gate) + vérif « zéro changement de position/taille de zone »
+ audit §23 + reduce-motion. Commit à V2a ET V2b.
