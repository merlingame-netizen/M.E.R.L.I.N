# RAG Manager v3.0 — Architecture Technique

> **Retrieval-Augmented Generation** pour Qwen 3.5 Multi-Brain
>
> Gestion structuree du contexte LLM avec budgets jetonnes per-cerveau, journal narratif, et memoire cross-run.

*Version: 3.0.0 — 2026-03-15*

*Status: PRODUCTION*

---

## Vue d'ensemble executif

Le RAG Manager est l'**epine dorsale cognitive** du systeme M.E.R.L.I.N. Il garantit que chaque invocation LLM
reçoit un contexte narratif **riche, coherent et priorise**, adapte a la capacite cognitive du cerveau appelant.

### Probleme resolu

- **Nano-models** (Qwen 0.8B) ne peuvent digerer ~200 tokens maximum avant hallucinations
- **Medium models** (Qwen 2B) supportent ~400 tokens de contexte pertinent
- **Larger models** (Qwen 4B) peuvent utiliser ~800 tokens pour narratives complexes
- **Contexte statique** (copier-coller du game state) = narratives generiques et repetitives

### Solution RAG v3.0

- **Prioritization par importance** (CRITICAL, HIGH, MEDIUM, LOW, OPTIONAL)
- **Token budgets adaptes au cerveau** (narrator: 800, gamemaster: 400, judge: 200, worker: 200)
- **Sections dynamiques** (12 types, sources multiples: journal, world state, registries)
- **Cross-run memory** (summaries des 20 dernieres parties, pour continuite narrative)
- **Scene contracts** (instructions explicites de tone/topics/forbiddens per scene)

---

## 1. Système de Budgets Jetonnes

### 1.1 Modèle d'estimation

```gdscript
const CHARS_PER_TOKEN := 4
const CONTEXT_BUDGET := 400  # Default backward compat

# rag_manager.gd:98-99
func estimate_tokens(text: String) -> int:
    return ceili(text.length() / float(CHARS_PER_TOKEN))
```

**Heuristique**: 1 token ~= 4 caracteres (moyenne multilangue: français + tags).

### 1.2 Budgets per-brain

```gdscript
# rag_manager.gd:22-27
const BRAIN_BUDGETS := {
    "narrator": 800,     # 4B model, context 8192 — narratives riches
    "gamemaster": 400,   # 2B model, context 4096 — jeu focus
    "judge": 200,        # 0.8B model, context 2048 — minimal
    "worker": 200,       # 0.8B model, context 2048 — fast tasks
}
```

**Allocation strategy**:
- **narrator** (800): recioit tout le contexte narratif, histoire recente, arcs actifs, ton, biome
- **gamemaster** (400): focus game state, factions, danger, choices (moins de narrative couleur)
- **judge** (200): minimal — juste le texte a scorer + quelques refs
- **worker** (200): fast generation tasks (fallback cards, quick wins)

### 1.3 Calcul du budget effectif

```gdscript
# rag_manager.gd:190-194
var budget: int = CONTEXT_BUDGET
if brain_role != "" and brain_role in BRAIN_BUDGETS:
    budget = int(BRAIN_BUDGETS[brain_role])
```

Si aucun `brain_role` specifie → fallback `CONTEXT_BUDGET` (400 tokens).

---

## 2. Système de Journal Narratif

### 2.1 Structure du journal

```gdscript
# rag_manager.gd:46-50
var journal: Array[Dictionary] = []

# Each entry: {
#   type: "card_played"|"choice_made"|"effect_applied"|
#          "aspect_shifted"|"ogham_used"|"run_event",
#   card_num: int, day: int, data: Dictionary, timestamp: float
# }
```

**Types d'entrees**:

| Type | Description | Exemples data |
|------|-------------|----------------|
| `card_played` | Une carte generee/jouee | `{text, tags, generated_by}` |
| `choice_made` | Option selectionnee par joueur | `{label, effects, cost}` |
| `effect_applied` | Effet applique au game state | `{effect_name, value, target}` |
| `aspect_shifted` | Faction reputation change | `{aspect, from: int, to: int}` |
| `ogham_used` | Ogham decouvert/utilise | `{ogham: String}` |
| `run_event` | Event narratif majeur | `{event: String, details: Dict}` |

### 2.2 Logging APIs

