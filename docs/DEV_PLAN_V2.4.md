# Plan de Developpement Strict — M.E.R.L.I.N. v2.4

> Source de verite design : `docs/GAME_DESIGN_BIBLE.md` v2.4
> Ce plan est la reference pour toute implementation. Chaque phase doit etre terminee et validee avant de passer a la suivante.
> Date : 2026-03-14

---

## Phase 0 : Cleanup Dead Code

**Objectif** : Supprimer TOUT le code mort des systemes supprimes. Zero reference residuelle.

### Fichiers a nettoyer

| Fichier | Dead Code | Action |
|---------|-----------|--------|
| `scripts/merlin/merlin_constants.gd` | ELEMENTS (14), ESSENCE_DROP_*, ESSENCE_ANCHOR_CARDS, ESSENCE_BASE_REWARDS, ESSENCE_VICTORY_BONUS, ESSENCE_CHUTE_BONUS, ESSENCE_MINIGAME_BONUS, ESSENCE_OGHAM_BONUS, ESSENCE_FACTION_BONUS, FLUX_*, RUN_TYPOLOGIES, DC_BASE, DC_DIFFICULTY_LABELS, ARCHETYPE_DC_BONUS, BOND_TIERS, OGHAM_STARTER_SKILLS, CardOption enum (left/center/right), FLUX_CHOICE_DELTA | Supprimer |
| `scripts/merlin/merlin_store.gd` | meta state keys: essence{14}, ogham_fragments, liens, gloire_points, bestiole_evolution | Supprimer |
| `scripts/merlin/merlin_card_system.gd` | GAUGES const, gauge init in init_run(), gauge checks in check_run_end(), _get_critical_gauges(), gauge effects in _apply_card_effects(), bestiole context block, _get_bestiole_modifier() | Supprimer |
| `scripts/ui/merlin_game_controller.gd` | souffle signal connections/DC bonus/regen, _update_flux() + refs, triade_aspects tutorial triggers + context, awen signal + refs, bond modifier + refs, bestiole wheel UI/evolution | Supprimer |
| `scripts/merlin/merlin_effect_engine.gd` | ADD_GAUGE, REMOVE_GAUGE, SET_GAUGE, souffle refs | Supprimer, remplacer par HEAL_LIFE/DAMAGE_LIFE |
| `scripts/merlin/merlin_llm_adapter.gd` | TRIADE_LLM_PARAMS, TRIADE_GRAMMAR_PATH | Supprimer/Renommer |
| `scripts/merlin/merlin_biome_system.gd` | aspect_bias (Corps/Ame/Monde) | Remplacer par faction_bias |

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

### 1A. Oghams (18)

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
    # ... 7 autres
}

const MATURITY_WEIGHTS: Dictionary = {
    "total_runs": 2, "fins_vues": 5, "oghams_debloques": 3, "max_faction_rep": 1
}
```

### 1C. Effet caps et formules

```gdscript
const EFFECT_CAPS: Dictionary = {
    "ADD_REPUTATION": {"max": 20, "min": -20},
    "HEAL_LIFE": {"max": 18},
    "DAMAGE_LIFE": {"max": 15},
    "ADD_BIOME_CURRENCY": {"max": 10},
    "UNLOCK_OGHAM": {"max_per_card": 1},
    "effects_per_option": 3,
    "score_bonus_cap": 2.0
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

Reprendre les 34 noeuds du plan existant (`purring-chasing-cloud.md`) mais avec les corrections v2.4 :
- Ogham starters dans branche centrale tier 0
- 15 Oghams repartis par branche (voir bible section 5.1)
- Bonus passifs : ~15-19 noeuds
- Couts en Anam uniquement

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

### Acceptance Criteria
- [ ] Profil unique fonctionnel (save/load/reset)
- [ ] run_state sauvegarde et restaure correctement
- [ ] Migration 0.4.0 → 1.0.0 sans perte de donnees
- [ ] Structure JSON conforme a la bible 13.4
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

### Ogham effects (18 types)
Chaque Ogham a une fonction dediee dans l'effect engine. Les Oghams de protection (luis, gort, eadhadh) interviennent a l'etape 8 du pipeline.

### Acceptance Criteria
- [ ] Pipeline 12 etapes conforme a la bible 13.3
- [ ] Tous les caps enforces (bible 6.5 caps table)
- [ ] Multiplicateur direct conforme (5 tranches)
- [ ] 18 Oghams implementes avec effets exacts
- [ ] Protection luis/gort/eadhadh fonctionnelle a l'etape 8
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

### Acceptance Criteria
- [ ] Anam calcule conforme aux formules bible 13.5
- [ ] Talent tree unlock avec Anam, prerequis verifies
- [ ] Score maturite calcule correctement
- [ ] Confiance Merlin clamp(0, 100), tiers corrects
- [ ] Periodes in-game fonctionnelles (1 periode = 5 cartes)
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
- Toujours 3 options par carte (code valide APRES generation LLM)
- Verbes neutres → champ esprit
- Max 2 promesses actives (guardrail MOS)
- FastRoute : selection par tags (biome, faction, field, trust_tier)
- Oghams narratifs (nuin, huath, ioho) : appel LLM ou FastRoute pour regenerer

### Acceptance Criteria
- [ ] 3 options toujours (validation post-LLM)
- [ ] Detection champ lexical fonctionnelle (45 verbes → 8+1 champs)
- [ ] Minigame mapping conforme
- [ ] Merlin Direct sans minigame, effets x1.0
- [ ] Promesses avec countdown, max 2, resolution
- [ ] FastRoute fallback fonctionnel
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

### Acceptance Criteria
- [ ] Personnage avance sur rail automatiquement
- [ ] Collectibles apparaissent (3-5s, +1-2 monnaie, fenetre 1.5s)
- [ ] Fondus fonctionnels (3D → carte → minigame → 3D)
- [ ] Inputs desactives pendant fondus
- [ ] MOS convergence : soft min/max/hard max respectes
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

### Guardrails
- Total effet < 50 par carte
- 90% des cartes ont des tradeoffs
- Pas de mort instantanee
- Pas de mots modernes / meta-references
- Max 2 promesses actives
- Cross-faction 10% des cartes max

### Acceptance Criteria
- [ ] Multi-brain fonctionnel (time-sharing ou parallele selon profil)
- [ ] FastRoute vs LLM routing
- [ ] Guardrails enforces
- [ ] Pacing (mercy apres 3 morts, recovery si vie <20)
- [ ] Confiance T0-T3 affecte le contenu genere
- [ ] Arcs narratifs inseres organiquement
- [ ] Commit : `feat(mos): orchestrator, guardrails, pacing, trust tiers`

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
