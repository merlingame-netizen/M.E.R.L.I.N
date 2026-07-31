# Rapport de conformité — Pipeline scénario M.E.R.L.I.N

> Contrat de référence : `data/ai/scenario_templates.json` v1.0.0 (jumeau machine-readable) + `docs/30_jdr/SCENARIO_TYPES_SPEC.md` v1.0 (2026-07-25) + `docs/GAME_DESIGN_BIBLE.md` §5.4, §25-§28, §30.
> Périmètre audité : les 4 étages du pipeline (titres → intro → squelette → cartes) et leur consommation runtime (`scenario_loading.gd` → `merlin_store` → `board_narration._run_live_loop` → `LiveCard3D`), plus l'état de jeu et les systèmes d'équilibrage.
> Date : 2026-07-26. Base de code : branche courante, HEAD local.

---

## 1. Verdict

**Non** : le jeu ne produit aujourd'hui aucun scénario conforme au contrat — la structure canonique (longueurs 11/15/17/21/25, 5 actes, 3 routes isométriques, checks, schéma de carte) n'est ni générée par le planner ni consommée par la boucle de jeu, qui joue 5 cartes fixes tirées d'un pool statique ; seules les règles d'équilibrage locales du squelette (adjacence, placement du LÉGENDAIRE, climax, part NARRATIVE) sont implémentées, et elles n'atteignent jamais la carte affichée.

Cadrage : l'audit interne du projet (`docs/30_jdr/PIPELINE_OUTPUT_AUDIT.md`, généré en exécutant le vrai `_balance_skeleton` via `tools/godot/conformance_pipeline.gd`) mesure déjà 0/12 sur les 4 règles structurelles et 1/12 sur la longueur canonique. Ce rapport ne contredit pas ce chiffrage : il l'étend au runtime et le rend actionnable.

---

## 2. Tableau de synthèse

Légende `Vérif.` : **C** = confirmé par relecture adversariale ligne à ligne ; **R** = vérifié par relecture directe lors de la rédaction de ce rapport ; **NV** = non re-vérifié de façon adversariale (constat de première passe, à confirmer avant chantier).

| # | Écart | Sév. | Vérif. | Zone | Fichier(s) à corriger |
|---|---|---|---|---|---|
| C1 | Longueur de run figée à 5 cartes en dur | CRITICAL | C | runtime | `scripts/board_narration/board_narration.gd:2914`, `:2749-2753` |
| C2 | Le squelette équilibré n'est jamais converti en cartes (`generate_card_for_beat` orphelin) | CRITICAL | C | étage 4 + runtime | `board_narration.gd:1692`, `:2749-2883` ; `scenario_planner.gd:840` |
| C3 | Aucun branchement : ni 3 routes, ni `leads_to_card_id`/`route_mask`/`branch_label` | CRITICAL | C | étages 1-4 + runtime | `scenario_skeleton.gbnf`, `scenario_planner.gd:586`, `board_narration.gd:1692` |
| C3b | Bug d'ordre : `init_run` lit `current_biome` avant son écriture → catalogue de scénarios mort | CRITICAL | C | state | `merlin_store.gd:282-289`, `store_run.gd:24+43` |
| H1 | Planner clampé à [5..10] beats — longueurs canon inatteignables en amont | HIGH | C | étages 1-3 | `scenario_planner.gd:512-513`, `:537-549`, `scenario_skeleton.gbnf:27` |
| H2 | Aucune projection sur 5 actes : ni rôle, ni courbe de danger, ni gates de checks | HIGH | C | étages 1-4 | `scenario_planner.gd:193-219`, `:586`, `bi_brain_pipeline.gd:61` |
| H3 | La carte générée ne porte aucun champ de contrat (12 champs manquants) | HIGH | C | étage 4 | `data/ai/merlin_card.gbnf:6,12`, `bi_brain_pipeline.gd:78-85` |
| H4 | Système de checks (stat + white/contextuel/red/fatal) entièrement débranché | HIGH | C | étage 4 + runtime + state | `merlin_effect_engine.gd:74`, `merlin_card.gbnf`, `merlin_store.gd:337` |
| H5 | `scenario_templates.json` lu par aucun GDScript — 10 archétypes absents du jeu | HIGH | C (MEDIUM sur le seul périmètre étages 1-3) | toutes zones | `scenario_planner.gd` (loader), `bi_brain_pipeline.gd:116-133` |
| H6 | Arc émotionnel non validé ; 4 fallbacks livrés violent le contrat | HIGH | R | étages 1-3 | `scenario_planner.gd:586-720`, fallbacks `:39-120` |
| H7 | Contrat d'option non appliqué (verbe, 3 factions distinctes, gradient de risque) | HIGH | NV | étage 4 | `merlin_card.gbnf:12`, `bi_brain_pipeline.gd:133` |
| H8 | Sortie étage 4 non validée / non cappée ; GBNF inerte avec le backend Ollama | HIGH | NV | étage 4 | `bi_brain_pipeline.gd:85`, `merlin_card.gbnf:28`, `ollama_backend.gd:425` |
| H9 | Caps d'effets contournés sur le chemin de résolution réel | HIGH | NV | state | `merlin_store.gd:593-631`, `merlin_effect_engine.gd:501` |
| H10 | Garde-fous anti-dégénérescence absents (caps par acte/run, cap multiplicateur) | HIGH | NV | state + runtime | `merlin_effect_engine.gd:594-614`, `store_run.gd` |
| H11 | Multiplicateurs de danger par acte [0.6…1.6] jamais implémentés | HIGH | NV | runtime | `merlin_constants.gd`, `merlin_store.gd:324`, `board_narration.gd` |
| H12 | Actes SHOP / EVENT / BOSS sans contenu : dégradation silencieuse en carte narrative | HIGH | NV | runtime | `data/ai/fastroute_cards.json`, `board_narration.gd:1691-1713` |
| H13 | 18 Oghams au lieu des 9 Rune-Circuits, cooldowns hors enveloppe 35-45 PV-eq | HIGH | NV | state | `merlin_constants.gd` (OGHAM_FULL_SPECS) |
| M1 | `RARITY_TARGETS` déclarée mais jamais lue (attribution positionnelle) | MEDIUM | NV | étages 1-3 | `scenario_planner.gd:822`, `:673` |
| M2 | PROMISE / RUNE_UNLOCK structurellement inatteignables ; pas de twist mi-run | MEDIUM | R | étages 1-3 | `scenario_planner.gd:193-198`, `:208-219` |
| M3 | Contraintes d'écriture mesurables non validées (mots du titre, borne haute intro, summaries) | MEDIUM | NV | étages 1-3 | `scenario_planner.gd:396-418`, `:340-354` |
| M4 | Drain -1/carte conservé contre le modèle no-drain du contrat | MEDIUM | NV | state | `merlin_constants.gd:102`, `:390`, `:398-411` |

---

## 3. Écarts CRITICAL

### C1 — La longueur de run est figée à 5 cartes en dur

**Contrat.** `structure_constraints.canonical_lengths = [11, 15, 17, 21, 25]`, projetées sur 5 actes. Tout l'équilibrage chiffré est calibré sur 25 cartes (`danger_budget_25_cards`, `check_act_distribution_25`, `rune_circuit_economy` = `1 + floor(24/CD)`), et chaque archétype porte un `length_bias` dans cette liste.

