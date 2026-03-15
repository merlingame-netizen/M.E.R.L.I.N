# MerlinOmniscient — Architecture Complète

**Dernière mise à jour** : 2026-03-15
**Version** : 1.0.0
**Fichier source** : `addons/merlin_ai/merlin_omniscient.gd` (~2664 lignes, 108KB)

---

## 1. Rôle

**MerlinOmniscient** est l'orchestrateur IA central du jeu M.E.R.L.I.N. (*Mémoire Éternelle des Récits et Légendes d'Incarnations Narratives*). Il coordonne **TOUS** les systèmes narratifs, de récomputation, et de profilage pour générer des cartes narratives cohérentes, adaptées, et impossibles à prédire.

### Responsabilités

1. **Génération de cartes** — orchestrer N stratégies LLM (Swarm, Adapter, Sequential, Direct)
2. **Gestion des registres** — 5 registries cross-run (Profil Joueur, Historique Décisions, Relation, Narratif, Session)
3. **Filtrage de sécurité** — guardrails (langue FR, mots interdits, répétition, longueur)
4. **Danger & Adaptation** — détection état critique (vie, confiance) + ajustement difficulté
5. **Contexte RAG** — synchronisation vers RAG v2.0 pour enrichissement dynamique
6. **Événements calendrier** — injection probabiliste d'événements narratifs
7. **Préchargement** — prefetch asynchrone de cartes N+1, N+2, N+3 (swarm BitNet)
8. **Sauvegarde** — persistance cross-run, run-state, journal RAG

---

## 2. Architecture

### 2.1 Position dans la hiérarchie IA

```
MerlinGameController (scene UI)
    ↓
MerlinOmniscient (orchestrateur)
    ├─ llm_interface → /root/MerlinAI (autoload, multi-brain Qwen 3.5)
    ├─ rag_manager → RAGManager (v2.0, contexte dynamique)
    ├─ context_builder → MerlinContextBuilder
    ├─ difficulty_adapter → DifficultyAdapter (P1.1)
    ├─ event_adapter → EventAdapter (calendrier, sabbats)
    ├─ event_selector → EventCategorySelector (Phase 44, typologies cartes)
    ├─ narrative_scaler → NarrativeScaler
    ├─ tone_controller → ToneController
    ├─ _quality_judge → BrainQualityJudge (Swarm best-of-N)
    └─ 5 Registries (persistent)
        ├─ player_profile → PlayerProfileRegistry
        ├─ decision_history → DecisionHistoryRegistry
        ├─ relationship → RelationshipRegistry
        ├─ narrative → NarrativeRegistry
        └─ session → SessionRegistry
```

### 2.2 Initialisation

```gdscript
# _ready() (ligne 119)
_init_registries()                    # Charge depuis disk
_init_processors()                    # Crée context_builder, adapters
_init_generators()                    # Cherche /root/MerlinAI + RAG
_connect_signals()                    # Wire signals registries
_quality_judge = BrainQualityJudge.new()

# setup(store: Node) (ligne 127)
_store = store                        # Référence DruStore (accès scenario_manager)
_is_ready = true
```

### 2.3 Cycle de vie génération

```
generate_card(game_state)
    ↓
1. Wait si generation/prefetch en cours
    ↓
2. Build full context (MerlinContextBuilder)
    ↓
3. Apply danger rules (DANGER_LIFE_CRITICAL, etc.)
    ↓
4. Inject scenario anchor (si scenario actif)
    ↓
5. Try prefetch (si valide)
    ├─ YES → return prefetched
    └─ NO  → continue
    ↓
6. Select event category (Phase 44, EventCategorySelector)
    ↓
7. Sync MOS → RAG v2.0 (registries to context)
    ↓
8. Apply adaptive processing (difficulty scaling)
    ↓
9. Generate with strategy (S/A/B/SEQ/C)
    ↓
10. Apply guardrails (langue, répétition, mots interdits)
    ↓
11. Validate & sanitize card
    ↓
12. Post-process (difficulty scaling appliquée)
    ↓
13. Tag scenario anchor (si present)
    ↓
14. Apply card modifier (Phase 44)
    ↓
15. Log to RAG journal
    ↓
16. Update stats + emit signal
```

---

## 3. Guardrails (Sécurité & Qualité)

**Source** : `_apply_guardrails()` (ligne 1524)

### 3.1 Hiérarchie (Soft vs Hard)

