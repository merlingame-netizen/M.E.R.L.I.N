# MERLIN OMNISCIENT SYSTEM (MOS) — Architecture Technique

> **M.E.R.L.I.N.**: Memoire Eternelle des Recits et Legendes d'Incarnations Narratives

*Version: 1.0.0 — 2026-02-08*
*Status: IMPLEMENTATION READY*

---

## Executive Summary

Le MOS transforme Merlin d'un simple generateur de texte en une **intelligence narrative omnisciente** qui:
- Connait TOUT du joueur (actions, decisions, style, temps de jeu)
- Maintient des **registres persistants** qui influencent ses decisions
- Adapte dynamiquement difficulte, ton et contenu narratif
- Reste **incassable** grace a un systeme de fallback multicouche

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MERLIN OMNISCIENT SYSTEM (MOS)                           │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         REGISTRIES LAYER                             │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │ Player   │ │ Decision │ │Relation- │ │Narrative │ │ Session  │  │   │
│  │  │ Profile  │ │ History  │ │   ship   │ │ Registry │ │ Registry │  │   │
│  │  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │   │
│  └───────┼───────────┼───────────┼───────────┼───────────┼──────────┘   │
│          └───────────┴───────────┴───────────┴───────────┘               │
│                                    │                                      │
│  ┌─────────────────────────────────▼───────────────────────────────────┐  │
│  │                      CONTEXT BUILDER                                 │  │
│  │  Aggrege les registres + game state → contexte LLM riche            │  │
│  └─────────────────────────────────┬───────────────────────────────────┘  │
│                                    │                                      │
│  ┌─────────────────────────────────▼───────────────────────────────────┐  │
│  │                    ADAPTIVE PROCESSORS                               │  │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐         │  │
│  │  │ Difficulty     │  │ Narrative      │  │ Tone           │         │  │
│  │  │ Adapter        │  │ Scaler         │  │ Controller     │         │  │
│  │  └────────────────┘  └────────────────┘  └────────────────┘         │  │
│  └─────────────────────────────────┬───────────────────────────────────┘  │
│                                    │                                      │
│  ┌─────────────────────────────────▼───────────────────────────────────┐  │
│  │                      GENERATION LAYER                                │  │
│  │                                                                      │  │
│  │    FastRoute → Template Engine → LLM Client → Validator → Output    │  │
│  │         ↓             ↓              ↓            ↓                 │  │
│  │    Instant       Cached          Qwen 3B     Sanitize              │  │
│  │    Response      Templates       Generate    + Clamp                │  │
│  │                                                                      │  │
│  │    ┌──────────────────────────────────────────────────────────┐     │  │
│  │    │              FALLBACK POOL (Always Ready)                 │     │  │
│  │    │  200+ cartes pre-ecrites avec matching contextuel        │     │  │
│  │    └──────────────────────────────────────────────────────────┘     │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                         ┌─────────────────┐
                         │  MERLIN STORE   │
                         │  (Game State)   │
                         └─────────────────┘
```

---

## 1. Registries Layer — Les 5 Memoires de Merlin

### 1.1 Player Profile Registry (PPR)

**Fichier**: `addons/merlin_ai/registries/player_profile_registry.gd`
**Persistance**: Cross-run (sauvegarde disque)

```gdscript
class_name PlayerProfileRegistry
extends RefCounted

# Style de jeu (0.0 = extreme gauche, 1.0 = extreme droite)
var play_style := {
    "aggression": 0.5,      # Prudent ↔ Reckless
    "altruism": 0.5,        # Egoiste ↔ Altruiste
    "curiosity": 0.5,       # Pragmatique ↔ Explorateur
    "patience": 0.5,        # Impulsif ↔ Methodique
    "trust_merlin": 0.5,    # Mefiant ↔ Confiant
}

# Evaluation des competences
var skill_assessment := {
    "gauge_management": 0.5,    # Capacite a equilibrer les jauges
    "pattern_recognition": 0.5, # Detecte les setups narratifs
    "risk_assessment": 0.5,     # Fait des tradeoffs informes
    "memory": 0.5,              # Se souvient des events/NPCs
}

