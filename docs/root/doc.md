🌿 ARCHITECTURE TECHNIQUE — DRU : Le Jeu des Oghams
Document de Référence pour l'Intégration de Merlin (LLM Local)

📋 TABLE DES MATIÈRES

Vision Globale
Stack Technique
Architecture du Système
Intégration LLM ↔ Godot
Format des Données & Communication
Système de Persistance
Gestion des Performances
Équilibrage Dynamique
Système de Génération de Mots
Gestion des Erreurs & Fallbacks
Roadmap d'Implémentation


🎯 VISION GLOBALE
Principe Fondamental
Merlin est le cœur vivant du jeu. Ce n'est pas un système narratif externe, mais l'intelligence centrale qui :

Génère dynamiquement les Mots Sacrés (Oghams)
Équilibre la difficulté en temps réel
Crée une narration adaptative unique par partie
Surveille et réagit à chaque action du joueur
Manipule subtilement les règles du jeu dans des limites définies

Contraintes Techniques Majeures
✅ 100% Local — Aucune requête réseau, fonctionne hors ligne
✅ Mobile-First — Optimisé pour tablettes/téléphones haut de gamme
✅ Rapide — Temps de réponse < 2 secondes en combat
✅ Léger — Modèle 2-4 GB maximum
✅ Intégré — Natif dans Godot, pas de serveur externe

🔧 STACK TECHNIQUE
Modèle LLM Recommandé
Option 1 : Phi-3 Mini (3.8B) ⭐ RECOMMANDÉ

Taille : 2.3 GB (quantized 4-bit)
Performance : Excellent rapport qualité/taille
Support mobile : Optimisé ARM/Apple Silicon
Licence : MIT (Open Source)

Option 2 : Llama 3.2 3B (Alternative)

Taille : 2 GB (quantized)
Performance : Très bon en narration courte
Support mobile : Bon
Licence : Llama 3 Community License

Option 3 : Gemma 2B (Plus léger)

Taille : 1.4 GB
Performance : Correct pour dialogues courts
Support mobile : Excellent
Licence : Gemma Terms of Use