```gdscript
# rag_manager.gd:558-586
func log_card_played(card: Dictionary, card_num: int, day: int) -> void:
    _add_journal_entry("card_played", card_num, day, {
        "text": str(card.get("text", "")).substr(0, 60),
        "tags": card.get("tags", []),
        "generated_by": card.get("_generated_by", "unknown"),
    })

func log_choice_made(option: Dictionary, card_num: int, day: int) -> void:
    _add_journal_entry("choice_made", card_num, day, {
        "label": option.get("label", "?"),
        "effects": option.get("effects", []),
        "cost": option.get("cost", 0),
    })

func log_aspect_shifted(aspect: String, old_state: int, new_state: int,
                        card_num: int, day: int) -> void:
    _add_journal_entry("aspect_shifted", card_num, day, {
        "aspect": aspect, "from": old_state, "to": new_state,
    })

func log_ogham_used(ogham_id: String, card_num: int, day: int) -> void:
    _add_journal_entry("ogham_used", card_num, day, {"ogham": ogham_id})

func log_run_event(event_type: String, details: Dictionary,
                   card_num: int, day: int) -> void:
    _add_journal_entry("run_event", card_num, day,
                       {"event": event_type, "details": details})
```

**Ring buffer**: MAX_JOURNAL_ENTRIES = 100 (garde les 100 dernieres entrees)

### 2.3 Reset et persistance

```gdscript
# rag_manager.gd:549-551
func reset_for_new_run() -> void:
    journal.clear()
    save_journal()

# rag_manager.gd:770-774
func save_journal() -> void:
    var file := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(journal))
        file.close()
```

**Chemin**: `user://ai/memory/game_journal.json` (persistent entre les sessions)

---

## 3. Mémoire Cross-Run

### 3.1 Structure des summaries

```gdscript
# rag_manager.gd:56-59
var cross_run_memory: Array[Dictionary] = []

# Each: {
#   run_id, ending, cards_played, dominant_faction,
#   notable_events, player_style, score, life_final, timestamp
# }
```

**Conservation**: Max 20 dernieres parties (ring buffer).

### 3.2 Archivage de fin de run

```gdscript
# rag_manager.gd:601-618
func summarize_and_archive_run(ending: String, final_state: Dictionary) -> void:
    cross_run_memory.append({
        "run_id": cross_run_memory.size() + 1,
        "ending": ending,
        "cards_played": journal.size(),
        "dominant_faction": _find_dominant_faction(final_state),
        "notable_events": _extract_notable_events(),
        "player_style": _classify_player_style(),
        "score": int(final_state.get("score", 0)),
        "life_final": int(final_state.get("run", {}).get("life_essence", 0)),
        "timestamp": Time.get_unix_time_from_system(),
    })
    if cross_run_memory.size() > MAX_CROSS_RUN_SUMMARIES:
        cross_run_memory = cross_run_memory.slice(-MAX_CROSS_RUN_SUMMARIES)
    _save_cross_run_memory()
    journal.clear()
    save_journal()
```

### 3.3 Classification du style joueur

```gdscript
# rag_manager.gd:647-659
func _classify_player_style() -> String:
    var center_count := 0
    var total := 0
    for entry in journal:
        if entry.get("type") == "choice_made":
            total += 1
            if int(entry.get("data", {}).get("cost", 0)) > 0:
                center_count += 1
    if total == 0:
        return "equilibre"
    if center_count > total * 0.4:
        return "prudent"
    return "audacieux"
```

Analyse: Si >40% des choix ont un `cost` positif → style "prudent" (hesitant). Sinon "audacieux".

### 3.4 Recuperation pour contexte narratif

```gdscript
# rag_manager.gd:727-758
func get_past_lives_for_prompt() -> String:
    if cross_run_memory.is_empty():
        return ""
    var lines: Array[String] = []
    var start_idx: int = maxi(0, cross_run_memory.size() - 3)
    for i in range(start_idx, cross_run_memory.size()):
        var run: Dictionary = cross_run_memory[i]
        var ending: String = str(run.get("ending", "inconnu"))
        var cards: int = int(run.get("cards_played", 0))
        var dom: String = str(run.get("dominant_faction", ""))
        var style: String = str(run.get("player_style", ""))
        var life: int = int(run.get("life_final", 0))
        var parts: Array[String] = ["Vie %d" % (i + 1)]
        if not ending.is_empty():
            parts.append("fin: %s" % ending)
        if cards > 0:
            parts.append("%d cartes" % cards)
        if not dom.is_empty():
            parts.append("dominant: %s" % dom)
        if not style.is_empty():
            parts.append("style: %s" % style)
        if life > 0:
            parts.append("vie restante: %d" % life)
        lines.append(", ".join(parts))
    if lines.is_empty():
        return ""
    return "Vies passees du voyageur: " + " | ".join(lines)
```

**Exemple output**:
```
Vies passees du voyageur: Vie 1, fin: mort premature, 42 cartes, dominant: Fae, style: prudent, vie restante: 5 | Vie 2, fin: victoire mystique, 67 cartes, dominant: Druide, style: audacieux, vie restante: 78
```