# Preferences detectees
var preferences := {
    "preferred_themes": [],     # ["mystere", "combat", "social"]
    "avoided_themes": [],       # Themes evites
    "favorite_npcs": [],        # NPCs avec interactions positives
    "humor_receptivity": 0.5,   # 0=serieux, 1=aime l'humour
    "lore_interest": 0.5,       # Interet pour le lore profond
}

# Meta-progression
var meta := {
    "runs_completed": 0,
    "total_cards_played": 0,
    "average_run_length": 50,
    "endings_seen": [],
    "lore_fragments_discovered": [],
    "first_seen_date": 0,       # Unix timestamp
    "total_play_time_seconds": 0,
}

# Update rules
const TRAIT_LEARNING_RATE := 0.05
const SKILL_LEARNING_RATE := 0.03
const DECAY_RATE := 0.99  # Per session

func update_from_choice(card: Dictionary, option: int, outcome: Dictionary) -> void:
    # Analyse le choix et met a jour le profil
    var tags = card.get("tags", [])

    # Update aggression based on choice type
    if "aggressive" in tags:
        play_style.aggression = lerp(play_style.aggression, 1.0, TRAIT_LEARNING_RATE)
    elif "peaceful" in tags:
        play_style.aggression = lerp(play_style.aggression, 0.0, TRAIT_LEARNING_RATE)

    # Update altruism
    if "help_others" in tags:
        play_style.altruism = lerp(play_style.altruism, 1.0, TRAIT_LEARNING_RATE)
    elif "self_interest" in tags:
        play_style.altruism = lerp(play_style.altruism, 0.0, TRAIT_LEARNING_RATE)

    # Track patterns for skill assessment
    _update_skill_assessment(outcome)

func _update_skill_assessment(outcome: Dictionary) -> void:
    # Si le joueur a evite une crise, son gauge_management augmente
    if outcome.get("avoided_crisis", false):
        skill_assessment.gauge_management = lerp(
            skill_assessment.gauge_management, 1.0, SKILL_LEARNING_RATE)
```

---

### 1.2 Decision History Registry (DHR)

**Fichier**: `addons/merlin_ai/registries/decision_history_registry.gd`
**Persistance**: Per-run + compressed cross-run summary

```gdscript
class_name DecisionHistoryRegistry
extends RefCounted

const MAX_CURRENT_RUN_ENTRIES := 200
const PATTERN_DETECTION_THRESHOLD := 0.7

# Historique de la run courante
var current_run: Array[Dictionary] = []

# Patterns detectes
var patterns_detected := {}

# Resume historique (cross-run)
var historical_summary := {
    "total_choices": 0,
    "left_ratio": 0.5,
    "promise_acceptance_rate": 0.0,
    "average_gauge_at_death": {},
    "npc_karma": {},  # {"druide_noir": -30, "guerisseuse": 65}
}

func record_choice(card: Dictionary, option: int, context: Dictionary) -> void:
    var entry := {
        "card_id": card.get("id", ""),
        "card_type": card.get("type", "narrative"),
        "option": option,
        "gauges_before": context.get("gauges", {}).duplicate(),
        "gauges_after": {},  # Filled after effects applied
        "timestamp": Time.get_unix_time_from_system(),
        "day": context.get("day", 1),
        "biome": context.get("biome", ""),
        "tags": card.get("tags", []),
        "decision_time_ms": context.get("decision_time_ms", 0),
    }

    current_run.append(entry)

    # Limit size
    if current_run.size() > MAX_CURRENT_RUN_ENTRIES:
        current_run.pop_front()

    # Detect patterns
    _detect_patterns()

