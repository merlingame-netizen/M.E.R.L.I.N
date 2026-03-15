# Fallback Pool System — Architecture Complete

**Date de mise a jour**: 2026-03-15
**Statut**: Architecture de production
**Scope**: Pre-authored card pools pour robustesse LLM
**Dependances**: `MerlinCardSystem`, `MerlinLlmAdapter`, `MerlinEffectEngine`

---

## Vue d'ensemble

Le **Fallback Pool** est l'epine dorsale de la robustesse narrative de Merlin. Il fournit des cartes pre-ecrites, contextuellement pertinentes, quand :
- L'LLM est indisponible ou timeout (Ollama down, network error)
- L'LLM retourne une carte invalide (JSON corrompu, options manquantes)
- Le joueur a epuise les cartes LLM dans une run (limite soft ~50 cartes)

### Garantie fondamentale

**Merlin ne sera JAMAIS silencieux.** Une carte valide est *toujours* retournee — soit du pool LLM, soit du Fallback Pool, soit une carte d'urgence generee dynamiquement.

### Composants principaux

| Composant | Role |
|-----------|------|
| `MerlinFallbackPool` | Classe gestionnaire (addons/merlin_ai/generators/fallback_pool.gd) |
| `fallback_cards.json` | Donnees non utilisees (reserve legacy) |
| **FastRoute Pool** | 500+ cartes pre-ecrites + variants par tier confiance |
| **MerlinDirect Cards** | Aparitions de Merlin, counsel, revelations (4 variants T0-T3) |
| **NPC Encounter Pool** | Rencontres pre-ecrites (5 archeypes) |
| **Emergency Generator** | Generateur ultra-fallback (carte minimale valide) |

---

## 1. Architecture Pool

### 1.1 Organisation logique

```
MerlinFallbackPool
├── Pool organises par contexte (cards_by_context)
│   ├── early_game          → Cartes pour 1-30 cartes jouees
│   ├── mid_game            → Cartes pour 31-70 cartes jouees
│   ├── late_game           → Cartes pour 71+ cartes jouees
│   ├── crisis_low          → Jauges < 15 (urgence)
│   ├── crisis_high         → Jauges > 85 (calme requis)
│   ├── recovery            → Reequilibrage (factions extremes)
│   ├── universal           → Toujours valides (3 generiques)
│   ├── merlin_direct       → Merlin dialogue (no minigame)
│   ├── promise             → Cartes promesses (legacy, non utilise)
│   └── npc_encounter       → PNJ dialogue (5 archeypes)
│
├── Tracking runtime
│   ├── recently_used        → Deduplication (20 cartes max)
│   └── _rng                 → RandomNumberGenerator (seeded)
│
└── Fichier donnees
    └── res://data/ai/fallback_cards.json (non utilise actuellement)
```

### 1.2 Structure carte Fallback

Chaque carte fallback adhère au schema `MerlinCard` standard :

```gdscript
{
    "id": String,                       # Identifiant unique
    "text": String,                     # Corps de la carte
    "type": String,                     # "narrative" | "merlin_direct" | "npc_encounter"
    "options": Array[Dictionary],       # Exactement 3 options
    "tags": Array[String],              # Classification (optionnel)
    "conditions": {                     # Filtrage contextuel (optionnel)
        "min_card": int,                # N cartes jouees minimum
        "max_card": int,                # N cartes jouees maximum
        "requires_tags": Array[String]  # Tags actifs requis
    },
    "biome": String,                    # Optionnel : zone thematique
    "priority": String,                 # "high" | "normal" (defaut)
    "speaker": String,                  # Optionnel : NPC ou "MERLIN"
    "trust_tier_min": String            # T0|T1|T2|T3 (merlin_direct uniquement)
}
```

### 1.3 Structure option

```gdscript
{
    "label": String,                    # Texte du choix
    "direction": String,                # "left" | "center" | "right" (pose d'UI)
    "verb": String,                     # Verbe d'action explicite (optionnel)
    "effects": Array[Dictionary],       # Effets mecaniques
    "preview": String                   # Label court pour HUD (optionnel)
}
```

**Exemple complet** (from fastroute_cards.json) :