### 3.5 Persistance

```gdscript
# rag_manager.gd:787-801
func _save_cross_run_memory() -> void:
    var file := FileAccess.open(CROSS_RUN_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(cross_run_memory))
        file.close()

func _load_cross_run_memory() -> void:
    if FileAccess.file_exists(CROSS_RUN_PATH):
        var file := FileAccess.open(CROSS_RUN_PATH, FileAccess.READ)
        if file:
            var data = JSON.parse_string(file.get_as_text())
            file.close()
            if data is Array:
                cross_run_memory.assign(data)
```

**Chemin**: `user://ai/memory/cross_run_memory.json`

---

## 4. World State & Scene Contracts

### 4.1 World State (MOS Registries Sync)

```gdscript
# rag_manager.gd:65-73
var world_state: Dictionary = {}
var actions_by_category: Dictionary = {}
var _scene_context: Dictionary = {}

# Phase 44 — Tag glossary pour contexte narratif
var _tag_glossary: Dictionary = {}
var _theme_dualities: Array = []
var _biome_tags: Dictionary = {}
var _tag_glossary_loaded := false
```

**Sincronisation**: Le MOS peut injecter des donnees arbitraires via `update_world_state()` et `sync_from_registries()`.

### 4.2 Scene Contracts (Tone/Topics/Forbiddens)

```gdscript
# rag_manager.gd:670-688
func set_scene_context(scene_context: Dictionary) -> void:
    _scene_context = scene_context.duplicate(true)
    if _scene_context.is_empty():
        world_state.erase("scene_context")
    else:
        world_state["scene_context"] = _scene_context

func clear_scene_context() -> void:
    _scene_context.clear()
    world_state.erase("scene_context")

func get_scene_context() -> Dictionary:
    if not _scene_context.is_empty():
        return _scene_context.duplicate(true)
    if world_state.has("scene_context") and world_state["scene_context"] is Dictionary:
        return world_state["scene_context"].duplicate(true)
    return {}
```

**Scene context structure** (example):
```json
{
  "scene_id": "SCENE_TAVERN",
  "phase": "Arrivee",
  "intent": "Negotiation with bard",
  "tone_target": "Mystique,Humour",
  "allowed_topics": ["musique", "voyage", "magie"],
  "must_reference": ["barde_nomade"],
  "forbidden_topics": ["mort", "destruction"]
}
```

Chaque scene peut imposer des contraintes LLM explicites.

---

## 5. Pipeline de Recuperation de Contexte Priorise

### 5.1 Architecture globale

```
game_state + brain_role
        │
        ▼
┌─────────────────────────────────┐
│ get_prioritized_context()       │
│ (12 types de sections)          │
└────────┬────────────────────────┘
         │
         ├─→ _get_crisis_context()
         ├─→ _get_scene_contract_context()
         ├─→ _get_recent_narrative()
         ├─→ _get_active_arcs_context()
         ├─→ _get_biome_context()
         ├─→ _get_tone_context()
         ├─→ _get_karma_tension_context()
         ├─→ _get_promises_context()
         ├─→ _get_player_pattern_context()
         ├─→ _get_faction_context()
         ├─→ _get_event_category_context() [Phase 44]
         ├─→ _get_player_profile_context() [P1.10.1]
         ├─→ _get_archetype_context() [B.3]
         ├─→ _get_aspects_state_context() [B.4]
         ├─→ _get_danger_context() [P1.10.1]
         └─→ _get_cross_run_callbacks() [P1.10.2]
                   │
                   ▼
        ┌─────────────────────────┐
        │ Trier par Priority      │
        │ (CRITICAL > HIGH > ...) │
        └────────┬────────────────┘
                 │
                 ▼
        ┌─────────────────────────┐
        │ Pack sections jusqu'au  │
        │ budget tokens epuise    │
        └────────┬────────────────┘
                 │
                 ▼
            contexte final
            (String trimmed)
```

### 5.2 Détail par section

#### Crisis Context (CRITICAL)

```gdscript
# rag_manager.gd:252-267
func _get_crisis_context(game_state: Dictionary) -> String:
    var run: Dictionary = game_state.get("run", {})
    var factions: Dictionary = run.get("factions", {})
    var oghams: Array = run.get("oghams_decouverts", [])
    var crises: Array[String] = []
    for faction in factions:
        var val: float = float(factions[faction])
        if val <= 10.0:
            crises.append("%s=HOSTILE" % faction)
        elif val >= 90.0:
            crises.append("%s=DOMINANT" % faction)
    if oghams.size() >= 5:
        crises.append("Oghams=%d (avance)" % oghams.size())
    if crises.is_empty():
        return ""
    return "CRISE: " + ", ".join(crises)
```