Framework d'Intégration
llama.cpp ⭐ SOLUTION RECOMMANDÉE
Pourquoi ?
✅ Supporte Phi-3, Llama, Gemma
✅ Optimisé CPU + GPU (Metal/Vulkan/OpenCL)
✅ Quantization native (4-bit, 5-bit, 8-bit)
✅ Bindings C/C++ faciles à wrapper en GDExtension
✅ Inférence ultra-rapide sur mobile
✅ Communauté active + maintenance régulière
Intégration Godot
GDExtension (C++)
cpp// Structure proposée
godot-mcp/
├── addons/
│   └── merlin_llm/
│       ├── plugin.cfg
│       ├── merlin_core.gd          # Interface GDScript
│       ├── libmerlin.{so|dylib|dll} # Bibliothèque native
│       └── models/
│           └── phi3-mini-q4.gguf   # Modèle quantifié
Wrapper C++ simplifié :
cppclass MerlinLLM : public RefCounted {
    GDCLASS(MerlinLLM, RefCounted)
    
private:
    llama_model* model;
    llama_context* ctx;
    std::thread inference_thread;
    
public:
    // Initialisation
    Error load_model(String model_path);
    
    // Inférence asynchrone
    void generate_async(String prompt, Callable callback);
    
    // Inférence synchrone (avec timeout)
    String generate_sync(String prompt, float timeout_sec);
    
    // Contrôle
    void cancel_generation();
    bool is_generating();
};
```

---

## 🏗️ ARCHITECTURE DU SYSTÈME

### Diagramme Global
```
┌─────────────────────────────────────────────────────────┐
│                    GODOT ENGINE                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │           GAMEPLAY CORE (GDScript)               │  │
│  │  ┌────────┐  ┌────────┐  ┌────────┐            │  │
│  │  │Combat  │  │Events  │  │ UI     │            │  │
│  │  │System  │  │System  │  │Manager │            │  │
│  │  └───┬────┘  └───┬────┘  └───┬────┘            │  │
│  │      │           │            │                  │  │
│  │      └───────────┼────────────┘                  │  │
│  │                  │                               │  │
│  │      ┌───────────▼────────────┐                 │  │
│  │      │   MERLIN INTERFACE     │                 │  │
│  │      │   (merlin_core.gd)     │                 │  │
│  │      └───────────┬────────────┘                 │  │
│  └──────────────────┼───────────────────────────────┘  │
│                     │                                   │
│  ┌──────────────────▼───────────────────────────────┐  │
│  │       GDExtension (C++)                          │  │
│  │  ┌──────────────────────────────────────────┐   │  │
│  │  │         MERLIN LLM ENGINE                │   │  │
│  │  │  ┌────────────┐  ┌──────────────────┐   │   │  │
│  │  │  │ llama.cpp  │  │ Thread Manager   │   │   │  │
│  │  │  │ Interface  │  │ (async inference)│   │   │  │
│  │  │  └─────┬──────┘  └────────┬─────────┘   │   │  │
│  │  │        │                  │             │   │  │
│  │  │  ┌─────▼──────────────────▼─────────┐   │   │  │
│  │  │  │    Phi-3 Mini Model (GGUF)       │   │   │  │
│  │  │  │    (2.3 GB, 4-bit quantized)     │   │   │  │
│  │  │  └──────────────────────────────────┘   │   │  │
│  │  └──────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │         PERSISTENCE LAYER                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │  │
│  │  │Grimoire  │  │Player    │  │ Merlin   │       │  │
│  │  │DB (JSON) │  │Profile   │  │ Memory   │       │  │
│  │  └──────────┘  └──────────┘  └──────────┘       │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Flux de Communication
```
[ÉVÉNEMENT JEU]
      ↓
[Merlin Interface (GDScript)]
      ↓
[Format en Prompt Optimisé]
      ↓
[GDExtension C++]
      ↓
[Thread Async]
      ↓
[llama.cpp inference]
      ↓ (0.5-2 sec)
[Texte Généré]
      ↓
[Parse & Validation]
      ↓
[Callback GDScript]
      ↓
[UI + Gameplay Update]

🔌 INTÉGRATION LLM ↔ GODOT
Interface GDScript (merlin_core.gd)
gdscriptclass_name MerlinCore
extends Node

signal response_ready(response: Dictionary)
signal generation_started()
signal generation_failed(error: String)

var _llm: MerlinLLM  # GDExtension C++
var _context_buffer: Array[Dictionary] = []
var _is_generating: bool = false

# Configuration
var max_context_length: int = 2048
var temperature: float = 0.7
var top_p: float = 0.9
var max_tokens: int = 150

func _ready():
    _llm = MerlinLLM.new()
    var err = _llm.load_model("res://addons/merlin_llm/models/phi3-mini-q4.gguf")
    if err != OK:
        push_error("Failed to load Merlin model")

# Génération asynchrone
func generate(context: Dictionary, callback: Callable):
    if _is_generating:
        push_warning("Merlin is already generating")
        return
    
    _is_generating = true
    generation_started.emit()
    
    var prompt = _build_prompt(context)
    _llm.generate_async(prompt, func(result):
        _is_generating = false
        if result.has("error"):
            generation_failed.emit(result.error)
        else:
            var parsed = _parse_response(result.text)
            response_ready.emit(parsed)
            if callback:
                callback.call(parsed)
    )

# Construction du prompt optimisé
func _build_prompt(context: Dictionary) -> String:
    var system = "Tu es Merlin, druide omniscient du Jeu des Oghams."
    
    var ctx_str = ""
    ctx_str += "Vie: %d/%d\n" % [context.hp, context.max_hp]
    ctx_str += "Zone: %d\n" % context.zone
    ctx_str += "Deck: %s\n" % str(context.deck)
    ctx_str += "Style: %s\n" % context.playstyle
    
    var user_query = context.get("query", "Que se passe-t-il ?")
    
    # Format optimisé pour Phi-3
    return "<|system|>%s<|end|><|user|>%s\n%s<|end|><|assistant|>" % [
        system, ctx_str, user_query
    ]

# Parse la réponse JSON si applicable
func _parse_response(text: String) -> Dictionary:
    # Extraction JSON si présent
    var json_regex = RegEx.new()
    json_regex.compile("\\{[^}]+\\}")
    var match = json_regex.search(text)
    
    if match:
        var json = JSON.new()
        if json.parse(match.get_string()) == OK:
            return json.get_data()
    
    # Sinon retour texte brut
    return {"text": text.strip_edges(), "type": "narrative"}
Wrapper C++ (Simplifié)
cpp// merlin_llm.h
#ifndef MERLIN_LLM_H
#define MERLIN_LLM_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/thread.hpp>
#include "llama.h"

class MerlinLLM : public godot::RefCounted {
    GDCLASS(MerlinLLM, godot::RefCounted)

private:
    llama_model* model = nullptr;
    llama_context* ctx = nullptr;
    godot::Ref<godot::Thread> inference_thread;
    bool is_generating = false;

protected:
    static void _bind_methods();

public:
    MerlinLLM();
    ~MerlinLLM();

    godot::Error load_model(godot::String path);
    void generate_async(godot::String prompt, godot::Callable callback);
    bool is_generating_now();
    void cancel_generation();
};

#endif
cpp// merlin_llm.cpp
#include "merlin_llm.h"
#include <godot_cpp/variant/utility_functions.hpp>

void MerlinLLM::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_model", "path"), &MerlinLLM::load_model);
    ClassDB::bind_method(D_METHOD("generate_async", "prompt", "callback"), &MerlinLLM::generate_async);
    ClassDB::bind_method(D_METHOD("is_generating_now"), &MerlinLLM::is_generating_now);
}

godot::Error MerlinLLM::load_model(godot::String path) {
    llama_backend_init();
    
    llama_model_params model_params = llama_model_default_params();
    model = llama_load_model_from_file(path.utf8().get_data(), model_params);
    
    if (!model) {
        godot::UtilityFunctions::printerr("Failed to load model");
        return godot::ERR_CANT_OPEN;
    }
    
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_threads = 4;
    ctx = llama_new_context_with_model(model, ctx_params);
    
    return godot::OK;
}

void MerlinLLM::generate_async(godot::String prompt, godot::Callable callback) {
    if (is_generating) return;
    
    is_generating = true;
    
    // Lancer thread d'inférence
    inference_thread = godot::Thread::create([this, prompt, callback]() {
        // Tokenize
        std::vector<llama_token> tokens = llama_tokenize(ctx, prompt.utf8().get_data(), true);
        
        // Generate
        godot::String result;
        for (int i = 0; i < 150; i++) {  // max_tokens
            llama_token token = llama_sample_token(ctx, /* sampling params */);
            if (token == llama_token_eos(model)) break;
            
            char buf[128];
            llama_token_to_piece(model, token, buf, sizeof(buf));
            result += godot::String(buf);
        }
        
        is_generating = false;
        
        // Callback sur thread principal
        godot::Dictionary response;
        response["text"] = result;
        callback.call(response);
    });
}

📦 FORMAT DES DONNÉES & COMMUNICATION
Structure du Contexte Jeu → Merlin
gdscript# Format ultra-compact pour économiser les tokens
var game_context = {
    "hp": 45,           # Vie actuelle
    "max_hp": 100,
    "zone": 3,          # Niveau/zone actuel
    "deck": ["R", "V", "C", "F"],  # Runes actuelles (codes courts)
    "playstyle": "aggressive",  # Détecté par patterns
    "last_combat": {
        "won": true,
        "turns": 8,
        "hp_lost": 25
    },
    "relics": ["brume", "pierre_lune"],  # Reliques possédées
    "query": "combat_start",  # Type de requête
    "enemy": "druide_noir"     # Contexte additionnel
}
Format des Réponses Merlin → Jeu
Type 1 : Narration Simple
json{
    "type": "narrative",
    "text": "Le vent tourne, voyageur. Prépare-toi.",
    "tone": "warning"  # neutral, warning, encouraging, taunting
}
Type 2 : Choix Interactifs
json{
    "type": "choices",
    "text": "La druidesse t'observe. Que fais-tu ?",
    "options": [
        {
            "id": "purify",
            "label": "Te purifier dans le ruisseau",
            "effect": {"heal": 15, "cost": "lose_rune"}
        },
        {
            "id": "listen",
            "label": "L'écouter attentivement",
            "effect": {"learn_word": true}
        },
        {
            "id": "challenge",
            "label": "La défier",
            "effect": {"combat": "druidesse", "reward": "high"}
        }
    ]
}
Type 3 : Génération de Mot Sacré
json{
    "type": "word_creation",
    "word": {
        "name": "BRANÚIL",
        "runes": ["R", "V", "C"],  # Racine, Vent, Chant
        "effect": {
            "type": "summon_totem",
            "power": 8,
            "duration": 3,
            "description": "Invoque un totem végétal qui attaque pour (8 × Vent) à chaque fin de tour."
        },
        "lore": "Souffle de l'Arbre Haut, né du murmure des branches ancestrales."
    }
}
Type 4 : Ajustement Difficulté
json{
    "type": "balance_adjustment",
    "changes": {
        "enemy_hp": 1.15,     # +15%
        "rune_drop": 0.9,     # -10%
        "special_event": "trial_of_wind"
    },
    "reason": "Le joueur maîtrise trop bien le Vent. Il est temps d'un défi."
}
```