```json
{
    "id": "fr_broceliande_001",
    "text": "Un sentier se divise en trois devant un chene noueux. Des murmures viennent de chaque direction.",
    "biome": "foret_broceliande",
    "type": "narrative",
    "options": [
        {
            "label": "Observer les traces au sol",
            "verb": "observer",
            "direction": "left",
            "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}],
            "preview": "+Druides"
        },
        {
            "label": "Ecouter les murmures",
            "verb": "ecouter",
            "direction": "center",
            "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 5}],
            "preview": "+Anciens"
        },
        {
            "label": "Avancer au hasard",
            "verb": "tenter sa chance",
            "direction": "right",
            "effects": [{"type": "HEAL_LIFE", "amount": 3}],
            "preview": "Vie"
        }
    ],
    "tags": ["foret", "exploration"]
}
```

---

## 2. FastRoute Pool — 500+ cartes pré-écrites

### 2.1 Definition et scope

Le **FastRoute Pool** est le systeme de cartes pre-ecrites permanentes, organise par **biome**. Il sert de fallback principal quand l'LLM ne peut pas generer.

**Volume**: 500+ cartes handwritten en francais celtique/breton.

**Stockage**: `data/ai/fastroute_cards.json` — structure bilingue

```json
{
    "narrative": [
        { id: "fr_broceliande_001", ... },
        { id: "fr_broceliande_002", ... },
        ...
        { id: "fr_generic_001", ... }  // Biome vide = generique
    ],
    "merlin_direct": [
        { id: "md_conseil_001", trust_tier_min: "T0", ... },
        { id: "md_secret_001", trust_tier_min: "T1", ... },
        ...
    ]
}
```

### 2.2 Schema biome

8 biomes celtiques, each avec 20-50 cartes thematiques :

| Biome | Clé JSON | Exemple | Archeotypes |
|-------|----------|---------|------------|
| Forêt de Brocéliande | `foret_broceliande` | Sentiers, animaux, druides | Observation, meditation, danger |
| Landes de Bruyère | `landes_bruyere` | Cairns, vent, survie | Resistance, abri, courage |
| Côtes Sauvages | `cotes_sauvages` | Grottes, falaises, vagues | Exploration, escalade, mystere |
| Villages Celtes | `villages_celtes` | Conteurs, foyers, communaute | Social, tradition, partage |
| Cercles de Pierres | `cercles_pierres` | Menhirs, spirales, rituels | Magie, meditation, ancetres |
| Marais des Korrigans | `marais_korrigans` | Bulles, rire, danger liquide | Negotiation, ruse, tresor |
| Collines des Dolmens | `collines_dolmens` | Tombes, os, passage | Respect, analyse, sacrifice |
| Îles Mystiques | `iles_mystiques` | Brumes, coquillages, eau | Decodage, collection, mort |

### 2.3 Selection algorithm

Algorithme `get_fastroute_card(context: Dictionary)` :

```gdscript
func get_fastroute_card(context: Dictionary) -> Dictionary:
    # 1. Segmenter par biome
    var biome = context.get("biome", "")
    var candidates = []
    var generic = []

    for card in _fastroute_narrative_pool:
        if card.id in _fastroute_seen:
            continue  # Deduplication

        if card.biome == biome:
            candidates.append(card)  # Priorite biome-specific
        elif card.biome.is_empty():
            generic.append(card)     # Fallback generique

    # 2. Escalade
    if candidates.is_empty():
        candidates = generic
    if candidates.is_empty():
        _fastroute_seen.clear()  # Reset recent si epuise
        candidates = _fastroute_narrative_pool.duplicate()
    if candidates.is_empty():
        return _get_emergency_card()

    # 3. Selection aleatoire + tracking
    var selected = candidates[_rng.randi_range(0, candidates.size() - 1)]
    _fastroute_seen.append(selected.id)

    # 4. Annotation (verb → field → minigame)
    _annotate_fields(selected)

    return _ensure_3_options(selected)
```

### 2.4 Deduplication

**Limite recent**: 20 cartes par run.

Quand `_fastroute_seen` accumule 20 cartes :
- Prochaine carte force reset du tracking
- Permet de revoir une carte apres 20 autres
- Previent repetition frustrante

---

## 3. MerlinDirect — Aparitions de Merlin

### 3.1 Definition

Les cartes **MerlinDirect** sont des aparitions speciales de Merlin (le mage guide). Elles ont des caracteristiques uniques :
- **No minigame** : les effets s'appliquent directement (multiplicateur ×1.0)
- **Multiplier 1.0** : Pas de bonus/malus du minigame
- **Skip minigame** : Pipeline passe directement aux effets
- **Trust tier gated** : Accessible seulement si confiance Merlin ≥ seuil

