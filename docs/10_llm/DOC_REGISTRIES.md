# Architecture des 5 Registres IA — M.E.R.L.I.N.

**Dernière mise à jour:** 2026-03-15
**Version:** 1.0.0
**Auteur:** Documentation Omnisciente

---

## Table des matières
1. [Vue d'ensemble](#vue-densemble)
2. [Player Profile Registry](#1-player-profile-registry)
3. [Session Registry](#2-session-registry)
4. [Decision History Registry](#3-decision-history-registry)
5. [Narrative Registry](#4-narrative-registry)
6. [Relationship Registry](#5-relationship-registry)
7. [Intégration système](#intégration-système)
8. [Flux de données complet](#flux-de-données-complet)

---

## Vue d'ensemble

### Qu'est-ce qu'un Registre ?

Les **registres IA** sont des objets RefCounted qui modélisent différentes dimensions de l'état du joueur et du jeu, spécifiquement pour les décisions narratives du LLM. Ils:

- **Capturent des signaux** depuis les événements du jeu (choix, fins de run, interactions)
- **Calculent des métriques** (patterns comportementaux, niveaux d'engagement, confiance)
- **Persistent à disque** (JSON, cross-run ou per-session)
- **Alimentent le contexte LLM** via des méthodes `get_context_for_llm()` et `get_summary_for_prompt()`

### Hiérarchie des 5 registres

```
MerlinOmniscient (orchestrateur)
├── PlayerProfileRegistry      ← Qui est le joueur? (cross-run, psychologie)
├── SessionRegistry             ← Comment joue-t-il maintenant? (bien-être, engagement)
├── DecisionHistoryRegistry     ← Qu'a-t-il choisi? (patterns, NPC karma)
├── NarrativeRegistry           ← Où sommes-nous? (arcs, monde, thèmes)
└── RelationshipRegistry        ← Quel est son lien avec Merlin? (confiance, rapport)
```

### Persistance

| Registre | Portée | Fichier | Fréquence |
|----------|--------|---------|-----------|
| **PlayerProfileRegistry** | Cross-run (global) | `user://merlin_player_profile.json` | `on_run_end()` |
| **SessionRegistry** | Per-session (historique) | `user://merlin_session_history.json` | `end_session()` |
| **DecisionHistoryRegistry** | Per-run + summary cross-run | `user://merlin_decision_history.json` | `on_run_end()` |
| **NarrativeRegistry** | Per-run + arcs complétés | `user://merlin_narrative.json` | `on_run_end()` |
| **RelationshipRegistry** | Cross-run avec decay | `user://merlin_relationship.json` | `save_to_disk()` |

---

## 1. Player Profile Registry

**Fichier:** `addons/merlin_ai/registries/player_profile_registry.gd`

### Objectif

Modélise le **profil psychologique du joueur** à travers les runs. Répond à: **"Qui est ce joueur? Quel est son style de jeu?"**

### Schéma

```gdscript
# 6 axes du Play Style (0.0 = extrême gauche, 1.0 = extrême droite)
play_style: {
    "aggression": 0.5,          # Prudent (0) ↔ Audacieux (1)
    "altruism": 0.5,            # Égoïste (0) ↔ Altruiste (1)
    "curiosity": 0.5,           # Pragmatique (0) ↔ Explorateur (1)
    "patience": 0.5,            # Impulsif (0) ↔ Méthodique (1)
    "trust_merlin": 0.5,        # Méfiant (0) ↔ Confiant (1)
    "risk_tolerance": 0.5,      # Risk-averse (0) ↔ Risk-seeking (1)
}

# 6 compétences (0.0 = novice, 1.0 = maître)
skill_assessment: {
    "gauge_management": 0.5,    # Équilibre des jauges
    "pattern_recognition": 0.5, # Détecte les setups narratifs
    "risk_assessment": 0.5,     # Tradeoffs informés
    "memory": 0.5,              # Se souvient des events/NPCs
    "timing": 0.5,              # Utilise les skills au bon moment
    "recovery": 0.5,            # Sort des crises
}

# Préférences détectées
preferences: {
    "preferred_themes": [],     # ["mystère", "combat", "social"]
    "avoided_themes": [],
    "favorite_npcs": [],        # NPCs avec +3 interactions positives
    "disliked_npcs": [],
    "humor_receptivity": 0.5,   # 0=sérieux, 1=aime l'humour
    "lore_interest": 0.5,       # Intérêt pour le lore profond
    "preferred_gauges": [],
    "preferred_biomes": [],
    "archetype_id": "",         # Résultat du quiz de personnalité
    "archetype_title": "",      # Ex: "Le Gardien"
}

# Méta-progression
meta: {
    "runs_completed": 0,
    "runs_won": 0,
    "total_cards_played": 0,
    "average_run_length": 50.0,
    "longest_run": 0,
    "shortest_run": 999,
    "endings_seen": [],
    "lore_fragments_discovered": [],
    "first_seen_date": 0,       # Unix timestamp
    "last_seen_date": 0,
    "total_play_time_seconds": 0,
    "total_sessions": 0,
    "achievements_unlocked": [],
}
```

### Lifecycle

1. **Initialisation** (`_init()`)
   - `load_from_disk()` → charge le profil persisté
   - Sinon crée valeurs par défaut (0.5 partout)

2. **Chaque choix** (`update_from_choice(card, option, context)`)
   - Analyse tags, effets, temps de décision
   - Shift traits via `_shift_trait()` (lerp vers target avec `TRAIT_LEARNING_RATE = 0.05`)
   - Track NPC interactions et thèmes

3. **Fin de choix** (outcome) (`update_from_outcome(outcome)`)
   - Update skills basées sur résultats (crise évitée? pattern reconnu?)
   - Modifie `trust_merlin` si promesses tenues/cassées

4. **Fin de run** (`on_run_end(run_data)`)
   - Update meta (runs, cartes, endings)
   - Apply session decay (lent retour vers 0.5, `DECAY_RATE = 0.995`)
   - Reset `_current_run_data`
   - **`save_to_disk()`**

### Tiers d'expérience

```gdscript
enum ExperienceTier { INITIATE, APPRENTICE, JOURNEYER, ADEPT, MASTER }

# Basé sur runs_completed:
INITIATE   ≤ 5 runs
APPRENTICE 6-20
JOURNEYER  21-50
ADEPT      51-100
MASTER     > 100
```

### Contexte pour LLM

**Méthode:** `get_context_for_llm() → Dictionary`

Retourne:
```gdscript
{
    "style": {6 axes},
    "skill": {6 compétences},
    "runs_completed": int,
    "experience_tier": String,      # "Initié", "Apprenti", etc.
    "preferred_themes": [],
    "avoided_themes": [],
    "humor_receptivity": float,
    "lore_interest": float,
}
```

**Résumé textuel:** `get_summary_for_prompt() → String`

Exemple:
```
Joueur Apprenti (Le Gardien): pragmatique, altruiste, explorateur, méthodique, confiant envers Merlin, prudent face au risque
```

### Signaux

- `profile_updated(trait_name, old_value, new_value)` — Trait changé
- `skill_assessed(skill, level)` — Compétence mise à jour
- `preference_detected(preference, value)` — Nouvelle préférence détectée

### Coupling

- **QuizResult:** `seed_from_quiz(quiz_result)` initialise play_style depuis axes du quiz (-1 to +1)
- **CardSystem:** reçoit `update_from_choice()` après chaque choix joueur
- **MerlinOmniscient:** accède via `context_builder` pour construire LLM context

---

## 2. Session Registry

**Fichier:** `addons/merlin_ai/registries/session_registry.gd`

### Objectif

Modélise le **comportement en temps réel du joueur CETTE SESSION**. Répond à: **"Comment joue-t-il maintenant? Montre-t-il des signes de fatigue, frustration, engagement?"**

### Schéma

```gdscript
# État session actuelle
current: {
    "start_time": 0,             # Unix timestamp
    "cards_this_session": 0,
    "runs_this_session": 0,
    "deaths_this_session": 0,
    "breaks_taken": 0,
    "total_decision_time_ms": 0,
    "rushed_decisions": 0,       # < 1 seconde
    "contemplated_decisions": 0, # > 10 secondes
    "skill_uses": 0,
    "faction_interactions": 0,
}

# Métriques calculées
average_decision_time: float = 4.5      # En secondes
decision_time_trend: float = 0.0        # Positif = ralentit (fatigue?)

# Historique cross-session
history: {
    "total_sessions": 0,
    "total_playtime_seconds": 0,
    "average_session_minutes": 38.0,
    "preferred_play_times": [],         # ["morning", "evening", "night"]
    "days_since_last_play": 0,
    "longest_streak": 0,                # Jours consécutifs
    "current_streak": 0,
    "session_lengths": [],              # Last 20 sessions (en minutes)
    "last_session_date": 0,             # Unix timestamp
}

# Engagement actuel
engagement: {
    "current_level": EngagementLevel.MEDIUM,  # LOW, MEDIUM, HIGH, VERY_HIGH
    "card_reading_speed": "normal",           # "fast", "normal", "slow", "variable"
    "faction_interaction_rate": 0.5,          # 0-1
    "skill_usage_rate": 0.3,                  # 0-1
    "menu_time_ratio": 0.15,                  # Temps menu / gameplay
    "dialogue_skip_rate": 0.0,                # 0-1
}

# Wellness flags — détectent problèmes de bien-être
wellness: {
    "long_session_warned": false,      # > 90 min
    "break_suggested": false,          # > 60 min
    "frustration_detected": false,     # Morts rapides + rushed decisions
    "fatigue_detected": false,         # Decisions 50% plus lentes
    "tilt_detected": false,            # 3+ morts rapides
    "positive_momentum": false,        # Joueur dans le flow
}
```

### Lifecycle

1. **Initialisation** (`_init()`)
   - `load_from_disk()` → historique
   - `start_new_session()` → reset current, calc streak

2. **Chaque décision** (`record_decision(time_ms)`)
   - Incrémente `cards_this_session`, `total_decision_time_ms`
   - Compte rushed/contemplated
   - Calcule trend (moitié récente vs moitié précédente)
   - `_update_engagement()` → score basé rushes, contemplation, skills, etc.
   - `_check_wellness()` → détecte frustration, fatigue, tilt

3. **Événements** (signaux)
   - `record_death()`
   - `record_run_start()`
   - `record_skill_use()`
   - `record_faction_interaction()`
   - `record_dialogue_skip()`
   - `record_break()` → reset `break_suggested`

4. **Fin de session** (`end_session() → Dictionary`)
   - Update history (total_sessions, playtime, avg_session_minutes)
   - Sauvegarde à disque
   - Émet `session_ended` signal
   - Retourne résumé pour affichage

### Seuils wellness

| Condition | Valeur | Avertissement |
|-----------|--------|---------------|
| Session longue | ≥ 90 min | `long_session_warned` |
| Pause suggérée | ≥ 60 min | `break_suggested` |
| Frustration | 3+ morts + 40% rushed | `frustration_detected` |
| Fatigue | Trend > 50% slowdown | `fatigue_detected` |
| Tilt | 3+ morts en < 30 min | `tilt_detected` |
| Flow | 50+ cartes sans mort | `positive_momentum` |

### Engagement Level

Calculé via score (0.0-1.0):
```
score = 0.5
score -= rush_ratio × 0.3       # Rushed = low engagement
score += contemplate_ratio × 0.2 # Contemplated = high
score += skill_usage × 0.2
score += faction_interaction × 0.1
score -= dialogue_skip × 0.3

LOW (< 0.3) | MEDIUM (0.3-0.5) | HIGH (0.5-0.7) | VERY_HIGH (≥ 0.7)
```

### Contexte pour LLM

**Méthode:** `get_context_for_llm() → Dictionary`

```gdscript
{
    "cards_this_session": int,
    "session_length_minutes": float,
    "is_returning_player": bool,
    "days_away": int,
    "is_long_session": bool,
    "seems_frustrated": bool,
    "seems_fatigued": bool,
    "in_tilt": bool,
    "in_flow": bool,
    "engagement_level": String,     # "low", "medium", "high", "very_high"
    "reading_speed": String,        # "fast", "normal", "slow", "variable"
    "total_sessions": int,
    "current_streak": int,
}
```

**Résumé textuel:** `get_summary_for_prompt() → String`

```
Session: 45 minutes, 23 cartes
Retour après 2 jours
ATTENTION: Joueur frustré, adoucir
Engagement bas, stimuler l'intérêt
```

### Signaux

- `wellness_alert(alert_type, data)` — Alerte bien-être (frustration, fatigue, etc.)
- `engagement_changed(level)` — Niveau engagement changé
- `session_ended(summary)` — Fin de session

### Coupling

- **GameController:** appelle `record_decision()`, `record_death()`, `end_session()`
- **MerlinOmniscient:** accède pour adapter difficulté/ton basé sur wellness
- **UI:** affiche notifications wellness (pause suggestion)

---

## 3. Decision History Registry

**Fichier:** `addons/merlin_ai/registries/decision_history_registry.gd`

### Objectif

Modélise la **mémoire des choix et les patterns comportementaux du joueur**. Répond à: **"Qu'a-t-il choisi? Y a-t-il des patterns?"**

### Schéma

```gdscript
# Historique de run actuelle (max 200 entrées)
current_run: Array[Dictionary] = []
# Chaque entrée: {
#   "card_id": String,
#   "card_type": String,
#   "option": int (0=gauche, 1=droite, 2=centre),
#   "effects": Array,
#   "gauges_before": Dictionary,
#   "gauges_after": Dictionary,
#   "timestamp": int,
#   "day": int,
#   "biome": String,
#   "tags": Array,
#   "decision_time_ms": int,
#   "npc_id": String,
# }

# Patterns détectés (6 comportementaux + 4 jauges)
patterns_detected: Dictionary = {}
# Structure: {
#   "pattern_name": {
#       "confidence": float,    # 0.0-1.0
#       "occurrences": int,
#       "last_updated": int,    # Unix timestamp
#   }
# }

# Patterns prédéfinis
PATTERNS = {
    "always_helps_strangers": {"filter_tags": ["stranger", "help_request"], "expected_option": 1},
    "avoids_promises": {"filter_tags": ["promise"], "expected_option": 0},
    "seeks_mystery": {"filter_tags": ["mystery", "investigate", "lore"], "expected_option": 1},
    "favors_factions": {"filter_tags": ["faction_choice"], "expected_option": 0},
    "takes_risks": {"filter_tags": ["risky", "dangerous", "gamble"], "expected_option": 1},
    "avoids_conflict": {"filter_tags": ["conflict", "fight", "aggressive"], "expected_option": 0},
}

# Gauge patterns
gauge_patterns: {
    "protects_vigueur": {"count": 0, "opportunities": 0},
    "protects_esprit": {"count": 0, "opportunities": 0},
    "protects_faveur": {"count": 0, "opportunities": 0},
    "protects_ressources": {"count": 0, "opportunities": 0},
}

# NPC karma (influence callbacks et tone)
npc_karma: {npc_id: int}          # -100 to +100
npc_last_seen: {npc_id: int}      # Numéro de carte

# Summary cross-run
historical_summary: {
    "total_choices": int,
    "left_ratio": float,    # Proportion choix gauche
    "center_ratio": float,
    "right_ratio": float,
    "promise_acceptance_rate": float,
    "average_gauge_at_death": Dictionary,
    "most_common_death_gauge": String,
    "patterns_over_time": Dictionary,  # Évolution patterns
}
```

### Lifecycle

1. **Initialisation** (`_init()`)
   - `load_from_disk()` → patterns et karma persistés

2. **Chaque choix** (`record_choice(card, option, context)`)
   - Crée entry dans `current_run`
   - Update `historical_summary` ratios
   - `_track_npc_interaction(entry)` → karma ±10/-5/etc selon tags
   - `_track_gauge_protection(entry, context)` → compte opportunities vs protections
   - `_detect_patterns()` → calcule confidence pour chaque pattern

3. **Après effet** (`update_last_entry_gauges(gauges_after)`)
   - Remplit `gauges_after` du dernier choix

4. **Fin de run** (`on_run_end(ending_data)`)
   - Track death gauge statistics
   - Update promise acceptance rate
   - Save patterns evolution
   - `reset_run()` → clear current_run, keep karma/patterns
   - **`save_to_disk()`**

### Pattern Detection

**Seuil minimum:** `PATTERN_MIN_OCCURRENCES = 5`
**Confidence seuil:** `PATTERN_DETECTION_THRESHOLD = 0.7` (70%)

Calcul:
```
consistency = matching_choices / total_matching_entries
if consistency >= 0.7 and count >= 5:
    → Pattern détecté
```

### NPC Karma & Callbacks

**Karma changes:**
- `"help"/"gift"/"trust"`: +10 (option 1), -5 (option 0)
- `"refuse"/"betray"`: -10 (opt 1), +5 (opt 0)
- `"attack"/"steal"`: -15 (opt 1), 0 (opt 0)
- Clamped: -100 to +100

**Callback opportunity:**
- NPC peut revenir après 10+ cartes depuis dernière rencontre
- Si `|karma| >= 30` → callback possible

**Relationship summary:**
```
karma >= 50   → "allié_fidèle"
20-49         → "ami"
-20 to 19     → "neutre"
-50 to -21    → "méfiant"
< -50         → "ennemi"
```

### Contexte pour LLM

**Méthode:** `get_context_for_llm() → Dictionary`

```gdscript
{
    "cards_this_run": int,
    "patterns": {pattern_name: confidence},
    "npc_karma": {npc_id: karma},
    "npcs_met_count": int,
    "recent_choices": Array[{type, option, tags}],  # Last 5
    "promise_acceptance_rate": float,
    "most_common_death_gauge": String,
}
```

**Résumé textuel:** `get_pattern_for_llm() → String`

Exemple:
```
Le joueur toujours aide les étrangers
Le joueur souvent refuse les promesses
Le joueur souvent protège sa Vigueur
```

### Signaux

- `pattern_detected(pattern_name, confidence)` — Nouveau pattern >= 0.7
- `callback_opportunity(npc_id, card_id)` — NPC peut revenir

### Coupling

- **CardSystem:** appelle `record_choice()` après choix, `update_last_entry_gauges()` après effets
- **MerlinOmniscient:** accède patterns pour context LLM
- **LLM Prompt:** utilise `get_pattern_for_llm()` pour injecter patterns dans prompt

---

## 4. Narrative Registry

**Fichier:** `addons/merlin_ai/registries/narrative_registry.gd`

### Objectif

Modélise la **structure narrative et l'état du monde**. Répond à: **"Où sommes-nous? Quels arcs sont actifs? Quels twists sont plantés?"**

### Schéma

```gdscript
# FSM run-level (4 phases)
enum ArcPhase { SETUP = 1, RISING = 2, CLIMAX = 3, RESOLUTION = 4 }

run_phase: int = ArcPhase.SETUP  # Phase narrative globale de la run
_current_card_number: int = 0

# Seuils de progression run_phase (en cartes jouées)
RUN_PHASE_THRESHOLDS = {
    ArcPhase.SETUP: 5,      # Cartes 1-5
    ArcPhase.RISING: 15,    # Cartes 6-20
    ArcPhase.CLIMAX: 25,    # Cartes 21-45
    # > 45 → RESOLUTION
}

# Arcs narratifs actifs (max 2)
active_arcs: Array[Dictionary] = []
# Chaque arc: {
#   "id": String,
#   "stage": int (ArcPhase),
#   "cards_in_arc": Array[String],  # IDs cartes dans l'arc
#   "flags": Dictionary,            # State custom pour l'arc
#   "started_at_card": int,
#   "deadline_card": int,           # Auto-close après X cartes
#   "stage_card_count": int,        # Cards depuis dernier stage change
# }

# Seuils auto-progression arcs
ARC_AUTO_PROGRESS = {
    ArcPhase.SETUP: 3,      # 3 cartes → RISING
    ArcPhase.RISING: 6,     # 6 cartes → CLIMAX
    ArcPhase.CLIMAX: 2,     # 2 cartes → RESOLUTION
}
ARC_AUTO_CLOSE_CARDS = 30  # Ferme auto si pas de résolution

# Arcs complétés (cross-run)
completed_arcs: Array[Dictionary] = []
# Chaque arc: {"id", "resolution", "cards_played", "outcome", "completed_at"}

# Foreshadowing (max 5 actifs)
foreshadowing: Array[Dictionary] = []
# Chaque hint: {
#   "id": String,
#   "hint": String,
#   "planted_at_card": int,
#   "min_reveal_card": int,    # Earliest reveal
#   "max_reveal_card": int,    # Latest before auto-reveal
#   "revealed": bool,
#   "twist_type": String,      # Type de twist quand révélé
# }

TWIST_TYPES = [
    "identity_hidden",       # NPC n'est pas ce qu'il semble
    "motivation_inverse",    # Motivations cachées
    "consequence_differee",  # Choix passé → consequence
    "fausse_victoire",      # Semblait bon, ne l'est pas
    "ami_ennemi",           # Allié devient adversaire
    "ennemi_ami",           # Adversaire devient allié
]

# NPC tracking per-run
npcs: Dictionary = {}
# Structure: {
#   npc_id: {
#       "encounters": int,
#       "last_seen_card": int,
#       "relationship": int,        # -100 to 100
#       "secrets_known": Array[String],
#       "can_return": bool,
#       "arc_id": String,
#   }
# }

# État du monde
world: {
    "biome": String,        # Nom du biome
    "day": int,             # Numéro du jour
    "season": String,       # "spring", "summer", "autumn", "winter"
    "time_of_day": String,  # "aube", "jour", "soir", "nuit"
    "active_tags": Array,   # Tags actifs ajoutés par cartes
    "global_tension": float, # 0-1, affecte prob twist
    "weather": String,      # "clear", "cloudy", "rain", "storm", "mist", "snow"
    "moon_phase": String,   # "waxing", "full", "waning", "new"
}

# Theme fatigue
recent_themes: Array[String] = []    # Last 10 themes joués
theme_fatigue: {theme: float}        # Accumule avec chaque jeu
THEME_FATIGUE_DECAY = 0.1            # Décroît per card
THEME_FATIGUE_WARNING = 3            # Avertir après 3 repetitions

THEMES = [
    "mystery", "combat", "social", "survival",
    "spiritual", "political", "romantic", "horror",
    "comedy", "tragedy", "adventure", "introspection"
]
```

### Lifecycle

1. **Initialisation** (`_init()`)
   - `load_from_disk()` → completed_arcs seulement

2. **Début de run** (`reset_run()`)
   - Clear active_arcs, foreshadowing, npcs, recent_themes, theme_fatigue
   - Reset run_phase et _current_card_number
   - Init world avec random season

3. **Chaque carte** (`process_card(card)`)
   - `_current_card_number += 1`
   - `_track_themes(card.themes)` → ajoute à recent_themes, incremente theme_fatigue
   - `_track_npc_encounter(npc_id, card)` → encounters, relationship, secrets
   - `_progress_arc(arc_id, card)` → add card à arc, check stage progression
   - `_auto_progress_arc_stages()` → avance stages basées sur cards_in_arc count
   - `_auto_start_arc_if_needed()` → crée arc si aucun actif après 3 cartes
   - `_progress_run_phase()` → update run_phase basée sur _current_card_number
   - `_check_foreshadowing_reveals()` → auto-reveal si past max_card
   - `_check_arc_deadlines()` → auto-close si deadline passée
   - `_update_world_state(card)` → add/remove tags, update tension, biome
   - `_decay_theme_fatigue()` → décrémenter fatigue pour tous les thèmes

4. **Fin de run** (`on_run_end()`)
   - Close tous les active_arcs comme "run_ended"
   - **`save_to_disk()`** (completed_arcs seulement)

### Arc Management

**Auto-progression:**
```
Carte 1-3 en arc → SETUP
Après 3 cartes dans SETUP → stage = RISING, stage_card_count = 0
Après 6 cartes dans RISING → stage = CLIMAX
Après 2 cartes dans CLIMAX → _complete_arc(), remplace par RESOLUTION
```

**Deadline:**
```
Si _current_card_number >= deadline_card → auto-close avec "expired"
deadline = started_at_card + ARC_AUTO_CLOSE_CARDS (30 cartes)
```

**Flags custom:**
```
Arc peut avoir flags arbitraires, peut être modifiés par cartes
arc.flags["key"] = value
```

### Foreshadowing & Twists

**Plant:** `plant_foreshadowing(hint_id, hint_text, twist_type)`
- Min reveal: current_card + 5
- Max reveal: current_card + 30
- Si auto-reveal: marked "missed"

**Révéler:** `reveal_foreshadowing(hint_id)` ou `should_trigger_twist()`
```
should_trigger = random() < world.global_tension
if should_trigger:
    available_twist = get_available_twist()  # Picked from foreshadowing
```

### Contexte pour LLM

**Méthode:** `get_context_for_llm() → Dictionary`

```gdscript
{
    "run_phase": int,
    "run_phase_name": String,       # "Mise en place", "Montée dramatique", etc.
    "active_arcs": Array[{id, stage, stage_name, cards_in_arc}],
    "active_foreshadowing": int,
    "revealable_twists": int,
    "recent_themes": Array[String],
    "fatigued_themes": Array[String],
    "recommended_themes": Array[String],
    "tension_level": float,
    "known_npcs": Array[String],
    "npcs_for_callback": Array[String],
    "world_state": Dictionary,      # Complet world dict
}
```

**Résumé textuel:** `get_summary_for_prompt() → String`

```
Phase narrative: Montée dramatique (carte 18)
Jour 2, jour, automne
Lieu: Brocéliande, Météo: clair
Arcs actifs: arc_broceliande_8 (Montée dramatique, 7 cartes)
Tension narrative montante
Éviter themes: combat, horror
Privilégier themes: mystery, spiritual
NPCs disponibles pour retour: Morgane, Lancelot
```

### Signaux

- `arc_started(arc_id)` — Nouvel arc actif
- `arc_progressed(arc_id, stage)` — Arc change de stage
- `arc_completed(arc_id, resolution)` — Arc complété
- `foreshadowing_planted(hint_id)` — Hint planté
- `foreshadowing_revealed(hint_id)` — Hint révélé
- `twist_triggered(twist_type)` — Twist activé
- `theme_fatigue_warning(theme)` — Theme overused

### Coupling

- **CardSystem:** appelle `process_card()` après chaque carte
- **LLM Prompt:** utilise `get_summary_for_prompt()` et `get_context_for_llm()`
- **CardGenerator:** sélectionne cartes basées sur arcs actifs et tension

---

## 5. Relationship Registry

**Fichier:** `addons/merlin_ai/registries/relationship_registry.gd`

### Objectif

Modélise la **relation évolutive Merlin-Joueur**. Répond à: **"Quel est le lien de confiance? Comment Merlin doit-il parler?"**

### Schéma

```gdscript
# Tiers de confiance (progression)
enum TrustTier {
    DISTANT = 0,    # T0: Merlin cryptique, réponses courtes
    CAUTIOUS = 1,   # T1: Guidance occasionnelle
    ATTENTIVE = 2,  # T2: Réfléchi, hints patterns
    BOUND = 3       # T3: Chaud mais ambigu, moments émotionnels rares
}

TRUST_THRESHOLDS = [25, 50, 75]  # Points pour atteindre chaque tier
MAX_TRUST_POINTS = 100

trust_tier: TrustTier = TrustTier.DISTANT
trust_points: int = 0

# 5 dimensions du rapport (0.0-1.0)
rapport: {
    "respect": 0.3,         # Reconnaissance des compétences
    "warmth": 0.2,          # Connection émotionnelle
    "complicity": 0.2,      # Moments partagés, blagues
    "reverence": 0.1,       # Respect quasi-mystique
    "familiarity": 0.2,     # A quel point Merlin "connaît" le joueur
}

# Events impact trust
TRUST_CHANGES = {
    "promise_kept": 10,
    "followed_hint": 3,
    "ignored_warning_survived": 5,   # Respect autonomie
    "long_run_100": 5,
    "long_run_150": 8,
    "discovered_lore": 2,
    "thanked_merlin": 4,
    "asked_good_question": 3,
    "survived_crisis": 2,
    "completed_arc": 5,

    "promise_broken": -15,
    "ignored_warning_died": -5,
    "quick_death": -2,
    "rushed_many_decisions": -3,
    "abandoned_run": -5,
    "skipped_dialogue": -1,
}

# Interaction history
interactions: {
    "promises_proposed": 0,
    "promises_accepted": 0,
    "promises_kept": 0,
    "promises_broken": 0,
    "direct_addresses": 0,      # Merlin parle directement
    "hints_followed": 0,        # Joueur a suivi conseil
    "warnings_ignored": 0,
    "questions_asked": 0,       # Joueur interroge Merlin
    "thank_yous": 0,
    "defiances": 0,             # Opposition
}

# Special moments (flags uniques, cross-run)
special_moments: {
    "has_seen_melancholy": false,
    "has_seen_slip": false,         # Glissement de masque
    "questioned_merlin_nature": false,
    "thanked_merlin_sincerely": false,
    "defied_merlin": false,
    "shared_silence": false,
    "witnessed_prophecy": false,
    "saved_by_merlin": false,
    "1000_runs_revelation": false,  # Easter egg
}

# Decay par absence
TRUST_DECAY_PER_DAY = 1
MAX_DECAY_DAYS = 30
last_session_date: int = 0
```

### Lifecycle

1. **Initialisation** (`_init()`)
   - `load_from_disk()`
   - `_apply_absence_decay()` → pénalise jours d'absence (max 30)

2. **Reset** (nouveau joueur): `reset()`
   - trust_tier → DISTANT
   - trust_points → 0
   - rapport → valeurs basses (0.1-0.3)
   - interactions → tous à 0

3. **Événement de confiance** (`update_trust(event)`)
   - Lookup `TRUST_CHANGES[event]`
   - Add points, clamp [0, 100]
   - `_update_tier()` → check thresholds (25, 50, 75)
   - `_update_rapport_from_event()` → modifie dimensions
   - Emit `trust_changed` si tier change

4. **Interaction** (`record_interaction(type)`)
   - Incrémente counter
   - Si certains types → appelle `update_trust()`
   - Ex: "promises_kept" → `update_trust("promise_kept")`

5. **Special moments** (`trigger_special_moment(moment)`)
   - Set flag à true
   - Emit signal
   - Bonus trust ("discovered_lore")
   - Auto-checked via thresholds (ex: 3 thanks → "thanked_sincerely")

### Trust Tiers & Tone

**Chaque tier affecte le ton de Merlin:**

```gdscript
DISTANT (T0):
    humor: 1.0 (neutre), darkness: 0.0, warmth: 0.0, verbosity: 0.7
    Phrases courtes, cryptiques, pas d'humour

CAUTIOUS (T1):
    humor: 0.95, darkness: 0.05, warmth: 0.1, verbosity: 0.85
    Commence à tester avec hints

ATTENTIVE (T2):
    humor: 0.90, darkness: 0.10, warmth: 0.3, verbosity: 1.0
    Réfléchi, peut montrer un peu de darkness

BOUND (T3):
    humor: 0.85, darkness: 0.15, warmth: 0.5, verbosity: 1.2
    Chaleur, vulnerabilité rare, blagues complices
```

### Lore Reveal Depth

Peut révéler lore de quelle profondeur?

```gdscript
depth: 1=surface, 2=medium, 3=deep, 4=secret, 5=ultimate

DISTANT  → max depth 1 (faits basiques)
CAUTIOUS → max depth 2 (some context)
ATTENTIVE → max depth 3 (detailed history)
BOUND    → max depth 4 (secret motivations)
```

### Contexte pour LLM

**Méthode:** `get_context_for_llm() → Dictionary`

```gdscript
{
    "trust_tier": int,
    "trust_tier_name": String,      # "Distant", "Prudent", "Attentif", "Lié"
    "trust_points": int,
    "rapport": {5 dimensions},
    "tone_mods": {4 modifiers},     # humor, darkness, warmth, verbosity
    "can_show_darkness": bool,       # >= CAUTIOUS
    "can_show_melancholy": bool,
    "taunt_intensity": float,        # 0.0-1.0
}
```

**Résumé textuel:** `get_summary_for_prompt() → String`

```
Confiance: Attentif (62/100)
Ton: Peut montrer de la profondeur
Rapport chaleureux établi
Complicité avec le joueur
A déjà vu la mélancolie de Merlin
```

### Signaux

- `trust_changed(old_tier, new_tier, points)` — Tier changé
- `rapport_updated(dimension, value)` — Dimension changée
- `special_moment_triggered(moment)` — Moment spécial déclenché

### Coupling

- **GameController:** appelle `update_trust()`, `record_interaction()`, `trigger_special_moment()`
- **MerlinOmniscient:** accède pour adapter ton via tone_mods
- **LLM Prompt:** injecte trust context et tone modifiers dans prompt

---

## Intégration système

### MerlinOmniscient — Orchestrateur Central

**Fichier:** `addons/merlin_ai/merlin_omniscient.gd`

```gdscript
class MerlinOmniscient:
    var player_profile: PlayerProfileRegistry
    var decision_history: DecisionHistoryRegistry
    var relationship: RelationshipRegistry
    var narrative: NarrativeRegistry
    var session: SessionRegistry

    var context_builder: MerlinContextBuilder
    var rag_manager: RAGManager
    var llm_interface: Node  # merlin_ai.gd autoload
```

**Initialisation:** `_init_registries()` → crée toutes les instances, `load_from_disk()` per registry

### MerlinContextBuilder — Agrégateur de Contexte

**Fichier:** `addons/merlin_ai/context_builder.gd`

Agrège tous les registres en **contexte unique pour LLM:**

```gdscript
func build_full_context(game_state: Dictionary) → Dictionary:
    return {
        # Game state (jauges, tours, ogham, factions)
        "gauges": ...,
        "tour": ...,
        "factions": ...,

        # Registries → contexte LLM
        "player": player_profile.get_context_for_llm(),
        "patterns": decision_history.get_pattern_for_llm(),
        "trust": relationship.get_context_for_llm(),
        "narrative": narrative.get_context_for_llm(),
        "session": session.get_context_for_llm(),

        "_hidden": {tema weights, etc.}
    }

func build_llm_prompt_context(full_context: Dictionary) → String:
    # Transforme en texte pour le prompt
    # Agrège résumés textuels de tous les registries
```

### RAGManager — Context Ranking

**Gère la priorité du contexte** pour respecter token budget du LLM:

1. **Haute priorité:**
   - Game state actuel (jauges, tour, life_essence)
   - Trust tier et tone modifiers
   - Session wellness (frustration? fatigue?)

2. **Moyenne priorité:**
   - Recent patterns détectés
   - Active arcs et narrative phase
   - NPC karma pour callbacks

3. **Basse priorité:**
   - Theme fatigue (peut être omise)
   - Historical stats (runs, skills)
   - Lore discoveries

---

## Flux de données complet

### Séquence: Choix → Registres → LLM → Carte

```
1. PLAYER FAIT UN CHOIX
   game_state → choice_index
   Timing: record_decision(time_ms)

2. SESSION REGISTRY
   session.record_decision(decision_time_ms)
   → detect engagement, wellness flags
   → ALERT si frustration/fatigue/tilt

3. DECISION HISTORY + PLAYER PROFILE
   decision_history.record_choice(card, option, context)
   player_profile.update_from_choice(card, option, context)
   → track patterns, NPC karma, play_style shift
   → detect preferences

4. NARRATIVE (OPTIONAL)
   narrative.process_card(card)
   → track arc progression, themes, NPCs
   → auto-progress phases, foreshadowing

5. OUTCOME (SI FIN PRÉMATURÉE)
   decision_history.update_last_entry_gauges(gauges_after)
   player_profile.update_from_outcome(outcome)
   relationship.update_trust("event_type")

6. FIN DE RUN
   decision_history.on_run_end(ending_data)
   player_profile.on_run_end(run_data)
   narrative.on_run_end()
   relationship.save_to_disk()
   session.end_session()
   → TOUS save_to_disk()

7. GENÉRATION PROCHAINE CARTE
   full_context = context_builder.build_full_context(game_state)
   rag_context = rag_manager.rank_context(full_context)
   prompt = llm_template.format(rag_context, ...)
   card = llm_interface.generate(prompt)  # Call Qwen via Ollama

8. RETOUR À (1) pour prochaine carte
```

### Données Persisted

Après chaque `on_run_end()`:

| Fichier | Source | Contenu |
|---------|--------|---------|
| `merlin_player_profile.json` | PlayerProfileRegistry | play_style, skill_assessment, preferences, meta |
| `merlin_session_history.json` | SessionRegistry | history (total_sessions, playtime, streaks) |
| `merlin_decision_history.json` | DecisionHistoryRegistry | patterns, npc_karma, gauge_patterns, historical_summary |
| `merlin_narrative.json` | NarrativeRegistry | completed_arcs (ONLY) |
| `merlin_relationship.json` | RelationshipRegistry | trust_tier, trust_points, rapport, interactions, special_moments |

### Exemple: Impact Chaîne Complète

**Scenario:** Joueur fait 3 choix rapides (< 500ms) malgré vie basse (20/100)

```
1. SESSION
   → rushed_decisions += 3
   → average_decision_time basse
   → engagement_level → LOW
   → wellness.frustration_detected = true (si aussi 3+ morts)

2. PLAYER_PROFILE
   → patience shift vers 0.0 (impulsif)
   → gauge_management skill penalisée

3. LLM CONTEXT
   session.get_context_for_llm():
   {
       "seems_frustrated": true,
       "engagement_level": "low",
       "reading_speed": "fast",
   }

4. LLM PROMPT (injected)
   "ATTENTION: Joueur frustré, adoucir
    Engagement bas, stimuler l'intérêt"

   → LLM ajuste:
   - Réduit difficulté des choix
   - Propose moments d'espoir
   - Ajoute humour/légèreté
```

---

## Résumé schématique

```
PlayerProfileRegistry          SessionRegistry              DecisionHistoryRegistry
├─ 6 axes play_style          ├─ wellness flags            ├─ Patterns (6 comportement)
├─ 6 compétences              ├─ engagement_level          ├─ NPC karma (-100 à 100)
├─ Thèmes/NPCs/bio préf.      ├─ Session current stats     ├─ Gauge protection tracking
├─ Meta (runs, time, etc.)    └─ Historical (streaks, avg) └─ Historical summary (choix)
└─ Cross-run persistant           Per-session persistant       Per-run + summary cross-run

           NarrativeRegistry                    RelationshipRegistry
           ├─ Run phase FSM (4 états)          ├─ Trust tier (T0-T3)
           ├─ Arcs actifs (max 2)              ├─ Trust points (0-100)
           ├─ Foreshadowing (max 5)            ├─ 5 dimensions rapport
           ├─ World state (biome, jour, etc.)  ├─ Interactions history
           ├─ Theme fatigue                    ├─ Special moments
           ├─ NPC encounters per-run           └─ Absence decay
           └─ Per-run (arcs complétés cross-run)   Cross-run persistant

                              ↓ Tous

                    MerlinOmniscient (orchestrateur)
                           ↓

                    MerlinContextBuilder (agrégateur)
                           ↓

                    RAGManager (priorité context)
                           ↓

                    LLM Prompt (Qwen via Ollama)
                           ↓

                    Carte générée
```

---

**Fin du document**