**Output**: `"CRISE: Fae=HOSTILE, Druide=DOMINANT, Oghams=6 (avance)"`

#### Scene Contract Context (CRITICAL)

```gdscript
# rag_manager.gd:221-249
func _get_scene_contract_context() -> String:
    var ctx := get_scene_context()
    if ctx.is_empty():
        return ""
    var parts: Array[String] = []
    var scene_id := str(ctx.get("scene_id", ""))
    if scene_id != "":
        parts.append("Scene=%s" % scene_id)
    var phase := str(ctx.get("phase", ""))
    if phase != "":
        parts.append("Phase=%s" % phase)
    # ... tone, allowed_topics, must_reference, forbidden_topics
    return "SceneContract: " + " | ".join(parts)
```

#### Recent Narrative (HIGH)

```gdscript
# rag_manager.gd:270-281
func _get_recent_narrative() -> String:
    if journal.is_empty():
        return ""
    var recent := journal.slice(-mini(journal.size(), 10))
    var parts: Array[String] = []
    for entry in recent:
        if entry.get("type") == "choice_made":
            var data: Dictionary = entry.get("data", {})
            parts.append(str(data.get("label", "?")))
    if parts.is_empty():
        return ""
    return "Recents: " + ", ".join(parts)
```

**Output**: `"Recents: Affronter le garde, Prier pour aide, Fouiller le buisson"`

#### Active Arcs (HIGH)

```gdscript
# rag_manager.gd:284-307
func _get_active_arcs_context() -> String:
    var arcs: Array = world_state.get("active_arcs", [])
    # ... iterate active_arcs from world_state
    var prefix := ""
    if run_phase_name != "":
        prefix = "Phase: %s | " % run_phase_name
    return prefix + "Arcs: " + ", ".join(parts)
```

#### Biome Context (HIGH — cached)

```gdscript
# rag_manager.gd:400-415
var _biome_cache_key: String = ""
var _biome_cache_text: String = ""

func _get_biome_context(game_state: Dictionary) -> String:
    var run: Dictionary = game_state.get("run", {})
    var biome_key: String = str(run.get("current_biome", ""))
    if biome_key.is_empty():
        return ""
    # Cache: avoid re-instantiating MerlinBiomeSystem on every call
    if biome_key == _biome_cache_key and not _biome_cache_text.is_empty():
        return _biome_cache_text
    var BiomeSystemClass: GDScript = load("res://scripts/merlin/merlin_biome_system.gd")
    var biome_sys = BiomeSystemClass.new()
    _biome_cache_text = biome_sys.get_biome_context_for_llm(biome_key)
    _biome_cache_key = biome_key
    return _biome_cache_text
```

**Caching**: Evite de re-instancier `MerlinBiomeSystem` a chaque appel.

#### Tone Context (HIGH)

```gdscript
# rag_manager.gd:418-431
func _get_tone_context() -> String:
    var tone: String = str(world_state.get("current_tone", ""))
    if tone.is_empty() or tone == "neutral":
        return ""
    var chars: Dictionary = world_state.get("tone_characteristics", {})
    var parts: Array[String] = ["Registre: " + tone]
    # ...vocabulary, emotion
    return " ".join(parts)
```

#### Danger Context (CRITICAL)

```gdscript
# rag_manager.gd:387-397
func _get_danger_context(game_state: Dictionary) -> String:
    var run: Dictionary = game_state.get("run", {})
    var life: int = int(run.get("life_essence", 100))
    if life <= 15:
        return "DANGER CRITIQUE: Vie=%d — mort imminente, proteger le voyageur" % life
    elif life <= 25:
        return "DANGER: Vie=%d — favoriser options de soin" % life
    elif life <= 50:
        return "Vie basse: %d/100" % life
    return ""
```

**Priorite CRITICAL**: Injecte en priorite pour que LLM adapte options.

#### Faction Reputation States (HIGH)

```gdscript
# rag_manager.gd:365-384
func _get_aspects_state_context(game_state: Dictionary) -> String:
    var run: Dictionary = game_state.get("run", {})
    var factions: Dictionary = run.get("factions", {})
    var lines: Array = []
    for faction in factions:
        var val: float = float(factions[faction])
        if val <= 20.0:
            lines.append("%s: hostile (%.0f)" % [faction, val])
        elif val >= 80.0:
            lines.append("%s: allie (%.0f)" % [faction, val])
    if lines.is_empty():
        return ""
    return "FACTIONS: " + " | ".join(lines)
```

Only extrêmes (0-20 ou 80-100) pour eviter verbosité.

#### Cross-Run Callbacks (LOW)