### 3.2 Trust Tiers (T0-T3)

La **confiance Merlin** evolue au cours du jeu (0-100, clampe a 100). Elle se divise en 4 tiers, chacun debloquant des cartes MerlinDirect progressivement plus revelantes :

```gdscript
static func _trust_tier_to_index(tier: String) -> int:
    match tier:
        "T0": return 0  # Confiance initiale (0-25?)
        "T1": return 1  # Confiance croissante (25-50?)
        "T2": return 2  # Confiance haute (50-75?)
        "T3": return 3  # Confiance maximum (75-100)
    return 0
```

### 3.3 Pool MerlinDirect

4 variantes (from fastroute_cards.json ["merlin_direct"]) :

| ID | Texte | Tier | Theme |
|----|-------|------|-------|
| `md_conseil_001` | "Ecoute, jeune druide..." | T0 | Conseil basique |
| `md_secret_001` | "J'ai vu quelque chose dans les etoiles..." | T1 | Revelation confidentielle |
| `md_warning_001` | "Attention! Un danger approche..." | T0 | Avertissement urgent |
| `md_gift_001` | "Un cadeau. Utilise-le sagement." | T2 | Don magique |

### 3.4 Selection logic

```gdscript
func _generate_merlin_direct_card(context: Dictionary) -> Dictionary:
    if _fastroute_merlin_pool.is_empty():
        return {}

    var trust_tier = context.get("trust_tier", "T0")
    var tier_index = _trust_tier_to_index(trust_tier)

    # Filtrer par tier minimum
    var candidates = []
    for card in _fastroute_merlin_pool:
        var required_tier = card.get("trust_tier_min", "T0")
        if _trust_tier_to_index(required_tier) <= tier_index:
            candidates.append(card)

    if candidates.is_empty():
        return {}

    var selected = candidates[_rng.randi_range(0, candidates.size() - 1)]
    selected["type"] = "merlin_direct"
    return selected
```

### 3.5 Pipeline special pour MerlinDirect

Dans `MerlinCardSystem.handle_merlin_direct()` :

```gdscript
func handle_merlin_direct(card: Dictionary, chosen_option_index: int) -> Dictionary:
    var option = card.options[chosen_option_index]
    var effects = option.get("effects", [])
    return {
        "ok": true,
        "effects": effects,
        "multiplier": 1.0,
        "skip_minigame": true  # CRUCIAL : pas de minigame overlay
    }
```

**Consequence** : Aucun minigame ne s'affiche. Les effets MerlinDirect sont **directs et non-modifiables** (multiplicateur verrouille a 1.0).

---

## 4. NPC Encounter Pool

### 4.1 Definition

Les cartes **NPC Encounter** representent des rencontres avec des personnages secondaires. Elles sont :
- Type `npc_encounter`
- Presentes en pool dedié
- Selectionnees via `get_npc_card()`
- Incluses au besoin narratif (cartes promise, arcs)

### 4.2 Archeotypes NPC

5 templates de personnages (from fallback_pool.gd) :

```
1. Druide Ancien
   "Un vieux druide emerge de la brume..."
   → Dons de reputation druides

2. Villageoise
   "Une villageoise t'interpelle..."
   → Reputation anciens, + danger

3. Barde Errant
   "Un barde assis pres du feu gratte sa lyre..."
   → Storytelling, reputation variee

4. Guerrier du Gue
   "Un guerrier balafre bloque le passage..."
   → Combat/ruse, reputation anciens

5. Marchand des Ombres
   "Un marchand itinerant etale ses curiosites..."
   → Trading, reputation ankou
```

### 4.3 Selection logic

```gdscript
func get_npc_card() -> Dictionary:
    var pool = cards_by_context.get("npc_encounter", [])
    if pool.is_empty():
        return {}

    # Deduplication
    var filtered = pool.filter(func(c): return c.id not in recently_used)
    if filtered.is_empty():
        filtered = pool

    var selected = filtered[_rng.randi() % filtered.size()]
    recently_used.append(selected.id)
    if recently_used.size() > RECENT_LIMIT:
        recently_used.pop_front()

    return selected
```

---

## 5. Emergency Card Generator

### 5.1 Dernier recours

Quand **absolument tout a echoue** (tous les pools epuises, contexte invalide), une carte minimale est generee dynamiquement par `_generate_emergency_card(context)` :