- **LLM source** : soft warnings (Qwen peut mélanger langues, halluciner)
- **Fallback/Pool source** : hard rejects (données statiques doivent être parfaites)

### 3.2 Chèques appliquées

| Ordre | Chèque | Hard Reject | Soft Warning | Seuil |
|-------|--------|------------|-------------|-------|
| 1 | Longueur critique | `text.length() < 5` | N/A | N/A |
| 2 | Longueur normal | Non-LLM | LLM seulement | 30–800 chars |
| 3 | Langue française | Non-LLM | LLM seulement | ≥2 keywords FR |
| 4 | Mots interdits persona | Non-LLM | LLM seulement | whole-word match |
| 5 | Répétition | Non-LLM | LLM seulement | Jaccard ≥0.5 |

**Code** (ligne 1534–1577):

```gdscript
# 1. Length critical → always reject
if text.length() < 5:
    return {}  # Hard reject

# 2. Length normal → soft for LLM
if text.length() < 30 or text.length() > 800:
    if is_llm:
        push_warning("[MOS] Guardrail soft: text length...")
    else:
        return {}

# 3. French language → soft for LLM
if not _check_french_language(text):
    if is_llm:
        push_warning("[MOS] Guardrail soft: French language check failed")
    else:
        return {}

# 4. Persona forbidden words → soft for LLM
var forbidden_hit: String = _find_forbidden_word(text)
if not forbidden_hit.is_empty():
    if is_llm:
        push_warning("[MOS] Guardrail soft: forbidden word '%s' (allowing)" % forbidden_hit)
    else:
        return {}

# 5. Repetition → soft for LLM
if _is_repetitive(text):
    if is_llm:
        push_warning("[MOS] Guardrail soft: repetitive text detected")
    else:
        return {}
```

### 3.3 Constantes de Guardrails

```gdscript
const GUARDRAIL_MIN_TEXT_LEN := 30
const GUARDRAIL_MAX_TEXT_LEN := 800
const GUARDRAIL_LANG_KEYWORDS := ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et"]
const GUARDRAIL_LANG_THRESHOLD := 2  # min French keywords
const RECENT_CARDS_MEMORY := 15      # dernières cartes tracées
const REPETITION_SIMILARITY_THRESHOLD := 0.5  # Jaccard similarity
```

### 3.4 Détection Mots Interdits

**Fonction** : `_find_forbidden_word()` (ligne 1593)

```gdscript
## Check whole-word match (space-delimited)
## Prevents "ia" matching "confiance"
for word in _persona_forbidden_words:
    if lower.contains(" " + word + " ") or
       lower.begins_with(word + " ") or
       lower.ends_with(" " + word) or
       lower == word:
        return word
return ""
```

Mots interdits chargés depuis `merlin_persona.json` via `MerlinAI.generate_with_system()`.

### 3.5 Détection Répétition

**Fonction** : `_is_repetitive()` (ligne 1606)

```gdscript
## Jaccard similarity word-level
var similarity := _jaccard_similarity(lower, recent.to_lower())
if similarity >= REPETITION_SIMILARITY_THRESHOLD:  # 0.5
    return true
```

Garde les 15 dernières cartes en mémoire (`_recent_card_texts`).

---

## 4. Convergence MOS (Tension Narrative)

### 4.1 Systèmes imbriqués

**MOS** (Merlin Omniscient System) = concept meta de **convergence narrative**.

Les cartes du jeu convergent vers **soft min 8, target 20–25, soft max 40, hard max 50** via:

1. **Tension implicite** — cartes injectent tension progressive
2. **Réputation cumulée** — actions joueur convergent factions
3. **Promesses** — créent attentes narratives
4. **Arcs narratifs** — structurent runs autour d'objectifs
5. **Confiance Merlin** — T0 → T3, change implicitement ton + options

### 4.2 Calcul Tension

**Fonction** : `calculate_tension()` (ligne 2375)

```gdscript
func calculate_tension(state: Dictionary) -> float:
    ## Calcule tension basee sur
    ## - vie decroissante
    ## - factions divergentes
    ## - promesses non tenues
    ## - run phase (escalade dramatique)
    var tension := 0.0

    # Phase narrative augmente tension
    # Factions opposées = tension
    # Vie basse = stress
    # Promesses = enjeu
```

### 4.3 Application Pacing

**Fonction** : `apply_pacing()` (ligne 2414)

Ajuste carte générée via difficulty_adapter pour maintenir courbe tension.

---

## 5. Routage des Brains (Sélection stratégie)

