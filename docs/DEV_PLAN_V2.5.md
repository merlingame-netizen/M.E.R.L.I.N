# Plan de Developpement Strict — M.E.R.L.I.N. v2.5

> Source de verite design : `docs/GAME_DESIGN_BIBLE.md` v2.4
> Ce plan est la reference pour toute implementation. Chaque phase doit etre terminee et validee avant de passer a la suivante.
> Date : 2026-03-14 | Revision : 2026-03-14 (v2.5 — cross-check codebase + gap closure)

---

## Phase 0 : Cleanup Dead Code

**Objectif** : Supprimer TOUT le code mort des systemes supprimes. Zero reference residuelle.

### Fichiers a nettoyer

| Fichier | Dead Code | Action |
|---------|-----------|--------|
| `scripts/merlin/merlin_constants.gd` | ELEMENTS (14), ESSENCE_DROP_*, ESSENCE_ANCHOR_CARDS, ESSENCE_BASE_REWARDS, ESSENCE_VICTORY_BONUS, ESSENCE_CHUTE_BONUS, ESSENCE_MINIGAME_BONUS, ESSENCE_OGHAM_BONUS, ESSENCE_FACTION_BONUS, FLUX_*, RUN_TYPOLOGIES, DC_BASE, DC_DIFFICULTY_LABELS, ARCHETYPE_DC_BONUS, BOND_TIERS, OGHAM_STARTER_SKILLS, CardOption enum (left/center/right), FLUX_CHOICE_DELTA | Supprimer |
| `scripts/merlin/merlin_store.gd` | meta state keys: essence{14}, ogham_fragments, liens, gloire_points, bestiole_evolution. Renommer `_init_triade_run` → `_init_run`, `_resolve_triade_choice` → `_resolve_choice`, `_check_triade_run_end` → `_check_run_end`, `_apply_triade_effect` → `_apply_effect`, `_handle_triade_run_end` → `_handle_run_end` | Supprimer + Renommer |
| `scripts/merlin/merlin_card_system.gd` | GAUGES const, gauge init in init_run(), gauge checks in check_run_end(), _get_critical_gauges(), gauge effects in _apply_card_effects(), bestiole context block, _get_bestiole_modifier() | Supprimer |
| `scripts/ui/merlin_game_controller.gd` | bestiole badge (l.1725), bestiole modifier check (l.1736), bestiole_wheel references (l.2198-2233). souffle/flux/triade/awen/bond already removed — verify 0 refs | Supprimer |
| `scripts/merlin/merlin_effect_engine.gd` | LEGACY_GAUGE_EFFECTS const (l.122-128): ADD_GAUGE, REMOVE_GAUGE, MODIFY_BOND | Supprimer dead entries, keep QUEUE_CARD/TRIGGER_ARC in VALID_CODES |
| `scripts/merlin/merlin_llm_adapter.gd` | TRIADE_GRAMMAR_PATH (l.106), VALID_GAUGES (l.133), MAX_GAUGE_DELTA/MIN_GAUGE_DELTA (l.135-136), bestiole_bond in prompt (l.220) | Supprimer |
| `scripts/merlin/merlin_biome_system.gd` | aspect refs "Corps"/"Ame"/"Monde" in passive effects (l.44, 59, 74, 89) | Remplacer par faction_bias |
| `scripts/game_manager.gd` | signal bestiole_updated, var bestiole dict, heal_bestiole(), damage_bestiole(), change_bestiole_type(), bestiole reset in run start | Supprimer |
| `scripts/autoload/merlin_visual.gd` | Palette entries "souffle", "souffle_full", "bestiole". GBC dead entries. CRT_ASPECT_COLORS Triade section | Supprimer |
| `scripts/Calendar.gd` | REROLL_AWEN_COST, awen references | Supprimer ou remplacer par monnaie biome |
| `scripts/Collection.gd` | bestiole refs, TRIADE_VICTORY_ENDINGS | Remplacer par fins bible v2.4 |
| `scripts/HubAntre.gd` | _typology_panel, _show_typology_panel(), _on_typology_selected() | Supprimer typology UI |
| `scripts/ui/merlin_game_ui.gd` | _typology_timer_bar, _typology_badge, typology functions | Supprimer |

### Fichiers a supprimer entierement (dead system files)

| Fichier | Systeme | Lignes |
|---------|---------|:---:|
| `scripts/ui/hub_souffle_bar.gd` | Souffle | ~80 |
| `scripts/ui/hub_triade_hud.gd` | Triade HUD | ~100 |
| `scripts/ui/bestiole_sprite.gd` | Bestiole | ~60 |
| `scripts/ui/bestiole_wheel_system.gd` | Bestiole | ~150 |
| `scripts/ui/bestiole_creature.gd` | Bestiole | ~80 |
| `scripts/ui/pixel_bestiole_fox.gd` | Bestiole | ~60 |
| `scripts/minigames/mg_de_du_destin.gd` | D20 dice | ~100 |

> Note: verifier l'existence de ces fichiers avant suppression — certains ont pu etre supprimes dans des sessions anterieures.

### TRIADE_ action dispatch rename (store + tous callers)

Renommer dans `merlin_store.gd` et TOUS les fichiers appelants :
- `TRIADE_START_RUN` → `START_RUN`
- `TRIADE_GET_CARD` → `GET_CARD`
- `TRIADE_RESOLVE_CHOICE` → `RESOLVE_CHOICE`
- `TRIADE_END_RUN` → `END_RUN`
- `TRIADE_DAMAGE_LIFE` → `DAMAGE_LIFE`
- `TRIADE_HEAL_LIFE` → `HEAL_LIFE`
- `TRIADE_GENERATE_MAP` → `GENERATE_MAP`
- `TRIADE_SELECT_NODE` → `SELECT_NODE`
- `TRIADE_PROGRESS_MISSION` → `PROGRESS_MISSION`
- `TRIADE_USE_SKILL` → `USE_SKILL`
- `TRIADE_APPLY_EFFECTS` → `APPLY_EFFECTS`