```gdscript
func _generate_emergency_card(context: Dictionary) -> Dictionary:
    # Identifier la faction PIRE (reputation minimale)
    var worst_faction = "druides"
    var worst_val = 50.0
    for faction in context.get("factions", {}):
        var val = context.factions[faction]
        if val < worst_val:
            worst_val = val
            worst_faction = faction

    # Offrir une carte de reconciliation
    return {
        "id": "emergency_%d" % Time.get_ticks_msec(),
        "text": "Un moment de calme dans la tempete...",
        "type": "narrative",
        "options": [
            {
                "label": "Tendre la main",
                "effects": [{"type": "ADD_REPUTATION", "faction": worst_faction, "amount": 10}]
            },
            {
                "label": "Mediter sur les oghams",
                "effects": [{"type": "ADD_REPUTATION", "faction": worst_faction, "amount": 5}]
            },
            {
                "label": "Continuer sans s'arreter",
                "effects": []
            }
        ],
        "tags": ["recovery", "emergency"],
        "_generated": true
    }
```

**Propriete specifique**: `_generated: true` marque les cartes d'urgence (pour debug).

---

## 6. Integration avec MerlinCardSystem

### 6.1 Pipeline generation (Phase 5)

```
generate_card(context)
├─ Pick card type (event/promise/merlin_direct/narrative)
│
├─ [event] → _generate_event_card()
├─ [promise] → _generate_promise_card()
├─ [merlin_direct] → _generate_merlin_direct_card()
│
└─ [narrative] (LLM first, FastRoute fallback)
   ├─ LLM available? → await _llm.generate_card(llm_context)
   │  ├─ Valid card → Return
   │  └─ Invalid/timeout → FALLBACK
   │
   └─ LLM unavailable → get_fastroute_card(context)
      ├─ Candidates by biome
      ├─ Weighted random
      ├─ Deduplication
      └─ Return annotated card
```

### 6.2 Appel du Fallback Pool

Dans `MerlinCardSystem` (merlin_card_system.gd, line 136) :

```gdscript
# Narrative: try LLM first
if _llm != null:
    var llm_context = _build_llm_context(context)
    var llm_result = await _llm.generate_card(llm_context)
    if llm_result.get("ok", false):
        var card = llm_result.get("card", {})
        var validated = _validate_card(card)
        if validated.get("valid", false):
            # ... return validated card
            return final_card

# FastRoute fallback (THIS IS THE CRITICAL LINE)
return get_fastroute_card(context)
```

### 6.3 Chargement du pool

Au demarrage (`MerlinCardSystem.setup()`) :

```gdscript
func setup(effects: MerlinEffectEngine, llm: MerlinLlmAdapter, rng: MerlinRng) -> void:
    _effects = effects
    _llm = llm
    _rng = rng
    _load_event_cards()
    _load_promise_cards()
    _load_fastroute_cards()  # ← Charge le pool FastRoute
    _event_selector = EventCategorySelector.new()
```

`_load_fastroute_cards()` charge depuis `fastroute_cards.json` dans les arrays internes.

---

## 7. API Publique

### 7.1 MerlinFallbackPool

**Initialisation** :

```gdscript
# Automatique lors de la creation
var pool = MerlinFallbackPool.new()
# → Charge les cartes depuis res://data/ai/fallback_cards.json si elle existe
# → Sinon genere un set de cartes par defaut
```

**Retrieval** :

```gdscript
# Obtenir une carte fallback contextualisee
func get_fallback_card(context: Dictionary) -> Dictionary

# Exemple d'appel
var context = {
    "cards_played": 5,
    "gauges": {"health": 50},
    "factions": {"druides": 30, "anciens": 50, "korrigans": 20, "niamh": 10, "ankou": 5},
    "active_tags": [],
    "narrative": {
        "world_state": {"biome": "foret_broceliande"},
        "active_arcs": []
    },
    "_hidden": {
        "theme_weights": {"foret": 0.5, "magic": 1.5}
    }
}
var card = pool.get_fallback_card(context)
```

**NPC Cards** :

```gdscript
# Obtenir une carte PNJ
func get_npc_card() -> Dictionary

# Exemple
var npc = pool.get_npc_card()
# → Retourne une des 5 cartes archetype NPC
```

**Management** :

```gdscript
# Ajouter une carte custom a un pool
func add_card(context: String, card: Dictionary) -> bool

# Exemple
var custom_card = {
    "id": "custom_001",
    "text": "...",
    "options": [...]
}
pool.add_card("universal", custom_card)

# Sauvegarder les modifications en JSON
func save_cards_to_file() -> void

# Obtenir les stats des pools
func get_pool_sizes() -> Dictionary
# → { "early_game": 3, "mid_game": 1, ..., "universal": 3, ... }
```