### 5.1 Pipeline stratégies (ordre priorité)

**Fonction** : `_generate_with_strategy()` (ligne 724)

```
Strategy S: Swarm (BitNet)       — best-of-N + refinement
    ↓ (si disabled/failed)
Strategy A: Adapter              — parse étapes, gm effects
    ↓ (si failed)
Strategy B: Adapter fallback      — direct LLM si A échoue
    ↓ (si failed)
Strategy SEQ: Sequential          — narrator → parse → gm
    ↓ (si failed)
Strategy C: Direct LLM            — fallback classique
    ↓ (si tout échoue)
Return {}                         — empty, controller retry
```

### 5.2 Strategy S — Swarm (Best-of-N)

**Fonction** : `_try_swarm_generation()` (ligne 850)

```gdscript
# 1. Generate N=2 variants avec temperature différente
for i in range(n_variants):  # N=2 by default
    var result = await llm_interface.generate_with_system(
        system_prompt, user_prompt,
        {"max_tokens": 200, "temperature": base_temp + i*0.1}
    )
    if valid: candidates.append(result.text)

# 2. Quality Judge scores & picks best
var best = _quality_judge.pick_best(candidates)
var best_score = best.score  # 0.0–1.0

# 3. Refinement si score bas
if best_score < BrainQualityJudge.GOOD_SCORE:
    var refinement_prompt = _quality_judge.suggest_refinement(best_text)
    var refined = await llm_interface.generate_with_system(...)
    if refined.score > best.score:
        best = refined

# 4. Reject si < MIN_ACCEPTABLE_SCORE
if best_score < BrainQualityJudge.MIN_ACCEPTABLE_SCORE:
    return {}

# 5. Parse + return
return _parse_llm_response(best_text)
```

### 5.3 Strategy A/B — Adapter (JSON Structure)

**Fonction** : `_try_llm_generation()` (ligne 762)

Appelle `llm_interface.generate_adapter()` qui:
- Injecte template JSON en user prompt
- Parse réponse en card dict
- Hard rejects si JSON malformé

### 5.4 Strategy SEQ — Sequential (P1.5)

**Fonction** : `_try_sequential_generation()` (ligne 920)

```gdscript
# 1. Narrator stage → card structure brute
var seq_context = {
    "biome": ..., "day": ..., "life": ...,
    "danger_context": ..., "player_summary": ...
}
var card = await llm_interface.generate_sequential(seq_context)

# 2. GM stage (si implemented) → effect parsing
# Embedded dans generate_sequential()

# 3. Parse + return
if card.text.length() > 10 and card.options.size() >= 3:
    return card
return {}
```

### 5.5 Strategy C — Direct LLM (Fallback)

```gdscript
var system_prompt = _build_system_prompt()
var user_prompt = _build_user_prompt()

for attempt in range(MAX_RETRIES):  # 2 retries max
    var result = await llm_interface.generate_with_system(
        system_prompt, user_prompt,
        {"max_tokens": 200, "temperature": _get_temperature_for_context()}
    )
    var parsed = _parse_llm_response(result.text)
    if not parsed.is_empty():
        return parsed
return {}
```

### 5.6 Sélection Temperature

**Fonction** : `_get_temperature_for_context()` (ligne 1220)

```gdscript
var base_temp := 0.7

# Danger level → lower creativity (safer)
if danger_level >= 2:
    return 0.4  # Critical/Low life
elif danger_level >= 1:
    return 0.5  # Wounded

# Confidence Merlin → higher creativity (more mystery)
if trust_tier == 3:
    return 0.9  # T3 = très confiant
elif trust_tier == 2:
    return 0.8  # T2 = moyen

return base_temp  # T0/T1 = 0.7
```

---

## 6. Synchronisation État (State Sync)

### 6.1 MOS → RAG (Registries to Context)

**Fonction** : `_sync_mos_to_rag()` (ligne 1293)

```gdscript
## Sync player_profile, decision_history, narrative, relationship → RAG v2.0
## RAG injecte ce contexte dans prompts LLM (priorité budget)

var registry_data = {}

if player_profile:
    registry_data["player_patterns"] = decision_history.patterns_detected
    registry_data["player_profile_summary"] = player_profile.get_summary_for_prompt()
    registry_data["archetype_id"] = player_profile.get_archetype_id()
    registry_data["archetype_title"] = player_profile.get_archetype_title()

if narrative:
    var ctx = narrative.get_context_for_llm()
    registry_data["active_arcs"] = ctx.active_arcs
    registry_data["run_phase_name"] = ctx.run_phase_name

if relationship:
    registry_data["trust_tier"] = relationship.trust_tier
    registry_data["trust_tier_name"] = relationship.get_trust_tier_name()

if tone_controller:
    registry_data["current_tone"] = tone_controller.get_current_tone()
    registry_data["tone_characteristics"] = tone_controller.get_tone_characteristics()

rag_manager.sync_from_registries(registry_data)
```

