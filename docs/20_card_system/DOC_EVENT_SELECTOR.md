# Architecture — Event Category Selector (Phase 44)

**Fichier source**: `addons/merlin_ai/generators/event_category_selector.gd` (v2.0.0)
**Dernière mise à jour**: 2026-03-15
**Auteur**: MERLIN Game Design System
**Status**: Production

---

## 1. Vue d'ensemble

L'**Event Category Selector** est le composant responsable de la **sélection stochastique d'événements narratifs** au cours d'une run. Son rôle est triple:

1. **Catégorisation narrative** — Choisir une catégorie d'événement (Rencontre, Dilemme, Découverte, Conflit, Merveille, Catastrophe, Épreuve, Commerce, Repos) basée sur l'état du jeu
2. **Discrimination contextuelle** — Raffiner la catégorie en sélectionnant un sous-type spécifique (ex: "voyageur" vs "créature" pour Rencontre) selon des triggers d'état
3. **Modulation de probabilités** — Appliquer un système pénalisant la répétition et rewarding la diversité narrative

Le système est **pondéré et dynamique**: le poids de chaque catégorie varie en fonction de:
- Nombre de cartes jouées (phase de la run: début/milieu/fin)
- Réputation des factions (équilibre vs déséquilibre)
- Vie essence et tension (pity system pour joueurs en difficulté)
- Historique récent (anti-répétition)

---

## 2. Catégories d'événements

L'Event Category Selector gère **9 catégories d'événements** définies dans `data/ai/config/event_categories.json`:

| Catégorie | Poids Base | Description | Intensité |
|-----------|-----------|-------------|-----------|
| **rencontre** | 0.30 | Croisement avec un être (marchands, créatures, autochtones, revenants, messagers) | low |
| **dilemme** | 0.20 | Situation morale sans bonne réponse; force des choix (sacrifice, loyauté, vérité, survie) | **high** |
| **decouverte** | 0.12 | Trouvaille (lieu caché, objet magique, savoir, passage) | medium |
| **conflit** | 0.08 | Tension qui explose (interpersonnel, faction, intérieur) | **high** |
| **merveille** | 0.08 | Phénomène magique ou inexpliqué (vision, manifestation, don, transformation) | medium |
| **catastrophe** | 0.05 | Crise qui frappe (naturelle, surnaturelle, humaine) | **very_high** |
| **epreuve** | 0.07 | Défi actif avec succès/échec clair (physique, mentale, rituelle, sociale) | **high** |
| **commerce** | 0.05 | Échange et négociation (troc, marché noir, pacte, offrande) | medium |
| **repos** | 0.05 | Moment de respiration narrative (halte, festin, rêve, méditation) | low |

**Total base**: 1.0 (normalisé)

### 2.1 Structure de chaque catégorie

Chaque catégorie dans `event_categories.json` possède:

```json
{
  "label": "Nom lisible",
  "description": "Desc texte",
  "base_weight": 0.XX,
  "sub_types": {
    "subtype_key": {
      "description": "...",
      "weight": 0.XX,
      "tags": ["tag1", "tag2"],
      "triggers": { /* conditions de boost */ }
    }
  },
  "narrator_guidance": "Guidance pour le LLM narrateur",
  "effect_profile": {
    "primary": "effet_primaire:param",
    "secondary": ["effets", "secondaires"],
    "intensity": "low|medium|high|very_high"
  }
}
```

Exemple complet: **Rencontre** (lines 9-64 de event_categories.json):

```json
"rencontre": {
  "base_weight": 0.30,
  "sub_types": {
    "voyageur": {
      "weight": 0.35,
      "tags": ["stranger", "merchant", "pelerins", "barde"],
      "triggers": {
        "biome": ["cotes_sauvages", "landes_bruyere", "villages_celtes"],
        "min_cards_played": 0
      }
    },
    "creature": {
      "weight": 0.22,
      "tags": ["korrigan", "corbeau", "cerf", "loup", "wisp", "sidhe"],
      "triggers": {
        "biome": ["foret_broceliande", "marais_korrigans"]
      }
    },
    // ... autres sous-types
  }
}
```