**Code.**
- `scripts/board_narration/board_narration.gd:2914` — `const ACT_SEQUENCE := ["standard", "shop", "standard", "event", "boss"]`
- `:2749-2753` — `var total_acts: int = ACT_SEQUENCE.size()` puis `for act_idx in range(total_acts)`, avec exactement une carte récupérée (`:2770`) et un `RESOLVE_CHOICE` par itération. Le HUD affiche « Carte X / 5 » (`:1450-1452`).
- C'est la seule boucle de run atteignable : `project.godot` démarre sur `MenuTest.tscn` → `BoardNarration.tscn` ; `MerlinGame.tscn` a été retiré au triage plateau-only.
- `scripts/merlin/store_run.gd:236` conditionne la victoire à `cards_played >= MerlinConstants.MIN_CARDS_FOR_VICTORY` (= 25, `merlin_constants.gd:103`). Cette branche est injouable. Idem `hard_max = 50`, `soft_max = 40`, `target 20-25` et `soft_min = 8` de `MOS_CONVERGENCE`.
- Composition résultante : NARRATIVE 2/5 = 40 %, sous le plancher `min_share = 0.50` — la contrainte est violée par construction, quel que soit le contenu.

**Correction.** Remplacer `ACT_SEQUENCE` (liste de cartes) par une longueur `N` lue sur le scénario/squelette actif (`canonical_lengths`, filtrée par le `length_bias` de l'archétype), et boucler `for i in range(N)` avec projection `act = clamp(1 + floor(i * 5 / N), 1, 5)`. Ancrer par acte le contenu obligatoire (≥1 SHOP acte II, ≥1 EVENT acte IV, 2ᵉ SHOP si `N >= 21`, climax LÉGENDAIRE + MERLIN_DIRECT acte V). Afficher « Carte X / N ».

*Note : la mort termine bien le run (`board_narration.gd:2853-2856`, `res.run_ended` honoré `:2882-2883`). Ce sont uniquement les conditions de fin fondées sur le nombre de cartes qui sont inatteignables.*

---

### C2 — Le squelette équilibré est produit puis jeté

**Contrat.** SPEC §0 : l'étage 4 matérialise le squelette (longueur canon, séquence d'actes, quotas de types et de raretés, arc émotionnel) en cartes réellement jouées.

**Code.**
- `addons/merlin_ai/scenario_planner.gd:840` — `func generate_card_for_beat(...)`. Grep repo-wide : 3 occurrences seulement (docstring `:21`, définition `:840`, une ligne de `task_plan.md`). **Zéro appelant.** Même constat pour `judge_divergence` (`:879`) et `replan_from_beat` (`:977`).
- Par conséquent tout `BiBrainPipeline` est mort au runtime : sa seule instanciation est `scenario_planner.gd:236`, et son `generate_card` n'est appelé qu'à `:853`, dans la fonction orpheline.
- Le seul consommateur runtime du planner, `scripts/scenario_loading.gd`, n'appelle que `generate_titles` (`:178`), `generate_intro` (`:220`), `generate_skeleton` (`:241`).
- Le squelette est bien dispatché et stocké (`merlin_store.gd:539-544`), réhydraté (`board_narration.gd:2265-2269`), puis utilisé **uniquement** comme booléen anti-réentrée : `board_narration.gd:393` — `var skeleton_loaded: bool = _run_data.has("scenario_skeleton")`. Le tableau `beats` n'est jamais indexé (0 occurrence de `beats`, `rarity`, `card_type`, `pole` dans `board_narration.gd`).
- Les cartes affichées viennent de `_fetch_card_for_act` (`:1692`) → `_fallback_pool` filtré par `act_type`, ou de `GET_CARD` → `MerlinOmniscient.generate_card(state)`. Le contexte transmis au LLM (`addons/merlin_ai/context_builder.gd:30-71`) whiteliste explicitement ses champs : `scenario_skeleton` n'y figure pas.
- Conséquence : le travail de `_balance_skeleton` (`:586-720` : caps de types, adjacence, part NARRATIVE, placement LÉGENDAIRE, préservation du climax) n'est lu que par de l'outillage offline (`tools/godot/conformance_pipeline.gd`, `tools/check_pipeline_output.py`). Le joueur attend 3 appels LLM dont la sortie principale est jetée avant de jouer 5 actes génériques.

**Correction.** Faire transiter le squelette validé de `scenario_loading` vers `BoardNarration` et remplacer le tirage par `act_type` par une consommation indexée (puis, après C3, par `card_id` le long de la route active) : `planner.generate_card_for_beat(skeleton, idx, player_state)`, le pool fallback ne servant que si l'appel renvoie `{}`. Propager `rarity` / `card_type` / `pole` / `emotion` du beat sur la carte et les rendre visibles — `scripts/ui/digital_picker_card.gd:201` `apply_card_metadata(rarity, faction_or_pole, card_type)` est déjà écrit et n'a aucun appelant.

---

### C3 — Aucun branchement : ni 3 routes isométriques, ni carte d'aiguillage

**Contrat.** SPEC §2.2 + `structure_constraints.branching` : 3 routes (`ordre` / `chaos` / `liminal`), pattern `trunk (c1-c2) -> branch1 ×3 -> twist (convergence) -> branch2 ×3 -> convergence finale`. La carte d'aiguillage (dernière carte de l'acte I) est la **seule** dont les options changent la topologie. Les caps de types et de raretés s'évaluent **par route** (chemin réellement joué), les 3 routes étant isométriques.

**Code.**
- `data/ai/scenario_skeleton.gbnf:21-23` — `beats-kv` est une liste plate et `beat ::= "{" ws n-kv "," ws summary-kv "," ws tilt-kv "," ws emotion-kv ws "}"`. Le LLM ne **peut** pas structurellement émettre un identifiant de carte ni un pointeur.
- `grep "leads_to_card_id|route_mask|branch_label" --include=*.gd` → **0 résultat** dans tout le code Godot. Ces clés n'existent que dans `data/ai/scenarios_reference_broceliande.json`, `data/ai/scenario_golden_broceliande.json`, les outils Python et les docs.
- `scenario_planner.gd:586` — `_balance_skeleton` lit `skeleton.get("beats", [])` en `Array` plat et compte types et raretés sur cette séquence unique.
- Runtime : `board_narration.gd:2753` prend le type de la carte suivante dans `ACT_SEQUENCE[act_idx]` ; `_live_pending_choice` n'est jamais lu pour sélectionner la carte suivante (seulement `_resolve_boss_anam` `:2818`, `RESOLVE_CHOICE` `:2824`, `_capture_shop_modifier` `:2832`, `_spawn_live_token` `:2842`). Pour shop/event/boss, le tirage est un round-robin déterministe (`:1705-1706`).
- Le corpus de référence est pourtant parfaitement conforme (100 scénarios, `routes[3]` avec `card_ids`, `leads_to_card_id` par option, `route_mask`, `branch_label`) mais son seul lecteur Godot est `addons/merlin_ai/scenarios_rag.gd:36`, en few-shot ; `format_skeleton_as_few_shot` (`:498-522`) aplatit `cards` en beats `n/emotion/summary` et jette les clés de routage.
- Les mécanismes de branchement alternatifs sont morts : `MerlinRunGraph` n'est jamais alimenté (`SET_RUN_GRAPH` a un handler `merlin_store.gd:394` et aucun dispatcher) ; les « détours » de `merlin_skeleton_generator.gd:206-254` sont des boucles latérales de 2 nœuds sur un chemin unique, sans pôle ni aiguillage.