### 6.2 Cycle Enregistrement Choix

**Fonction** : `record_choice()` (ligne 1769)

```gdscript
## Called post-choice, updates ALL registries + RAG journal

# 1. Update player profile (archetype, patterns)
player_profile.update_from_choice(card, option, context)
player_profile.update_from_outcome(outcome)

# 2. Update decision history (patterns detected)
decision_history.record_choice(card, option, context)
decision_history.update_last_entry_gauges(outcome.gauges_after)

# 3. Update session (decision timing)
session.record_decision(decision_time_ms)

# 4. Update narrative (arcs, phases)
narrative.process_card(card)

# 5. Update relationship (promises, interactions)
if outcome.promise_kept: relationship.record_interaction("promises_kept")
if outcome.promise_broken: relationship.record_interaction("promises_broken")

# 6. RAG journal (log choice + reputation changes)
rag_manager.log_choice_made(options[option], cards_played, day)
rag_manager.log_reputation_changed(faction, old_val, new_val, cards_played, day)
```

### 6.3 Sauvegarde Cross-Run

**Fonction** : `save_all()` (ligne 2211)

```gdscript
## Persiste TOUS les registries + RAG

player_profile.save_to_disk()
decision_history.save_to_disk()
relationship.save_to_disk()
narrative.save_to_disk()
session.save_to_disk()
rag_manager.save_journal()
rag_manager.save_world_state()
```

### 6.4 Registries Run-Scoped (Phase 8)

Variables persistées dans `run_state` JSON:

```gdscript
var _mos_registries = {
    "player": {
        "choices_count": 0,
        "preferred_fields": {},
        "avg_score": 0.0,
        "total_score": 0,
    },
    "narrative": {
        "arc_tags": [],
        "pnj_met": [],
        "twists_resolved": [],
    },
    "faction": {
        "rep_deltas_this_run": {},
        "cross_faction_count": 0,
    },
    "cards": {
        "themes_seen": [],
        "fields_used": {},
        "total_played": 0,
    },
    "promises": {
        "active": [],
        "resolved": [],
        "broken": [],
    },
    "trust": {
        "current": 0,
        "tier": "T0",
        "changes": [],
    },
}

# Sauvegarde: save_mos_registries_to_run_state(run_state)
# Chargement: load_mos_registries_from_run_state(run_state)
```

---

## 7. Danger & Adaptation

### 7.1 Seuils de Danger

**Constantes** (ligne 82–85):

```gdscript
const DANGER_LIFE_CRITICAL := 15     # ≤15 → mort imminente
const DANGER_LIFE_LOW := 25          # ≤25 → danger, favoriser repos/soin
const DANGER_LIFE_WOUNDED := 50      # ≤50 → blesse, signaler au LLM
const DANGER_BLOCK_CATASTROPHE_AT := 15  # <15 → bloquer event_catastrophe
```

### 7.2 Application Règles

**Fonction** : `_apply_danger_rules()` (ligne 1244)

```gdscript
## Detecte état critique + ajuste contexte

var danger_level = 0  # 0=safe, 1=wounded, 2=low, 3=critical

# REGLE 1: Vie critique (≤15)
if life <= DANGER_LIFE_CRITICAL:
    danger_level = 3
    danger_signals.append("VIE CRITIQUE (%d) — situation de SURVIE" % life)

# REGLE 2: Vie basse (≤25)
elif life <= DANGER_LIFE_LOW:
    danger_level = 2
    danger_signals.append("VIE BASSE (%d) — favorise soin/repos" % life)

# REGLE 3: Blesse (≤50)
elif life <= DANGER_LIFE_WOUNDED:
    danger_level = 1
    danger_signals.append("Joueur blesse (%d vie)" % life)

# REGLE 4: Bloquer/rediriger events catastrophe
if life < DANGER_BLOCK_CATASTROPHE_AT:
    if event_cat == "event_catastrophe" or event_cat == "event_conflit":
        event_cat = "event_agonie"
        narrator_guidance = "Onirique de grace, entre vie et mort"
elif life <= DANGER_LIFE_LOW:
    if event_cat == "event_catastrophe":
        event_cat = "event_survie"
        narrator_guidance = "Scene de survie protectrice"

# Temperature override
if danger_level >= 2:
    temperature_override = 0.4  # Lower creativity
elif danger_level >= 1:
    temperature_override = 0.5
```