---

## 3. Sélection pondérée (Weighted Selection)

### 3.1 Pipeline de sélection (lignes 92-121)

La méthode publique `select_event(game_state: Dictionary) -> Dictionary` suit ce pipeline:

```
1. COMPUTE WEIGHTS
   ├─ Base weights (from categories config)
   ├─ Frequency matrix multipliers (run phase, game state)
   └─ Pity system overrides (life emergency)

2. APPLY ANTI-REPETITION
   ├─ Penalty for recently used categories
   └─ Penalty for consecutive uses

3. NORMALIZE & WEIGHTED SELECT
   └─ Stochastic selection by accumulated weight

4. SELECT SUB-TYPE
   ├─ Evaluate triggers for each sub-type
   ├─ Apply anti-repetition to sub-types
   └─ Return selected sub-type

5. RETURN RESULT
   └─ { category, sub_type, label, narrator_guidance, effect_profile }
```

### 3.2 Calcul des poids (lignes 128-151)

La fonction `_compute_category_weights(run: Dictionary) -> Dictionary` combine trois sources de modification:

```gdscript
var weights: Dictionary = {}

# Step 1: Base weights
for cat_key in _categories:
    weights[cat_key] = float(_categories[cat_key].get("base_weight", 0.1))

# Step 2: Matrix multipliers (multiplicative)
var matrix_multipliers := _get_matrix_multipliers(run)
for cat_key in weights:
    if matrix_multipliers.has(cat_key):
        weights[cat_key] *= float(matrix_multipliers[cat_key])

# Step 3: Pity overrides (replace multiplied weight)
var pity_overrides := _get_pity_overrides(run)
for cat_key in pity_overrides:
    if weights.has(cat_key):
        weights[cat_key] = float(weights[cat_key]) * float(pity_overrides[cat_key])

return weights
```

**Formule**:
```
poids_final[catégorie] = base_weight × matrix_multiplier × pity_multiplier
```

Les poids ne sont **jamais normalisés** avant sélection — c'est la sélection pondérée qui gère l'arrondi.

---

## 4. Probabilités pilotées par l'état du jeu

### 4.1 Matrice de fréquence (Frequency Matrix)

Définie dans `event_categories.json:419-495`, la matrice applique des **multiplicateurs contextuels** selon la phase de la run et l'état du jeu.

**Phases temporelles** (basées sur `cards_played`):

| Phase | Cartes | État | Focus |
|-------|--------|------|-------|
| **debut_run** | 1-8 | Présentation du monde | ↑ Rencontre, Découverte, Repos |
| **milieu_run** | 9-20 | Montée en tension | ↑ Dilemme, Conflit, Épreuve |
| **fin_run** | 21+ | Résolution, enjeux maximaux | ↑ Dilemme, Conflit, Épreuve, Catastrophe |

**Exemple (lines 421-434)**:

```json
"debut_run": {
  "condition": {"cards_played_max": 8},
  "multipliers": {
    "rencontre": 1.30,      // +30% encouragé
    "dilemme": 0.60,        // -40% découragé
    "decouverte": 1.70,     // +70% fortement encouragé
    "conflit": 0.50,        // -50% découragé
    "catastrophe": 0.00     // IMPOSSIBILITÉ
  }
}
```

### 4.2 Conditions de matrice

Les conditions supportées dans `_check_matrix_condition()` (lignes 181-214):

| Condition | Type | Sémantique |
|-----------|------|-----------|
| `cards_played_max` | int | Nombre max cartes jouées |
| `cards_played_min` | int | Nombre min cartes jouées |
| `all_aspects: "EQUILIBRE"` | string | Toutes les factions équilibrées (delta < 5) |
| `any_aspect: ["BAS", "HAUT"]` | array[string] | Au moins une faction en état extrême |