func _detect_patterns() -> void:
    # Pattern: Always helps strangers
    var stranger_cards = current_run.filter(func(e): return "stranger" in e.tags)
    if stranger_cards.size() >= 5:
        var help_rate = stranger_cards.filter(func(e): return e.option == 1).size() / float(stranger_cards.size())
        if help_rate > PATTERN_DETECTION_THRESHOLD:
            patterns_detected["always_helps_strangers"] = {
                "confidence": help_rate,
                "occurrences": stranger_cards.size()
            }

    # Pattern: Protects specific gauge
    for gauge in ["Vigueur", "Esprit", "Faveur", "Ressources"]:
        var protective_choices = _count_protective_choices(gauge)
        if protective_choices.rate > PATTERN_DETECTION_THRESHOLD:
            patterns_detected["protects_" + gauge.to_lower()] = {
                "confidence": protective_choices.rate,
                "occurrences": protective_choices.count
            }

func get_pattern_for_llm() -> String:
    # Generate natural language description of patterns
    var lines := []
    for pattern_name in patterns_detected:
        var data = patterns_detected[pattern_name]
        if data.confidence >= 0.7:
            lines.append(_pattern_to_french(pattern_name, data))
    return "\n".join(lines)
```

---

### 1.3 Relationship Registry (RR)

**Fichier**: `addons/merlin_ai/registries/relationship_registry.gd`
**Persistance**: Cross-run with decay

```gdscript
class_name RelationshipRegistry
extends RefCounted

# Trust tiers
enum TrustTier { DISTANT, CAUTIOUS, ATTENTIVE, BOUND }

# Seuils de confiance
const TRUST_THRESHOLDS := [25, 50, 75]

var trust_tier := TrustTier.DISTANT
var trust_points := 0  # 0-100

# Dimensions du rapport
var rapport := {
    "respect": 0.5,      # Reconnaissance des competences
    "warmth": 0.3,       # Connection emotionnelle
    "complicity": 0.4,   # Moments partages, blagues
    "reverence": 0.2,    # Respect quasi-mystique
}

# Historique d'interactions
var interactions := {
    "promises_proposed": 0,
    "promises_accepted": 0,
    "promises_kept": 0,
    "promises_broken": 0,
    "direct_addresses": 0,
    "hints_followed": 0,
    "warnings_ignored": 0,
}

# Flags speciaux
var special_moments := {
    "has_seen_melancholy": false,    # A vu la tristesse de Merlin
    "questioned_merlin": false,       # A questionne sa nature
    "thanked_merlin": false,          # Gratitude sincere
    "defied_merlin": false,           # Opposition deliberee
}

# Trust evolution rules
const TRUST_CHANGES := {
    "promise_kept": 10,
    "promise_broken": -15,
    "followed_hint": 3,
    "ignored_warning_survived": 5,
    "ignored_warning_died": -5,
    "long_run": 5,          # 100+ cards
    "quick_death": -2,      # < 20 cards
    "discovered_lore": 2,
}

func update_trust(event: String) -> void:
    var change = TRUST_CHANGES.get(event, 0)
    trust_points = clampi(trust_points + change, 0, 100)
    _update_tier()

func _update_tier() -> void:
    if trust_points >= TRUST_THRESHOLDS[2]:
        trust_tier = TrustTier.BOUND
    elif trust_points >= TRUST_THRESHOLDS[1]:
        trust_tier = TrustTier.ATTENTIVE
    elif trust_points >= TRUST_THRESHOLDS[0]:
        trust_tier = TrustTier.CAUTIOUS
    else:
        trust_tier = TrustTier.DISTANT

func get_tone_modifiers() -> Dictionary:
    # Retourne les modificateurs de ton selon le niveau de confiance
    match trust_tier:
        TrustTier.DISTANT:
            return {"humor": 1.0, "darkness": 0.0, "warmth": 0.0, "length": 0.7}
        TrustTier.CAUTIOUS:
            return {"humor": 0.95, "darkness": 0.05, "warmth": 0.1, "length": 0.85}
        TrustTier.ATTENTIVE:
            return {"humor": 0.90, "darkness": 0.10, "warmth": 0.3, "length": 1.0}
        TrustTier.BOUND:
            return {"humor": 0.85, "darkness": 0.15, "warmth": 0.5, "length": 1.2}
    return {}