### 7.3 Signaux Injectés au LLM

Danger signals injectés dans system prompt:

```
[DANGER] VIE CRITIQUE (12) — situation de SURVIE | event_catastrophe redirige vers event_agonie
```

---

## 8. Constantes

### 8.1 LLM Configuration

| Constante | Valeur | Notes |
|-----------|--------|-------|
| `LLM_TIMEOUT_MS` | 300000 | 300s — Qwen 3B CPU-only, cold start généreux |
| `MAX_RETRIES` | 2 | Tentatives par stratégie |
| `VERSION` | "1.0.0" | Version MOS |

### 8.2 Guardrails

| Constante | Valeur | Notes |
|-----------|--------|-------|
| `GUARDRAIL_MIN_TEXT_LEN` | 30 | Longueur minimum texte |
| `GUARDRAIL_MAX_TEXT_LEN` | 800 | Longueur maximum (LLM max_tokens=200 → ~1000 chars) |
| `GUARDRAIL_LANG_KEYWORDS` | ["le", "la", "de", ...] | French keywords détection |
| `GUARDRAIL_LANG_THRESHOLD` | 2 | Min French keywords à passer |
| `RECENT_CARDS_MEMORY` | 15 | Cartes tracées répétition check |
| `REPETITION_SIMILARITY_THRESHOLD` | 0.5 | Jaccard similarity seuil |

### 8.3 Danger

| Constante | Valeur | Notes |
|-----------|--------|-------|
| `DANGER_LIFE_CRITICAL` | 15 | Mort imminente |
| `DANGER_LIFE_LOW` | 25 | Danger — baisser difficulté |
| `DANGER_LIFE_WOUNDED` | 50 | Blesse — signaler LLM |
| `DANGER_BLOCK_CATASTROPHE_AT` | 15 | Bloquer event_catastrophe |

### 8.4 Cache & Prefetch

| Constante | Valeur | Notes |
|-----------|--------|-------|
| `CACHE_LIMIT` | 300 | Cache response limit |
| `PREFETCH_BUFFER_MAX` | 3 | Max pre-generated cards (BitNet) |

---

## 9. API Publique

### 9.1 Génération Cartes

#### `generate_card(game_state: Dictionary) -> Dictionary`

Génère une carte narrativa complète. Protected (ne crash jamais).

**Paramètres**:
- `game_state: Dictionary` — État complet du jeu (run, meta, factions, life_essence, flags, etc.)

**Retour**:
- `Dictionary` — Carte valide (text, options, tags, _strategy, _generated_by) ou `{}`

**Exemple**:
```gdscript
var card = mos.generate_card(game_state)
if not card.is_empty():
    print("Generated: %s" % card.text)
    for opt in card.options:
        print("  - %s" % opt.label)
```

#### `generate_npc_card(game_state: Dictionary) -> Dictionary`

Génère une carte rencontre PNJ via LLM ou fallback pool.

**Retour**:
- `Dictionary` — Carte PNJ (speaker, type="npc_encounter") ou `{}`

#### `generate_dream(game_state: Dictionary) -> String`

Génère un rêve narratif pour fin de run.

**Retour**:
- `String` — Texte rêve (~200 chars) ou ""

---

### 9.2 Préchargement

#### `prefetch_next_card(game_state: Dictionary) -> void`

Pre-génère cartes N+1 (et N+2, N+3 si swarm) en background.

**Timing** : Appelée par controller après afficher carte courante.

**Notes**:
- Asynchrone, ne bloque pas l'UI
- Valide contexte avant utilisation (hash comparison)
- Invalide si state trop différent

#### `try_consume_prefetch(game_state: Dictionary) -> Dictionary`

Consomme prefetched card si contexte valide.

**Retour**:
- `Dictionary` — Prefetched card si valide, sinon `{}`

#### `invalidate_prefetch() -> void`

Force invalidation prefetch (ex: après death).

---

### 9.3 Enregistrement

#### `record_choice(card: Dictionary, option: int, outcome: Dictionary) -> void`

Enregistre choix joueur dans TOUS les registries + RAG.