```gdscript
# rag_manager.gd:523-545
func _get_cross_run_callbacks() -> String:
    if cross_run_memory.is_empty():
        return ""
    var summaries: Array[String] = []
    var start_idx: int = maxi(0, cross_run_memory.size() - 2)
    for i in range(start_idx, cross_run_memory.size()):
        # ... format last 2 runs
    if summaries.is_empty():
        return ""
    return "Memoire: " + " | ".join(summaries)
```

Priority LOW pour laisser place aux infos immédiates si budget tight.

### 5.3 Algorithme de packing

```gdscript
# rag_manager.gd:195-208
var result := ""
var tokens_used := 0
for section in sections:
    var section_tokens := estimate_tokens(section.text)
    if tokens_used + section_tokens <= budget:
        result += section.text + "\n"
        tokens_used += section_tokens
    else:
        var remaining := maxi(budget - tokens_used, 0)
        if remaining > 10:
            result += trim_to_budget(section.text, remaining) + "\n"
        break

return result.strip_edges()
```

**Logic**:
1. Trier sections par priority (HIGH > MEDIUM > LOW)
2. Ajouter sections entieres tant qu'il y a budget
3. Si dernière section ne rentre pas entièrement → la trimmer si >10 tokens restants
4. Retourner contexte final (max = budget tokens)

---

## 6. Types de Sections (12 types)

| Section | Methode | Priority | Tokens | Contenu |
|---------|---------|----------|--------|---------|
| Crisis | `_get_crisis_context()` | CRITICAL | ~10-30 | Factions hostiles/dominantes, Oghams count |
| Scene Contract | `_get_scene_contract_context()` | CRITICAL | ~30-60 | Scene ID, phase, tone target, topics |
| Recent Narrative | `_get_recent_narrative()` | HIGH | ~20-50 | 10 derniers choix du journal |
| Active Arcs | `_get_active_arcs_context()` | HIGH | ~40-80 | Arcs actuels, stage names, run phase |
| Biome | `_get_biome_context()` | HIGH | ~40-100 | Contexte biome via MerlinBiomeSystem |
| Tone | `_get_tone_context()` | HIGH | ~20-40 | Registre (mystique/epique/humour) |
| Karma/Tension | `_get_karma_tension_context()` | HIGH | ~20-40 | Karma, tension, jour du run |
| Promises | `_get_promises_context()` | MEDIUM | ~20-40 | Promesses actives/engagements |
| Player Pattern | `_get_player_pattern_context()` | MEDIUM | ~10-20 | Style detecte (prudent/audacieux) |
| Faction Dominant | `_get_faction_context()` | MEDIUM | ~15-30 | Faction alliee primaire |
| Event Category | `_get_event_category_context()` | MEDIUM | ~30-60 | Phase 44 — tags glossary, dualites |
| Player Profile | `_get_player_profile_context()` | MEDIUM | ~40-80 | P1.10.1 — summary from MOS registry |
| Archetype | `_get_archetype_context()` | MEDIUM | ~20-40 | B.3 — archetype label + traits |
| Aspects State | `_get_aspects_state_context()` | HIGH | ~20-40 | B.4 — factions extremes (0-20, 80-100) |
| Danger | `_get_danger_context()` | CRITICAL | ~15-30 | P1.10.1 — life essence urgency |
| Cross-Run Callbacks | `_get_cross_run_callbacks()` | LOW | ~40-100 | P1.10.2 — last 2 run summaries |

---

## 7. Phase 44 — Tag Glossary & Dilemmas

### 7.1 Glossaire des tags

```gdscript
# rag_manager.gd:834-866
func _load_tag_glossary() -> void:
    var path := "res://data/ai/config/tag_glossary.json"
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return
    var data = JSON.parse_string(file.get_as_text())
    file.close()
    if not data is Dictionary:
        return

    var tags_dict: Dictionary = data.get("tags", {})
    _tag_glossary = tags_dict

    var dualities_raw = data.get("theme_dualities", {})
    if dualities_raw is Dictionary:
        _theme_dualities = dualities_raw.get("pairs", [])
    elif dualities_raw is Array:
        _theme_dualities = dualities_raw

    var biome_tags: Dictionary = data.get("biome_tags", {})
    _biome_tags = biome_tags

    _tag_glossary_loaded = not _tag_glossary.is_empty()
```

**Fichier source**: `res://data/ai/config/tag_glossary.json`

Structure:
```json
{
  "tags": {
    "sacrifice": {"meaning": "...", "opposite": "..."},
    "mystery": { "meaning": "...", "opposite": "..." }
  },
  "theme_dualities": {
    "pairs": [
      {"a": "sacrifice", "b": "gain"},
      {"a": "mystery", "b": "revelation"}
    ]
  },
  "biome_tags": {
    "foret_ancienne": ["mystere", "vie", "temps"],
    "falaises": ["courage", "hauteur", "danger"]
  }
}
```