Fichiers callers : `merlin_game_controller.gd`, `test_merlin_store.gd`, `test_llm_full_run.gd`, `test_llm_benchmark_run.gd`, `test_llm_intelligence.gd`, `auto_play_runner.gd`, `game_debug_server.gd`

### Acceptance Criteria
- [ ] `.\validate.bat` : 0 errors, 0 warnings
- [ ] grep -r "souffle\|flux\|triade\|bestiole\|awen\|bond\|gauges\|essence" scripts/ → 0 hits (hors commentaires historiques)
- [ ] grep -r "GAUGE\|FLUX_\|DC_BASE\|BOND_TIER\|RUN_TYPO" scripts/ → 0 hits
- [ ] Commit conventionnel : `refactor(cleanup): remove all dead systems (gauges, bestiole, flux, triade, souffle)`

**Complexite** : MODERATE (beaucoup de fichiers, mais suppressions simples)
**Dependances** : Aucune

---

## Phase 1 : Core Data Layer (`merlin_constants.gd`)

**Objectif** : Toutes les constantes du jeu alignees sur la bible v2.4. Source de verite code.

### 1A. Oghams (18) — CRITICAL: effet specs code ≠ bible

> **ATTENTION** : Le code actuel (`OGHAM_FULL_SPECS`) a des effets qui ne correspondent PAS a la bible v2.4.
> La Phase 1 DOIT corriger ces divergences.

| Ogham | Effet ACTUEL (code) | Effet BIBLE v2.4 | Action |
|-------|-------------------|------------------|--------|
| `duir` | `force_equilibre` | **Soin immediat +12 PV** | Changer → `heal_immediate`, amount: 12 |
| `onn` | `heal_life` (15 PV) | **+10 monnaie biome** | Changer → `add_biome_currency`, amount: 10 |
| `nuin` | `add_option` (4e) | **Remplace la pire option** | Changer → `replace_worst_option` |
| `quert` | `heal_worst` | **Soin +8 PV** | Changer → `heal_immediate`, amount: 8 |
| `ruis` | `balance_all` | **+18 PV, -5 monnaie biome** | Changer → `heal_and_cost` |
| `saille` | `reduce_cooldowns` | **+8 monnaie, +3 PV** | Changer → `currency_and_heal` |
| `ur` | `sacrifice_trade` | **-15 PV, +20 monnaie, buff x1.3** | Verifier params |

Les autres Oghams (beith, coll, ailm, luis, gort, eadhadh, tinne, huath, straif, muin, ioho) ont des effets conceptuellement corrects mais les noms d'effet doivent etre standardises.

```gdscript
const OGHAMS: Dictionary = {
    "beith": {
        "name": "Bouleau", "tree": "Betula", "category": "reveal",
        "effect": "reveal_one_option", "cooldown": 3, "cost_anam": 0,
        "branch": "central", "tier": 0,
        "description": "Revele l'effet complet d'1 option au choix",
        "effect_params": {"target": "single_option"}
    },
    # ... 17 autres avec TOUS les champs chiffres de la bible section 2.2
}
```

**Champs obligatoires par Ogham** : name, tree, category, effect, cooldown, cost_anam, branch, tier, description, effect_params

### 1B. Biomes (8) avec seuils maturite

```gdscript
const BIOMES: Dictionary = {
    "foret_broceliande": {
        "name": "Foret de Broceliande", "subtitle": "Ou les arbres ont des yeux",
        "season": "printemps", "difficulty": 0, "maturity_threshold": 0,
        "oghams_affinity": ["quert", "huath", "coll"],
        "currency_name": "Herbes enchantees",
        "card_interval_range": [12, 15],
        "pnj": "gwenn", "arc": "le_chene_chantant", "arc_cards": 3,
        "arc_condition": {"type": "faction_rep", "faction": "druides", "value": 30}
    },
    # ... 7 autres avec les memes champs
}

const BIOME_MATURITY_THRESHOLDS: Dictionary = {
    "foret_broceliande": 0,   # starter
    "landes_bruyere": 15,
    "cotes_sauvages": 15,
    "villages_celtes": 25,
    "cercles_pierres": 30,
    "marais_korrigans": 40,
    "collines_dolmens": 50,
    "iles_mystiques": 75
}

const MATURITY_WEIGHTS: Dictionary = {
    "total_runs": 2, "fins_vues": 5, "oghams_debloques": 3, "max_faction_rep": 1
}
# Note: "max_faction_rep" = MAX across all 5 factions (single highest value, not sum)
```

### 1C. Effet caps et formules