**Correction.** Passer le squelette du modèle « liste de beats » au modèle « pool + routes » du corpus :
1. étendre la GBNF pour que chaque beat porte `card_id` et `branch_label` (`"trunk"` | `"<pole>_b1_<i>"` | `"twist"` | `"<pole>_b2_<i>"` | `"convergence"`) ;
2. générer le pool par segments (trunk, 3× branch1, twist unique, 3× branch2, convergence commune) ;
3. calculer **côté client, de façon déterministe** les 3 routes (tableaux de `card_ids` isométriques) et le `route_mask` de chaque carte ;
4. faire porter à chaque option de la carte d'aiguillage un `leads_to_card_id` vers la tête de sa branche ;
5. faire tourner les caps de `_balance_skeleton` sur chacune des 3 routes reconstituées, plus sur la liste globale ;
6. côté runtime, maintenir `run.route` et `run.current_card_id`, et résoudre la carte suivante via `options[choice].leads_to_card_id`.

*Précision de sévérité : sur le seul périmètre du planner, le défaut est une non-implémentation structurelle tracée (`PIPELINE_OUTPUT_AUDIT.md` : 0/12) sans calcul faux — sur un squelette linéaire, la séquence globale EST le chemin joué. La sévérité CRITICAL vient du runtime : le choix du joueur ne change jamais la topologie, et la route est l'unité sur laquelle tous les caps du contrat sont définis.*

---

### C3b — Bug d'ordonnancement : le catalogue de scénarios est mort en production

Écart distinct de C3, mais qui le conditionne côté état de jeu, et corrigeable seul en quelques lignes.

**Code.**
- `scripts/merlin/merlin_store.gd:282` appelle `StoreRun.init_run(state, rng, scenarios)` **avant** `:289` `state["run"]["current_biome"] = biome_key`.
- `scripts/merlin/store_run.gd:24` remet `run["current_biome"] = ""`, puis `:43-44` lit `var biome_for_scenario: String = str(run.get("current_biome", ""))` et appelle `scenarios.select_scenario(biome_for_scenario, ...)`.
- `select_scenario` reçoit donc toujours `""`. Or les 6/6 scénarios de `data/ai/scenarios/scenario_catalogue.json` ont un `biome_affinity` non vide, et `scripts/merlin/merlin_scenario_manager.gd:72-73` (`if not affinity.is_empty() and not affinity.has(biome): continue`) les élimine tous → `candidates` vide → `return {}` systématique.
- Conséquence : `run["active_scenario"] = ""`, les 24 anchors du catalogue et `_resolve_branch` ne s'activent jamais. Les tests restent verts parce qu'ils appellent `select_scenario("forest")` directement (`scripts/test/test_scenario_manager.gd:157-227`).

**Correction.** Passer `biome_key` en argument (`StoreRun.init_run(state, rng, scenarios, biome_key)`) ou déplacer l'écriture de `current_biome` avant l'appel. Ajouter un test d'intégration qui dispatche `START_RUN` et assère `run.active_scenario != ""`.

---

## 4. Écarts HIGH

### H1 — Le planner est clampé à [5..10] beats

**Contrat.** `canonical_lengths = [11, 15, 17, 21, 25]` ; `length_bias` par archétype (ex. `forgotten_ritual` [21, 25], `druidic_awakening` [11, 15, 17]). Le corpus de 100 références ne contient que ces 5 longueurs (11:18, 15:15, 17:26, 21:24, 25:17).

**Code.** `scenario_planner.gd:512-513` (`const MIN_BEATS := 5` / `const MAX_BEATS := 10`), `:537-540` (troncature), `:541-549` (padding depuis le fallback), `:982` et `:1013` (`replan_from_beat` rejette hors bornes). Le prompt demande explicitement « SIMPLE (5 actes) / CLASSIQUE (7 actes) / ÉPIQUE (10 actes) » (`:489-491`), et `data/ai/scenario_skeleton.gbnf:27` plafonne `beat-num` à 10. Les 8 `FALLBACK_SKELETONS` (`:39-120`) font tous 5 beats. Au-delà de l'index 10, `_beat_to_act_type` (`:856-867`) retombe sur `"standard"`.

**Correction.** Lire `canonical_lengths` depuis `scenario_templates.json` et **choisir la longueur cible avant l'appel LLM** (via le `length_bias` de l'archétype retenu) au lieu de la laisser au modèle ; injecter cette longueur dans le prompt et snapper post-parse sur la longueur canon la plus proche. Côté grammaire : supprimer `n-kv`/`beat-num` (le `n` est de toute façon renuméroté de force par `_parse_skeleton`), et augmenter `max_tokens` proportionnellement (400-500 est déjà juste pour 10 beats).

*C1 et H1 sont deux plafonds indépendants : lever l'un sans l'autre ne change rien à la longueur jouée.*

---

### H2 — Aucune projection sur les 5 actes : ni rôle, ni courbe de danger, ni gates de checks

**Contrat.** `acts = 5` avec `act_roles = [ouverture, pacte, epreuve, bascule, climax]` ; `act_danger_multipliers = [0.6, 0.8, 1.0, 1.3, 1.6]` multipliés par le `danger_modifier` de l'archétype ; `check_act_gates` (red interdit actes I-II, autorisé dès l'acte III ; fatal actes IV-V uniquement) ; `fatal_concentration_rule` (5 % du tirage sur les 10 dernières cartes, 0 % avant) — la SPEC §5.3 établit que la mortalité est pilotée à ~100 % par ce placement.

**Code.** Le seul mapping est `BEAT_ACT_SEQUENCE` (`scenario_planner.gd:208-219`), 10 entrées plates du vocabulaire `{standard, shop, event, boss}` : c'est un type de carte, pas un acte. Le contrat demande 5 actes contenant chacun plusieurs cartes, le code fait 1 beat = 1 acte = 1 carte. Aucun champ `act` sur un beat, aucun multiplicateur calculé ni stocké. `generate_card_for_beat` (`:840-853`) ne transmet que `(biome_id, act_type, ogham_used, beat)` à `BiBrainPipeline.generate_card` (`bi_brain_pipeline.gd:61-62`) : ni index d'acte, ni budget de danger, ni gate. Aucune production `check` dans `merlin_card.gbnf`, `gamemaster_choices.gbnf`, `gamemaster_effects.gbnf`.

Côté runtime (H11), l'acte est matérialisé visuellement (`board_narration.gd:2758` → `JuiceHelpers.update_act_indicator`, `juice_helpers.gd:361`) mais n'entre dans aucun calcul : `grep "danger_multiplier|ACT_DANGER|act_multiplier"` sur `scripts/` + `addons/` → 0 résultat. Le joueur lit « Acte 5/5 — Confrontation finale » avec exactement le profil de risque de l'acte I.

*À noter : la projection existe déjà, mais uniquement dans l'outillage offline — `tools/build_golden_scenario.py:159` (`act_of(n)`), `:225-240` (gates `fatal` si `act >= 4`, `red` si `act >= 3`), `:99-103` (bandes de dégâts par acte), et `tools/validate_scenario_balance.py:270` / `:331` (chargement et application en `--strict`). C'est le pipeline in-game qui ne la porte pas.*

**Correction.** Ajouter dans `_balance_skeleton` une étape de projection : pour chaque beat, `act = clamp(1 + floor(i * 5 / total), 1, 5)`, puis stocker `act`, `act_role`, `danger_mult = act_danger_multipliers[act-1] * archetype.danger_modifier`, `allow_red`, `allow_fatal`. Étendre `generate_card_for_beat` et `BiBrainPipeline.generate_card` pour transmettre ce contexte, injecter le budget chiffré de l'acte dans le prompt GM, et appliquer la gate côté client après parse (dégrader `fatal` → `red` si acte < IV ou vie ≤ 15). Ajouter `const ACT_DANGER_MULTIPLIERS` dans `merlin_constants.gd` et multiplier les montants `DAMAGE_LIFE` (et `HEAL_LIFE` par `heal_modifier`) **avant** le clamp de `cap_effect`.