### 7.2 APIs de recuperation

```gdscript
# rag_manager.gd:501-520
func get_random_duality() -> Dictionary:
    if _theme_dualities.is_empty():
        return {}
    var idx: int = randi() % _theme_dualities.size()
    var duality = _theme_dualities[idx]
    if duality is Dictionary:
        return duality
    return {}

func get_tags_for_biome(biome: String) -> Array:
    return _biome_tags.get(biome, [])

func get_tag_info(tag_name: String) -> Dictionary:
    return _tag_glossary.get(tag_name, {})
```

**Usage** (eg. MOS pour dilemmas):
```gdscript
var duality = rag_manager.get_random_duality()
# → {"a": "sacrifice", "b": "gain"}
# LLM genere 2 options: une basee sur sacrifice, une sur gain
```

---

## 8. Fenetre de Contexte & Allocation

### 8.1 Modèle d'allocation per-brain

```
┌──────────────────────────────────────────────────────────────┐
│                    NARRATOR (800 tokens)                     │
├──────────────────────────────────────────────────────────────┤
│ CRITICAL (100)  │ HIGH (350)  │ MEDIUM (300) │ LOW (50)      │
│ • Crisis        │ • Recents   │ • Profile    │ • Cross-run   │
│ • Danger        │ • Arcs      │ • Archetype  │               │
│ • Scene         │ • Biome     │ • Faction    │               │
│                 │ • Tone      │ • Promises   │               │
│                 │ • Aspects   │ • Pattern    │               │
│                 │ • Tension   │              │               │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                   GAMEMASTER (400 tokens)                    │
├──────────────────────────────────────────────────────────────┤
│ CRITICAL (60) │ HIGH (200)  │ MEDIUM (120) │ LOW (20)       │
│ • Crisis      │ • Recents   │ • Faction    │ • Cross-run    │
│ • Danger      │ • Aspects   │ • Pattern    │                │
│               │ • Scene     │              │                │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                     JUDGE (200 tokens)                       │
├──────────────────────────────────────────────────────────────┤
│ CRITICAL (30) │ HIGH (100) │ MEDIUM (60) │ LOW (10)         │
│ • Crisis      │ • Recents  │ • Pattern   │ • Cross-run     │
│ • Danger      │ • Scene    │             │                  │
└──────────────────────────────────────────────────────────────┘
```

### 8.2 Token utilization par-phase

**Phase 1 — Card Generation** (narrator):
- Scene context (mandatory): ~50 tokens
- Recent history: ~40 tokens
- Current state (crisis/danger/arcs): ~80 tokens
- Player profile: ~60 tokens
- Narrative tone: ~30 tokens
- **Total**: ~260 tokens (budget 800)
- **Reserve**: 540 tokens pour prompt instructions + generation space

**Phase 2 — Effect Selection** (gamemaster):
- Scene context: ~30 tokens
- Crisis state: ~20 tokens
- Faction aspects: ~40 tokens
- Recent choices: ~30 tokens
- **Total**: ~120 tokens (budget 400)
- **Reserve**: 280 tokens pour prompt + selection logic

**Phase 3 — Quality Scoring** (judge):
- Text to score: ~80 tokens
- Minimal context: ~20 tokens
- **Total**: ~100 tokens (budget 200)
- **Reserve**: 100 tokens pour scoring prompt

---

## 9. API Publique

### 9.1 Context Retrieval

```gdscript
# Signature principale
func get_prioritized_context(game_state: Dictionary,
                             brain_role: String = "") -> String:
    ## Construit contexte priorise, adapte au budget per-brain.
    ## brain_role: "narrator"|"gamemaster"|"judge"|"worker"
    ## Returns: String trimme au budget tokens
```

**Usage**:
```gdscript
var brain_role = "narrator"
var ctx = rag_manager.get_prioritized_context(game_state, brain_role)
# → contexte ~800 tokens max, sections triees par priority
```

### 9.2 Journal Operations

```gdscript
func log_card_played(card: Dictionary, card_num: int, day: int) -> void
func log_choice_made(option: Dictionary, card_num: int, day: int) -> void
func log_aspect_shifted(aspect: String, old_state: int, new_state: int,
                        card_num: int, day: int) -> void
func log_ogham_used(ogham_id: String, card_num: int, day: int) -> void
func log_run_event(event_type: String, details: Dictionary,
                   card_num: int, day: int) -> void
func reset_for_new_run() -> void
func save_journal() -> void
```

### 9.3 Cross-Run Memory