```

---

### 1.4 Narrative Registry (NR)

**Fichier**: `addons/merlin_ai/registries/narrative_registry.gd`
**Persistance**: Per-run + major arcs cross-run

```gdscript
class_name NarrativeRegistry
extends RefCounted

const MAX_ACTIVE_ARCS := 2
const MAX_FORESHADOWING := 5
const THEME_FATIGUE_DECAY := 0.1

# Arcs narratifs actifs
var active_arcs: Array[Dictionary] = []
# Structure: {id, stage, cards_in_arc, flags, deadline}

# Foreshadowing plante
var foreshadowing: Array[Dictionary] = []
# Structure: {id, hint, planted_at_card, min_reveal, max_reveal, revealed}

# NPCs rencontres
var npcs := {}
# Structure: {npc_id: {encounters, last_seen, relationship, secrets_known}}

# Etat du monde
var world := {
    "biome": "broceliande",
    "day": 1,
    "season": "autumn",
    "time_of_day": "jour",
    "active_tags": [],
    "global_tension": 0.3,  # Probabilite de twist
}

# Themes recents (pour eviter repetition)
var recent_themes: Array[String] = []
var theme_fatigue := {}

func add_card_to_history(card: Dictionary) -> void:
    var themes = card.get("themes", card.get("tags", []))
    for theme in themes:
        recent_themes.append(theme)
        theme_fatigue[theme] = theme_fatigue.get(theme, 0) + 1

    # Keep only last 10
    while recent_themes.size() > 10:
        var old_theme = recent_themes.pop_front()
        theme_fatigue[old_theme] = maxf(0, theme_fatigue.get(old_theme, 1) - 1)

    # Decay all fatigue
    for t in theme_fatigue:
        theme_fatigue[t] = maxf(0, theme_fatigue[t] - THEME_FATIGUE_DECAY)

func get_theme_weight(theme: String) -> float:
    var base_weight := 1.0
    var fatigue_penalty := theme_fatigue.get(theme, 0) * 0.15
    return maxf(0.1, base_weight - fatigue_penalty)

func should_trigger_twist() -> bool:
    return randf() < world.global_tension

func increase_tension(amount: float = 0.05) -> void:
    world.global_tension = minf(1.0, world.global_tension + amount)

func get_narrative_context_for_llm() -> Dictionary:
    return {
        "active_arcs": active_arcs.map(func(a): return a.id),
        "active_foreshadowing": foreshadowing.filter(func(f): return not f.revealed).size(),
        "recent_themes": recent_themes,
        "tension_level": world.global_tension,
        "known_npcs": npcs.keys(),
        "world_state": world.duplicate(),
    }
```

---

### 1.5 Session Registry (SR)

**Fichier**: `addons/merlin_ai/registries/session_registry.gd`
**Persistance**: Cross-session

```gdscript
class_name SessionRegistry
extends RefCounted

# Session courante
var current := {
    "start_time": 0,
    "cards_this_session": 0,
    "breaks_taken": 0,
    "average_decision_time": 4.5,
    "rushed_decisions": 0,      # < 1 seconde
    "contemplated_decisions": 0, # > 10 secondes
}

# Historique
var history := {
    "total_sessions": 0,
    "total_playtime_hours": 0.0,
    "average_session_length": 38,  # minutes
    "preferred_play_times": [],    # ["evening", "night"]
    "days_since_last_play": 0,
    "longest_streak": 0,
    "current_streak": 0,
}

# Signaux d'engagement
var engagement := {
    "card_reading_speed": "normal",  # fast, normal, slow, variable
    "bestiole_care_frequency": 0.5,
    "skill_usage_rate": 0.4,
    "menu_time_ratio": 0.15,
}

# Flags de bien-etre
var wellness := {
    "long_session_warning": false,
    "suggested_break": false,
    "frustration_detected": false,
    "fatigue_detected": false,
}

const FRUSTRATION_THRESHOLD := 3  # Quick deaths + rushed decisions
const LONG_SESSION_MINUTES := 90