---

### H3 — La carte générée ne porte aucun champ de contrat

**Contrat.** SPEC §2-§3 + bible §30 : chaque carte est `{n, card_id, type, rarity, pole, emotion, summary, options: [{label, verb, primary_faction, check: {stat, type}, leads_to_card_id}]}`. C'est ce schéma que valide `tools/validate_scenario_balance.py` (parts par route, raretés, placement du légendaire, arc émotionnel, 3 factions distinctes).

**Code.**
- `data/ai/merlin_card.gbnf:6` — `root ::= ws "{" ws text-kv "," ws speaker-kv "," ws options-kv ws "}"` : 3 clés racine.
- `data/ai/merlin_card.gbnf:12` — `option ::= "{" ws label-kv "," ws effects-kv ws "}"` : ni `verb`, ni `primary_faction`, ni `check`, ni `leads_to_card_id`.
- `addons/merlin_ai/bi_brain_pipeline.gd:78-85` — la phase C n'ajoute que `id` / `biome` / `tags` puis `return gm_card`. Sortie finale : 6 clés `{text, speaker, options, id, biome, tags}`.
- `:128-133` — `beat_context` n'est lu que pour `faction_tilt` / `emotion` / `summary`, et uniquement concaténé dans des chaînes de prompt. Les trois champs réellement calculés par `_balance_skeleton` (`rarity`, `pole`, `card_type`) ne sont même pas lus.
- Le chemin FastRoute n'est pas meilleur : `data/ai/fastroute_cards.json` = `{id, text, biome, options[{label, verb, effects}], tags}`, et `board_narration.gd:1856-1862` normalise vers `{id, text, prompt, options}` en jetant `tags`.

**Correction.** Étendre `merlin_card.gbnf` : ajouter au root `card_id` / `type` / `rarity` / `pole` / `emotion` (enums fermés) et à `option` les clés `verb` / `primary_faction` / `check{stat,type}` / `leads_to_card_id`. En phase C, **recopier systématiquement depuis `beat_context`** les champs déjà calculés par `_balance_skeleton` en écrasant toute valeur LLM divergente : le beat est la source de vérité, le LLM n'écrit que la prose.

---

### H4 — Le système de checks est débranché de bout en bout

**Contrat.** `balance_model.check_schema` : chaque option porte `{stat ∈ logic/empathie/volonte/instinct, type ∈ white/contextuel/red/fatal}`, mix global 75/15/8/2, `check_damage_on_fail` (white 3-5, contextuel 7-9, red 12-15, fatal = fin de run), `check_act_gates`, `red_spacing_rule`, `ember_rule` (vie ≤ 15 : fatal dégradé en red), `late_game_requirement`. C'est le pilier qui produit les cibles de mortalité (15-30 % au premier run, 100 % des morts actes IV-V) et le build 4 stats (+1 XP par choix aligné).

**Code.**
- `scripts/merlin/merlin_effect_engine.gd:74` — `func resolve_option_check(option: Dictionary) -> Dictionary`. **Unique occurrence du symbole dans tout le dépôt**, tests et `.tscn` inclus : code mort.
- `:79-80` — `if stat_name.is_empty(): return {"passed": true, ...}` : même appelée, la fonction ferait auto-passer 100 % des options.
- Aucune grammaire n'émet de check (`grep "check"` sur `data/ai/*.gbnf` → 0 hit hors commentaire), aucune donnée runtime n'en porte (`fastroute_cards.json`, `event_cards.json`, `data/ai/scenarios/` → 0 occurrence).
- **Divergence de schéma latente** : `merlin_effect_engine.gd:75-77` lit des clés plates `check_stat` / `check_type` / `check_modifier`, alors que `docs/GAME_DESIGN_BIBLE.md:455` **et** le générateur `tools/build_golden_scenario.py:314-325` émettent tous deux un sous-objet `check: {stat, type, fail_damage, telegraphed}`. Le jour où la passe de génération arrivera, `resolve_option_check` ne lira rien et retournera silencieusement `passed = true`.
- Corollaire XP : `scripts/merlin/merlin_store.gd:337-341` lit `chosen_opt.get("check_stat", "")` pour attribuer +1 XP (bible §25.2). La condition n'est jamais vraie → les 4 stats restent à 0 XP et le HUD Disco affiche L0/50 % en permanence. La formule elle-même est correcte (`merlin_stats_system.gd:98-100`).
- Aucune table de dégâts d'échec, aucune gate par acte, aucun traitement du type `fatal`, aucune ember rule côté GDScript.

**Correction.** Trancher le schéma (sous-objet `check: {stat, type, modifier}` conforme à la bible, avec adaptateur rétrocompatible dans `resolve_option_check`), l'ajouter à la grammaire de carte et au pool FastRoute avec enums fermés, **tirer le type de check dans le planner** (selon `check_act_gates` + `check_act_distribution_25` + spacing) plutôt que de le laisser au LLM, appeler `resolve_option_check` dans le handler `RESOLVE_CHOICE` avant application des effets, brancher les dégâts d'échec et `fatal` → `check_run_end`, et afficher le glyphe de stat + % sur la face de carte.

---

### H5 — `scenario_templates.json` n'a aucun consommateur GDScript