```gdscript
func summarize_and_archive_run(ending: String,
                               final_state: Dictionary) -> void
func get_run_count() -> int
func get_last_ending() -> String
func get_past_lives_for_prompt() -> String
func get_run_summaries_for_journal() -> Array[Dictionary]
```

### 9.4 World State Management

```gdscript
func update_world_state(key: String, value) -> void
func set_scene_context(scene_context: Dictionary) -> void
func clear_scene_context() -> void
func get_scene_context() -> Dictionary
func sync_from_registries(registries: Dictionary) -> void
```

### 9.5 Tag Glossary (Phase 44)

```gdscript
func get_random_duality() -> Dictionary
func get_tags_for_biome(biome: String) -> Array
func get_tag_info(tag_name: String) -> Dictionary
```

### 9.6 Search & Retrieval

```gdscript
func search_journal(keywords: Array[String], max_results: int = 5) -> Array
func get_relevant_context(query: String, _category: String) -> Dictionary
```

### 9.7 Legacy Compatibility

```gdscript
func add_to_history(input_text: String, response: String) -> void
```

---

## 10. Intégration avec MerlinOmniscient

### 10.1 Initialisation

```gdscript
# merlin_omniscient.gd:49
var rag_manager: RAGManager  # RAG v2.0 — priority-based context
```

**Dans MOS**: Charge `RAGManager` comme enfant Node ou reference externe.

### 10.2 Flux d'utilisation (Phase "Context Build")

```
MOS.generate_card(game_state)
    │
    ├─→ rag_manager.get_prioritized_context(game_state, "narrator")
    │   → contexte 800 tokens, triee par priority
    │
    ├─→ merlin_ai.invoke("narrator", {
    │       "prompt": prompt_template,
    │       "context": contexte,  # Inject du RAG
    │       "max_tokens": 200
    │   })
    │
    └─→ rag_manager.log_card_played(generated_card, card_num, day)
        (sauvegarde dans journal pour future contexte)
```

### 10.3 Synchronisation MOS ↔ RAG

**Apres chaque decision joueur**:
```gdscript
# MOS (merlin_omniscient.gd) appelle RAGManager pour enregistrer
rag_manager.log_choice_made(selected_option, card_num, day)
rag_manager.log_aspect_shifted("Fae", 50, 35, card_num, day)
```

**Avant fin de run**:
```gdscript
rag_manager.summarize_and_archive_run("victoire_mystique", final_state)
```

### 10.4 Sync des registries

```gdscript
# MOS synchronise ses registries vers RAG (world_state)
var registries = {
    "player_profile_summary": player_profile.to_prompt_string(),
    "active_arcs": narrative.get_active_arcs(),
    "active_promises": relationship.get_active_promises(),
    "current_tone": tone_controller.current_tone(),
    "archetype_id": player_profile.archetype_id,
}
rag_manager.sync_from_registries(registries)
```

---

## 11. Persistance & Chemins de Fichiers

```gdscript
const JOURNAL_PATH := "user://ai/memory/game_journal.json"
const CROSS_RUN_PATH := "user://ai/memory/cross_run_memory.json"
const WORLD_STATE_PATH := "user://ai/memory/world_state.json"
```

**Emplacement windows**: `%APPDATA%/Godot/app_userdata/M.E.R.L.I.N./ai/memory/`

**Strategie**:
- `game_journal.json` — Major update chaque log + explicit `save_journal()`
- `cross_run_memory.json` — Sauvegarde seulement sur archivage de run
- `world_state.json` — Sauvegarde sur chaque `sync_from_registries()`

---

## 12. Performance & Optimisations

### 12.1 Caching — Biome Context

```gdscript
# rag_manager.gd:400-415
var _biome_cache_key: String = ""
var _biome_cache_text: String = ""

# Cache hit: evite re-load + re-instantiation
if biome_key == _biome_cache_key and not _biome_cache_text.is_empty():
    return _biome_cache_text
```

**Benefice**: ~50ms saved per context build si biome inchange.

### 12.2 Ring Buffers

- Journal: MAX_JOURNAL_ENTRIES = 100 (slice(-100) autodetrim)
- Cross-run: MAX_CROSS_RUN_SUMMARIES = 20 (slice(-20) autodetrim)

**Benefice**: Memory bounded, aucune fuite mémoire.

### 12.3 Token Estimation — Approximation

```gdscript
func estimate_tokens(text: String) -> int:
    return ceili(text.length() / float(CHARS_PER_TOKEN))  # 4 chars = 1 token
```

**Precision**: ±10% (heuristique, suffisant pour budgetisation).

### 12.4 String Operations

- Tous `.substr(0, N)` pour limiter taille (eg. card text truncate)
- `.strip_edges()` avant retour contexte (clean trailing whitespace)

---

## 13. Cas d'Usage & Exemples