func record_decision(time_ms: int) -> void:
    current.cards_this_session += 1

    # Track decision speed
    if time_ms < 1000:
        current.rushed_decisions += 1
    elif time_ms > 10000:
        current.contemplated_decisions += 1

    # Update average
    var n = current.cards_this_session
    current.average_decision_time = (
        (current.average_decision_time * (n - 1) + time_ms / 1000.0) / n
    )

    _check_wellness()

func _check_wellness() -> void:
    # Detect frustration
    var session_minutes = (Time.get_unix_time_from_system() - current.start_time) / 60.0

    if current.rushed_decisions >= FRUSTRATION_THRESHOLD:
        wellness.frustration_detected = true

    if session_minutes >= LONG_SESSION_MINUTES and not wellness.suggested_break:
        wellness.suggested_break = true

    # Detect fatigue (decision time increasing)
    if current.average_decision_time > 8.0 and current.cards_this_session > 50:
        wellness.fatigue_detected = true

func get_session_context_for_llm() -> Dictionary:
    return {
        "cards_this_session": current.cards_this_session,
        "session_length_minutes": (Time.get_unix_time_from_system() - current.start_time) / 60.0,
        "is_returning_player": history.total_sessions > 0,
        "days_away": history.days_since_last_play,
        "is_long_session": wellness.suggested_break,
        "seems_frustrated": wellness.frustration_detected,
        "seems_fatigued": wellness.fatigue_detected,
    }
```

---

## 2. Context Builder — L'Agregateur

**Fichier**: `addons/merlin_ai/context_builder.gd`

```gdscript
class_name MerlinContextBuilder
extends RefCounted

var player_profile: PlayerProfileRegistry
var decision_history: DecisionHistoryRegistry
var relationship: RelationshipRegistry
var narrative: NarrativeRegistry
var session: SessionRegistry

func build_full_context(game_state: Dictionary) -> Dictionary:
    """
    Construit le contexte complet pour le LLM.
    Inclut TOUT ce que Merlin sait.
    """
    var run = game_state.get("run", {})
    var bestiole = game_state.get("bestiole", {})

    return {
        # === GAME STATE (Etat actuel) ===
        "gauges": run.get("gauges", {}),
        "aspects": run.get("aspects", {}),
        "souffle": run.get("souffle", 0),
        "day": run.get("day", 1),
        "cards_played": run.get("cards_played", 0),
        "active_promises": run.get("active_promises", []),
        "active_tags": run.get("active_tags", []),

        # === BESTIOLE ===
        "bestiole": {
            "name": bestiole.get("name", "Bestiole"),
            "bond": bestiole.get("bond", 50),
            "mood": _get_bestiole_mood(bestiole),
            "skills_ready": _get_ready_skills(bestiole),
        },

        # === PLAYER PROFILE (Qui est le joueur) ===
        "player": {
            "style": player_profile.play_style.duplicate(),
            "skill": player_profile.skill_assessment.duplicate(),
            "runs_completed": player_profile.meta.runs_completed,
            "experience_tier": _get_experience_tier(),
        },

        # === PATTERNS (Ce que Merlin a remarque) ===
        "patterns": decision_history.get_pattern_for_llm(),

        # === RELATIONSHIP (Lien Merlin-Joueur) ===
        "trust": {
            "tier": relationship.trust_tier,
            "tier_name": _trust_tier_name(relationship.trust_tier),
            "points": relationship.trust_points,
            "tone_mods": relationship.get_tone_modifiers(),
        },

        # === NARRATIVE (Arcs en cours) ===
        "narrative": narrative.get_narrative_context_for_llm(),

        # === SESSION (Contexte temps reel) ===
        "session": session.get_session_context_for_llm(),

        # === HIDDEN STATE (Pour decisions internes) ===
        "_hidden": {
            "karma": run.get("hidden", {}).get("karma", 0),
            "tension": run.get("hidden", {}).get("tension", 0),
            "theme_weights": _calculate_theme_weights(),
        },
    }