```gdscript
const EFFECT_CAPS: Dictionary = {
    "ADD_REPUTATION": {"max": 20, "min": -20},
    "HEAL_LIFE": {"max": 18},
    "HEAL_CRITICAL": {"max": 5},         # bible 2.1: soin succes critique
    "DAMAGE_LIFE": {"max": 15},
    "DAMAGE_CRITICAL": {"max": 22},       # bible 6.5: echec critique = 15 x 1.5 = 22.5 → floor 22
    "ADD_BIOME_CURRENCY": {"max": 10},
    "UNLOCK_OGHAM": {"max_per_card": 1},
    "LIFE_MAX": 100,                      # bible 2.1
    "LIFE_MIN": 0,                        # ne peut pas etre negatif
    "effects_per_option": 3,
    "score_bonus_cap": 2.0,
    "drain_per_card": 1                   # bible 2.1: -1 au debut de chaque carte
}

const MULTIPLIER_TABLE: Array = [
    {"range": [0, 20], "label": "echec_critique", "factor": -1.5},
    {"range": [21, 50], "label": "echec", "factor": -1.0},
    {"range": [51, 79], "label": "reussite_partielle", "factor": 0.5},
    {"range": [80, 94], "label": "reussite", "factor": 1.0},
    {"range": [95, 100], "label": "reussite_critique", "factor": 1.5}
]

const ANAM_REWARDS: Dictionary = {
    "base": 10, "victory_bonus": 15,
    "minigame_won": 2, "minigame_threshold": 80,
    "ogham_used": 1, "faction_honored": 5, "faction_threshold": 80,
    "death_cap_cards": 30, "ogham_already_owned_bonus": 5
}

const TALENT_TIERS: Dictionary = {
    1: {"cost_range": [50, 80]},
    2: {"cost_range": [80, 120]},
    3: {"cost_range": [120, 180]},
    4: {"cost_range": [180, 250]},
    5: {"cost_range": [250, 350]}
}
```

### 1D. Verbes d'action (45) + mapping champs lexicaux

```gdscript
const ACTION_VERBS: Dictionary = {
    "chance": ["cueillir", "chercher au hasard", "tenter sa chance", "deviner", "fouiller a l'aveugle"],
    "bluff": ["marchander", "convaincre", "mentir", "negocier", "charmer", "amadouer"],
    "observation": ["observer", "scruter", "memoriser", "examiner", "fixer", "inspecter"],
    "logique": ["dechiffrer", "analyser", "resoudre", "decoder", "interpreter", "etudier"],
    "finesse": ["se faufiler", "esquiver", "contourner", "se cacher", "escalader", "traverser"],
    "vigueur": ["combattre", "courir", "fuir", "forcer", "pousser", "resister physiquement"],
    "esprit": ["calmer", "apaiser", "mediter", "resister mentalement", "se concentrer", "endurer",
               "parler", "accepter", "refuser", "attendre", "s'approcher"],
    "perception": ["ecouter", "suivre", "pister", "sentir", "flairer", "tendre l'oreille"]
}

const FIELD_MINIGAMES: Dictionary = {
    "chance": ["herboristerie"],
    "bluff": ["negociation"],
    "observation": ["fouille", "regard"],
    "logique": ["runes"],
    "finesse": ["ombres", "equilibre"],
    "vigueur": ["combat_rituel", "course"],
    "esprit": ["apaisement", "volonte", "sang_froid"],
    "perception": ["traces", "echo"]
}
```

### 1E. Talent Tree (34 noeuds)

34 noeuds : 5 branches faction × 5 tiers + 4 central + 5 cross-faction speciaux.
- Ogham starters dans branche centrale tier 0 (beith, luis, quert — cout 0)
- 15 Oghams non-starters repartis par branche faction (3/faction)
- Bonus passifs : ~15-19 noeuds (mecaniques uniquement, pas de contenu narratif exclusif)
- Couts en Anam uniquement
- Prereq : tier N requiert ≥1 noeud tier N-1 dans la meme branche

**Decision arretee** : 34 noeuds exactement (pas de fourchette 30-34 — chiffre fixe)

### 1F. MOS convergence + confiance

```gdscript
const MOS_CONVERGENCE: Dictionary = {
    "soft_min_cards": 8,
    "target_cards": [20, 25],
    "soft_max_cards": 40,
    "hard_max_cards": 50,
    "max_active_promises": 2
}

const TRUST_TIERS: Dictionary = {
    "T0": {"range": [0, 24], "label": "cryptique"},
    "T1": {"range": [25, 49], "label": "indices"},
    "T2": {"range": [50, 74], "label": "avertissements"},
    "T3": {"range": [75, 100], "label": "secrets"}
}

const TRUST_DELTAS: Dictionary = {
    "promise_kept": 10, "promise_broken": -15,
    "courageous_choice": [3, 5], "selfish_choice": [-5, -3]
}

const IN_GAME_PERIODS: Dictionary = {
    "aube": {"cards": [1, 5], "faction": "druides", "bonus": 0.10},
    "jour": {"cards": [6, 10], "faction": ["anciens", "niamh"], "bonus": 0.10},
    "crepuscule": {"cards": [11, 15], "faction": "korrigans", "bonus": 0.10},
    "nuit": {"cards": [16, 20], "faction": "ankou", "bonus": 0.15}
}
```

### Acceptance Criteria
- [ ] Toutes les constantes de la bible v2.4 presente dans `merlin_constants.gd`
- [ ] 18 Oghams avec TOUS les champs (name, tree, category, effect, cooldown, cost_anam, branch, tier, description, effect_params)
- [ ] 8 biomes avec seuils maturite
- [ ] 45 verbes mappes aux 8+1 champs lexicaux
- [ ] 34 noeuds talent tree
- [ ] `.\validate.bat` : 0 errors
- [ ] Commit : `feat(constants): align all game constants with bible v2.4`

**Complexite** : COMPLEX (300+ lignes de constantes)
**Dependances** : Phase 0

---

## Phase 2 : Save System (`merlin_save_system.gd`)

**Objectif** : Profil unique + run_state, conforme a la structure JSON de la bible section 13.4.

### Implementation

```gdscript
const PROFILE_PATH := "user://merlin_profile.json"
const CURRENT_VERSION := "1.0.0"

func save_profile(meta: Dictionary) -> bool
func load_profile() -> Dictionary
func profile_exists() -> bool
func reset_profile() -> void
func save_run_state(run_state: Dictionary) -> void
func load_run_state() -> Dictionary  # null si pas de run en cours
func clear_run_state() -> void
func _migrate(data: Dictionary) -> Dictionary  # 0.4.0 → 1.0.0
func _validate(data: Dictionary) -> bool
func _get_default_profile() -> Dictionary  # Structure de la bible 13.4
```