**Contrat.** SPEC §1 : 10 archétypes, chacun avec `pole_dominant`, `twist_pattern`, `difficulty`, `danger_modifier` (0.60-1.25), `heal_modifier` (0.75-1.5), `length_bias`, `emotional_palette`, `stat_mix`, `primary_factions`, `merlin_interference_bias` et `params` (règles spéciales : `druidic_awakening` 0 red/fatal, `mist_wanderer` 30 % d'options voilées, `forgotten_ritual` +1 PROMISE garantie, `hidden_sanctuary` carte de repos acte III…). Étage 1 : les 3 titres proposés = 3 archétypes distincts dont au plus 1 `hard` ; si vie < 40, exclure `forest_trial` et inclure `hidden_sanctuary`. `onboarding_overrides` impose `forced_archetype = druidic_awakening` au premier run.

**Code.**
- `grep -rn "scenario_templates" --include=*.gd` → **0 résultat**. Seuls `tools/validate_scenario_balance.py`, `tools/build_golden_scenario.py`, `tools/patch_reference_scenarios.py` et `tools/check_pipeline_output.py` le lisent.
- `grep "danger_modifier|heal_modifier|twist_pattern|pole_dominant|emotional_palette|stat_mix|no_red_checks|length_bias" --include=*.gd` → 0 hit.
- `scenario_planner.gd:252` — `func generate_titles(biome_id: String) -> Array` : aucun `player_state`, donc le filtre vie < 40 est impossible. `:409` ne valide qu'une longueur ≤ 60 caractères, `:413-418` retourne `{title, ogham}` — 3 chaînes libres appairées à un glyphe tiré au hasard, aucun archétype attaché.
- Le Pole n'est pas dérivé de l'archétype mais du biome (`BIOME_POLE_BIAS`, `:163-172`) ou du `faction_tilt` (`:810-816`).
- `_balance_skeleton` réimplante à la main des copies figées du contrat (`CARD_TYPE_CAPS:142-149`, `RARITY_TARGETS:153-158`, `LEGENDARY_START_SHARE:178`) : contrat et code peuvent dériver sans qu'aucun test ne le détecte.
- Le prompt GM (`bi_brain_pipeline.gd:116-133`) ne reçoit ni archétype, ni acte, ni multiplicateur de danger : les amplitudes d'effets sont identiques quel que soit l'archétype et quel que soit l'acte.

*Nuance : une couche archétype existe partiellement — `addons/merlin_ai/scenarios_rag.gd:431-443` hardcode les 10 `archetype_id` dans un keyword map et `:177-178`/`:264`/`:300` propagent `archetype_id`/`archetype_name` depuis le corpus. Mais c'est un tag de retrieval few-shot, sans aucun paramètre mécanique ni influence sur le run.*

**Correction.** Charger `res://data/ai/scenario_templates.json` une fois (autoload `MerlinBalance` ou `_load_templates()` dans `ScenarioPlanner._init`, sur le modèle de `_load_gbnf`) et faire lire `CARD_TYPE_CAPS` / `RARITY_TARGETS` / `act_danger_multipliers` / `archetypes` depuis cette source au lieu des copies en dur. Dans `generate_titles(biome_id, player_state)` : tirer 3 archétypes distincts (≤ 1 `hard`, filtre vie < 40, `forced_archetype` au premier run), passer leurs `name` / `twist_pattern` / `emotional_palette` au prompt, retourner `{title, ogham, archetype_id}`. Poser `run.archetype_id`, propager dans le squelette, et faire piloter par lui la longueur canon, la palette, le pôle dominant et les modifiers de danger/soin.

*Sévérité : l'analyse adversariale a classé cet écart MEDIUM sur le seul périmètre des étages 1-3, au motif que la SPEC §6 « Intégration pipeline (prochaines étapes code) » liste explicitement ces deux items comme non démarrés. Le classement HIGH retenu ici agrège les conséquences runtime (H2, H11 : aucune courbe de tension).*

---

### H6 — Arc émotionnel non appliqué, et 4 fallbacks livrés le violent

**Contrat.** `writing_constraints` : `first_beat_emotions = ["curiosite"]`, `emotion_no_repeat_consecutive = true`, `final_beat_emotions = ["sagesse", "peur", "emerveillement"]`, plus une palette propre à chaque archétype. La SPEC §5.7 identifie déjà « 20 arcs ouvrent sur tension » comme un défaut à corriger dans le corpus.

**Code.** Ces trois règles n'existent que comme suggestion dans le system prompt (`scenario_planner.gd:495`, `:502-503`). Les 6 étapes de `_balance_skeleton` (`:586-720`) ne lisent ni n'écrivent jamais le champ `emotion` — elles ne normalisent que `card_type`, `pole` et `rarity`. `scenario_skeleton.gbnf:35` autorise n'importe laquelle des 9 émotions à n'importe quelle position. Aucun filet.

Violations livrées dans les fallbacks, qui traversent `_balance_skeleton` sans être corrigés :
- `:93` `marais_korrigans` beat 1 → `tension` (attendu `curiosite`)
- `:83` `cercles_pierres` beat 1 → `emerveillement`
- `:113` `iles_mystiques` beat 1 → `emerveillement`
- `:67` `cotes_sauvages` beat final → `espoir` (hors `{sagesse, peur, emerveillement}`)

Cohérent avec `PIPELINE_OUTPUT_AUDIT.md` : « arc émotionnel — RÉGLAGE — 8/12 ».

**Correction.** Ajouter une étape « arc émotionnel » dans `_balance_skeleton`, après l'assignation des défauts : forcer `beats[0].emotion = "curiosite"`, forcer la dernière émotion dans `final_beat_emotions` (choix piloté par le `twist_pattern` de l'archétype), puis balayer et remplacer toute émotion identique à la précédente par une autre valeur de la palette. Corriger en même temps les 4 fallbacks non conformes.

---

### H7 — Contrat d'option non appliqué, et le prompt GM demande l'inverse

**Contrat.** SPEC §3 + `writing_constraints.options` : exactement 3 options, verbe à l'infinitif en 1 mot, `distinct_primary_factions: true`, gradient positionnel fixe gauche = prudente / centre = équilibrée / droite = audacieuse, à EV proche mais variance croissante. Justification §4.2 : chacun des 5 builds canon doit trouver ≥ 1 ligne de jeu viable sur chaque carte.

**Code.** `merlin_card.gbnf:12` — l'option ne porte ni `verb`, ni `primary_faction`, ni gradient. Pire, `bi_brain_pipeline.gd:133` — `lines.append("Les effets DOIVENT tilt vers la faction %s." % tilt)` : le prompt pousse explicitement vers une carte mono-faction. Côté runtime, `verb` n'est lu que de façon optionnelle avec repli sur détection lexicale depuis le label (`merlin_card_system.gd:261-267`) ; `primary_faction` n'est lu par aucun script GDScript.

**Correction.** Ajouter `verb` et `primary_faction` (enum fermé des 5 factions) à la règle `option`. Réécrire la consigne de tilt : la faction du beat oriente l'option **centrale**, les deux autres devant porter des `primary_faction` différentes — contrainte re-vérifiée en post-traitement et corrigée par réassignation plutôt que par rejet. Ordonner les 3 options par risque croissant avant retour, pour que la position porte le gradient.

---

### H8 — Sortie étage 4 ni validée ni cappée, GBNF inerte à l'exécution

**Contrat.** SPEC §3 : « Effets : ≤ 3 par option ; whitelist bible §5.4 ; caps ±20 rep, +18 heal, -15 dmg » et « Options : exactement 3 ».

**Code.** Triple rupture.
1. `bi_brain_pipeline.gd:85` retourne le Dictionary parsé tel quel : ni `_validate_card`, ni `cap_effect`, ni `scale_and_cap` sur ce chemin. Seul filtre : `JSON.parse` + `parsed is Dictionary`.
2. `merlin_card.gbnf:28` — `number ::= "-"? [0-9] [0-9]?` autorise -99..99 : un `HEAL_LIFE: 99` ou `ADD_REPUTATION: 99` est grammaticalement valide, très au-delà des caps 18/20.
3. `addons/merlin_ai/ollama_backend.gd:425-431` — `set_grammar()` et `clear_grammar()` sont des **no-op déclarés** (« Ollama ne supporte pas GBNF grammar directement »). Avec le backend par défaut, la grammaire n'est qu'un texte transmis : même la garantie « exactement 3 options » n'existe pas à l'exécution.

**Correction.** Insérer un étage de sanitation avant `return gm_card` : `_validate_card` (rejet si type hors whitelist ou > 3 effets), `_ensure_3_options`, `cap_effect` sur chaque montant — le clamp doit **corriger** plutôt que rejeter, la carte étant déjà payée en temps LLM. Restreindre `number` aux intervalles utiles via des règles d'amount distinctes par type d'effet (la grammaire sert aussi de spec lisible par le LLM).

---

### H9 — Les caps d'effets ne sont pas appliqués sur le chemin de résolution réel

**Contrat.** `balance_model.effects_caps` : `ADD_REPUTATION` 20, `HEAL_LIFE` 18, `DAMAGE_LIFE` 15, `ADD_ESSENCE` 10, `effects_per_option` 3. Base du budget de danger (dégâts bruts 55-75 PV sur 25 cartes, vie finale p50 55-70).