func build_llm_prompt_context(full_context: Dictionary) -> String:
    """
    Transforme le contexte en texte pour le prompt LLM.
    Format optimise pour Qwen 3B.
    """
    var lines := []

    # Jauges critiques
    var critical = _get_critical_gauges(full_context.gauges)
    if critical.size() > 0:
        lines.append("URGENT: " + ", ".join(critical))

    # Jour et progression
    lines.append("Jour %d, %d cartes jouees" % [full_context.day, full_context.cards_played])

    # Profil joueur (resume)
    var style = full_context.player.style
    if style.aggression > 0.7:
        lines.append("Joueur: audacieux, prend des risques")
    elif style.aggression < 0.3:
        lines.append("Joueur: prudent, evite les conflits")

    # Patterns detectes
    if full_context.patterns != "":
        lines.append("Tendances: " + full_context.patterns)

    # Relation
    lines.append("Confiance: %s (%d/100)" % [full_context.trust.tier_name, full_context.trust.points])

    # Narration
    if full_context.narrative.active_arcs.size() > 0:
        lines.append("Arcs actifs: " + ", ".join(full_context.narrative.active_arcs))

    # Session
    if full_context.session.seems_frustrated:
        lines.append("Note: joueur semble frustre, adoucir difficulte")
    if full_context.session.is_long_session:
        lines.append("Note: longue session, considerer pause narrative")

    return "\n".join(lines)
```

---

## 3. Generation Layer — Strategie Multi-Tier

### 3.1 Flow de Generation

```
Request Card
     │
     ▼
┌────────────────┐
│  FastRoute     │─── Confidence > 0.8 ──→ Template Engine ──→ Output
│  (Patterns)    │
└───────┬────────┘
        │ Confidence < 0.8
        ▼
┌────────────────┐
│ Template Match │─── Match Found ──→ Fill Template ──→ Output
│  (KV Cache)    │
└───────┬────────┘
        │ No Match
        ▼
┌────────────────┐
│  LLM Client    │─── Success ──→ Validate ──→ Output
│  (Qwen 3B)     │
└───────┬────────┘
        │ Failure/Timeout/Invalid
        ▼
┌────────────────┐
│ Fallback Pool  │─── Always Works ──→ Output
│ (200+ cards)   │
└────────────────┘
```

### 3.2 Fallback Pool avec Matching Contextuel

**Fichier**: `addons/merlin_ai/fallback_pool.gd`

```gdscript
class_name MerlinFallbackPool
extends RefCounted

const POOL_PATH := "res://data/ai/fallback_cards.json"

var cards_by_context := {
    "early_game": [],      # Cards 1-30
    "mid_game": [],        # Cards 31-70
    "late_game": [],       # Cards 71+
    "crisis_low": [],      # Gauge < 15
    "crisis_high": [],     # Gauge > 85
    "recovery": [],        # Balancing cards
    "universal": [],       # Always valid
    "merlin_direct": [],   # Merlin commentary
    "promise": [],         # Promise cards
}

var recently_used: Array[String] = []
const RECENT_LIMIT := 20

func get_fallback_card(context: Dictionary) -> Dictionary:
    var pool := _select_pool(context)
    var valid := _filter_valid(pool, context)
    var weighted := _apply_weights(valid, context)

    if weighted.is_empty():
        # Dernier recours: universal pool
        weighted = cards_by_context.universal.duplicate()

    # Eviter repetitions
    weighted = weighted.filter(func(c): return c.id not in recently_used)

    if weighted.is_empty():
        # Reset recent si on a tout epuise
        recently_used.clear()
        weighted = _select_pool(context)

    var selected = _weighted_random(weighted)
    recently_used.append(selected.id)
    if recently_used.size() > RECENT_LIMIT:
        recently_used.pop_front()

    return selected

func _select_pool(context: Dictionary) -> Array:
    var pools := []

    # Par progression
    var cards_played = context.get("cards_played", 0)
    if cards_played < 30:
        pools.append_array(cards_by_context.early_game)
    elif cards_played < 70:
        pools.append_array(cards_by_context.mid_game)
    else:
        pools.append_array(cards_by_context.late_game)

    # Par etat de crise
    var gauges = context.get("gauges", {})
    for gauge_name in gauges:
        var value = gauges[gauge_name]
        if value < 15:
            pools.append_array(cards_by_context.crisis_low)
        elif value > 85:
            pools.append_array(cards_by_context.crisis_high)

    # Toujours ajouter universal
    pools.append_array(cards_by_context.universal)

    return pools