### Migration 0.4.0 → 1.0.0
- Prendre data["meta"] uniquement
- Supprimer: essence, ogham_fragments, liens, gloire_points, bestiole_evolution
- Convertir: sum(essence.values()) → ajouter a anam
- Ajouter: trust_merlin=0, arc_tags=[], biome_runs={}, ogham_discounts={}, run_state=null
- Garder: anam, faction_rep, talent_tree, oghams, total_runs, endings_seen

### Profile JSON Schema (bible 13.4 — reference code)

```json
{
  "version": "1.0.0",
  "meta": {
    "anam": 0,
    "total_runs": 0,
    "faction_rep": {"druides": 0.0, "anciens": 0.0, "korrigans": 0.0, "niamh": 0.0, "ankou": 0.0},
    "trust_merlin": 0,
    "talent_tree": {"unlocked": []},
    "oghams": {"owned": ["beith", "luis", "quert"], "equipped": "beith"},
    "ogham_discounts": {},
    "endings_seen": [],
    "arc_tags": [],
    "biome_runs": {"foret_broceliande": 0, "landes_bruyere": 0, "cotes_sauvages": 0,
                   "villages_celtes": 0, "cercles_pierres": 0, "marais_korrigans": 0,
                   "collines_dolmens": 0, "iles_mystiques": 0},
    "stats": {"total_cards": 0, "total_minigames_won": 0, "total_deaths": 0, "consecutive_deaths": 0,
              "oghams_discovered_in_runs": 0, "total_anam_earned": 0}
  },
  "run_state": null
}
```

**run_state schema (quand non-null)** :
```json
{
  "biome": "foret_broceliande",
  "card_index": 5,
  "life": 87,
  "life_max": 100,
  "biome_currency": 12,
  "equipped_oghams": ["beith", "coll"],
  "active_ogham": "beith",
  "cooldowns": {"beith": 0, "coll": 3},
  "promises": [{"id": "p1", "text": "...", "faction": "druides", "countdown": 3, "effect_kept": {}, "effect_broken": {}}],
  "faction_rep_delta": {"druides": 5.0, "anciens": 0.0, "korrigans": -3.0, "niamh": 0.0, "ankou": 0.0},
  "trust_delta": 0,
  "narrative_summary": "Le joueur a rencontre un esprit des bois...",
  "arc_tags_this_run": [],
  "period": "jour",
  "buffs": [],
  "events_log": []
}
```

**Nouveau joueur** : `_get_default_profile()` retourne la structure ci-dessus avec valeurs zero.
**Profile existant sans run** : `run_state = null`.

### Acceptance Criteria
- [ ] Profil unique fonctionnel (save/load/reset)
- [ ] `_get_default_profile()` retourne la structure JSON exacte ci-dessus
- [ ] run_state sauvegarde et restaure correctement
- [ ] Migration 0.4.0 → 1.0.0 sans perte de donnees
- [ ] Structure JSON conforme a la bible 13.4
- [ ] faction_rep est float (0.0-100.0), trust_merlin est int (0-100)
- [ ] `.\validate.bat` : 0 errors
- [ ] Commit : `feat(save): single profile + run_state resume system`

**Complexite** : MODERATE
**Dependances** : Phase 1 (constantes default profile)

---

## Phase 3 : Effect Engine (`merlin_effect_engine.gd`)

**Objectif** : Pipeline d'effets conforme a la bible section 13.3. Caps enforces. Oghams de protection.

### Pipeline (12 etapes)

```gdscript
func process_card(card: Dictionary, state: Dictionary) -> Dictionary:
    # 1. DRAIN: state.life -= 1
    # 2. AFFICHAGE: return card for display
    # 3. OGHAM: handle ogham activation (if player activates)
    # 4. CHOIX: receive player choice (option_index)
    # 5. MINIGAME: trigger minigame (if not merlin_direct)
    # 6. SCORE: receive minigame score 0-100
    # 7. EFFETS: apply effects with multiplier
    # 8. PROTECTION: filter negatives through active ogham protections
    # 9. VIE: check life <= 0
    # 10. PROMESSES: decrement countdowns, check expirations
    # 11. COOLDOWN: decrement active ogham cooldown
    # 12. RETURN: signal return to 3D

func _apply_effect(effect: Dictionary, multiplier: float, state: Dictionary) -> void
func _cap_effect(effect: Dictionary) -> Dictionary
func _get_multiplier(score: int) -> float
func _apply_ogham_protection(effects: Array, active_ogham: String) -> Array
```

### Effets whitelist (10 types)
- ADD_REPUTATION, HEAL_LIFE, DAMAGE_LIFE, UNLOCK_OGHAM, ADD_TAG, REMOVE_TAG
- TRIGGER_EVENT, PROMISE, PLAY_SFX, ADD_BIOME_CURRENCY, SHOW_DIALOG

### Ogham effects (18 types — implementation par categorie)

Chaque Ogham a une fonction dediee dans l'effect engine.

**Reveal** (step 3 — avant choix) :
- `beith` : marque 1 option comme revealed (UI affiche effets complets)
- `coll` : marque les 3 options comme revealed
- `ailm` : retourne {"theme": String, "field": String} de la prochaine carte (query MOS/FastRoute)

**Protection** (step 8 — apres effets, filtre negatifs) :
- `luis` : supprime le 1er effet negatif de la liste des effets appliques
- `gort` : tout effet DAMAGE_LIFE > 10 est reduit a 5
- `eadhadh` : supprime TOUS les effets negatifs (DAMAGE_LIFE, negatif ADD_REPUTATION)
- Ordre si multiples : luis → gort → eadhadh (chacun filtre les restants)