---

## 💾 SYSTÈME DE PERSISTANCE

### Structure des Fichiers
```
user://
├── grimoire.json          # Tous les Mots découverts
├── player_profile.json    # Profil long-terme
└── current_run.json       # État de la run actuelle
grimoire.json
json{
    "version": 2,
    "words": [
        {
            "name": "BRANÚIL",
            "runes": ["R", "V", "C"],
            "effect": {...},
            "times_used": 12,
            "win_rate": 0.75,
            "discovered_at": "2024-01-15T10:30:00Z",
            "favorite": true  # Peut être consigné pour les prochaines parties
        }
    ],
    "total_words_created": 47
}
player_profile.json
json{
    "total_runs": 156,
    "victories": 23,
    "playstyle": {
        "aggressive": 0.65,
        "defensive": 0.20,
        "balanced": 0.15
    },
    "favorite_runes": ["V", "F"],  # Vent, Feu
    "longest_run": 18,
    "merlin_relationship": "respectful",  # neutral, respectful, defiant
    "achievements": ["first_victory", "word_master"],
    "banned_words": ["KROSSTORM"]  # Mots abusifs détectés
}
current_run.json
json{
    "run_id": "abc123",
    "zone": 5,
    "hp": 67,
    "deck": [...],
    "relics": [...],
    "events_seen": ["ruisseau", "menhir"],
    "words_this_run": [
        {"name": "BRANÚIL", "uses": 3},
        {"name": "KROSSTORM", "uses": 8}  # Détection d'abus
    ],
    "merlin_interventions": 7,
    "seed": 987654321  # Pour reproductibilité si nécessaire
}

⚡ GESTION DES PERFORMANCES
Optimisations LLM
1. Quantization Agressive

Utiliser 4-bit (GGUF Q4_K_M) prioritairement
Dégradation minimale de qualité
Gain mémoire : ~70%
Gain vitesse : ~40%

2. Context Window Réduit
gdscript# Au lieu de tout l'historique :
var context = {
    "recent_events": _last_n_events(3),  # Seulement les 3 derniers
    "critical_state": _extract_critical_state(),  # HP, zone, reliques importantes
    "query": current_query
}
3. Prompt Caching
gdscript# Cache des prompts système
var _system_prompt_cache = {}

func _get_system_prompt(type: String) -> String:
    if not _system_prompt_cache.has(type):
        _system_prompt_cache[type] = _load_system_prompt(type)
    return _system_prompt_cache[type]
4. Batch Inference (Optionnel)
gdscript# Pour événements non-critiques, grouper les requêtes
var _pending_requests = []

func request_generation(context: Dictionary, priority: int):
    if priority == HIGH:
        _generate_immediately(context)
    else:
        _pending_requests.append(context)
        if len(_pending_requests) >= 3:
            _batch_generate(_pending_requests)
Threading & Async
gdscript# Pendant génération : afficher brumes animées
func _on_merlin_generating():
    $MistEffect.show()
    $MistSound.play()
    $LoadingSpinner.rotation_speed = 0.5

func _on_merlin_ready(response):
    $MistEffect.hide()
    $MistSound.stop()
    _display_merlin_text(response.text)
Limites de Timeout
gdscriptconst GENERATION_TIMEOUT = 3.0  # secondes

func generate_with_timeout(context: Dictionary):
    var timer = get_tree().create_timer(GENERATION_TIMEOUT)
    timer.timeout.connect(_on_generation_timeout)
    
    _llm.generate_async(context, func(response):
        if timer:
            timer.timeout.disconnect(_on_generation_timeout)
        _handle_response(response)
    )

func _on_generation_timeout():
    push_warning("Merlin timed out, using fallback")
    _use_fallback_narrative()

🎲 ÉQUILIBRAGE DYNAMIQUE
Détection du Niveau du Joueur
gdscriptclass_name PlayerAnalyzer
extends Node

var _combat_history: Array[Dictionary] = []
var _difficulty_score: float = 0.5  # 0.0 = novice, 1.0 = expert

func analyze_combat(combat_data: Dictionary):
    _combat_history.append(combat_data)
    if len(_combat_history) > 10:
        _combat_history.pop_front()
    
    _update_difficulty_score()

func _update_difficulty_score():
    var avg_turns = 0.0
    var avg_hp_lost_percent = 0.0
    var win_rate = 0.0
    
    for combat in _combat_history:
        avg_turns += combat.turns
        avg_hp_lost_percent += combat.hp_lost / float(combat.max_hp)
        win_rate += 1.0 if combat.won else 0.0
    
    avg_turns /= len(_combat_history)
    avg_hp_lost_percent /= len(_combat_history)
    win_rate /= len(_combat_history)
    
    # Score composite
    _difficulty_score = (
        (1.0 - avg_turns / 15.0) * 0.3 +  # Combats courts = bon
        (1.0 - avg_hp_lost_percent) * 0.3 +  # Peu de dégâts = bon
        win_rate * 0.4  # Victoires = bon
    )
    
    _difficulty_score = clampf(_difficulty_score, 0.0, 1.0)

func get_recommended_scaling() -> Dictionary:
    if _difficulty_score < 0.3:
        return {"enemy_hp": 0.85, "rune_quality": 1.1, "help": true}
    elif _difficulty_score > 0.7:
        return {"enemy_hp": 1.2, "rune_quality": 0.9, "taunt": true}
    else:
        return {"enemy_hp": 1.0, "rune_quality": 1.0}
Ajustements Autorisés par Merlin
gdscript# Fourchettes de modification autorisées
const BALANCE_LIMITS = {
    "enemy_hp": [0.75, 1.35],       # ±25% / +35%
    "enemy_damage": [0.8, 1.25],
    "rune_drop_rate": [0.85, 1.15],
    "rune_power": [0.9, 1.1],
    "heal_amount": [0.9, 1.2]
}

func apply_merlin_adjustment(changes: Dictionary):
    for key in changes:
        if key in BALANCE_LIMITS:
            var value = changes[key]
            var limits = BALANCE_LIMITS[key]
            value = clampf(value, limits[0], limits[1])
            _apply_balance_change(key, value)
        else:
            push_warning("Merlin tried to modify unauthorized parameter: %s" % key)
Détection d'Abus de Mots
gdscriptfunc _check_word_abuse(word_stats: Dictionary) -> bool:
    # Si un mot est utilisé >60% du temps et win_rate >0.9
    if word_stats.usage_rate > 0.6 and word_stats.win_rate > 0.9:
        return true
    
    # Si dégâts moyens absurdes
    if word_stats.avg_damage > 100:  # Seuil arbitraire
        return true
    
    return false

func _nerf_abused_word(word_name: String):
    # Merlin intervient narrativement
    Merlin.generate({
        "type": "word_nerf",
        "word": word_name,
        "reason": "abuse_detected"
    }, func(response):
        _display_merlin_warning(response.text)
        _modify_word_effect(word_name, response.new_effect)
    )

📝 SYSTÈME DE GÉNÉRATION DE MOTS
Déclenchement de l'Oghamforge
gdscript# Aux Menhirs Sacrés (événements spéciaux)
func _trigger_oghamforge():
    var available_runes = GameState.player_deck.get_unique_runes()
    
    var context = {
        "type": "word_creation",
        "available_runes": available_runes,
        "player_style": PlayerAnalyzer.get_playstyle(),
        "existing_words": Grimoire.get_all_words(),
        "constraints": "balanced"  # ou "powerful" si le joueur galère
    }
    
    Merlin.generate(context, _on_word_created)
Validation & Enregistrement
gdscriptfunc _on_word_created(response: Dictionary):
    if response.type != "word_creation":
        return
    
    var word = response.word
    
    # Validation de sécurité
    if not _validate_word(word):
        push_error("Invalid word generated by Merlin")
        return
    
    # Enregistrement dans le Grimoire
    Grimoire.add_word(word)
    
    # Ajout au deck actuel
    GameState.current_run_words.append(word)
    
    # UI : Affichage dramatique
    $WordRevealAnimation.play(word)

func _validate_word(word: Dictionary) -> bool:
    # Checks basiques
    if not word.has_all(["name", "runes", "effect"]):
        return false
    
    if len(word.name) > 20:
        return false
    
    if len(word.runes) < 2 or len(word.runes) > 5:
        return false
    
    # Validation effet (pas d'instakill, etc.)
    var effect = word.effect
    if effect.has("damage") and effect.damage > 200:
        return false
    
    return true
Prompt Optimisé pour Génération de Mot
gdscriptfunc _build_word_creation_prompt(context: Dictionary) -> String:
    var runes_str = ", ".join(context.available_runes)
    
    return """<|system|>Tu es Merlin, maître des Oghams. Crée un Mot Sacré unique.
<|user|>
Runes disponibles: %s
Style du joueur: %s

Génère un Mot Sacré au format JSON:
{
  "name": "NOM_OGHAMIQUE",
  "runes": ["R", "V"],
  "effect": {
    "type": "damage|heal|buff|summon|control",
    "power": 10-50,
    "description": "Description claire de l'effet"
  },
  "lore": "Légende courte et poétique"
}
<|assistant|>""" % [runes_str, context.player_style]

🚨 GESTION DES ERREURS & FALLBACKS
Stratégie Multi-Niveaux
gdscriptenum FallbackLevel {
    RETRY,          # Réessayer la génération
    CACHED,         # Utiliser une réponse en cache
    PROCEDURAL,     # Générer procéduralement
    GENERIC         # Message générique
}

var _fallback_cache = {}
var _retry_count = 0
const MAX_RETRIES = 2

func _on_generation_failed(error: String):
    _retry_count += 1
    
    if _retry_count <= MAX_RETRIES:
        _use_fallback(FallbackLevel.RETRY, error)
    else:
        _use_fallback(FallbackLevel.CACHED, error)

func _use_fallback(level: FallbackLevel, context):
    match level:
        FallbackLevel.RETRY:
            await get_tree().create_timer(1.0).timeout
            _reinit_llm()
            Merlin.generate(context, _callback)
        
        FallbackLevel.CACHED:
            var cached = _get_cached_response(context.type)
            if cached:
                _handle_response(cached)
            else:
                _use_fallback(FallbackLevel.PROCEDURAL, context)
        
        FallbackLevel.PROCEDURAL:
            var generated = _procedural_generation(context)
            _handle_response(generated)
        
        FallbackLevel.GENERIC:
            _display_generic_message()
Messages Immersifs d'Erreur
gdscriptconst ERROR_MESSAGES = [
    "Merlin semble distrait par les brumes du temps...",
    "Les Oghams murmurent trop fort pour être entendus...",
    "Un voile mystique obscurcit la vision du druide...",
    "Les étoiles se cachent derrière les nuages..."
]

func _display_error_immersive():
    var msg = ERROR_MESSAGES.pick_random()
    $MerlinDialogue.show_text(msg, 2.0)
    $ErrorSound.play()
Diagnostic & Auto-Réparation
gdscriptfunc _run_llm_diagnostics():
    var tests = {
        "model_loaded": _llm.model != null,
        "context_valid": _llm.ctx != null,
        "memory_ok": OS.get_static_memory_usage() < 3_000_000_000,  # <3GB
        "not_overheating": false  # TODO: thermal monitoring sur mobile
    }
    
    var failed = []
    for test_name in tests:
        if not tests[test_name]:
            failed.append(test_name)
    
    if failed.is_empty():
        return true
    else:
        push_warning("LLM diagnostics failed: %s" % str(failed))
        _attempt_recovery(failed)
        return false

func _attempt_recovery(failed_tests: Array):
    if "model_loaded" in failed_tests:
        _reload_model()
    if "memory_ok" in failed_tests:
        _clear_caches()
        _compact_context()

🗺️ ROADMAP D'IMPLÉMENTATION
Phase 1 : Infrastructure (Semaines 1-2)

 Intégrer llama.cpp en GDExtension
 Compiler Phi-3 Mini en GGUF 4-bit
 Créer wrapper C++ basique
 Tests d'inférence simple (hello world)
 Mesures de performance (latence, mémoire)

Phase 2 : Interface Godot (Semaines 3-4)

 Créer MerlinCore GDScript
 Implémenter génération asynchrone
 Système de threading propre
 Gestion timeouts & erreurs
 UI de debug pour monitoring

Phase 3 : Formats & Communication (Semaine 5)

 Définir structures de contexte
 Parser réponses JSON
 Système de validation
 Cache de prompts système
 Tests d'intégration

Phase 4 : Persistance (Semaine 6)

 Système de Grimoire
 Profil joueur
 Sauvegarde runs
 Migration de schéma

Phase 5 : Génération de Mots (Semaines 7-8)

 Prompts de création Oghams
 Validation effets
 Enregistrement dynamique
 Tests équilibre

Phase 6 : Équilibrage Dynamique (Semaines 9-10)

 Analyseur de performance joueur
 Ajustements temps réel
 Détection abus
 Nerfs narratifs

Phase 7 : Narration Adaptative (Semaines 11-12)

 Système de choix interactifs
 Commentaires en combat
 Événements procéduraux
 Personnalisation Merlin

Phase 8 : Optimisation Mobile (Semaines 13-14)

 Profiling sur tablette
 Réduction mémoire
 Optimisation inférence
 Tests thermiques
 Batterie monitoring

Phase 9 : Polish & Tests (Semaines 15-16)

 Messages d'erreur immersifs
 Fallbacks robustes
 Tests utilisateurs
 Ajustements finaux


📊 MÉTRIQUES DE SUCCÈS
Performance Cible

✅ Temps réponse moyen : < 1.5 sec (combat)
✅ Temps réponse max : < 3 sec (hors combat)
✅ RAM utilisée : < 3.5 GB total
✅ Taux échec : < 2%
✅ Température CPU/GPU : < 85°C (mobile)

Qualité Narrative

✅ Cohérence générations : > 95%
✅ Diversité vocabulaire : high
✅ Pertinence contextuelle : > 90%

Équilibrage

✅ Win rate global : 40-60%
✅ Satisfaction difficulté : > 75%
✅ Abus détectés : < 5%


🔗 RESSOURCES & LIENS
Modèles

Phi-3 Mini
Llama 3.2 3B
Gemma 2B

Outils

llama.cpp
GDExtension Docs
GGUF Quantization Guide

Optimisation Mobile

ARM NEON Optimization
Metal Performance Shaders


Version du document : 1.0
Dernière mise à jour : 2024
Auteur : Architecture Technique DRU