### 13.1 Scenario: Danger Life Low (P1.10.1)

```gdscript
game_state = {
    "run": {
        "life_essence": 18,
        "factions": {"Fae": 5, "Druide": 95},
        "current_biome": "falaises"
    }
}

var ctx = rag_manager.get_prioritized_context(game_state, "narrator")
```

**Output contextuel**:
```
DANGER CRITIQUE: Vie=18 — mort imminente, proteger le voyageur
CRISE: Fae=HOSTILE, Druide=DOMINANT
Recents: Fuir le monstre, Prier pour aide
Arcs: Arc_Prophecy (stage 3, 8 cartes)
Registre: Heroique
FACTIONS: Druide: allie (95.0) | Fae: hostile (5.0)
```

→ Narrateur alignera options vers **soin + protection**, **resolve** vs panic.

### 13.2 Scenario: Archetype Mismatch (B.3)

```gdscript
var ctx = rag_manager.get_prioritized_context(game_state, "narrator")
# world_state contient {"archetype_id": "sage", "archetype_title": "Le Sage"}
```

**Output** (si archetype charge):
```
Archetype: Le Sage — guide les enjeux vers le style sage
```

→ Narrateur propose options plus contemplatives, strategiques vs impulsives.

### 13.3 Scenario: Cross-Run Callback (P1.10.2)

```gdscript
rag_manager.summarize_and_archive_run("defaite_dramatique", final_state)
rag_manager.summarize_and_archive_run("victoire_pyrrhe", final_state2)

var ctx = rag_manager.get_prioritized_context(new_game_state, "narrator")
```

**Output** (si budget permet):
```
Memoire: Run 1, fin: defaite_dramatique, 54 cartes, dominant: Fae, style: prudent, vie restante: 2 | Run 2, fin: victoire_pyrrhe, 78 cartes, dominant: Druide, style: audacieux, vie restante: 61
```

→ Narrateur peut referencer "tes vies passees" + proposer redemption arc.

---

## 14. Roadmap & Limitations Connues

### 14.1 v3.0 (Current)

- Per-brain budgets (narrator 800, gamemaster 400, judge 200, worker 200)
- 16 section types (crisis, scene, narrative, arcs, biome, tone, karma, promises, pattern, faction, events, profile, archetype, aspects, danger, crossrun)
- Cross-run memory (20 runs max)
- Phase 44 tag glossary + theme dualities
- Caching biome context

### 14.2 Limitations

1. **Token estimation heuristique** — Pas parfaite pour tous les cas (special chars, codes, etc)
2. **No semantic reranking** — Simple priority order, pas NLP-based relevance
3. **Journal size fixed** — 100 entries max (pas configurable)
4. **World state sync manual** — MOS doit explicitement appeler `sync_from_registries()`
5. **No compression** — Contexte long = long string (pas de summary compression)

### 14.3 Possibles améliorations futures

- **v3.1**: Semantic reranking via embeddings (si compute disponible)
- **v3.2**: Adaptive budget scaling (ajuster per-brain budgets dynamiquement)
- **v3.3**: Context compression (summarizer pour journal + cross-run)
- **v4.0**: Knowledge graph (entity extraction pour richer cross-run memory)

---

## 15. Checklist Intégration

Pour integrer RAG Manager v3.0 dans un nouvel projet:

- [ ] Instancier `RAGManager` dans MOS ou autoload
- [ ] Appeler `rag_manager._ready()` on startup (charge journal + cross-run)
- [ ] Router tous les logs (`log_card_played`, `log_choice_made`, etc) depuis game controller
- [ ] Synchroniser `world_state` via `sync_from_registries()` apres chaque MOS update
- [ ] Passer `brain_role` lors de l'appel a `get_prioritized_context()` (narrator/gamemaster/judge/worker)
- [ ] Appeler `summarize_and_archive_run()` a la fin de chaque run (avant reset journal)
- [ ] Verifier chemins de persistance (`user://ai/memory/`)
- [ ] Charger `tag_glossary.json` depuis `res://data/ai/config/` (Phase 44)

---

## References

- **RAG Manager Source**: `addons/merlin_ai/rag_manager.gd` (v3.0.0, 884 lines)
- **MOS Integration**: `addons/merlin_ai/merlin_omniscient.gd` (line 49)
- **Game Design Bible**: `docs/GAME_DESIGN_BIBLE.md` v2.4 (source de verite narrative)
- **LLM Architecture**: `docs/10_llm/LLM_ARCHITECTURE.md` (multi-brain, token budgets)
- **CLAUDE.md**: Project rules + smart workflow

---

**Last Updated**: 2026-03-15
**Version**: 3.0.0
**Status**: PRODUCTION