**Boost** (step 3 — avant choix, effet immediat) :
- `duir` : HEAL_LIFE +12 immediat (cap 18)
- `tinne` : flag `double_positives = true` (step 7 double les effets positifs de l'option choisie)
- `onn` : ADD_BIOME_CURRENCY +10 immediat (cap 10)

**Narratif** (step 3 — modifie la carte avant choix) :
- `nuin` : identifie l'option avec le plus de negatifs, la remplace (LLM call ou FastRoute)
- `huath` : regenere les 3 options (nouveau LLM call ou FastRoute)
- `straif` : flag `twist_next_card = true` (MOS insere un twist narratif dans la carte suivante)

**Recovery** (step 3 — avant choix, effet immediat) :
- `quert` : HEAL_LIFE +8 (cap 18)
- `ruis` : HEAL_LIFE +18 puis ADD_BIOME_CURRENCY -5 (peut aller negatif mais clamp 0)
- `saille` : ADD_BIOME_CURRENCY +8 puis HEAL_LIFE +3

**Special** (step 3 ou step 7) :
- `muin` (step 7) : inverse positifs/negatifs. Si echec critique → bonus x1.5, succes → malus x1.5
- `ioho` (step 3) : defausse la carte, genere une nouvelle (LLM call). Le joueur rejoue
- `ur` (step 3) : DAMAGE_LIFE -15, ADD_BIOME_CURRENCY +20, flag `score_buff_1.3 = true`

**Verb d'action detection fallback** : si le LLM genere un verbe hors des 45 listes, mapper a `"esprit"` par defaut.

### Acceptance Criteria
- [ ] Pipeline 12 etapes conforme a la bible 13.3
- [ ] Tous les caps enforces (bible 6.5 caps table)
- [ ] Multiplicateur direct conforme (5 tranches)
- [ ] 18 Oghams implementes avec effets exacts (voir specs par categorie ci-dessus)
- [ ] Protection luis/gort/eadhadh fonctionnelle a l'etape 8 (ordre : luis → gort → eadhadh)
- [ ] Drain -1 PV au DEBUT de chaque carte (step 1, avant choix et effets)
- [ ] Verification mort APRES application de TOUS les effets (step 9)
- [ ] Echec critique → DAMAGE × 1.5 (floor to int), reussite critique → HEAL bonus
- [ ] Commit : `feat(effects): implement strict 12-step pipeline with caps`

**Complexite** : COMPLEX
**Dependances** : Phase 1

---

## Phase 4 : Economie & Progression (`merlin_store.gd`)

**Objectif** : Anam calculation, talent tree, score maturite, confiance Merlin.

### Functions

```gdscript
func calculate_run_rewards(run_data: Dictionary) -> Dictionary
func apply_run_rewards(rewards: Dictionary) -> void
func unlock_talent(node_id: String) -> bool
func can_unlock_talent(node_id: String) -> bool
func calculate_maturity_score() -> int
func can_unlock_biome(biome_id: String) -> bool
func update_trust_merlin(delta: int) -> void
func get_trust_tier() -> String  # "T0", "T1", "T2", "T3"
func get_ogham_cost(ogham_id: String) -> int  # avec discount si decouvert en run
func apply_ogham_discount(ogham_id: String) -> void  # -50%
func get_period(card_index: int) -> String  # "aube", "jour", etc.
func get_period_bonus(card_index: int, faction: String) -> float
func _apply_talent_effects_for_run() -> Dictionary  # modifiers actifs
```

### Formules (bible 13.5)
- `calculate_run_rewards()` : base(10) + victoire(15) + minigames(n×2) + oghams(n×1) + factions(n×5) + collecte
- Mort/abandon : × min(cartes/30, 1.0)
- Maturite : runs×2 + fins×5 + oghams×3 + max_rep×1

### Decisions de phase
- `get_period_bonus()` : le bonus +10%/+15% est **multiplicatif** sur les gains rep de la faction correspondante
- `calculate_maturity_score()` : `max_faction_rep` = la valeur MAX parmi les 5 factions (pas la somme)
- `update_trust_merlin()` : changement de tier T0→T3 **immediat** mid-run (pas en fin de run)
- Affinite biome : si l'Ogham actif est dans `BIOMES[biome].oghams_affinity` → +10% score minigame + -1 cooldown
- `apply_ogham_discount()` : met `ogham_discounts[id] = int(base_cost * 0.5)` dans le profil

### Acceptance Criteria
- [ ] Anam calcule conforme aux formules bible 13.5
- [ ] Mort/abandon : Anam × min(cartes/30, 1.0) — cap 100%, pas de bonus au-dela de 30 cartes
- [ ] Talent tree unlock avec Anam, prerequis verifies (tier N-1 requis dans la meme branche)
- [ ] Score maturite calcule correctement : runs×2 + fins×5 + oghams×3 + max(faction_rep.values())×1
- [ ] Biome unlock : `can_unlock_biome()` verifie maturity_score >= BIOME_MATURITY_THRESHOLDS[biome_id]
- [ ] Confiance Merlin clamp(0, 100), tiers corrects (T0=0-24, T1=25-49, T2=50-74, T3=75-100)
- [ ] Periodes in-game fonctionnelles (1 periode = 5 cartes, bonus rep multiplicatif)
- [ ] Affinite biome appliquee : +10% score minigame + -1 cooldown pour Oghams d'affinite
- [ ] Ogham discount 50% sauvegarde dans profil
- [ ] Commit : `feat(economy): anam rewards, talent tree, maturity score, trust system`

**Complexite** : COMPLEX
**Dependances** : Phase 1, Phase 2, Phase 3

---

## Phase 5 : Card System (`merlin_card_system.gd`)

**Objectif** : 3 options fixes, detection champ lexical, Merlin Direct, promesses, FastRoute.

### Functions

```gdscript
func init_run(biome: String, ogham: String) -> void
func generate_card(context: Dictionary) -> Dictionary
func detect_lexical_field(option_label: String) -> String  # retourne le champ
func select_minigame(field: String) -> String  # retourne le minigame id
func handle_merlin_direct(card: Dictionary) -> void
func create_promise(promise_data: Dictionary) -> void
func resolve_promise(promise_id: String, kept: bool) -> void
func check_promises(card_index: int) -> Array  # promesses expirees
func get_fastroute_card(context: Dictionary) -> Dictionary
func apply_ogham_narrative(ogham_id: String, card: Dictionary) -> Dictionary
func check_run_end(state: Dictionary) -> Dictionary  # {ended: bool, reason: String}
```

### Regles
- Toujours 3 options par carte (code valide APRES generation LLM — si != 3, rejeter et fallback FastRoute)
- Verbes neutres → champ esprit (default)
- Verbe hors des 45 listes → champ esprit (fallback)
- Max 2 promesses actives (guardrail local, PAS dependant du MOS)
- FastRoute : selection par tags (biome, faction, field, trust_tier) — Phase 5 implemente le SELECTEUR
- Oghams narratifs (nuin, huath, ioho) : appel LLM ou FastRoute pour regenerer
- Merlin Direct : detection par `card.type == "merlin_direct"` (tag dans la carte generee)

### Contrat Phase 5 ↔ Phase 8 (resolution dependance circulaire)

Phase 5 fournit :
- `generate_card(context) -> Dictionary` : genere via LLM ou FastRoute fallback
- `get_fastroute_card(context) -> Dictionary` : selection deterministe par tags
- `detect_lexical_field(option_label) -> String` : 45 verbes → 8+1 champs
- `select_minigame(field) -> String` : champ → minigame id

Phase 8 (MOS) consomme les fonctions Phase 5 et ajoute :
- `orchestrate_card()` : appelle `generate_card()` avec context enrichi
- `check_guardrails()` : valide la carte APRES generation
- Pacing, tension, arc insertion

**Phase 5 fonctionne SANS Phase 8** (mode standalone avec FastRoute). Phase 8 enrichit.

### Acceptance Criteria
- [ ] 3 options toujours (validation post-LLM, fallback FastRoute si != 3)
- [ ] Detection champ lexical fonctionnelle (45 verbes → 8+1 champs, fallback esprit)
- [ ] Minigame mapping conforme (FIELD_MINIGAMES de Phase 1)
- [ ] Merlin Direct sans minigame, effets x1.0 (detection par card.type)
- [ ] Promesses avec countdown, max 2, resolution (trust_merlin ±10/±15)
- [ ] FastRoute selecteur fonctionnel (standalone, sans MOS)
- [ ] check_run_end : retourne {ended, reason} quand vie=0 ou MOS converge
- [ ] Commit : `feat(cards): 3 options, lexical detection, promises, fastroute`

**Complexite** : COMPLEX
**Dependances** : Phase 1, Phase 3, Phase 4

---

## Phase 6 : Run Flow 3D

**Objectif** : Rail on-rails, collecte, fondus, MOS convergence.

### Scenes Godot
- `scenes/Run3D.tscn` : scene principale du run 3D
- `scripts/run/run_3d_controller.gd` : controller du rail
- `scripts/run/collectible_spawner.gd` : spawn des events 3D
- `scripts/run/transition_manager.gd` : fondus 3D ↔ carte ↔ minigame

### Functions

```gdscript
# run_3d_controller.gd
func start_run(biome: String, ogham: String) -> void
func pause_for_card() -> void  # fige la 3D, lance fondu
func resume_after_card() -> void  # reprend la marche
func check_convergence(card_index: int, tension: float) -> bool

# collectible_spawner.gd
func spawn_currency(frequency_range: Vector2) -> void  # 3-5s
func spawn_event(type: String) -> void  # plant, trap, rune, spirit, anam_rare

# transition_manager.gd
func fade_to_card(duration: float) -> void  # 1-2s
func fade_to_3d(duration: float) -> void
func fade_to_minigame(duration: float) -> void
func disable_inputs() -> void  # pendant fondu
func enable_inputs() -> void
```

### Contrat signaux Phase 6 → Phase 7 (HUD)

Phase 6 emet des signaux consommes par Phase 7 (HUD) :

```gdscript
signal life_changed(current: int, max: int)
signal currency_changed(amount: int)
signal ogham_updated(ogham_id: String, cooldown: int)
signal promises_updated(promises: Array)
signal period_changed(period: String)
signal card_started(card: Dictionary)
signal card_ended()
signal run_ended(reason: String, data: Dictionary)
```

Phase 7 HUD s'abonne a ces signaux — pas de couplage direct.

### Acceptance Criteria
- [ ] Personnage avance sur rail automatiquement
- [ ] Collectibles apparaissent (3-5s, +1-2 monnaie, fenetre 1.5s)
- [ ] Fondus fonctionnels (3D → carte → minigame → 3D)
- [ ] Inputs desactives pendant fondus (1-2s)
- [ ] MOS convergence : soft min/max/hard max respectes
- [ ] Signaux emis pour HUD (Phase 7) conformes au contrat ci-dessus
- [ ] Commit : `feat(run3d): on-rails permanent, collectibles, transitions`

**Complexite** : COMPLEX
**Dependances** : Phase 3, Phase 5

---

## Phase 7 : Hub & UI

**Objectif** : Hub 2D minimaliste, HUD 3D/carte, ecran fin de run.

### Ecrans
- **Hub** : Merlin dialogue (LLM), arbre talents, choix biome, stats, oghams, journal, options
- **HUD 3D** : vie, monnaie, ogham cliquable (switch), promesses, periode
- **HUD carte** : overlay avec texte, 3 options, bouton ogham
- **Fin de run** : fondu narratif → carte du voyage → ecran gains

### Functions cles

```gdscript
# hub_controller.gd
func show_hub() -> void
func generate_merlin_dialogue(last_run: Dictionary) -> void
func show_talent_tree() -> void
func show_biome_select() -> void

# hud_controller.gd
func update_life(current: int, max: int) -> void
func update_currency(amount: int) -> void
func update_ogham(ogham_id: String, cooldown: int) -> void
func update_promises(promises: Array) -> void
func update_period(period: String) -> void
func show_ogham_switch_menu(available: Array) -> void

# end_run_screen.gd
func show_narrative_ending(text: String) -> void
func show_journey_map(events: Array) -> void
func show_rewards(rewards: Dictionary) -> void
func show_faction_choice(factions: Array) -> void  # si 2+ ≥ 80
```

### Acceptance Criteria
- [ ] Hub fonctionnel avec tous les ecrans
- [ ] HUD 3D minimaliste (vie, monnaie, ogham, promesses, periode)
- [ ] HUD carte overlay (texte, 3 options, ogham activation)
- [ ] Fin de run : 3 ecrans (narratif, carte voyage, gains)
- [ ] Choix de fin si multiples factions ≥ 80
- [ ] Commit : `feat(ui): hub 2D, HUD 3D/carte, end-run screens`

**Complexite** : COMPLEX
**Dependances** : Phase 4, Phase 6

---

## Phase 8 : MOS & AI

**Objectif** : Multi-brain orchestration, RAG, pacing, guardrails, confiance.

### Architecture
- `merlin_omniscient.gd` : orchestrateur central
- `merlin_ai.gd` : multi-brain (Narrator 4B, GM 2B, Judge 0.8B)
- `rag_manager.gd` : contexte par cerveau

### Functions cles

```gdscript
# merlin_omniscient.gd
func orchestrate_card(context: Dictionary) -> Dictionary
func check_guardrails(card: Dictionary) -> Dictionary  # valide/ajuste
func calculate_tension(state: Dictionary) -> float  # 0-0.8
func apply_pacing(state: Dictionary) -> Dictionary  # mercy, recovery
func select_fastroute_or_llm(context: Dictionary) -> String  # "fastroute" | "llm"
func get_merlin_voice(context: Dictionary) -> String  # neutre/mysterieux/avertissement/moquerie/melancolie
func insert_arc_card(state: Dictionary) -> Dictionary  # si conditions remplies
func insert_key_card(state: Dictionary) -> Dictionary  # carte-cle biome

# rag_manager.gd
func build_context(brain: String, state: Dictionary) -> String  # budget tokens
```

### 8A. MOS Registries (in-memory, sauvegardes dans run_state)

| Registry | Schema | Source | Usage |
|----------|--------|--------|-------|
| Player | `{choices_count: int, preferred_fields: {}, avg_score: float}` | Choix joueur | Rubber-banding contexte |
| Narrative | `{arc_tags: [], pnj_met: [], twists_resolved: []}` | Cards jouees | Eviter repetitions |
| Faction | `{rep_deltas_this_run: {}, cross_faction_count: int}` | Effets | Cap cross-faction 10% |
| Cards | `{themes_seen: [], fields_used: {}, total_played: int}` | Generation | Variete thematique |
| Promises | `{active: [], resolved: [], broken: []}` | Promise system | Max 2 guardrail |
| Trust | `{current: int, tier: String, changes: []}` | Choix joueur | Voice mode, contenu |

### 8B. Tension, Pacing & Voice

```gdscript
func calculate_tension(state: Dictionary) -> float:
    # Formule : ponderation de 4 facteurs normalises 0-1
    # tension = 0.3 * (1 - life/100) + 0.2 * cross_faction_pressure
    #         + 0.3 * promise_urgency + 0.2 * cards_since_climax
    # Clamp 0.0 - 0.8

func get_merlin_voice(context: Dictionary) -> String:
    # T0 (0-24) : "cryptique" (reponses vagues, enigmes)
    # T1 (25-49) : "indices" (suggestions indirectes)
    # T2 (50-74) : "avertissement" (mises en garde claires)
    # T3 (75-100) : "secrets" (informations directes, revelations)
    # + si tension > 0.6 : override → "avertissement" quel que soit le tier
    # + si vie < 20 : override → "melancolie"
```

### 8C. PNJ recurrents (8 — 1 par biome)

Chaque biome a 1 PNJ marchand recurrent (bible 2.4 section marchands) :
- Detection en 3D (modele visible, clic → carte marchand overlay)
- Prix variables par PNJ (pas cher → cher selon personnalite)
- Pas de phase dediee — le MOS decide quand inserer un marchand (1 par run max)

### 8D. Arcs narratifs (8 biome + 1 cross)

- Arc tracking via `arc_tags` dans le profil (persistant cross-run)
- Max 1-2 cartes arc par run (guardrail MOS)
- Condition de declenchement : `BIOMES[biome].arc_condition` (faction_rep, total_runs, etc.)
- Arc complet → fin narrative specifique debloquee

### 8E. Festivals (bible 7.3 — differe)

Les festivals (Imbolc/Beltane/Lughnasadh/Samhain) sont des **modificateurs de pool de cartes** lies au calendrier reel. Implementation differee — pas dans le scope des 10 phases. Tracker via `todo.md`.

### Guardrails
- Total effet < 50 par carte (somme des valeurs absolues de tous les effets)
- 90% des cartes ont des tradeoffs (au moins 1 effet negatif)
- Pas de mort instantanee (DAMAGE_LIFE cap 15, critique 22)
- Pas de mots modernes / meta-references (validation LLM output)
- Max 2 promesses actives (guardrail code, PAS LLM)
- Cross-faction 10% des cartes max (registry Faction.cross_faction_count)

### Acceptance Criteria
- [ ] Multi-brain fonctionnel (time-sharing ou parallele selon profil)
- [ ] FastRoute vs LLM routing (contexte-dependant)
- [ ] 6 guardrails enforces (verifiables par test unitaire)
- [ ] Pacing : mercy -20% scaling apres 3 morts consecutives (stats.consecutive_deaths), recovery +5 PV si vie <20
- [ ] Confiance T0-T3 affecte le contenu genere (voice modes)
- [ ] Arcs narratifs inseres organiquement (max 1-2/run, condition verifiee)
- [ ] PNJ marchands fonctionnels (1/run max, prix variables)
- [ ] MOS registries en memoire + sauvegardes dans run_state
- [ ] Tension calculee (formule 4 facteurs, clamp 0-0.8)
- [ ] Commit : `feat(mos): orchestrator, guardrails, pacing, trust tiers, registries`

**Complexite** : COMPLEX
**Dependances** : Phase 5, Phase 6

---

## Phase 9 : Audio & Polish

**Objectif** : Stems par biome, SFX feedback, tutoriel diegetique.

### Implementation
- 8 themes musicaux (1 par biome) decomposes en 4 stems
- Crossfade stems selon tension MOS (2-3s)
- SFX pour chaque action (30+ sons)
- Tutoriel diegetique (premieres cartes scriptees)
- Tooltips progressives (flags dans le profil)

### Acceptance Criteria
- [ ] Stems music fonctionnels (4 stems × 8 biomes)
- [ ] Crossfade selon tension
- [ ] SFX feedback complet
- [ ] Premier run scripto (2-3 cartes fixes)
- [ ] Tooltips une seule fois (tutorial_flags)
- [ ] Commit : `feat(audio): stems music, sfx, tutorial onboarding`

**Complexite** : MODERATE
**Dependances** : Phase 6, Phase 7

---

## Ordre d'execution et parallelisme

```
Phase 0 (Cleanup)          ← PREMIER, debloque tout
     ↓
Phase 1 (Constants)        ← Fondation de donnees
     ↓
Phase 2 (Save) ←──────────── dependance Phase 1
     ↓
Phase 3 (Effects) ←───────── dependance Phase 1
     ↓
Phase 4 (Economy) ←───────── dependances Phase 1, 2, 3
     ↓
Phase 5 (Cards) ←─────────── dependances Phase 1, 3, 4
     ↓
Phase 6 (Run 3D) ←────────── dependances Phase 3, 5
Phase 7 (Hub/UI) ←────────── dependances Phase 4, 6   (parallelisable avec 6 partiellement)
     ↓
Phase 8 (MOS/AI) ←────────── dependances Phase 5, 6
     ↓
Phase 9 (Audio/Polish) ←──── dependances Phase 6, 7
```

**Chemin critique** : 0 → 1 → 3 → 4 → 5 → 6 → 8 → 9
**Phases parallelisables** : Phase 6 + Phase 7 (partiellement)

---

## Metriques de completion

| Phase | Fichiers | Lignes estimees | Complexite |
|:---:|---------|:---:|:---:|
| 0 | 7 | -400 (suppression) | MODERATE |
| 1 | 1 | +500 | COMPLEX |
| 2 | 1 | +150 | MODERATE |
| 3 | 1 | +300 | COMPLEX |
| 4 | 1 | +250 | COMPLEX |
| 5 | 1 | +300 | COMPLEX |
| 6 | 4 | +400 | COMPLEX |
| 7 | 4 | +500 | COMPLEX |
| 8 | 3 | +350 | COMPLEX |
| 9 | 2 | +200 | MODERATE |
| **Total** | **~25** | **~2950 nettes** | |

---

## Regles de dev (OBLIGATOIRES)

1. **Chaque phase termine par** : `.\validate.bat` → 0 errors → commit conventionnel
2. **Pas de code sans spec** : chaque valeur doit etre tracable dans la bible v2.4
3. **Pas de "a definir plus tard"** : toutes les valeurs sont dans la bible ou dans ce plan
4. **Pipeline 13.3 est la reference code** : tout le runtime suit les 12 etapes dans l'ordre exact
5. **Caps sont des guardrails HARD** : jamais depasses, meme par des Oghams ou talents
6. **1 Ogham par carte** : le bouton se desactive apres usage
7. **Toujours 3 options** : le code valide et corrige si LLM genere != 3
8. **Phase 5 standalone** : le card system fonctionne SANS MOS (FastRoute fallback), Phase 8 enrichit
9. **Signaux HUD** : Phase 6 emet, Phase 7 s'abonne — jamais de couplage direct

---

## Systemes differes (hors scope 10 phases)

| Systeme | Bible Section | Raison | Quand |
|---------|:---:|--------|-------|
| Festivals (Imbolc/Beltane/Lughnasadh/Samhain) | 7.3 | Modificateur pool, faible priorite | Post-Phase 9, playtest |
| Real-time ambiance lighting | 7.1 | Polish 3D, non-bloquant | Post-Phase 6, polish |
| Judge scoring (LLM 0.8B) | 6.1 | Optionnel, qualite LLM output | Phase 8 extension |
| Carte du voyage (journey map end screen) | 5.3 | UI polish, non-bloquant | Phase 7 extension |

Ces systemes ont des specs dans la bible mais sont non-bloquants pour le core loop.