**Paramètres**:
- `card: Dictionary` — Carte jouée
- `option: int` — Index option (0, 1, ou 2)
- `outcome: Dictionary` — Résultat choix (factions_before/after, promise_kept, etc.)

**Side effects**:
- Update player_profile (archetype, patterns)
- Update decision_history (patterns_detected)
- Update narrative (arcs, phases)
- Update relationship (trust, promises)
- Update session (timing)
- Log to RAG journal

#### `on_run_start() -> void`

Appelée au début run. Reset registries run-scoped.

**Side effects**:
- `session.record_run_start()`
- `decision_history.reset_run()`
- `narrative.reset_run()`
- `rag_manager.reset_for_new_run()`

#### `on_run_end(run_data: Dictionary) -> void`

Appelée à fin run. Archive données + persistance.

**Paramètres**:
- `run_data: Dictionary` — Données fin run (cards_played, ending, etc.)

**Side effects**:
- Update relationship trust (long_run_100, quick_death, etc.)
- Archive run dans RAG
- Persist TOUS les registries

---

### 9.4 Contexte & Registries

#### `get_merlin_comment(context: String) -> String`

Génère commentaire Merlin adapté ton + contexte.

**Paramètres**:
- `context: String` — Contexte narratif (ex: "victory", "promise_broken", etc.)

**Retour**:
- `String` — Replique Merlin (~100 chars)

#### `is_ready() -> bool`

Vérifie si MOS initialisé + prêt.

#### `get_stats() -> Dictionary`

Retourne stats génération cartes.

```gdscript
{
    "cards_generated": 42,
    "llm_successes": 38,
    "llm_failures": 4,
    "fallback_uses": 2,
    "fast_route_hits": 15,
    "prefetch_hits": 10,
    "prefetch_misses": 5,
    "average_generation_time_ms": 2145.0,
}
```

#### `get_debug_info() -> Dictionary`

Retourne info debug complète (registries, state, etc.).

#### `save_all() -> void`

Persiste TOUS registries + RAG.

#### `reload_registries() -> void`

Recharge registries depuis disk.

---

### 9.5 Registries (Lecture)

```gdscript
# Accès direct aux registries
mos.player_profile       → PlayerProfileRegistry
mos.decision_history     → DecisionHistoryRegistry
mos.relationship         → RelationshipRegistry
mos.narrative            → NarrativeRegistry
mos.session              → SessionRegistry
mos.rag_manager          → RAGManager
```

**Exemple**:
```gdscript
var archetype = mos.player_profile.get_archetype_title()
var trust_tier = mos.relationship.trust_tier  # 0–3
var active_arcs = mos.narrative.get_context_for_llm()["active_arcs"]
```

---

## 10. Signal Flow

### 10.1 Signaux Émis

| Signal | Paramètres | Timing |
|--------|-----------|--------|
| `card_generated` | `card: Dictionary` | Après génération complète |
| `generation_failed` | `reason: String` | Guademail hard reject |
| `context_built` | `context: Dictionary` | Après MerlinContextBuilder |
| `trust_tier_changed` | `old_tier, new_tier: int` | Relationship update |
| `pattern_detected` | `pattern: String, confidence: float` | Decision history match |
| `wellness_alert` | `alert_type: String, data: Dictionary` | Session stress detected |
| `merlin_speaks` | `text: String, tone: String` | Merlin comment generated |
| `prefetch_ready` | aucun | Prefetch terminé |

### 10.2 Signaux Reçus (Connections)

```gdscript
func _connect_signals():
    # Registries → MOS reactions
    relationship.trust_changed.connect(_on_trust_changed)
    decision_history.pattern_detected.connect(_on_pattern_detected)
    session.wellness_alert.connect(_on_wellness_alert)

    # Narrative events
    narrative.arc_completed.connect(_on_arc_completed)
    narrative.twist_triggered.connect(_on_twist_triggered)

    # Screen FX
    merlin_speaks.connect(_on_merlin_speaks_screen_fx)
```

### 10.3 Handlers Signaux

#### `_on_trust_changed(old_tier: int, new_tier: int, points: int)`

Called when Merlin trust increases/decreases.

#### `_on_pattern_detected(pattern: String, confidence: float)`

Called when decision_history détecte pattern joueur répété.

#### `_on_wellness_alert(alert_type: String, data: Dictionary)`

Called when session détecte stress/frustration.

#### `_on_arc_completed(arc_id: String, resolution: String)`