**Code.** Le chemin vivant `RESOLVE_CHOICE` → `StoreRun.resolve_choice` → `MerlinStore._apply_effect` envoie `DAMAGE_LIFE` / `HEAL_LIFE` vers `_damage_life` (`merlin_store.gd:593-601`) et `_heal_life` (`:604-612`), qui ne font qu'un clamp [0, 100] — **aucun plafond par effet**. `cap_effect` (`merlin_effect_engine.gd:594`), seul lecteur réel de `EFFECT_CAPS`, n'est atteint que via `scale_and_cap` (`:610`), appelé depuis `merlin_card_system.gd:478` et deux branches d'ogham. Le cap de réputation est appliqué, mais en dur : `merlin_effect_engine.gd:501` — `var capped_delta: int = clampi(delta, -20, 20)`, sans lire `EFFECT_CAPS`. Constat de première passe non re-vérifié : les données livrées contiendraient 292 effets `DAMAGE_LIFE` > 15 (jusqu'à 20) et 13 `HEAL_LIFE` > 18, notamment dans le pool RPG chargé au démarrage — **à confirmer avant chantier**.

**Correction.** Faire passer tout `DAMAGE_LIFE` / `HEAL_LIFE` par `cap_effect()` dans `_apply_effect` et dans les actions directes du dispatcher ; remplacer le littéral `clampi(delta, -20, 20)` par une lecture de `EFFECT_CAPS["ADD_REPUTATION"]`. Ajouter un test de conformité du corpus de cartes contre `EFFECT_CAPS`.

---

### H10 — Garde-fous anti-dégénérescence absents

**Contrat.** `anti_degenerescence_params` : `safe_streak_max` 3 (après 3 options zéro-risque, forcer une carte sans option neutre), `rep_cap_per_run_per_faction` 60, `rep_soft_cap` 80 avec gains divisés par 2 au-delà, `heal_cap_per_act` 24, `same_stat_streak_max_for_xp` 3, `essence_gain_max_per_card` 10, `global_multiplier_cap` 2.0 appliqué **après** tout cumul.

**Code.** Seuls les caps **par carte** existent (`merlin_constants.gd:378-391`). Aucun compteur cumulatif : `grep "safe_streak|heal_cap_per_act|rep_cap_per_run|same_stat_streak"` sur `scripts/` + `addons/` → 0 hit. `merlin_constants.gd:389` déclare `"score_bonus_cap": 2.0` — lu uniquement par `scripts/test/test_minigame_scoring.gd`, aucun consommateur de production. `scale_and_cap` (`merlin_effect_engine.gd:610-614`) multiplie puis clampe le résultat, sans jamais clamper le multiplicateur lui-même ; `get_multiplier` plafonne déjà à ±1.5, donc la règle « clamp après cumul » n'a rien à borner aujourd'hui — et sera fausse dès qu'un cumul sera ajouté.

**Correction.** Ajouter dans `state.run` les accumulateurs `rep_gained_per_faction`, `heal_this_act`, `safe_streak`, `stat_streak`, `essence_this_card` ; les incrémenter dans `_apply_effect` et les faire appliquer par un unique point de passage qui clampe avant écriture (dont la division par 2 des gains de réputation au-dessus de 80). Exposer `safe_streak >= 3` au MOS pour forcer une carte sans option neutre, et appliquer `global_multiplier_cap` en dernier dans `scale_and_cap`.

---

### H11 — Multiplicateurs de danger par acte jamais implémentés

Voir H2 pour la partie planner. Côté runtime : `board_narration.gd:2758` alimente un indicateur HUD (`juice_helpers.gd:361` — `"%s  Acte %d / %d — %s"`), et c'est le seul usage de `act_idx` en dehors de l'indexation de `ACT_SEQUENCE`. Aucune entrée dans un calcul d'effet, de dégâts ou de tirage. La courbe de tension type Slay the Spire, justification centrale du découpage en 5 actes, est absente.

---

### H12 — Actes SHOP / EVENT / BOSS sans contenu

**Contrat.** SPEC §2.1 : acte II ≥ 1 carte SHOP (respiration stratégique : soins, dons, équipement rune), acte IV ≥ 1 carte EVENT, acte V = finale LÉGENDAIRE + MERLIN_DIRECT. `heal_policy.shop_heal_ev = 8`. `deckbuilding_layer` : le SHOP est le point de draft des dons per-run.

**Code.** Aucune carte du pool ne porte de champ `act_type` (0 occurrence dans `data/ai/*.json`) et `_load_fallback_pool` (`board_narration.gd:1866-1883`) ne charge que la section `narrative` filtrée par biome. Le filtre `board_narration.gd:1700` (`str(c.get("act_type", "standard"))`) fait donc défaulter toutes les cartes à `standard` ; `matching` reste vide pour shop/event/boss, la garde `:1704` (`if act_type != "standard" and not matching.is_empty()`) n'est jamais vraie, et on retombe sur `_pick_fallback_card()` (`:1713`). En chaîne : `_capture_shop_modifier` cherche un effet `APPLY_MODIFIER` absent → `_active_modifier` reste vide ; `_resolve_boss_anam` cherche un `DICE_TEST` absent → retour immédiat sans jet ni Anam → `_run_anam_earned` reste 0 et l'outro affiche toujours la variante par défaut.

**Correction.** Créer des cartes SHOP (`APPLY_MODIFIER` + `HEAL_LIFE` ~8, choix de don), EVENT et BOSS (`DICE_TEST` avec branches succès/échec + récompense Anam), taguées `act_type`, et charger les sections correspondantes. Ajouter une assertion de démarrage : si le pool ne contient aucune carte pour un `act_type` de la séquence, `push_error` au lieu de dégrader silencieusement.

---

### H13 — 18 Oghams au lieu des 9 Rune-Circuits budgétés

**Contrat.** `balance_model.rune_circuit_economy` : 9 runes (beith, luis, quert, duir, nuin, saille, muin, straif, ioho), cooldowns 3/4/4/5/6/5/7/8/10, valeur cible **35-45 PV-eq** par rune et par run de 25 cartes (activations = `1 + floor(24/CD)`). Le contrat identifie déjà `quert` (70 PV-eq) comme « bug d'équilibrage n°1 ».

**Code.** `merlin_constants.gd` — `OGHAM_FULL_SPECS` contient **18 entrées** (beith, coll, ailm, luis, gort, eadhadh, duir, tinne, onn, nuin, huath, straif, quert, ruis, saille, muin, ioho, ur) : les 9 runes hors contrat ne sont budgétées nulle part. Les cooldowns des 9 runes canon divergent de la baseline (duir 4 vs 5, saille 6 vs 5, straif 10 vs 8, ioho 12 vs 10). Dépassements calculés : duir (heal 12, CD 4) = 7 × 12 = 84 PV-eq/run, ruis (heal 18, CD 8) = 4 × 18 = 72, quert (heal 8, CD 4) = 56 — soit 125 % à 190 % de la cible haute. `scripts/IntroCeltOS.gd:33` affiche « INIT RUNE_CIRCUITS [9/9] » à titre purement décoratif. *Chiffres issus de la première passe, non re-vérifiés ligne à ligne.*

**Correction.** Réduire `OGHAM_FULL_SPECS` aux 9 Rune-Circuits (archiver les autres), aligner les cooldowns sur `cooldowns_current`, puis appliquer le tuning proposé (quert CD 6 / soin 8, luis 5, straif 7, nuin 5) une fois la décision utilisateur prise. Ajouter un test qui recalcule `(1 + floor(24/CD)) × valeur` et échoue hors [35, 45] PV-eq.

---

## 5. Écarts MEDIUM