### 7.2 MerlinCardSystem (FastRoute specifique)

```gdscript
# Obtenir une carte FastRoute
func get_fastroute_card(context: Dictionary) -> Dictionary

# Exemples d'appel (voir section 5.3 du GAME_DESIGN_BIBLE)
var context = {
    "biome": "foret_broceliande",
    "cards_played": 15
}
var card = card_system.get_fastroute_card(context)
# → Retourne une carte du biome "foret_broceliande" ou generic

# Generate merlin direct
func _generate_merlin_direct_card(context: Dictionary) -> Dictionary
# (Interne, utilisee par generate_card())

# Annoter les champs lexicaux d'une carte
func _annotate_fields(card: Dictionary) -> void
# → Ajoute "field" et "minigame" a chaque option
```

---

## 8. Data Flow — Exemple complet

### Scenario : LLM unavailable, FastRoute fallback

```
1. run_state = {
    biome: "foret_broceliande",
    cards_played: 12,
    factions: { druides: 45, anciens: 30, korrigans: 20, niamh: 50, ankou: 10 },
    ...
}

2. merlin_game_controller calls:
   card = await card_system.generate_card(run_state)

3. Inside generate_card():
   - card_type = "narrative" (picked by _pick_card_type)
   - LLM is unavailable (timeout)
   - FALLBACK: return get_fastroute_card(run_state)

4. Inside get_fastroute_card():
   - biome = "foret_broceliande"
   - candidates = [fr_broceliande_001, fr_broceliande_002, ...]
   - selected = fr_broceliande_001 (random)
   - _fastroute_seen.append("fr_broceliande_001")
   - Annotate fields (observer → observe field)
   - Return card with 3 options + field + minigame

5. Back in merlin_game_controller:
   - Display card to player
   - Player chooses option
   - Minigame plays (field-based)
   - Effects apply
   - Next card generated
```

---

## 9. Contexte complet pour selection

Les methodes `get_fallback_card()` et `get_fastroute_card()` acceptent un dictionnaire de contexte riche :

```gdscript
context = {
    # Progression
    "cards_played": int,                    # Nombre de cartes jouees ce run
    "cards_seen": Array[String],            # IDs vues cette run

    # Etat
    "gauges": {
        "health": float,
        "mana": float,
        "tension": float
    },
    "factions": {
        "druides": float,
        "anciens": float,
        "korrigans": float,
        "niamh": float,
        "ankou": float
    },

    # Narratif
    "biome": String,
    "active_ogham": String,
    "narrative": {
        "world_state": {
            "biome": String
        },
        "active_arcs": Array[String]
    },

    # Tags actifs
    "active_tags": Array[String],

    # Hidden (for weighted selection)
    "_hidden": {
        "theme_weights": {
            "foret": float,
            "magic": float,
            ...
        }
    },

    # Trust Merlin
    "trust_tier": String                    # T0|T1|T2|T3
}
```

---

## 10. Robustesse et escalade

### 10.1 Priorite d'escalade

```
1. LLM (if available)
   ├─ Valid response
   │  └─ Return immediately
   └─ Invalid/timeout
      └─ FALLBACK

2. FastRoute (by biome)
   ├─ Candidates in biome
   │  └─ Return random
   └─ No biome matches
      └─ Use generic (biome="")

3. Generic FastRoute
   ├─ Candidates available
   │  └─ Return random
   └─ All seen recently
      └─ FALLBACK

4. Recently_used reset
   ├─ Clear dedup tracker
   └─ Retry FastRoute pool

5. Universal pool
   ├─ Always valid
   └─ Return random

6. Emergency generator
   └─ Last resort: dynamic card
```

### 10.2 Conditions de "epuisement"

Un pool est considere **epuise** quand :
- Toutes ses cartes sont dans `recently_used` (dedup limit)
- Aucune carte ne correspond aux criteres contextuels

**Action**: Reset `recently_used`, recharger le pool.

### 10.3 Emergency card semantics

L'emergency card genere dynamiquement :
- Texte **vague mais valide** ("Un moment de calme dans la tempete...")
- 3 options toujours **valides** (jamais crashantes)
- Toujours orientee vers **reconciliation** (+rep faction pire)
- Marque interne avec `_generated: true`
- ID unique par timestamp (`emergency_<ticks_msec>`)