### 4.3 Système de Pity (Pity System)

Le système de **grâce** s'active quand le joueur est en difficulté ou trop dominant.

**Conditions et overrides** (lines 497-525 de event_categories.json):

**recovery_boost** (quand `life < 25`):
- ↑ merveille × 2.50 (encouragé)
- ↑ decouverte × 1.50
- ↓ catastrophe × 0.10 (quasi-interdit)
- ↓ conflit × 0.30
- ↑ repos × 2.50 (fortement encouragé)

**challenge_boost** (quand `life > 80`):
- ↑ conflit × 2.00
- ↑ dilemme × 1.50
- ↑ epreuve × 2.00 (fortement encouragé)
- ↓ repos × 0.20 (presque interdit)

La fonction `_get_pity_overrides()` (lignes 217-254) **remplace** les poids multipliés pour les catégories concernées.

### 4.4 Sélection stochastique

La fonction `_weighted_select(weights: Dictionary) -> String` (lignes 604-619) implémente la sélection par roulette biaisée:

```gdscript
func _weighted_select(weights: Dictionary) -> String:
    var total: float = 0.0
    for w in weights.values():
        total += float(w)

    if total <= 0.0:
        return weights.keys()[0] if not weights.is_empty() else ""

    var roll: float = randf() * total
    var cumulative: float = 0.0
    for key in weights:
        cumulative += float(weights[key])
        if roll < cumulative:
            return key

    return weights.keys()[-1] if not weights.is_empty() else ""
```

**Algorithme**: Accumule les poids cumulatifs jusqu'à dépasser un random [0, total[.

---

## 5. Sélection de sous-types et Triggers

### 5.1 Triggers — Conditions contextuelles

La fonction `_select_sub_type()` (lignes 261-302) évalue des **conditions de trigger** pour amplifier les poids de sous-types.

Chaque sous-type peut déclarer des triggers dans `sub_types[].triggers`:

```json
"creature": {
  "weight": 0.22,
  "triggers": {
    "biome": ["foret_broceliande", "marais_korrigans"]
  }
}
```

### 5.2 Fonctions de trigger (lignes 305-387)

La fonction `_evaluate_triggers()` évalue tous les triggers et retourne un multiplicateur (bonus) appliqué au poids du sous-type.

**Triggers supportés et multiplicateurs**:

| Trigger | Condition | Matched | Unmatched | Notes |
|---------|-----------|---------|-----------|-------|
| `biome` | liste de biomes | ×2.0 | ×0.5 | Comparaison `in list` |
| `aspect_condition` | dict faction → states | ×1.5 | ×0.3 | Remplace `all_aspects`/`any_aspect` |
| `min_cards_played` | int | ✓ pass | ×0.0 (block) | Bloquery si non atteint |
| `flags_required` | array de flags | ✓ pass | ×0.1 | Pénalité si flags manquants |
| `tension_above` | int seuil | ×1.5 | ×0.5 | Comparaison `hidden.tension` |
| `life_below` | int seuil | ×1.5 | ×0.5 | Comparaison `life_essence` |
| `dominant_faction_above` | int seuil | ×1.5 | ×0.5 | Max reputation des factions > seuil |
| `karma_above` | int seuil | ×1.5 | ×0.5 | Comparaison `hidden.karma` |
| `season` | string | ×1.0 | N/A | Placeholder — toujours neutre |

**Exemple** (lines 18-21 de event_categories.json):

```json
"voyageur": {
  "weight": 0.35,
  "triggers": {
    "biome": ["cotes_sauvages", "landes_bruyere", "villages_celtes"],
    "min_cards_played": 0
  }
}
```

Si le joueur est dans "foret_broceliande" (biome non listé), le bonus = 0.5 → poids_final = 0.35 × 0.5 = 0.175.

---

## 6. Anti-répétition

### 6.1 Historique et fenêtres

L'historique est stocké dans `_history: Array[Dictionary]` (lines 35-36):

