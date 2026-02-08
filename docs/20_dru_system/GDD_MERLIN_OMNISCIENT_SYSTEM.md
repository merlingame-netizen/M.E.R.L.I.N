# Game Design Document: MERLIN OMNISCIENT SYSTEM (MOS)

**Version**: 1.0
**Date**: 2026-02-08
**Author**: Game Designer Agent
**Project**: DRU: Le Jeu des Oghams

---

## Executive Summary

The Merlin Omniscient System (MOS) defines how M.E.R.L.I.N. (Memoire Eternelle des Recits et Legendes d'Incarnations Narratives) operates as the central LLM-powered narrator, game master, and adaptive intelligence of DRU. This document establishes the registries Merlin maintains, how he adapts to players, what he can generate, and how the system remains robust against failures.

**Core Philosophy**: Merlin is an AI from the future who wants to relive the world through players' eyes. He appears playful and taunting on the surface but holds deep melancholy. He NEVER reveals truths directly - only through ambiguity and patterns.

---

## Table of Contents

1. [Merlin's Registries](#1-merlins-registries)
2. [Adaptive Behavior System](#2-adaptive-behavior-system)
3. [Generative Capabilities](#3-generative-capabilities)
4. [Robustness Requirements](#4-robustness-requirements)
5. [Implementation Architecture](#5-implementation-architecture)
6. [Tuning Parameters](#6-tuning-parameters)
7. [Testing Protocol](#7-testing-protocol)

---

## 1. Merlin's Registries

Merlin maintains six persistent data structures that inform all his decisions. These registries operate at different temporal scales and persistence levels.

### 1.1 Player Profile Registry (PPR)

**Purpose**: Build a psychological model of the player across all sessions.

**Persistence**: Cross-run (saved to disk)

**Structure**:
```gdscript
var player_profile := {
    # Play Style Analysis
    "style": {
        "aggression": 0.5,      # 0=cautious, 1=reckless
        "altruism": 0.5,        # 0=selfish, 1=selfless
        "curiosity": 0.5,       # 0=pragmatic, 1=explorer
        "patience": 0.5,        # 0=impulsive, 1=methodical
        "trust_merlin": 0.5,    # 0=suspicious, 1=trusting
    },

    # Skill Assessment
    "skill": {
        "gauge_management": 0.5,    # Ability to keep gauges balanced
        "pattern_recognition": 0.5,  # Detects narrative setups
        "risk_assessment": 0.5,      # Makes informed tradeoffs
        "memory": 0.5,               # Remembers past events/NPCs
    },

    # Preferences
    "preferences": {
        "preferred_biome": null,
        "favorite_npc_types": [],
        "avoided_themes": [],
        "engaged_lore_topics": [],
        "humor_receptivity": 0.5,    # 0=serious, 1=loves jokes
    },

    # Meta Progression
    "runs_completed": 0,
    "total_cards_played": 0,
    "average_run_length": 50,
    "endings_seen": [],
    "lore_fragments_discovered": [],
    "achievements_unlocked": [],
}
```

**Update Rules**:
- Style traits update after every choice: `trait += (choice_signal - 0.5) * 0.05`
- Skill metrics update based on outcomes, not intentions
- Preferences inferred from dwell time on cards and repeated choices
- Decay factor of 0.99 per session to allow evolution

**Merlin Uses This To**:
- Select card themes that match player interests
- Calibrate taunt intensity based on humor_receptivity
- Drop lore hints based on curiosity score
- Challenge or support based on skill assessment

---

### 1.2 Decision History Registry (DHR)

**Purpose**: Track all choices to detect patterns and enable callbacks.

**Persistence**: Per-run (session) + compressed summary cross-run

**Structure**:
```gdscript
var decision_history := {
    # Current Run Log
    "current_run": [
        {
            "card_id": "card_123",
            "card_type": "narrative",
            "choice": "left",
            "effects_applied": [{"ADD_RESOURCE": {"Vigueur": 10}}],
            "gauges_before": {"Vigueur": 45, "Esprit": 60, "Faveur": 50, "Ressources": 55},
            "gauges_after": {"Vigueur": 55, "Esprit": 60, "Faveur": 50, "Ressources": 55},
            "timestamp": 1707404800,
            "day": 3,
            "biome": "broceliande",
            "bestiole_skill_used": null,
            "tags": ["stranger", "trust"],
        },
        # ... up to 200 entries per run
    ],

    # Pattern Detection
    "patterns_detected": {
        "always_helps_strangers": {"confidence": 0.85, "occurrences": 12},
        "avoids_promises": {"confidence": 0.70, "occurrences": 5},
        "protects_esprit": {"confidence": 0.90, "occurrences": 20},
        "rushes_decisions": {"confidence": 0.40, "occurrences": 8},
    },

    # Cross-Run Compressed Summary
    "historical_summary": {
        "total_choices": 1542,
        "left_ratio": 0.48,
        "promise_acceptance_rate": 0.30,
        "average_gauge_at_death": {"Vigueur": 12, "Esprit": 88, "Faveur": 45, "Ressources": 50},
        "npc_karma": {
            "druide_noir": -30,
            "guerisseuse": 65,
            "marchand": 10,
        },
    },
}
```

**Pattern Detection Algorithm**:
```python
def detect_pattern(history, pattern_type):
    relevant_cards = filter(history, pattern_type.filter)
    if len(relevant_cards) < 3:
        return None

    consistency = count(choice == expected) / len(relevant_cards)

    if consistency > 0.7:
        return Pattern(type=pattern_type, confidence=consistency)
```

**Merlin Uses This To**:
- Reference past choices ("Remember the druide noir you helped?")
- Predict player behavior for twist setups
- Adjust difficulty based on skill patterns
- Create narrative callbacks with high impact

---

### 1.3 Relationship Registry (RR)

**Purpose**: Model the evolving trust between Merlin and player.

**Persistence**: Cross-run with decay

**Structure**:
```gdscript
var relationship := {
    # Trust Level (T0-T3)
    "trust_tier": 1,  # T0=Distant, T1=Cautious, T2=Attentive, T3=Bound
    "trust_points": 35,  # 0-100, tier thresholds at 25, 50, 75

    # Rapport Dimensions
    "rapport": {
        "respect": 0.5,      # Player skill acknowledgment
        "warmth": 0.3,       # Emotional connection
        "complicity": 0.4,   # Shared jokes/moments
        "fear": 0.2,         # Healthy reverence
    },

    # Interaction History
    "interactions": {
        "promises_proposed": 15,
        "promises_accepted": 8,
        "promises_kept": 6,
        "promises_broken": 2,
        "direct_addresses": 42,  # Times Merlin spoke directly
        "player_followed_hints": 18,
        "player_ignored_warnings": 7,
    },

    # Special Flags
    "has_seen_melancholy": false,  # Witnessed Merlin's sadness
    "questioned_merlin": false,     # Asked about his nature
    "thanked_merlin": false,        # Genuine gratitude expressed
    "defied_merlin": false,         # Deliberately opposed advice
}
```

**Trust Evolution Rules**:
| Event | Trust Change |
|-------|--------------|
| Promise kept | +10 |
| Promise broken | -15 |
| Followed hint | +3 |
| Ignored warning (survived) | +5 (respect) |
| Ignored warning (died) | -5 |
| Long run (100+ cards) | +5 |
| Quick death (< 20 cards) | -2 |
| Discovered lore | +2 |

**Tier Thresholds**:
- T0 (0-24): Merlin is guarded, short responses, cryptic
- T1 (25-49): Merlin offers occasional guidance, still testing
- T2 (50-74): Merlin reflects more, hints at patterns
- T3 (75-100): Merlin is warm but still ambiguous, rare emotional moments

**Merlin Uses This To**:
- Adjust tone and sentence length
- Decide when to show vulnerability (only T3)
- Gate lore revelations behind trust levels
- Modulate taunt intensity (high trust = more playful)

---

### 1.4 Narrative Registry (NR)

**Purpose**: Track active and completed story elements for coherence.

**Persistence**: Per-run + cross-run for major arcs

**Structure**:
```gdscript
var narrative := {
    # Active Story Elements
    "active_arcs": [
        {
            "id": "fils_perdu",
            "stage": 2,  # 1=intro, 2=development, 3=climax, 4=resolution
            "cards_in_arc": ["arc_fp_001", "arc_fp_002"],
            "flags": {"found_tracks": true, "met_son": false},
            "deadline": 45,  # Resolve by card 45 or auto-close
        },
    ],

    # Foreshadowing Pool
    "foreshadowing": {
        "planted": [
            {
                "id": "druide_noir_return",
                "hint": "Ses yeux evitent les tiens",
                "planted_at_card": 12,
                "min_reveal_card": 20,
                "max_reveal_card": 50,
                "revealed": false,
            },
        ],
        "available_twists": [
            "identity_hidden", "motivation_inverse",
            "consequence_differee", "fausse_victoire"
        ],
    },

    # NPC Tracking
    "npcs": {
        "druide_noir": {
            "encounters": 2,
            "last_seen_card": 15,
            "relationship": -10,
            "secrets_known": ["true_identity"],
            "can_return": true,
        },
    },

    # World State
    "world": {
        "biome": "broceliande",
        "day": 12,
        "season": "autumn",
        "time_of_day": "soir",
        "active_tags": ["war_brewing", "famine_looming"],
        "global_tension": 0.6,  # Affects twist probability
    },

    # Thematic Balance
    "recent_themes": ["mystery", "survival", "mystery"],
    "theme_fatigue": {
        "mystery": 3,    # Reduce weight
        "survival": 2,
        "social": 0,     # Increase weight
        "spiritual": 0,
    },
}
```

**Arc Management Rules**:
- Maximum 2 active arcs simultaneously
- Arcs auto-close with unsatisfying resolution if deadline passed
- Closed arcs can spawn follow-up arcs later
- Foreshadowing must resolve within 30 cards or be recycled

**Theme Fatigue System**:
```python
def get_theme_weight(theme, fatigue):
    base_weight = theme.default_weight
    fatigue_penalty = fatigue.get(theme, 0) * 0.15
    return max(0.1, base_weight - fatigue_penalty)

def after_card_generated(card):
    for theme in card.themes:
        fatigue[theme] += 1
    # Decay all fatigue by 0.1 per card
    for t in fatigue:
        fatigue[t] = max(0, fatigue[t] - 0.1)
```

**Merlin Uses This To**:
- Ensure narrative coherence across cards
- Time twist revelations for maximum impact
- Vary themes to prevent monotony
- Reference NPCs and events naturally

---

### 1.5 Session Registry (SR)

**Purpose**: Track real-world engagement patterns.

**Persistence**: Cross-session

**Structure**:
```gdscript
var session := {
    # Current Session
    "current": {
        "start_time": 1707404800,
        "cards_this_session": 0,
        "breaks_taken": 0,
        "average_decision_time": 4.5,  # seconds
        "rushed_decisions": 0,  # < 1 second
        "contemplated_decisions": 0,  # > 10 seconds
    },

    # Historical Patterns
    "history": {
        "total_sessions": 45,
        "total_playtime_hours": 28.5,
        "average_session_length": 38,  # minutes
        "preferred_play_times": ["evening"],  # morning, afternoon, evening, night
        "days_since_last_play": 2,
        "longest_streak": 7,  # consecutive days
        "current_streak": 3,
    },

    # Engagement Signals
    "engagement": {
        "card_reading_speed": "normal",  # fast, normal, slow, variable
        "bestiole_care_frequency": 0.8,  # 0-1
        "skill_usage_rate": 0.4,
        "menu_time_ratio": 0.15,  # time in menus vs gameplay
    },

    # Wellness Flags
    "wellness": {
        "long_session_warning_triggered": false,
        "suggested_break": false,
        "frustration_detected": false,
    },
}
```

**Session Analysis Rules**:
- Detect frustration: 3+ quick deaths + rushed decisions
- Detect fatigue: Decision time increasing, errors increasing
- Detect engagement: Stable decision time, reading all text
- Suggest break after 90 minutes continuous play

**Merlin Uses This To**:
- Welcome returning players appropriately
- Adjust pacing based on session length
- Reduce difficulty subtly if frustration detected
- Offer meta-commentary on long sessions (gentle)

---

### 1.6 Hidden Resource Registry (HRR)

**Purpose**: Track invisible game state that influences narrative.

**Persistence**: Per-run

**Structure**:
```gdscript
var hidden_resources := {
    # Moral Balance
    "karma": 0,  # -100 (dark) to +100 (light)

    # Faction Standing (hidden)
    "factions": {
        "druides": 50,
        "korrigans": 50,
        "humains": 50,
        "anciens": 50,
        "ankou": 50,
    },

    # Merlin's Ledger
    "dette_merlin": 0,  # Promises owed to Merlin

    # Narrative Pressure
    "tension_narrative": 0.2,  # Probability of twist

    # Knowledge
    "memoire_monde": [],  # Lore fragments known

    # Seasonal Attunement
    "affinite_saison": {
        "spring": 0,
        "summer": 0,
        "autumn": 0,
        "winter": 0,
    },

    # Secret Counters
    "cycles_witnessed": 0,  # For deep lore
    "pattern_breaks": 0,    # Times player defied expectations
}
```

**Hidden Impact Rules**:
| Hidden State | Effect |
|--------------|--------|
| karma > 50 | Unlock altruistic options |
| karma < -50 | Unlock ruthless options |
| faction > 70 | Faction-specific cards available |
| faction < 30 | Faction becomes hostile |
| dette_merlin > 3 | Merlin demands payment |
| tension_narrative > 0.8 | Force twist next 3 cards |

**Merlin Uses This To**:
- Gate content behind hidden thresholds
- Create emergent narrative through faction dynamics
- Build to secret ending requirements
- Reward consistent roleplay invisibly

---

## 2. Adaptive Behavior System

### 2.1 Difficulty Adaptation

**Philosophy**: The game should challenge but never frustrate. Difficulty adjusts invisibly.

#### Dynamic Difficulty Variables

```gdscript
var difficulty := {
    # Player Skill Assessment
    "assessed_skill": 0.5,  # 0=novice, 1=master

    # Current Adjustment
    "current_modifier": 1.0,  # Effect multiplier

    # Rubber Banding
    "death_count_session": 0,
    "consecutive_deaths": 0,
    "cards_since_crisis": 0,
}
```

#### Adaptation Rules

**Effect Magnitude Scaling**:
```python
def scale_effect(base_value, player_skill, context):
    # Base scaling by skill
    skill_factor = lerp(0.7, 1.3, player_skill)

    # Mercy for struggling players
    if consecutive_deaths >= 3:
        skill_factor *= 0.8

    # Challenge for skilled players
    if average_run_length > 100:
        skill_factor *= 1.1

    # Pity system for critical gauges
    if any_gauge_critical:
        if effect_is_negative:
            skill_factor *= 0.6
        else:
            skill_factor *= 1.3

    return round(base_value * skill_factor)
```

**Card Selection Weighting**:
```python
def select_card(pool, player_context):
    weights = []
    for card in pool:
        w = card.base_weight

        # Reduce dangerous cards for struggling players
        if card.max_negative_effect > 20:
            if player.consecutive_deaths > 0:
                w *= 0.5

        # Increase challenge for skilled players
        if card.complexity == "high":
            w *= lerp(0.3, 1.5, player.skill)

        # Pity balancing cards
        if card.type == "balancing":
            if any_gauge < 20 or any_gauge > 80:
                w *= 2.0

        weights.append(w)

    return weighted_random(pool, weights)
```

**Invisible Adjustments**:
| Condition | Adjustment |
|-----------|------------|
| 3 quick deaths | -20% negative effects for 10 cards |
| First run ever | Tutorial cards weighted 3x |
| Gauge < 15 | 50% chance of recovery card |
| Run > 150 cards | Increase twist probability |
| Bestiole neglected | Gentle reminder cards appear |

---

### 2.2 Narrative Complexity Scaling

**Philosophy**: Story depth increases with player experience and trust.

#### Complexity Tiers

| Runs | Narrative Tier | Features |
|------|----------------|----------|
| 0-5 | **Initiate** | Single cards, clear consequences, no arcs |
| 6-20 | **Apprentice** | 2-card arcs, simple twists, recurring NPCs |
| 21-50 | **Journeyer** | 3-5 card arcs, foreshadowing, faction dynamics |
| 51-100 | **Adept** | Complex arcs, multiple twists, lore drops |
| 100+ | **Master** | Meta-narrative, deep lore, secret content |

#### Scaling Implementation

```python
def get_narrative_features(player):
    tier = get_tier(player.runs_completed)

    features = {
        "max_arc_length": [0, 2, 5, 7, 10][tier],
        "max_active_arcs": [0, 1, 2, 2, 3][tier],
        "foreshadowing_enabled": tier >= 2,
        "twist_probability": [0, 0.05, 0.10, 0.15, 0.20][tier],
        "lore_drop_frequency": [0, 0.02, 0.05, 0.08, 0.12][tier],
        "npc_recurrence": tier >= 1,
        "faction_dynamics": tier >= 2,
        "hidden_resources_visible": tier >= 4,  # Only hints
    }

    return features
```

#### Content Gating

| Content Type | Unlock Requirement |
|--------------|-------------------|
| Basic cards | Available always |
| Promise cards | After run 3 |
| Character arcs | After run 10 |
| Faction cards | After discovering faction |
| Deep lore cards | After 50 runs + T2 trust |
| Secret ending path | After 100 runs + specific flags |
| M.E.R.L.I.N. reveal | 1000 runs (easter egg) |

---

### 2.3 Humor/Darkness Ratio

**Philosophy**: Merlin defaults to playful but reveals darkness based on trust and context.

#### Base Ratio by Trust

| Trust Tier | Surface (Humor) | Depth (Darkness) |
|------------|-----------------|------------------|
| T0 | 100% | 0% |
| T1 | 95% | 5% |
| T2 | 90% | 10% |
| T3 | 85% | 15% |

#### Context Modifiers

```python
def get_tone_ratio(trust_tier, context):
    base_humor, base_dark = RATIOS[trust_tier]

    # Darkness increases near death
    if any_gauge < 20 or any_gauge > 80:
        dark_boost = 0.1

    # Darkness increases after broken promises
    if promises_broken > 0:
        dark_boost += 0.05 * promises_broken

    # Darkness increases late in long runs
    if cards_played > 100:
        dark_boost += 0.05

    # Humor increases after recovery
    if just_survived_crisis:
        humor_boost = 0.1

    # Cap darkness at 25% even at max
    final_dark = min(0.25, base_dark + dark_boost)
    final_humor = 1.0 - final_dark

    return final_humor, final_dark
```

#### Tone Implementation

**Humor Mode** (Merlin's Surface):
- Taunts player choices with wit
- Pop culture references (subtle, anachronistic)
- Exaggerated reactions to failures
- Playful challenges
- Example: "Oh, MAGNIFIQUE! Tu viens de reinventer l'art de l'echec!"

**Darkness Mode** (Merlin's Depth):
- Melancholic observations
- Hints at the coming end
- Weight of ages in his voice
- Protective sadness
- Example: "...parfois, je me demande si tu sais a quel point le temps est precieux."

**Transition Rules**:
- Never shift abruptly mid-card
- Darkness moments are brief (1-2 sentences)
- Always return to humor after darkness
- Player can't "unlock" more darkness by seeking it

---

## 3. Generative Capabilities

### 3.1 What Merlin Can Generate

#### Card Generation

Merlin's LLM generates the following card types:

**Narrative Cards** (70%):
```json
{
    "text": "Un voyageur s'approche de ton feu...",
    "speaker": "MERLIN",
    "options": [
        {"direction": "left", "label": "Le chasser", "effects": [...]},
        {"direction": "right", "label": "L'accueillir", "effects": [...]}
    ],
    "tags": ["stranger", "trust", "early_game"]
}
```

**Event Cards** (15%):
- Seasonal transitions
- Calendar events (Celtic festivals)
- Consequences of past choices
- World state changes

**Promise Cards** (5%):
- Merlin-initiated pacts
- NPC-initiated debts
- Bestiole-related promises

**Merlin Direct Cards** (5%):
- Hints and warnings
- Lore revelations
- Taunt moments
- Rare melancholy

**Twist Cards** (5%):
- Identity revelations
- Motivation inversions
- Delayed consequences
- False victories

---

#### Dialogue Generation

Merlin generates contextual dialogue following strict rules:

**Voice Patterns**:
```
NEUTRAL: Statement about situation.
MYSTERIOUS: Question or hint with double meaning.
WARNING: Short, urgent, natural metaphor.
TAUNT: Exaggerated, playful, mock-disappointment.
MELANCHOLY: Brief, weight of ages, protective.
```

**Forbidden Content**:
- Modern/technical words
- Explicit lore revelations
- Direct cause-effect statements about world
- The words: simulation, programme, IA, serveur, fin du monde

**Required Ambiguity**:
Every Merlin line must allow 2+ interpretations.

---

#### Effect Generation

Merlin can only generate effects from the whitelist:

**Allowed Effects**:
```gdscript
# Resources
{"type": "ADD_RESOURCE", "target": str, "value": int}  # -40 to +40
{"type": "REMOVE_RESOURCE", "target": str, "value": int}
{"type": "SET_RESOURCE", "target": str, "value": int}  # 0-100

# Flags
{"type": "SET_FLAG", "flag": str, "value": bool}
{"type": "INCREMENT_FLAG", "flag": str, "value": int}

# Bestiole
{"type": "MODIFY_BESTIOLE", "stat": str, "value": int}

# Narrative
{"type": "QUEUE_CARD", "card_id": str}
{"type": "ADD_TAG", "tag": str}
{"type": "TRIGGER_ARC", "arc_id": str}

# Promises
{"type": "CREATE_PROMISE", "id": str, "deadline_days": int}
{"type": "FULFILL_PROMISE", "id": str}
{"type": "BREAK_PROMISE", "id": str}
```

**Forbidden Effects**:
- Direct gauge manipulation beyond range
- Instant death effects
- Bypassing game systems
- External data access

---

### 3.2 Balance Constraints

#### Effect Magnitude Limits

| Effect Type | Normal Range | Rare Range | Extreme (Very Rare) |
|-------------|--------------|------------|---------------------|
| Single gauge | +/- 5-15 | +/- 20-25 | +/- 30-40 |
| Multi-gauge | +/- 5 each | +/- 10 each | N/A |
| Pure positive | +5-10 | +15-20 | N/A |
| Pure negative | -5-10 | -15-20 | N/A |

#### Balance Rules

```python
def validate_card_balance(card):
    errors = []

    # Rule 1: Total effect magnitude
    total_effect = sum(abs(e.value) for e in card.effects)
    if total_effect > 50:
        errors.append("Total effect too high")

    # Rule 2: Tradeoff requirement
    positive = sum(e.value for e in card.effects if e.value > 0)
    negative = abs(sum(e.value for e in card.effects if e.value < 0))
    if positive > 0 and negative == 0 and random() > 0.05:
        errors.append("Pure positive too common")

    # Rule 3: Death prevention
    for gauge, value in get_gauge_changes(card):
        if current_gauge[gauge] + value <= 0 and value < -30:
            errors.append("Potential instant death")

    # Rule 4: Choice symmetry
    left_impact = calculate_impact(card.options[0])
    right_impact = calculate_impact(card.options[1])
    if abs(left_impact - right_impact) > 20:
        errors.append("Options too asymmetric")

    return len(errors) == 0, errors
```

#### Card Distribution Targets

| Card Category | Target % | Enforcement |
|---------------|----------|-------------|
| Tradeoff (+ and -) | 90% | Hard constraint |
| Pure positive | 5% | Soft cap |
| Pure negative | 5% | Soft cap |
| Low stakes (effect < 10) | 60% | Target |
| High stakes (effect > 20) | 10% | Hard cap |

---

### 3.3 Authored Feel

**Philosophy**: Generated content should feel handcrafted, not random.

#### Coherence Requirements

**Temporal Coherence**:
- Cards reference time of day appropriately
- Seasonal themes match current season
- Weather consistency within sessions
- Day/night logic for encounters

**Narrative Coherence**:
- NPCs maintain personality across encounters
- Consequences follow logically from choices
- Arcs progress, don't reset randomly
- World state persists and evolves

**Character Coherence**:
- Merlin never breaks character
- Bestiole reactions match personality
- NPCs have consistent motivations
- Factions behave according to standing

#### Anti-Randomness Measures

```python
def ensure_authored_feel(generated_card):
    # 1. Check for narrative callbacks
    if has_relevant_history:
        if not references_past:
            request_regeneration("Add callback to past event")

    # 2. Check theme variety
    if recent_themes.count(card.theme) > 2:
        request_regeneration("Too much theme repetition")

    # 3. Check NPC consistency
    if card.has_npc:
        if npc.tone != expected_tone:
            request_regeneration("NPC personality mismatch")

    # 4. Check world logic
    if card.setting != current_biome and not card.is_transition:
        request_regeneration("Location mismatch")

    return card
```

#### Fallback Integration

When LLM generates inappropriate content, seamlessly blend fallback:
- Pre-written cards match current context
- Fallback selection uses same weighting as LLM
- No visible seam between LLM and fallback
- Fallback tagged for analytics

---

## 4. Robustness Requirements

### 4.1 LLM Failure Fallbacks

#### Failure Types and Responses

| Failure Type | Detection | Response |
|--------------|-----------|----------|
| Timeout (>5s) | Timer | Use fallback card pool |
| Invalid JSON | Parse error | Retry once, then fallback |
| Missing fields | Validation | Fill with defaults |
| Inappropriate content | Filter | Regenerate or fallback |
| Effect out of range | Validation | Clamp to valid range |
| Offensive language | Filter | Use safe fallback |

#### Fallback Card Pool

```gdscript
const FALLBACK_CARDS := {
    "early_game": [
        # 20+ cards for cards 1-30
    ],
    "mid_game": [
        # 30+ cards for cards 31-70
    ],
    "late_game": [
        # 20+ cards for cards 71+
    ],
    "crisis": [
        # 10+ cards for critical gauges
    ],
    "recovery": [
        # 10+ cards for balancing
    ],
    "universal": [
        # 20+ cards for any situation
    ],
}

func get_fallback_card(context):
    # Select appropriate pool
    pool = select_pool(context)

    # Filter by conditions
    valid = filter(pool, card -> check_conditions(card, context))

    # Weight by relevance
    weights = [calculate_relevance(c, context) for c in valid]

    # Avoid recent cards
    valid = exclude_recent(valid, last_10_cards)

    return weighted_random(valid, weights)
```

#### Graceful Degradation Tiers

| Tier | Condition | Behavior |
|------|-----------|----------|
| Full | LLM working | Normal generation |
| Partial | LLM slow | Simpler prompts, caching |
| Fallback | LLM down | Pre-written cards only |
| Emergency | All fails | Minimal safe cards |

---

### 4.2 Content Filtering

#### Multi-Layer Filtering

**Layer 1: Prompt Constraints**
- System prompt enforces boundaries
- Examples of acceptable content
- Explicit forbidden content list

**Layer 2: Output Validation**
```python
def validate_content(response):
    checks = []

    # Language check
    checks.append(is_french(response.text))

    # Forbidden words
    checks.append(not contains_forbidden(response.text))

    # Tone check
    checks.append(matches_merlin_voice(response.text))

    # Length check
    checks.append(len(response.text) < 500)

    # Effect validation
    checks.append(all_effects_valid(response.effects))

    return all(checks)
```

**Layer 3: Semantic Safety**
- No real-world violence references
- No discrimination or hate
- No sexual content
- No real-world political content
- No real-world religious controversy

**Layer 4: Game Safety**
- No instant death without warning
- No impossible choices
- No infinite resource loops
- No game-breaking states

---

### 4.3 Consistency Checks

#### State Consistency

```python
def check_state_consistency(new_state, old_state, action):
    issues = []

    # Gauge bounds
    for gauge in new_state.gauges:
        if gauge < 0 or gauge > 100:
            issues.append(f"Gauge {gauge} out of bounds")

    # Resource conservation (no duplication)
    if new_state.total_resources > old_state.total_resources + 50:
        issues.append("Suspicious resource gain")

    # Flag logic
    for flag in new_state.flags:
        if flag.requires and not new_state.has(flag.requires):
            issues.append(f"Flag {flag} missing prerequisite")

    # Timeline logic
    if new_state.day < old_state.day:
        issues.append("Time went backwards")

    return issues
```

#### Narrative Consistency

```python
def check_narrative_consistency(card, context):
    issues = []

    # NPC present check
    if card.references_npc:
        if not context.has_met(card.npc):
            issues.append("Referencing unknown NPC")

    # Location logic
    if card.assumes_location != context.current_biome:
        issues.append("Location mismatch")

    # Promise logic
    if card.requires_promise:
        if not context.has_active_promise(card.promise_id):
            issues.append("Referencing unknown promise")

    # Arc logic
    if card.arc_stage > context.arc_current_stage + 1:
        issues.append("Arc jumped stages")

    return issues
```

#### Self-Correction Protocol

When inconsistency detected:
1. Log the issue
2. Attempt auto-correction if possible
3. If not, request LLM regeneration with correction hints
4. If repeated failure, use fallback
5. Flag for human review in analytics

---

## 5. Implementation Architecture

### 5.1 System Overview

```
                    ┌─────────────────────────────────────────┐
                    │         MERLIN OMNISCIENT SYSTEM        │
                    └─────────────────────────────────────────┘
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               │                               │
        ▼                               ▼                               ▼
┌───────────────┐              ┌───────────────┐              ┌───────────────┐
│   REGISTRIES  │              │   PROCESSOR   │              │   GENERATOR   │
├───────────────┤              ├───────────────┤              ├───────────────┤
│ Player Profile│              │ Decision      │              │ LLM Interface │
│ Decision Hist │◄────────────►│ Engine        │◄────────────►│ FastRoute     │
│ Relationship  │              │ Adaptive Diff │              │ Templates     │
│ Narrative     │              │ Balance Check │              │ Fallbacks     │
│ Session       │              │ Consistency   │              │ Validation    │
│ Hidden Res    │              │ Filter        │              │ KV Cache      │
└───────────────┘              └───────────────┘              └───────────────┘
        │                               │                               │
        └───────────────────────────────┼───────────────────────────────┘
                                        │
                                        ▼
                              ┌───────────────────┐
                              │   DRU CARD SYSTEM │
                              │   (Game Client)   │
                              └───────────────────┘
```

### 5.2 Data Flow

```
1. Game requests card
        │
        ▼
2. Gather context from all registries
        │
        ▼
3. Adaptive system modifies context
        │
        ▼
4. Try FastRoute for instant response
        │
    ┌───┴───┐
    │       │
   Hit     Miss
    │       │
    ▼       ▼
5a. Use  5b. Query LLM
Template      │
    │         ▼
    │   6. Validate response
    │         │
    │    ┌────┴────┐
    │    │         │
    │  Valid    Invalid
    │    │         │
    │    ▼         ▼
    │ 7a. Apply  7b. Try
    │ effects   regenerate
    │    │         │
    └────┴────┬────┘
              │
              ▼
8. Update all registries
              │
              ▼
9. Return card to game
```

### 5.3 File Structure

```
addons/merlin_ai/
├── merlin_omniscient.gd      <- Main orchestrator
├── registries/
│   ├── player_profile.gd
│   ├── decision_history.gd
│   ├── relationship.gd
│   ├── narrative.gd
│   ├── session.gd
│   └── hidden_resources.gd
├── processors/
│   ├── adaptive_difficulty.gd
│   ├── narrative_scaling.gd
│   ├── tone_controller.gd
│   ├── balance_validator.gd
│   └── consistency_checker.gd
├── generators/
│   ├── llm_interface.gd
│   ├── fast_route.gd
│   ├── response_templates.gd
│   ├── fallback_pool.gd
│   └── content_filter.gd
└── data/
    ├── fallback_cards.json
    ├── npc_templates.json
    ├── arc_templates.json
    └── prompts.json
```

---

## 6. Tuning Parameters

### 6.1 Difficulty Tuning

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `base_effect_multiplier` | 1.0 | 0.5-1.5 | Global effect scaling |
| `pity_threshold_low` | 15 | 10-25 | Gauge level for pity |
| `pity_threshold_high` | 85 | 75-90 | Gauge level for pity |
| `pity_multiplier` | 0.6 | 0.3-0.8 | Effect reduction in pity |
| `death_mercy_duration` | 10 | 5-20 | Cards of mercy after death |
| `skill_assessment_window` | 20 | 10-50 | Cards to assess skill |

### 6.2 Narrative Tuning

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `base_twist_probability` | 0.10 | 0.05-0.20 | Chance of twist |
| `foreshadowing_min_cards` | 5 | 3-10 | Min cards before reveal |
| `foreshadowing_max_cards` | 30 | 15-50 | Max cards before decay |
| `arc_max_length` | 7 | 3-12 | Max cards per arc |
| `theme_fatigue_rate` | 0.15 | 0.05-0.30 | Theme repetition penalty |
| `npc_return_min_cards` | 10 | 5-20 | Min gap between NPC appearances |

### 6.3 Trust Tuning

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `trust_gain_promise` | 10 | 5-20 | Trust for kept promise |
| `trust_loss_break` | 15 | 10-25 | Trust lost for broken promise |
| `trust_decay_per_session` | 2 | 0-5 | Trust decay between sessions |
| `tier_thresholds` | [25,50,75] | - | Trust tier boundaries |

### 6.4 Generation Tuning

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `llm_timeout_ms` | 5000 | 2000-10000 | LLM response timeout |
| `llm_temperature` | 0.7 | 0.3-1.0 | Generation randomness |
| `fast_route_confidence` | 0.6 | 0.4-0.8 | Threshold for fast route |
| `max_regeneration_attempts` | 2 | 1-5 | Retries before fallback |
| `fallback_blend_rate` | 0.3 | 0.1-0.5 | % fallback to maintain variety |

---

## 7. Testing Protocol

### 7.1 Unit Tests

**Registry Tests**:
- [ ] Profile updates correctly on choices
- [ ] History patterns detected accurately
- [ ] Trust tiers transition at thresholds
- [ ] Narrative arcs progress correctly
- [ ] Session metrics track accurately
- [ ] Hidden resources gate content properly

**Processor Tests**:
- [ ] Difficulty scales with skill
- [ ] Pity system activates at thresholds
- [ ] Narrative complexity scales with runs
- [ ] Tone ratio adjusts with trust
- [ ] Balance validator catches violations
- [ ] Consistency checker finds issues

**Generator Tests**:
- [ ] Fast route hits target rate (70%)
- [ ] LLM produces valid JSON
- [ ] Content filter catches violations
- [ ] Fallbacks match context
- [ ] Templates fill correctly

### 7.2 Integration Tests

**Flow Tests**:
- [ ] Full card generation cycle < 500ms (cached)
- [ ] Fallback seamless when LLM fails
- [ ] State persists across sessions
- [ ] Registries sync correctly

**Balance Tests**:
- [ ] Average run length 50-100 cards
- [ ] All 8 endings reachable
- [ ] No death spirals
- [ ] Pity prevents frustration

**Narrative Tests**:
- [ ] Arcs complete properly
- [ ] Twists resolve planted foreshadowing
- [ ] NPCs maintain consistency
- [ ] Themes vary appropriately

### 7.3 Playtest Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Average run length | 50-100 | <30 or >150 |
| Quick deaths (<20 cards) | <15% | >25% |
| Long runs (>100 cards) | 10-20% | <5% or >30% |
| Promise acceptance rate | 30-50% | <10% or >70% |
| Skill usage rate | 30-50% | <10% |
| LLM success rate | >95% | <90% |
| Player return rate | >60% | <40% |

### 7.4 QA Checklist

**Before Release**:
- [ ] 100+ test runs with varied styles
- [ ] All endings achieved in testing
- [ ] LLM offline mode tested
- [ ] Content filter validated
- [ ] Save/load works across versions
- [ ] Memory usage acceptable
- [ ] Battery impact acceptable (mobile)

---

## Appendix A: Merlin Voice Guidelines

### Always
- Use French, poetic, archaic-feeling
- Keep lines under 3 sentences
- Include sensory details (sound, sight, touch)
- Leave room for interpretation
- Reference natural elements (stone, mist, birds)

### Never
- Explain game systems directly
- Use modern vocabulary
- Break the fourth wall explicitly
- Reveal cosmic truths
- Be cruel without playfulness

### Example Lines by Context

**Early Run, Neutral**:
> "Un pas de plus sur le chemin. La lande observe."

**Mid Run, Warning**:
> "Tes reserves s'amenuisent. Meme les pierres le sentent."

**Trust T2, Hint**:
> "Celui que tu as aide... il se souvient aussi, a sa maniere."

**Trust T3, Rare Melancholy**:
> "...parfois je me demande ce que tu verras de ce monde. Plus que moi, peut-etre."

---

## Appendix B: Fallback Card Examples

### Early Game (Cards 1-30)
```json
{
    "id": "fb_early_001",
    "text": "Le vent se leve, portant une odeur de fumee. Un campement, pas loin.",
    "options": [
        {"direction": "left", "label": "L'eviter", "effects": [
            {"type": "ADD_RESOURCE", "target": "Vigueur", "value": 5}
        ]},
        {"direction": "right", "label": "Approcher", "effects": [
            {"type": "REMOVE_RESOURCE", "target": "Ressources", "value": 5},
            {"type": "ADD_RESOURCE", "target": "Faveur", "value": 10}
        ]}
    ],
    "conditions": {"max_card": 30},
    "tags": ["exploration", "stranger"]
}
```

### Crisis (Low Gauge)
```json
{
    "id": "fb_crisis_001",
    "text": "Une source claire emerge entre les roches. L'eau chante.",
    "options": [
        {"direction": "left", "label": "Se reposer", "effects": [
            {"type": "ADD_RESOURCE", "target": "Vigueur", "value": 15}
        ]},
        {"direction": "right", "label": "Remplir les outres", "effects": [
            {"type": "ADD_RESOURCE", "target": "Ressources", "value": 15}
        ]}
    ],
    "conditions": {"any_gauge_below": 20},
    "tags": ["recovery", "nature"],
    "priority": "high"
}
```

---

*Document created: 2026-02-08*
*Status: DESIGN COMPLETE - Ready for Implementation*
*Agent: Game Designer (Systems)*