Called when narrative arc resolved.

#### `_on_twist_triggered(twist_type: String)`

Called when narrative twist occurs.

#### `_on_merlin_speaks_screen_fx(text: String, tone: String)`

Trigger screen distortion FX basé sur tone.

---

## 11. Context Building

### 11.1 System Prompt (_build_system_prompt)

**Fonction** : ligne 1330

```gdscript
var base := "Narrateur celtique de Broceliande. Ecris une scene courte (2-3 phrases)
avec vocabulaire druidique (nemeton, ogham, sidhe, dolmen, korrigans).
Puis donne EXACTEMENT 3 choix:\nA) [verbe action]\nB) [verbe action]\nC) [verbe action]"
```

**Injections (ordre de priorité)**:
1. Locale directive (LocaleManager)
2. Scene contract block (scene context)
3. Tone guidance (ToneController)
4. **Danger signals** (P1.8.1) — highest priority
5. Narrative context (run phase, arcs)
6. **RAG v2.0 prioritized context** (token budget)

### 11.2 User Prompt (_build_user_prompt)

**Fonction** : ligne 1376

```
Factions: druides=45 anciens=32 korrigans=18 niamh=12 ankou=5
Jour:3 Carte:12 Vie:75
Scene:foret Biome: foret
Event: event_transition
[event-specific guidance from EventCategorySelector]
```

Inclut:
- Factions compact
- Day + Life + Biome
- Scenario theme (si actif)
- Event category guidance

---

## 12. Événements Calendrier

### 12.1 Injection Probabiliste

**Fonction** : `_try_calendar_event()` (ligne 428)

```gdscript
# ~15% chance event injecté
if randf() > MerlinConstants.EVENT_CARD_PROBABILITY:  # 0.15
    return {}

# Select event via EventAdapter
var selected = event_adapter.select_event_for_card(ctx)
if selected.is_empty():
    return {}

# Convert to card format
return _calendar_event_to_card(selected)
```

### 12.2 Conversion Événement → Carte

**Fonction** : `_calendar_event_to_card()` (ligne 500)

```gdscript
## Convertit event JSON → card dict avec options variables

# Build 3 options basées category:
if category == "sabbat":
    left_label = "Participer au rituel"
    center_label = "Communier avec les esprits"
    right_label = "Observer la ceremonie"
elif category == "transition":
    left_label = "Embrasser le changement"
    center_label = "S'adapter en douceur"
    right_label = "Resister au passage"
# ... etc

return {
    "id": "cal_%s_%d" % [ev_id, Time.get_ticks_msec()],
    "text": text,
    "speaker": "Merlin",
    "type": "event",
    "calendar_event_id": ev_id,
    "options": [left_option, center_option, right_option],
    "tags": tags + ["calendar_event", category],
    "visual_theme": str(visual.theme),
}
```

---

## 13. Processeurs (Adapters)

### 13.1 MerlinContextBuilder

Construit contexte complet depuis game_state.

**Inputs**: game_state (run, meta, factions, flags, etc.)
**Outputs**: full_context (enriched)

### 13.2 DifficultyAdapter

Ajuste difficulté + scaling récompenses.

### 13.3 EventAdapter

Sélectionne events calendrier (sabbats, transitions, secrets).

### 13.4 NarrativeScaler

Ajuste scaling narratif (arc phases, tension).

### 13.5 ToneController

Gère ton Merlin (mystery, guidance, warning, celebration).

---

## 14. RAG v2.0 Integration

### 14.1 Sync Registry → RAG

Appelé chaque génération:

```gdscript
_sync_mos_to_rag()
    ├─ player_patterns → RAG world state
    ├─ player_profile_summary → RAG context
    ├─ archetype_id → RAG context
    ├─ active_arcs → RAG context
    ├─ trust_tier → RAG context
    └─ current_tone → RAG context
```

### 14.2 RAG Context Injection

RAG retourne contexte prioritisé:

```gdscript
var rag_context = rag_manager.get_prioritized_context(_current_context)
# Injecté dans system prompt via token budget
```

### 14.3 RAG Journal

**Logging**:
- Cartes générées (play log)
- Choix faits (choice log)
- Changements réputation (faction log)
- Fin run (summary + archive)

```gdscript
record_choice()
    ├─ rag_manager.log_choice_made(option, cards_played, day)
    └─ rag_manager.log_reputation_changed(faction, old_val, new_val, ...)

on_run_end()
    └─ rag_manager.summarize_and_archive_run(ending, run_data)
```