```gdscript
var _history: Array[Dictionary] = []
// Chaque entrée: { category: String, sub_type: String, card_num: int }
```

La fenêtre d'historique est configurée dans event_categories.json (line 531):
```json
"history_window": 10
```

La méthode `record_selection()` (lignes 584-589) ajoute une entrée et tranche l'historique à la fenêtre.

### 6.2 Pénalités

La fonction `_apply_anti_repetition()` (lignes 394-411) applique deux niveaux de pénalité:

**1. Gap penalty** — Si catégorie récemment utilisée:
```gdscript
var min_gap: int = int(_anti_repetition.get("min_gap_same_category", 2))
if gap >= 0 and gap < min_gap:
    result[cat_key] *= 0.1  // -90% pénalité
```

Configuré dans event_categories.json (line 528):
```json
"min_gap_same_category": 2
```

Signification: Si la catégorie a été utilisée dans les 2 dernières cartes, réduire son poids de 90%.

**2. Consecutive penalty** — Si catégorie utilisée trop souvent d'affilée:
```gdscript
var max_consecutive: int = int(_anti_repetition.get("max_consecutive_same_category", 2))
if consecutive >= max_consecutive:
    result[cat_key] *= 0.05  // -95% pénalité
```

Configuration (line 530):
```json
"max_consecutive_same_category": 2
```

Signification: Si la catégorie a été utilisée 2 fois consécutives, réduire son poids de 95%.

### 6.3 Anti-répétition des sous-types

Dans `_select_sub_type()` (lignes 289-293):

```gdscript
var gap := _cards_since_last_subtype(sub_key)
var min_gap: int = int(_anti_repetition.get("min_gap_same_subtype", 4))
if gap >= 0 and gap < min_gap:
    weight *= 0.1  // -90% pénalité
```

Configuration (line 529):
```json
"min_gap_same_subtype": 4
```

Signification: Si le sous-type a été utilisé dans les 4 dernières cartes, réduire son poids de 90%.

---

## 7. Système de Modifiers (Phase Card-Typology)

Le système de **modifiers** permet de superposer des **overlays narratifs** sur une carte événement (ex: "Cet événement Rencontre est une **Tentation**").

### 7.1 Configuration

Les modifiers sont chargés depuis `data/ai/config/card_modifiers.json` dans `_load_modifiers()` (lignes 444-464).

Structure:
```json
{
  "modifiers": {
    "tentation": {
      "label": "Tentation",
      "prompt_injection": "L'option prudente est tentante mais perdante; l'option audacieuse est risquée mais gratifiante.",
      "category_exclusions": ["repos", "decouverte"],
      "probability": 0.08,
      "trigger": {
        "dominant_faction_above": 50
      },
      "effect_modifier": { /* modifie effect_profile */ },
      "minigame_pool": ["word_field_temptation"]
    }
  },
  "selection_rules": {
    "scenario_anchor_never_modified": true,
    "max_consecutive_modified": 2,
    "min_gap_same_modifier": 5
  }
}
```

### 7.2 Sélection de modifiers

La méthode publique `select_modifier(game_state: Dictionary, category: String) -> Dictionary` (lignes 467-526):

1. **Exclusions**: Skip si carte est anchor ou catégorie est dans `category_exclusions`
2. **Consecutive limit**: Skip si trop de cartes modifiées d'affilée
3. **Candidates**: Collecter tous les modifiers avec triggers valides
4. **Anti-repetition**: Skip si modifier utilisé récemment (< min_gap)
5. **Probabilistic roll**: Pour chaque candidat, roll aléatoire pour sélection

```gdscript
for c in candidates:
    if randf() < float(c["probability"]):
        return { "modifier": str(c["key"]), ... }
return {}
```

**Retour**: `{ modifier: String, label: String, prompt_injection: String, effect_modifier: Dict, minigame_pool: Array }`

### 7.3 Historique des modifiers

Analogue à l'historique des événements:

```gdscript
var _modifier_history: Array[String] = []
// Tracks recent modifier names for anti-repetition
```

Méthode `record_modifier(modifier_name: String)` (lignes 573-577) enregistre chaque sélection (ou "" si pas de modifier).

---

## 8. Configuration et constantes (Tuning)

Tous les paramètres de configuration sont externalisés dans JSON. Les principales tuning variables:

### 8.1 event_categories.json

**Base weights** (colonnes "base_weight"):
- Regissent la probabilité relative de chaque catégorie en l'absence de contexte
- Somme = 1.0

**Frequency matrix multipliers** (frequency_matrix.*.multipliers):
- Multiplicateurs par phase et état du jeu
- Valeur 1.0 = neutre, < 1 = découragé, > 1 = encouragé
- Combinaison multiplicative si plusieurs matrices matchent

**Pity overrides** (pity_system.*.overrides):
- **Ne remplacent pas**, mais **multiplient** le poids déjà ajusté
- Activation: life_below 25 ou life_above 80

**Anti-repetition thresholds** (anti_repetition.*):
```json
"min_gap_same_category": 2,           // Écart min entre utilisations
"min_gap_same_subtype": 4,            // Écart min pour sous-types
"max_consecutive_same_category": 2,   // Max utilisations consécutives
"history_window": 10                  // Fenêtre d'historique (cartes)
```

### 8.2 card_modifiers.json

**Modifier-level tuning**:
- `probability`: Probabilité base du modifier si triggers matchent
- `category_exclusions`: Catégories où ne s'applique jamais
- `trigger.*`: Conditions pour candidature

**Global rules**:
```json
"scenario_anchor_never_modified": true,
"max_consecutive_modified": 2,
"min_gap_same_modifier": 5
```

### 8.3 Modulation manuelle

L'API publique expose des méthodes de debug pour ajuster en temps réel:

```gdscript
func get_debug_weights(game_state: Dictionary) -> Dictionary
    // Returns computed weights (avec anti-rep appliquée)

func get_category_info(category: String) -> Dictionary
    // Full category config

func get_all_categories() -> Array[String]
    // Liste des catégories

func get_sub_types(category: String) -> Array[String]
    // Sous-types d'une catégorie
```

---

## 9. API publique

### 9.1 Initialisation

```gdscript
var selector := EventCategorySelector.new()
// Auto-charge event_categories.json et card_modifiers.json

func is_loaded() -> bool
    // Retourne true si event_categories.json chargé avec succès
```

### 9.2 Sélection d'événements

```gdscript
func select_event(game_state: Dictionary) -> Dictionary
    /**
     * Sélectionne une catégorie + sous-type basé sur l'état du jeu.
     *
     * Paramètre:
     *   game_state: {
     *     "run": {
     *       "cards_played": int,
     *       "life_essence": int,
     *       "current_biome": String,
     *       "faction_rep_delta": { faction_name: float, ... },
     *       "factions": { faction_name: float, ... },
     *       "flags": { flag_name: bool, ... },
     *       "hidden": {
     *         "tension": int (0-100),
     *         "karma": int
     *       }
     *     }
     *   }
     *
     * Retour:
     *   {
     *     "category": String,
     *     "sub_type": String,
     *     "label": String,
     *     "narrator_guidance": String,
     *     "effect_profile": Dictionary
     *   }
     * OU {} si non chargé
     */
```

### 9.3 Historique

```gdscript
func record_selection(category: String, sub_type: String, card_num: int) -> void
    // Enregistre une sélection pour anti-répétition

func get_history() -> Array[Dictionary]
    // Retourne historique complet (copie)
    // Chaque: { category, sub_type, card_num }

func clear_history() -> void
    // Efface historique (ex: nouvelle run)
```

### 9.4 Modifiers