- **M1 — `RARITY_TARGETS` déclarée mais jamais lue.** La constante (`scenario_planner.gd:153-158`) n'a aucun lecteur ; l'attribution réelle est faite par `_default_rarity_for_beat` (`:822`), purement positionnelle (dernier = LÉGENDAIRE, avant-dernier = ÉPIQUE, premier = COMMUNE, sinon RARE si `n % 3 == 0`). À n = 5, la distribution est 40/20/20/20 vs 68/20/8/4, soit 28 points de drift sur COMMUNE et 16 sur LÉGENDAIRE — hors tolérance ±15 du validateur. Or n = 5 est la taille de tous les fallbacks et de tout squelette padé. Aux tailles 7-10 le drift repasse sous 15 points, mais par coïncidence arithmétique. *Fix : attribution par quotas (effectifs cibles = `RARITY_TARGETS × total`), climax réservé, ÉPIQUE dans le dernier tiers, vérification de drift en fin d'étape 4.*
- **M2 — PROMISE et RUNE_UNLOCK inatteignables ; pas de twist mi-run.** Les deux types figurent dans `CARD_TYPE_CAPS` (`:142-149`) mais ne sont la valeur d'aucune entrée de `ACT_TYPE_TO_CARDTYPE` (`:193-198`), la GBNF interdit au LLM d'émettre `card_type`, et leur `min_count = 0` empêche l'étape 5 de les promouvoir. Par ailleurs le seul MERLIN_DIRECT et le seul ÉPIQUE sont les deux derniers beats (`:208-219`) : le twist ÉPIQUE + MERLIN_DIRECT à ~50 % du run n'existe jamais. **Correction de la formulation initiale** : la part NARRATIVE 50-70 %, elle, **est** désormais appliquée — l'étape 3bis `_enforce_narrative_share` (`:667-670`, définition `:729`) a été ajoutée en v7.7.26 précisément pour ce défaut. Le point reste ouvert uniquement pour n < 11, où le commentaire du code note lui-même que la borne min est mathématiquement inatteignable.
- **M3 — Contraintes d'écriture mesurables non validées.** Titre : seule la borne 60 caractères est appliquée (`:409`, `MAX_TITLE_LENGTH:223`) ; pas de comptage de mots (le « 3-7 mots » du prompt diverge déjà du canon 2-7), pas de longueur minimale, pas de déduplication. Intro : seule la borne basse est vérifiée (`:342-345`), par un comptage naïf de `.`/`!`/`?` qui compte aussi les points de suspension ; aucune borne haute, donc une intro de 15 phrases déborde le parchemin. Summary de beat : aucune validation de longueur (le prompt dit 10-20 mots, le canon 8-22). *Fix : helper `_word_count`, bornes lues depuis `writing_constraints`, troncature propre de l'intro à la 8ᵉ phrase plutôt que fallback total.*
- **M4 — Drain -1/carte contre le modèle no-drain.** `merlin_constants.gd:102` (`LIFE_ESSENCE_DRAIN_PER_CARD := 1`) et `:390` (`"drain_per_card": 1`), alors que `_meta.inspirations.hand_of_fate_2` pose « no-drain, tension via composition du deck » et que tout le budget de danger est calculé sans attrition automatique. L'effet est nul aujourd'hui par accident : le seul consommateur de production, `scripts/run/run_3d_controller.gd:241-242`, n'est instancié dans aucune scène. Mais `EFFECT_PIPELINE` (`:398-411`) compte 12 étapes contre 11 attendues et commence toujours par `DRAIN_VIE`, et la valeur est verrouillée par `scripts/test/test_constants_bible_alignment.gd:337-338`. Toute réactivation du pipeline réintroduira -25 PV sur un run de 25 cartes, soit ~45 % de l'attrition brute budgétée. *Fix : passer les deux constantes à 0, retirer `DRAIN_VIE` du pipeline, mettre à jour le test.*

Aucun écart LOW retenu.

---

## 6. Roadmap de correction, ordonnée par dépendance

L'ordre compte : corriger H6, M1 ou H9 avant C2 revient à améliorer un artefact que personne ne lit. L'effort est relatif (S ≈ quelques heures, M ≈ 1 jour, L ≈ 2-3 jours, XL ≈ semaine).

### Phase 0 — Prérequis, sans effet visible mais débloquants (effort total : M)

| # | Action | Effort |
|---|---|---|
| 0.1 | Loader du contrat : autoload `MerlinBalance` parsant `scenario_templates.json`, exposant `get_archetype(id)`, `canonical_lengths`, `card_type_caps`, `rarity_targets`, `act_danger_multipliers`, `check_act_gates`. Faire lire les copies en dur du planner depuis cette source (**H5**, **C-contrat**). | M |
| 0.2 | Fix d'ordre `init_run` / `current_biome` (**C3b**) + test d'intégration `START_RUN` → `active_scenario != ""`. | S |
| 0.3 | Déclamper le planner : `MIN_BEATS`/`MAX_BEATS` → `canonical_lengths`, suppression de `n-kv`/`beat-num` de la GBNF, réécriture du prompt de longueur, `max_tokens` proportionnel, regénération des 8 fallbacks à la longueur canon (**H1**). | M |

### Phase 1 — Schéma structurel (effort total : L)

| # | Action | Effort |
|---|---|---|
| 1.1 | Squelette « pool + routes » : GBNF `card_id` + `branch_label`, génération par segments, calcul déterministe côté client des 3 routes et des `route_mask` (**C3**). | L |
| 1.2 | Projection 5 actes : champs `act`, `act_role`, `danger_mult`, `allow_red`, `allow_fatal` sur chaque beat (**H2**). | M |
| 1.3 | Sélection d'archétype à l'étage titres : `generate_titles(biome_id, player_state)`, 3 archétypes distincts, ≤ 1 `hard`, filtre vie < 40, `forced_archetype` premier run ; propagation dans le squelette et dans `run.archetype_id` (**H5**). | M |
| 1.4 | Évaluation des caps **par route** dans `_balance_skeleton` (**C3**, dépend de 1.1). | M |

### Phase 2 — Câblage runtime : le point de bascule (effort total : L)

| # | Action | Effort |
|---|---|---|
| 2.1 | Remplacer `ACT_SEQUENCE` par la longueur `N` du scénario actif et boucler sur les cartes, pas sur les actes ; HUD « Carte X / N » (**C1**). | M |
| 2.2 | `_fetch_card_for_act` → consommation du squelette par `card_id` le long de la route, `generate_card_for_beat` branché, pool fallback en secours uniquement (**C2**). | L |
| 2.3 | Suivi de route : `run.route`, `run.current_card_id`, résolution via `options[choice].leads_to_card_id` sur la carte d'aiguillage (**C3**, dépend de 2.2). | M |

> À la fin de la phase 2, les 5 règles CAPACITÉ de `PIPELINE_OUTPUT_AUDIT.md` doivent passer de 0/12 à 12/12. C'est le jalon de vérification naturel.

### Phase 3 — Schéma de carte et couche Disco (effort total : L)

| # | Action | Effort |
|---|---|---|
| 3.1 | Étendre `merlin_card.gbnf` au schéma contrat + stamp systématique depuis le beat en phase C (**H3**). | M |
| 3.2 | Trancher le schéma `check` (sous-objet, adaptateur rétrocompatible), tirage du type dans le planner selon les gates, `resolve_option_check` appelé dans `RESOLVE_CHOICE`, dégâts d'échec, `fatal` → fin de run, ember rule, affichage du glyphe de stat (**H4**). | L |
| 3.3 | Contrat d'option : `verb`, `primary_faction` distinctes, réécriture de la consigne de tilt, tri par risque croissant (**H7**). | M |
| 3.4 | Sanitation de sortie étage 4 : `_validate_card` + `_ensure_3_options` + `cap_effect`, resserrement des `number` de la GBNF (**H8**). | S |