func _apply_weights(cards: Array, context: Dictionary) -> Array:
    var weighted := []
    var theme_weights = context.get("_hidden", {}).get("theme_weights", {})

    for card in cards:
        var weight := 1.0

        # Theme fatigue
        for theme in card.get("tags", []):
            weight *= theme_weights.get(theme, 1.0)

        # Bonus si correspond au biome
        if card.get("biome", "") == context.get("narrative", {}).get("world_state", {}).get("biome", ""):
            weight *= 1.5

        # Bonus si resolution d'arc
        if card.get("arc_id", "") in context.get("narrative", {}).get("active_arcs", []):
            weight *= 2.0

        weighted.append({"card": card, "weight": weight})

    return weighted
```

---

## 4. Adaptive Processors

### 4.1 Difficulty Adapter

```gdscript
class_name DifficultyAdapter
extends RefCounted

var player_skill := 0.5  # From PlayerProfileRegistry

# Pity system
var consecutive_deaths := 0
var cards_since_crisis := 0

const PITY_THRESHOLD_DEATHS := 3
const PITY_DURATION_CARDS := 10

func scale_effect(base_value: int, effect_type: String, context: Dictionary) -> int:
    var skill_factor := lerpf(0.7, 1.3, player_skill)

    # Mercy after deaths
    if consecutive_deaths >= PITY_THRESHOLD_DEATHS:
        if effect_type == "negative":
            skill_factor *= 0.6
        else:
            skill_factor *= 1.4

    # Crisis protection
    var gauges = context.get("gauges", {})
    var any_critical := false
    for g in gauges.values():
        if g < 15 or g > 85:
            any_critical = true
            break

    if any_critical:
        if effect_type == "negative":
            skill_factor *= 0.5
        else:
            skill_factor *= 1.5

    return roundi(base_value * skill_factor)
```

### 4.2 Narrative Scaler

```gdscript
class_name NarrativeScaler
extends RefCounted

enum Tier { INITIATE, APPRENTICE, JOURNEYER, ADEPT, MASTER }

func get_tier(runs_completed: int) -> Tier:
    if runs_completed <= 5:
        return Tier.INITIATE
    elif runs_completed <= 20:
        return Tier.APPRENTICE
    elif runs_completed <= 50:
        return Tier.JOURNEYER
    elif runs_completed <= 100:
        return Tier.ADEPT
    else:
        return Tier.MASTER

func get_features(tier: Tier) -> Dictionary:
    return {
        Tier.INITIATE: {
            "max_arc_length": 0,
            "max_active_arcs": 0,
            "foreshadowing": false,
            "twist_probability": 0.0,
            "lore_frequency": 0.0,
        },
        Tier.APPRENTICE: {
            "max_arc_length": 2,
            "max_active_arcs": 1,
            "foreshadowing": false,
            "twist_probability": 0.05,
            "lore_frequency": 0.02,
        },
        Tier.JOURNEYER: {
            "max_arc_length": 5,
            "max_active_arcs": 2,
            "foreshadowing": true,
            "twist_probability": 0.10,
            "lore_frequency": 0.05,
        },
        Tier.ADEPT: {
            "max_arc_length": 7,
            "max_active_arcs": 2,
            "foreshadowing": true,
            "twist_probability": 0.15,
            "lore_frequency": 0.08,
        },
        Tier.MASTER: {
            "max_arc_length": 10,
            "max_active_arcs": 3,
            "foreshadowing": true,
            "twist_probability": 0.20,
            "lore_frequency": 0.12,
        },
    }[tier]
```

---

## 5. Robustness — Incassable par Design

### 5.1 Timeout & Retry Strategy

```gdscript
const LLM_TIMEOUT_MS := 5000
const MAX_RETRIES := 2
const RETRY_DELAY_MS := 100