```gdscript
func select_modifier(game_state: Dictionary, category: String) -> Dictionary
    /**
     * Sélectionne un modifier overlay pour la carte courante.
     *
     * Paramètre:
     *   category: String — catégorie déjà sélectionnée (pour exclusions)
     *
     * Retour:
     *   {
     *     "modifier": String,
     *     "label": String,
     *     "prompt_injection": String,  // Guidance pour LLM
     *     "effect_modifier": Dictionary,
     *     "minigame_pool": Array[String]
     *   }
     * OU {} si pas de modifier sélectionné
     */

func record_modifier(modifier_name: String) -> void
    // Enregistre un modifier pour anti-répétition
    // Passer "" si pas de modifier
```

### 9.5 Debug

```gdscript
func get_debug_weights(game_state: Dictionary) -> Dictionary
    // Retourne poids finaux après anti-rep (utile pour inspector)
    // Format: { category_key: float_weight, ... }

func get_category_info(category: String) -> Dictionary
    // Retourne config complète d'une catégorie

func get_all_categories() -> Array[String]
    // Liste des clés de catégories

func get_sub_types(category: String) -> Array[String]
    // Liste des clés de sous-types
```

---

## 10. Intégration avec les systèmes

### 10.1 MerlinOmniscient (Orchestrateur IA)

Défini dans `addons/merlin_ai/merlin_omniscient.gd`:

```gdscript
var event_selector: EventCategorySelector  # Phase 44

func _init():
    event_selector = EventCategorySelector.new()
    if event_selector.is_loaded():
        print("[MerlinOmniscient] EventCategorySelector loaded (%d categories)"
              % event_selector.get_all_categories().size())
```

**Cas d'usage**: Orchestrateur appelle `event_selector.select_event(game_state)` pour déterminer le **contexte narratif** avant d'invoquer le LLM narrateur.

### 10.2 MerlinCardSystem (Moteur de cartes)

Défini dans `scripts/merlin/merlin_card_system.gd`:

```gdscript
var _event_selector: EventCategorySelector = null

func set_event_selector(selector: EventCategorySelector) -> void:
    _event_selector = selector

# Utilisation interne:
# var event_result := _event_selector.select_event(game_state)
# var modifier_result := _event_selector.select_modifier(game_state, event_result.category)
```

**Cas d'usage**: Lors de la génération d'une carte, MerlinCardSystem:
1. Appelle `select_event()` → obtient catégorie + sous-type
2. Appelle `select_modifier()` → obtient overlay narratif optionnel
3. Enregistre: `record_selection(category, sub_type, card_num)`
4. Passe résultats au LLM narrateur pour générer le texte

### 10.3 Flux complet

```
MerlinGameController (hub)
  ↓
MerlinCardSystem.generate_card(game_state)
  ├─ event_selector.select_event(game_state)
  │  ├─ _compute_category_weights(run)
  │  │  ├─ _get_matrix_multipliers(run)
  │  │  └─ _get_pity_overrides(run)
  │  ├─ _apply_anti_repetition(weights)
  │  ├─ _weighted_select(weights) → category
  │  ├─ _select_sub_type(category, run)
  │  │  ├─ _evaluate_triggers(...)
  │  │  └─ _weighted_select(sub_weights) → sub_type
  │  └─ return { category, sub_type, ... }
  │
  ├─ event_selector.select_modifier(game_state, category)
  │  ├─ _check_modifier_trigger(...)
  │  ├─ probabilistic roll
  │  └─ return { modifier, ... } OR {}
  │
  ├─ event_selector.record_selection(category, sub_type, card_num)
  ├─ event_selector.record_modifier(modifier_name)
  │
  └─ MerlinOmniscient.generate_narrative(event_result, modifier_result)
     └─ LLM narrateur → texte carte

User sees card
  ↓
Minigame (choice)
  ↓
Effects pipeline
  ↓
...
```

---

## 11. Utilité — Mappages de delta faction

La fonction `_faction_delta_to_state()` (lignes 622-629) convertit un delta de réputation en état qualitatif pour les conditions:

```gdscript
func _faction_delta_to_state(delta: float) -> String:
    if delta < -5.0:
        return "BAS"      // Réputation baissée
    elif delta > 5.0:
        return "HAUT"     // Réputation augmentée
    return "EQUILIBRE"    // Stable
```

**Seuils**:
- BAS: delta < -5.0
- EQUILIBRE: -5.0 ≤ delta ≤ 5.0
- HAUT: delta > 5.0

**Utilisation**: Condition `aspect_condition` dans triggers (ex: `{ "anciens": ["BAS", "EQUILIBRE"] }` signifie "déclenche si anciens baissent ou sont stables").

---

## 12. Cas d'usage et exemples

### 12.1 Joueur en début de run (5 cartes jouées, vie = 100)

**État**:
```json
{
  "cards_played": 5,
  "life_essence": 100,
  "faction_rep_delta": { "anciens": 10, "peuple": 5, ... },
  "tension": 30
}
```

**Calcul**:

1. Base weights: rencontre=0.30, dilemme=0.20, decouverte=0.12, ...
2. Matrice "debut_run" (0-8 cartes):
   - rencontre: 0.30 × 1.30 = 0.39
   - dilemme: 0.20 × 0.60 = 0.12
   - decouverte: 0.12 × 1.70 = 0.204
   - catastrophe: 0.05 × 0.00 = 0.00 (IMPOSSIBLE)
   - repos: 0.05 × 1.50 = 0.075
3. Pas de pity (vie > 25 et < 80)
4. Anti-rep: aucune antériorité
5. Sélection pondérée: **decouverte** très probable (20.4%), **rencontre** probable (39%), **repos** moins (7.5%), **dilemme** rare (12%)

**Résultat attendu**: Découverte ou Rencontre.

### 12.2 Joueur en crise (20 cartes jouées, vie = 22)

**État**:
```json
{
  "cards_played": 20,
  "life_essence": 22,
  "tension": 75
}
```

**Calcul**:

1. Base weights (idem)
2. Matrice "milieu_run" (9-20):
   - dilemme: 0.20 × 1.20 = 0.24
   - conflit: 0.08 × 1.50 = 0.12
   - epreuve: 0.07 × 1.30 = 0.091
3. **Pity "recovery_boost"** (life < 25):
   - merveille: 0.08 × 2.50 = 0.20
   - decouverte: 0.12 × 1.50 = 0.18
   - catastrophe: 0.05 × 0.10 = 0.005 (quasi bloquée)
   - repos: 0.05 × 2.50 = 0.125 (fortement encouragé)
   - conflit: 0.08 × 0.30 = 0.024 (presque bloqué)
4. Anti-rep: Si dernière = dilemme, pénalité ×0.1
5. **Résultat attendu**: Merveille, Découverte ou Repos — le jeu aide le joueur à récupérer.

### 12.3 Joueur trop puissant (vie = 95)

**État**:
```json
{
  "cards_played": 15,
  "life_essence": 95,
  "faction_rep_delta": { ... }
}
```

**Calcul**:

1. Matrice "milieu_run"
2. **Pity "challenge_boost"** (life > 80):
   - conflit: 0.08 × 2.00 = 0.16
   - dilemme: 0.20 × 1.50 = 0.30
   - epreuve: 0.07 × 2.00 = 0.14
   - catastrophe: 0.05 × 1.50 = 0.075
   - repos: 0.05 × 0.20 = 0.01 (quasi bloquée)
3. **Résultat attendu**: Dilemme, Conflit, ou Épreuve — le jeu augmente la difficulté.

---

## 13. Considérations de design

### 13.1 Poids base et équilibre narratif

Les poids base sont choisis pour une **distribution équilibrée** en l'absence de contexte:
- **Rencontre** (0.30): Majorité des cartes — construction du monde
- **Dilemme** (0.20): 1/5 — moments clés de personnalité
- **Découverte** (0.12): Exploration et lore mineur
- **Conflit, Merveille** (0.08 chacun): Tonal spice
- **Catastrophe, Épreuve, Commerce, Repos** (0.05-0.07): Rare à moyen