### Phase 4 — Équilibrage (effort total : M-L)

| # | Action | Effort |
|---|---|---|
| 4.1 | Caps d'effets sur le chemin réel : `_apply_effect` et actions directes passent par `cap_effect` ; `EFFECT_CAPS` au lieu du littéral ±20 ; test de conformité du corpus (**H9**). | S |
| 4.2 | Courbe de danger : `ACT_DANGER_MULTIPLIERS × archetype.danger_modifier` appliqué avant clamp ; budget chiffré injecté dans le prompt GM (**H11**, **H2**). | M |
| 4.3 | Accumulateurs anti-dégénérescence dans `state.run` + point de passage unique de clamp + cap multiplicateur appliqué en dernier (**H10**). | M |
| 4.4 | Réduction à 9 Rune-Circuits, alignement des cooldowns, test d'enveloppe 35-45 PV-eq (**H13**). | M |
| 4.5 | Passage `drain_per_card` à 0, pipeline 12 → 11 étapes, mise à jour du test d'alignement (**M4**). | S |

### Phase 5 — Contenu, écriture, CI (effort total : L)

| # | Action | Effort |
|---|---|---|
| 5.1 | Cartes SHOP / EVENT / BOSS taguées `act_type`, chargement des sections, assertion de démarrage (**H12**). | L |
| 5.2 | Étape « arc émotionnel » dans `_balance_skeleton` + correction des 4 fallbacks (**H6**). | S |
| 5.3 | Attribution des raretés par quotas + vérification de drift (**M1**) ; PROMISE / RUNE_UNLOCK atteignables + twist mi-run (**M2**). | M |
| 5.4 | Validation des contraintes d'écriture mesurables (**M3**). | S |
| 5.5 | Brancher `tools/godot/conformance_pipeline.gd` + `validate_scenario_balance.py --strict` sur la sortie réelle du pipeline en CI, pas seulement sur le golden fixture. | M |

---

## 7. Ce qui est déjà conforme

Le rapport ci-dessus porte sur la structure et le câblage. Plusieurs briques sont correctes et n'ont pas à être refaites.

**Étage squelette — règles de RÉGLAGE implémentées et vérifiées** (source : `PIPELINE_OUTPUT_AUDIT.md`, généré en exécutant le vrai `_balance_skeleton`) :
- adjacence des types uniques (`NO_REPEAT_CARDTYPES`) — **12/12** ;
- placement du LÉGENDAIRE dans le dernier 30 % (`LEGENDARY_START_SHARE`, `scenario_planner.gd:673`) — **12/12** ;
- climax LÉGENDAIRE + MERLIN_DIRECT, y compris sa préservation quand le LLM dépasse un `max_count` (`:634-640`) — **12/12** ;
- part NARRATIVE 50-70 % : `_enforce_narrative_share` (`:667-670`, `:729`) a été ajoutée en v7.7.26 et applique désormais la règle, contrairement à ce que laissait entendre un audit antérieur.

**Robustesse du pipeline LLM** : normalisation de casse des enums émis par le modèle (`:601-616`), renumérotation forcée de `n`, réparation JSON, 8 fallbacks par biome, clamp de longueur de titre, borne basse d'intro, timeouts et repli gracieux à chaque étage. Le jeu ne casse jamais quand le LLM dérape — il produit du contenu hors contrat, pas des erreurs.

**Corpus et outillage offline — entièrement conformes** :
- `data/ai/scenarios_reference_broceliande.json` : 100 scénarios avec `routes[3]`, `card_ids`, `leads_to_card_id`, `route_mask`, `branch_label`, longueurs exclusivement canon (11:18, 15:15, 17:26, 21:24, 25:17) ;
- `tools/build_golden_scenario.py` implémente réellement `act_of(n)` (`:159`), les gates red/fatal (`:225-240`), les bandes de dégâts d'échec (`:242-245`) et le sous-objet `check` complet (`:314-325`) ;
- `tools/validate_scenario_balance.py` couvre routes, caps par route, drift de rareté, gates de checks et télégraphie en `--strict` ;
- `tools/godot/conformance_pipeline.gd` + `tools/check_pipeline_output.py` forment un harnais qui exécute le **vrai** code d'équilibrage sans Ollama, et distinguent explicitement CAPACITÉ et RÉGLAGE. C'est ce harnais qui a produit le chiffrage repris ici — le projet mesurait déjà correctement ses écarts.

**Systèmes de jeu corrects** : formule de check `50 % + (niveau × 10 %)` (`merlin_stats_system.gd:98-100`) ; caps par carte déclarés et implémentés dans `cap_effect` (`merlin_effect_engine.gd:594-607`) ; clamp de réputation ±20 par carte ; 5 factions, réputation cross-run sans decay, sauvegarde profil unique + `run_state` ; constantes MOS complètes et cohérentes avec le contrat ; `DigitalPickerCard.apply_card_metadata` (rareté / pôle / type) déjà écrit et prêt à être appelé.

**Statut documentaire** : `SCENARIO_TYPES_SPEC.md` §6 « Intégration pipeline (prochaines étapes code) » et §8.2 (« le corpus actuel ne porte aucune couche mécanique — c'est la mesure chiffrée de ce qu'il reste à générer ») déclarent explicitement une partie de ces écarts comme travail planifié, non comme régressions. Le contrat a été rédigé le 2026-07-25 ; le format de squelette date de v7.7 (2026-05). L'essentiel du delta est un contrat plus récent que le code — à l'exception de C1, C2, C3b et H4, qui sont des défauts fonctionnels autonomes (fin de partie injouable, appels LLM jetés, catalogue mort, code mort avec divergence de schéma latente).

---

## 8. Suites données dans cette session (2026-07-26)

Deux écarts ont été corrigés immédiatement, les autres restent ouverts.

**C3b — corrigé.** Vérifié à la main avant correction : `store_run.gd` posait
`run["current_biome"] = ""` puis relisait cette même clé vingt lignes plus bas
pour filtrer le catalogue sur `biome_affinity`. Tous les scénarios du catalogue
ayant une affinité non vide, `select_scenario` ne retenait jamais aucun candidat
et retournait `{}` — le catalogue entier (`data/ai/scenarios/scenario_catalogue.json`,
six quêtes avec ancres, drapeaux et branches) était du code mort.
Correction : `init_run` prend désormais un paramètre `biome`, et `START_RUN`
résout le biome avant de l'appeler. Non-régression :
`tools/godot/test_scenario_selection.gd` (PASS — trois biomes tirent bien un
scénario, le biome vide n'en tire aucun, ce qui était exactement l'état du bug).

**Part NARRATIVE — corrigée** (hors tableau, découverte par l'audit outillé) :
`CARD_TYPE_CAPS` déclarait `min_share`/`max_share` sans que `_balance_skeleton`
ne les applique jamais, l'étape 2 renvoyant à « l'étape 4 » qui traite en réalité
le placement des LÉGENDAIRE. Mesure : 0/12 squelettes conformes avant, 3/12 après ;
les huit restants sont des squelettes à 5 beats où la borne est arithmétiquement
inatteignable (un SHOP, un EVENT et un climax plafonnent le narratif à 40 %).

**Non corrigés** — C1, C2, C3, H1 à H13 : ce sont des chantiers d'architecture
(longueur de run, matérialisation du squelette en cartes, branchement en trois
voies, couche de checks) qui engagent le design et non un simple réglage. La
roadmap du §6 reste la référence pour les ordonner.