func generate_card_robust(context: Dictionary) -> Dictionary:
    # Tier 1: Try FastRoute
    var fast = FastRoute.get_template(context)
    if fast.confidence >= 0.8:
        return fast.card

    # Tier 2: Try LLM with retries
    for attempt in range(MAX_RETRIES):
        var result = await _generate_with_timeout(context, LLM_TIMEOUT_MS)
        if result.ok:
            var validated = _validate_and_sanitize(result.card)
            if validated.ok:
                return validated.card
        await get_tree().create_timer(RETRY_DELAY_MS / 1000.0).timeout

    # Tier 3: Fallback pool (always works)
    return fallback_pool.get_fallback_card(context)
```

### 5.2 Content Validation

```gdscript
const FORBIDDEN_WORDS := [
    "simulation", "programme", "ia", "intelligence artificielle",
    "serveur", "ordinateur", "bug", "glitch", "code",
    "fin du monde", "apocalypse", "mort de merlin",
]

const REQUIRED_STRUCTURE := {
    "text": TYPE_STRING,
    "options": TYPE_ARRAY,
}

func validate_card(card: Dictionary) -> Dictionary:
    var errors := []

    # Structure check
    for key in REQUIRED_STRUCTURE:
        if not card.has(key):
            errors.append("Missing key: " + key)

    # Content check
    var text = str(card.get("text", "")).to_lower()
    for word in FORBIDDEN_WORDS:
        if word in text:
            errors.append("Forbidden word: " + word)

    # Effect bounds check
    for option in card.get("options", []):
        for effect in option.get("effects", []):
            if not _validate_effect_bounds(effect):
                errors.append("Effect out of bounds")

    return {
        "ok": errors.is_empty(),
        "errors": errors,
        "card": _sanitize_card(card) if errors.is_empty() else {}
    }
```

---

## 6. Integration avec DruStore

**Fichier modifie**: `scripts/dru/dru_store.gd`

```gdscript
# Ajouter en haut du fichier
var merlin: MerlinOmniscient = null

func _ready() -> void:
    # ... existing code ...

    # Initialize Merlin Omniscient System
    if ClassDB.class_exists("MerlinLLM"):
        merlin = MerlinOmniscient.new()
        merlin.setup(self)
        add_child(merlin)

# Modifier la generation de cartes
func _get_next_card() -> Dictionary:
    if merlin != null and merlin.is_ready():
        var context = merlin.build_context(state)
        return await merlin.generate_card(context)
    else:
        return cards.get_next_card(state)  # Fallback to scripted

# Apres chaque choix, informer Merlin
func _after_choice(card: Dictionary, option: int, outcome: Dictionary) -> void:
    if merlin != null:
        merlin.record_choice(card, option, outcome)
```

---

## 7. Fichiers a Creer

```
addons/merlin_ai/
├── merlin_omniscient.gd        <- Orchestrateur principal
├── context_builder.gd          <- Agregation contexte
├── registries/
│   ├── player_profile_registry.gd
│   ├── decision_history_registry.gd
│   ├── relationship_registry.gd
│   ├── narrative_registry.gd
│   └── session_registry.gd
├── processors/
│   ├── difficulty_adapter.gd
│   ├── narrative_scaler.gd
│   └── tone_controller.gd
├── generators/
│   ├── template_engine.gd
│   └── fallback_pool.gd
└── data/
    └── fallback_cards.json
```

---

## 8. Metrics de Succes

| Metrique | Cible | Critique |
|----------|-------|----------|
| Temps generation carte | < 500ms (cache), < 3s (LLM) | > 5s |
| Taux fallback | < 20% | > 40% |
| Coherence narrative | > 80% player satisfaction | < 60% |
| Trust progression | Naturelle sur 20+ runs | Stagnante |
| Run moyenne | 50-100 cartes | < 30 ou > 150 |

---

*Document: MOS_ARCHITECTURE.md*
*Version: 1.0.0*
*Date: 2026-02-08*
*Status: READY FOR IMPLEMENTATION*