Total = 1.0 (normalisé).

### 13.2 Dynamique tension-relief

Le système privilégie les **arcs narratifs**:
- **Début**: Découvertes + Rencontres (exploration)
- **Milieu**: Dilemmes + Conflits (tension)
- **Fin**: Épreuves + Catastrophes (climax)
- **Repos & Merveilles**: Placés stratégiquement pour respiration

### 13.3 Pity vs Challenge

Le **pity system** est agressif pour éviter frustration extrême:
- Joueur à life < 25 reçoit 2.5x plus de merveilles et repos
- Joueur dominant (life > 80) reçoit 2x plus de conflits

Ceci **prévient spirales** (mort trop rapide ou victoire ennuyeuse).

### 13.4 Anti-répétition tunée

Les **gaps** sont ajustés pour éviter:
- **Monotonie**: min_gap = 2 → minimum 2 cartes entre répétitions
- **Pattern machine**: max_consecutive = 2 → max 2 identiques d'affilée

Fenêtre = 10 cartes (20-30 secondes de jeu).

---

## 14. Troubleshooting

### Problème: Une catégorie ne sort jamais

**Diagnostique**:
1. Vérifier `base_weight` > 0 dans event_categories.json
2. Vérifier matrice active: poids × 0.00 = bloquée
3. Vérifier pity_system: surcharge multiplicative
4. Utiliser `get_debug_weights()` pour inspection

**Solution**: Ajuster base_weight ou multiplicateurs de matrice.

### Problème: Trop de répétitions d'une catégorie

**Cause**: `min_gap_same_category` trop bas ou historique petite fenêtre.

**Diagnostique**:
```
_history.size() < history_window
→ fenêtre trop petite
```

**Solution**: Augmenter `min_gap_same_category` (par défaut 2) ou `history_window` (par défaut 10).

### Problème: Modifiers ne s'appliquent jamais

**Cause**:
1. card_modifiers.json non trouvé/valide
2. Triggers trop restrictifs
3. Probabilité trop basse

**Diagnostique**:
- Vérifier console pour "[EventCategorySelector] Loaded X modifiers"
- Vérifier triggers avec `get_debug_weights()` analogue pour modifiers

**Solution**: Relaxer triggers ou augmenter probabilités.

---

## 15. Références croisées

- **Système d'effets**: `scripts/merlin/merlin_effect_engine.gd` — consomme `effect_profile` retourné
- **Système de réputation**: `scripts/merlin/merlin_reputation_system.gd` — fournit `faction_rep_delta`
- **Générateur narratif**: `addons/merlin_ai/merlin_omniscient.gd` — consomme catégorie + modifier pour LLM
- **Système de cartes**: `scripts/merlin/merlin_card_system.gd` — orchestrateur principal
- **Glossaire tags**: `data/ai/config/tag_glossary.json` — défini les tags référencés

---

## Résumé

L'**Event Category Selector** implémente une **sélection d'événements probabiliste et contextuelle** qui:

✓ Choisit entre 9 catégories d'événements narratifs basées sur l'état du jeu
✓ Affine en sélectionnant un sous-type selon des triggers localisés
✓ Applique des pénalités anti-répétition pour diversité garantie
✓ Supporte des modifiers narratifs overlays (tentation, bénédiction, etc.)
✓ Utilise un système de pity pour équilibrer joueurs faibles/forts
✓ Est entièrement configurable via JSON (event_categories.json, card_modifiers.json)

Le système est **robuste**, **testable** et **non-déterministe** (chaque run produit une narratif unique).

---

**Fichier**: `addons/merlin_ai/generators/event_category_selector.gd` v2.0.0
**Config**: `data/ai/config/event_categories.json`, `data/ai/config/card_modifiers.json`
**Integration**: `scripts/merlin/merlin_card_system.gd`, `addons/merlin_ai/merlin_omniscient.gd`