**Jamais affiché au joueur comme "emergency"** — apparait comme une vraie carte.

---

## 11. Performance et optimisations

### 11.1 Chargement lazy

Les cartes FastRoute sont chargees une seule fois au boot du CardSystem :

```gdscript
func _load_fastroute_cards() -> void:
    var file = FileAccess.open(FASTROUTE_PATH, FileAccess.READ)
    var data = JSON.parse_string(file.get_as_text())
    _fastroute_narrative_pool = data.get("narrative", [])
    _fastroute_merlin_pool = data.get("merlin_direct", [])
```

**Cache**: Arrays restent en memoire toute la session (150+ Ko pour 500 cartes).

### 11.2 Deduplication efficace

`recently_used: Array[String]` — contient seulement les IDs, pas les cartes.

```gdscript
if card.id in recently_used:
    continue  # O(n) iteration, acceptable pour n=20
```

**Limite**: 20 cartes par run = pas d'impact perf.

### 11.3 Weighted selection

Poids appliques a la selection :

```gdscript
var weight = 1.0
weight *= theme_weights.get(tag, 1.0)     # Fatigue theme
if card.biome == biome:
    weight *= 1.5                         # Bonus biome
if card.arc_id in active_arcs:
    weight *= 2.0                         # Bonus resolution d'arc
if card.priority == "high":
    weight *= 2.0                         # Boost priorite
```

**Weighted random**: O(n) scan + cumulative sum (acceptable).

---

## 12. Limitations et améliorations futures

### 12.1 Limitation actuelles

| Limitation | Raison | Impact |
|----------|--------|--------|
| Pool statique (~500 cartes) | Handwritten, maintenance manuelle | Peut devenir repetitif apres 100+ runs |
| No per-biome LLM variants | Architecture monolithique | All FastRoute generic across tiers |
| No promise-specific fallback | Promise pool empty/legacy | Promesses generees LLM seulement |
| No dynamic arc integration | Cartes handwritten, fixed | Arcs narratifs requires LLM |
| Merlin direct limited (4 variants) | Trust tier cost | T2-T3 cards rares |

### 12.2 Améliorations proposees

1. **Expand FastRoute Pool** → 1000+ cartes par biome, per-tier variants
2. **Dynamic reweighting** → Apprendre les preferences joueur au cours de la session
3. **Promise FastRoute** → 50+ cartes promesse handwritten, variants
4. **Arc integration** → Cartes marquees avec arc_id, bonus poids si arc actif
5. **LLM-assisted authoring** → CLI pour generer des cartes FastRoute via LLM, editer, valider
6. **A/B testing UI** → Overlay "was this card interesting?" apres chaque choix

---

## 13. Checklist developpeur

Quand vous modifiez le Fallback Pool :

- [ ] Les cartes handwritten incluent **exactement 3 options**
- [ ] Chaque option a un `effects` array (peut etre vide `[]`)
- [ ] Les IDs sont **uniques** dans le pool (ex: `fr_biome_NNN`)
- [ ] Tags sont **lowercase** et significatifs
- [ ] `verb` est present ou `label` est intelligible pour detection field
- [ ] Conditions contextuelles sont logiques (`min_card <= max_card`)
- [ ] MerlinDirect cards ont `trust_tier_min` valide (T0-T3)
- [ ] NPC cards ont `speaker` field
- [ ] Biome est soit valide, soit vide `""` (never typo)
- [ ] JSON valide (test avec `jq . fastroute_cards.json`)
- [ ] Carte teste dans Godot (au moins 1 run complet)
- [ ] Pas de hardcoded nombres > 20 (effects capes)

---

## 14. Refrences

- **Game Design Bible** : `docs/GAME_DESIGN_BIBLE.md` (sections 2.1 Cartes, 5 Pipeline Effets)
- **CardSystem API** : `scripts/merlin/merlin_card_system.gd` (lines 99-173)
- **FallbackPool Code** : `addons/merlin_ai/generators/fallback_pool.gd`
- **FastRoute Data** : `data/ai/fastroute_cards.json`
- **Effect Engine** : `scripts/merlin/merlin_effect_engine.gd`
- **LLM Adapter** : `scripts/merlin/merlin_llm_adapter.gd`

---

**Document cree par**: Claude Code
**Derniere revision**: 2026-03-15
**Prochaine revision**: A date de la prochaine extension du FastRoute Pool