---

## 15. Quality Judge (BrainQualityJudge)

### 15.1 Best-of-N Selection

Used by Strategy S (Swarm):

```gdscript
var best = _quality_judge.pick_best(candidates)
# Returns:
# {
#     "text": String (winning text),
#     "score": float (0.0–1.0),
#     "index": int (which variant won),
#     "detail": Dictionary (detailed scores),
# }
```

### 15.2 Scoring Criteria

- Narrative coherence
- Language quality
- Structure (3 options)
- Word choice variety
- Persona alignment

### 15.3 Refinement Suggestion

```gdscript
var refinement_prompt = _quality_judge.suggest_refinement(best_text, detail)
# Returns refinement user_prompt if score < GOOD_SCORE
```

---

## 16. État Internal

### 16.1 State Variables

```gdscript
# Registries
var player_profile: PlayerProfileRegistry
var decision_history: DecisionHistoryRegistry
var relationship: RelationshipRegistry
var narrative: NarrativeRegistry
var session: SessionRegistry

# Processors
var context_builder: MerlinContextBuilder
var difficulty_adapter: DifficultyAdapter
var event_adapter: EventAdapter
var narrative_scaler: NarrativeScaler
var tone_controller: ToneController

# Generators
var llm_interface: Node          # /root/MerlinAI autoload
var rag_manager: RAGManager
var event_selector: EventCategorySelector

# Generation state
var _is_ready: bool = false
var _generation_in_progress: bool = false
var _current_context: Dictionary = {}
var _scene_context: Dictionary = {}
var _last_card_time_ms: int = 0

# Prefetch
var _prefetched_card: Dictionary = {}
var _prefetch_in_progress: bool = false
var _prefetch_context_hash: int = 0
var _prefetch_biome: String = ""
var _prefetch_buffer: Array = []

# Recent cards (repetition check)
var _recent_card_texts: Array[String] = []

# Persona forbidden words (synced from MerlinAI)
var _persona_forbidden_words: PackedStringArray = []

# Quality judge
var _quality_judge: BrainQualityJudge

# Stats
var stats: Dictionary = {...}
```

### 16.2 Cached Prompt Templates

Loaded from `prompt_templates` via LLMInterface.

---

## 17. Exemple d'utilisation complet

```gdscript
# Initialization (via controller)
var mos = MerlinOmniscient.new()
add_child(mos)
var store = get_node("/root/DruStore")
mos.setup(store)

# Main loop
while game_running:
    # Generate card
    var card = await mos.generate_card(game_state)

    # Display card + options
    display_card(card)

    # Start prefetch for next card
    mos.prefetch_next_card(game_state)

    # Wait player choice
    var option_index = await player.choose_option()

    # Apply effects + outcomes
    var outcome = apply_effects(card.options[option_index])

    # Record choice in registries + RAG
    mos.record_choice(card, option_index, outcome)

    # Update game_state
    game_state = update_from_outcome(outcome)

    # Loop continues

# Run end
mos.on_run_end(run_summary)
```

---

## 18. Fichiers Connexes

| Fichier | Rôle |
|---------|------|
| `merlin_ai.gd` | Multi-brain LLM interface (Ollama, BitNet routing) |
| `rag_manager.gd` | RAG v2.0 context + journal |
| `merlin_context_builder.gd` | Full context construction |
| `difficulty_adapter.gd` | Adaptation difficulté |
| `event_adapter.gd` | Calendar event selection |
| `event_category_selector.gd` | Phase 44 card typologies |
| `brain_quality_judge.gd` | Swarm best-of-N scoring |
| Registries | `*_registry.gd` (5 types) |
| Constants | `merlin_constants.gd` |
| Visual | `merlin_visual.gd` (colors) |

---

## 19. Checklist Debug

**Token usage** (2026-03-15):
- MerlinOmniscient.gd: ~2664 lines, 108KB
- Supports Godot 4.x async/await
- Requires: MerlinAI (autoload), DruStore, RAGManager

**Performance**:
- Generation time: typical 2000–3000ms (CPU-only Qwen)
- Prefetch overhead: < 500ms per card
- Memory: registries ~1MB cross-run, RAG journal scalable

**Testing**:
- Unit: guardrails, context building, danger rules
- Integration: full generate_card() with all strategies
- E2E: multiple runs, registry persistence, RAG journal

---

**Document généré via code analysis** — `merlin_omniscient.gd` v1.0.0
