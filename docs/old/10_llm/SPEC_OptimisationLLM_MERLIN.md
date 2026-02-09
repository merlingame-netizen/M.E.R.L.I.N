# Spécification Technique : Optimisation LLM pour M.E.R.L.I.N

**Version** : 1.0  
**Date** : 2025-01-31  
**Projet** : M.E.R.L.I.N - Le Jeu des Oghams  
**Objectif** : Réduire le temps de réponse LLM de ~5-10 secondes à < 500ms

---

## Table des matières

1. [Contexte et diagnostic](#1-contexte-et-diagnostic)
2. [Architecture cible](#2-architecture-cible)
3. [Phase 1 : Fast-Route déterministe](#3-phase-1--fast-route-déterministe)
4. [Phase 2 : Remplacement des modèles](#4-phase-2--remplacement-des-modèles)
5. [Phase 3 : Cache KV persistant](#5-phase-3--cache-kv-persistant)
6. [Phase 4 : Réponses templates hybrides](#6-phase-4--réponses-templates-hybrides)
7. [Phase 5 : Optimisations GDExtension](#7-phase-5--optimisations-gdextension)
8. [Phase 6 : Speculative Decoding (optionnel)](#8-phase-6--speculative-decoding-optionnel)
9. [Tests et validation](#9-tests-et-validation)
10. [Fichiers à modifier](#10-fichiers-à-modifier)
11. [Ressources et téléchargements](#11-ressources-et-téléchargements)

---

## 1. Contexte et diagnostic

### 1.1 Architecture actuelle

```
Entrée joueur
    │
    ▼
┌─────────────────────┐
│ Router LLM          │ ← Llama 3.2 3B Q6_K (~2.5 GB)
│ Latence: ~2-3s      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Executor LLM        │ ← Qwen 2.5 7B Q5_K_M (~5 GB)
│ Latence: ~5-8s      │
└──────────┬──────────┘
           │
           ▼
      Réponse
      
TOTAL: 7-11 secondes par requête
```

### 1.2 Problèmes identifiés

| Problème | Impact | Priorité |
|----------|--------|----------|
| Double inférence séquentielle | Latence x2 | CRITIQUE |
| Modèles surdimensionnés | Mémoire excessive, lenteur | HAUTE |
| Quantification qualité > vitesse | -30% vitesse | MOYENNE |
| Pas de cache KV | Re-calcul système à chaque fois | HAUTE |
| Pas de pré-classification | LLM appelé même pour cas triviaux | CRITIQUE |

### 1.3 Objectifs de performance

| Métrique | Actuel | Cible Phase 1 | Cible Finale |
|----------|--------|---------------|--------------|
| Latence moyenne | 7-11s | < 2s | < 500ms |
| Mémoire VRAM | ~7.5 GB | < 4 GB | < 3 GB |
| Cas instantanés | 0% | 60% | 80% |

---

## 2. Architecture cible

```
Entrée joueur
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    FAST-ROUTE                           │
│  Pattern matching + règles déterministes                │
│  Latence: 0ms | Couverture: ~70% des cas               │
└────────────────────────┬────────────────────────────────┘
                         │
            ┌────────────┴────────────┐
            │ Catégorie trouvée?      │
            └────────────┬────────────┘
                    Oui  │  Non
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌─────────────────┐             ┌─────────────────┐
│ TEMPLATE ENGINE │             │ MICRO-ROUTER    │
│ Réponses pré-   │             │ Phi-3.5 Mini    │
│ générées        │             │ 0.5B Q4_0       │
│ Latence: 0ms    │             │ Latence: ~100ms │
└────────┬────────┘             └────────┬────────┘
         │                               │
         │      ┌────────────────────────┘
         │      │
         ▼      ▼
┌─────────────────────────────────────────────────────────┐
│                 EXECUTOR LÉGER                          │
│  Qwen2.5 3B Q4_K_M avec KV Cache                       │
│  Latence: 200-400ms                                     │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
                    Réponse finale
```

---

## 3. Phase 1 : Fast-Route déterministe

**Priorité** : CRITIQUE  
**Effort** : 2-3 heures  
**Gain attendu** : -50% latence sur 70% des requêtes

### 3.1 Nouveau fichier : `addons/merlin_ai/fast_route.gd`

```gdscript
class_name FastRoute
extends RefCounted

## Système de classification rapide par règles déterministes
## Évite l'appel au LLM router pour les cas évidents

# Dictionnaire de patterns par catégorie
# Clé = catégorie, Valeur = Array de patterns (mots-clés, expressions)
const PATTERNS := {
	"combat": {
		"keywords": ["attaque", "attaquer", "frappe", "frapper", "combat", "combattre",
					 "tue", "tuer", "blesse", "blesser", "defend", "défendre", "défense",
					 "esquive", "esquiver", "pare", "parer", "riposte", "contre-attaque",
					 "dégât", "dégâts", "coup", "épée", "hache", "arc", "flèche",
					 "ennemi", "monstre", "créature", "adversaire", "cible"],
		"phrases": ["je frappe", "j'attaque", "je me défends", "je tire sur",
					"lance une attaque", "porte un coup", "vise la tête"],
		"excludes": ["comment attaquer", "règles de combat", "explique"]
	},
	"dialogue": {
		"keywords": ["parle", "parler", "dis", "dire", "demande", "demander",
					 "salue", "saluer", "bonjour", "bonsoir", "merci", "pnj",
					 "conversation", "discute", "discuter", "questionne", "interroge",
					 "négocie", "négocier", "marchande", "marchander", "convainc"],
		"phrases": ["je dis", "je lui parle", "je demande à", "je salue",
					"parle avec", "discute avec", "je réponds"],
		"excludes": []
	},
	"exploration": {
		"keywords": ["explore", "explorer", "cherche", "chercher", "fouille", "fouiller",
					 "examine", "examiner", "regarde", "regarder", "observe", "observer",
					 "inspecte", "inspecter", "entre", "entrer", "sors", "sortir",
					 "monte", "monter", "descends", "descendre", "ouvre", "ouvrir",
					 "porte", "coffre", "pièce", "salle", "couloir", "forêt", "grotte",
					 "direction", "nord", "sud", "est", "ouest", "gauche", "droite"],
		"phrases": ["je vais vers", "j'entre dans", "je fouille", "j'examine",
					"qu'est-ce qu'il y a", "je regarde autour", "j'ouvre la"],
		"excludes": ["comment explorer", "règles d'exploration"]
	},
	"inventaire": {
		"keywords": ["inventaire", "objet", "objets", "équipe", "équiper", "équipement",
					 "prends", "prendre", "ramasse", "ramasser", "dépose", "déposer",
					 "utilise", "utiliser", "consomme", "consommer", "bois", "boire",
					 "mange", "manger", "potion", "arme", "armure", "anneau", "amulette",
					 "sac", "bourse", "or", "pièces", "achète", "acheter", "vends", "vendre"],
		"phrases": ["je prends", "j'équipe", "j'utilise", "je bois", "je mange",
					"dans mon sac", "mon inventaire", "je ramasse"],
		"excludes": ["règles inventaire", "comment utiliser"]
	},
	"magie": {
		"keywords": ["magie", "magique", "sort", "sorts", "sortilège", "enchantement",
					 "ogham", "rune", "runes", "incantation", "invoque", "invoquer",
					 "conjure", "conjurer", "lance", "lancer", "mana", "énergie",
					 "druide", "druidique", "bénédiction", "malédiction", "aura",
					 "feu", "glace", "foudre", "terre", "vent", "eau", "lumière", "ombre"],
		"phrases": ["je lance", "j'invoque", "je conjure", "utilise la magie",
					"trace la rune", "active l'ogham", "incante"],
		"excludes": ["règles magie", "comment lancer", "explique la magie", "apprendre"]
	},
	"quete": {
		"keywords": ["quête", "quêtes", "mission", "missions", "objectif", "objectifs",
					 "journal", "accepte", "accepter", "refuse", "refuser", "abandonne",
					 "termine", "terminer", "complète", "compléter", "récompense",
					 "livraison", "escorte", "recherche", "enquête"],
		"phrases": ["j'accepte la quête", "je refuse la mission", "mes quêtes",
					"objectif suivant", "où dois-je aller", "qui dois-je voir"],
		"excludes": ["règles quêtes", "comment fonctionnent"]
	}
}

# Patterns pour les questions méta / demandes d'aide (ne pas router vers action)
const META_PATTERNS := {
	"keywords": ["règle", "règles", "explique", "expliquer", "comment", "pourquoi",
				 "aide", "aider", "tutoriel", "apprendre", "comprendre", "c'est quoi",
				 "définition", "signifie", "veut dire"],
	"phrases": ["comment ça marche", "explique-moi", "c'est quoi", "qu'est-ce que",
				"comment faire pour", "aide-moi à comprendre"]
}

## Analyse une entrée et retourne la catégorie si trouvée avec certitude
## Retourne "" si aucune correspondance certaine (fallback vers LLM)
static func classify(input: String) -> Dictionary:
	var lower := input.to_lower().strip_edges()
	var result := {"category": "", "confidence": 0.0, "is_meta": false, "method": "none"}
	
	# Vérifier d'abord si c'est une question méta
	if _is_meta_question(lower):
		result.is_meta = true
		result.category = "dialogue"  # Les questions méta vont au dialogue
		result.confidence = 0.8
		result.method = "meta_detection"
		return result
	
	# Scorer chaque catégorie
	var scores := {}
	var best_score := 0.0
	var best_category := ""
	
	for category in PATTERNS.keys():
		var score := _score_category(lower, PATTERNS[category])
		scores[category] = score
		if score > best_score:
			best_score = score
			best_category = category
	
	# Seuil de confiance pour éviter les faux positifs
	if best_score >= 0.6:
		result.category = best_category
		result.confidence = best_score
		result.method = "pattern_match"
	elif best_score >= 0.3:
		# Confiance moyenne - on suggère mais le LLM peut confirmer
		result.category = best_category
		result.confidence = best_score
		result.method = "pattern_suggest"
	
	return result

## Vérifie si l'input est une question méta (aide, règles, explications)
static func _is_meta_question(input: String) -> bool:
	for keyword in META_PATTERNS.keywords:
		if input.contains(keyword):
			return true
	for phrase in META_PATTERNS.phrases:
		if input.contains(phrase):
			return true
	return false

## Calcule un score de correspondance pour une catégorie
static func _score_category(input: String, patterns: Dictionary) -> float:
	var score := 0.0
	var matches := 0
	
	# Vérifier les exclusions d'abord
	for exclude in patterns.get("excludes", []):
		if input.contains(exclude):
			return 0.0
	
	# Scorer les mots-clés (poids: 0.15 chacun, max contribue 0.6)
	for keyword in patterns.get("keywords", []):
		if input.contains(keyword):
			matches += 1
			score += 0.15
	
	# Scorer les phrases exactes (poids: 0.4 chacune)
	for phrase in patterns.get("phrases", []):
		if input.contains(phrase):
			score += 0.4
	
	# Bonus si plusieurs mots-clés différents
	if matches >= 3:
		score += 0.2
	elif matches >= 2:
		score += 0.1
	
	# Normaliser entre 0 et 1
	return clampf(score, 0.0, 1.0)

## Méthode de test pour afficher les scores de toutes les catégories
static func debug_scores(input: String) -> Dictionary:
	var lower := input.to_lower().strip_edges()
	var scores := {}
	for category in PATTERNS.keys():
		scores[category] = _score_category(lower, PATTERNS[category])
	scores["_is_meta"] = _is_meta_question(lower)
	scores["_input"] = lower
	return scores
```

### 3.2 Modification de `addons/merlin_ai/merlin_ai.gd`

Remplacer la fonction `process_player_input` et `_route_input` :

```gdscript
# Ajouter en haut du fichier
const FastRoute = preload("res://addons/merlin_ai/fast_route.gd")

# Stats de performance (optionnel mais utile)
var stats := {
	"fast_route_hits": 0,
	"fast_route_suggests": 0,
	"llm_route_calls": 0,
	"total_requests": 0
}

func process_player_input(input_text: String) -> void:
	stats.total_requests += 1
	
	if not is_ready:
		_set_status("Connexion: OFF", "Modeles non charges", 0.0)
		error_occurred.emit("Modeles non charges")
		return
	
	# ÉTAPE 1: Essayer le fast-route d'abord
	var fast_result := FastRoute.classify(input_text)
	var category: String
	
	if fast_result.confidence >= 0.6:
		# Confiance haute - utiliser directement
		category = fast_result.category
		stats.fast_route_hits += 1
		_log("FastRoute: '%s' -> %s (%.0f%%)" % [input_text.substr(0, 30), category, fast_result.confidence * 100])
	elif fast_result.confidence >= 0.3:
		# Confiance moyenne - utiliser la suggestion mais noter
		category = fast_result.category
		stats.fast_route_suggests += 1
		_log("FastRoute (suggest): '%s' -> %s (%.0f%%)" % [input_text.substr(0, 30), category, fast_result.confidence * 100])
	else:
		# Pas de correspondance - fallback LLM
		category = await _route_input(input_text)
		stats.llm_route_calls += 1
		_log("LLM Route: '%s' -> %s" % [input_text.substr(0, 30), category])
	
	# ÉTAPE 2: Récupérer le contexte RAG
	var context = await rag_manager.get_relevant_context(input_text, category)
	
	# ÉTAPE 3: Exécuter avec le contexte
	var result = await _execute_with_context(input_text, context, category)
	
	# ÉTAPE 4: Valider et appliquer les actions
	if result.has("action") and result.action != null:
		var validated = action_validator.validate(result.action)
		if validated.valid:
			game_state_sync.apply_action(result.action)
			action_executed.emit(result.action)
		else:
			_log("Action invalide: " + JSON.stringify(validated.errors))
	
	# ÉTAPE 5: Historique et émission
	rag_manager.add_to_history(input_text, str(result.get("response", "")))
	response_received.emit(result)

## Retourne les statistiques de performance du routage
func get_routing_stats() -> Dictionary:
	var total = stats.total_requests
	if total == 0:
		return stats.duplicate()
	
	var result = stats.duplicate()
	result["fast_route_rate"] = "%.1f%%" % ((stats.fast_route_hits + stats.fast_route_suggests) / float(total) * 100)
	result["llm_route_rate"] = "%.1f%%" % (stats.llm_route_calls / float(total) * 100)
	return result

## Reset les statistiques
func reset_routing_stats() -> void:
	stats = {
		"fast_route_hits": 0,
		"fast_route_suggests": 0,
		"llm_route_calls": 0,
		"total_requests": 0
	}
```

### 3.3 Tests Phase 1

Créer `tests/test_fast_route.gd` :

```gdscript
extends SceneTree

const FastRoute = preload("res://addons/merlin_ai/fast_route.gd")

func _init() -> void:
	print("=== Tests FastRoute ===\n")
	
	var test_cases := [
		# Combat - doit matcher
		["J'attaque le gobelin avec mon épée", "combat", 0.6],
		["Je frappe l'ennemi", "combat", 0.6],
		["Je me défends contre l'attaque", "combat", 0.6],
		
		# Dialogue - doit matcher
		["Je parle au marchand", "dialogue", 0.6],
		["Bonjour, comment allez-vous ?", "dialogue", 0.6],
		["Je demande des informations au garde", "dialogue", 0.6],
		
		# Exploration - doit matcher
		["J'examine la pièce", "exploration", 0.6],
		["Je fouille le coffre", "exploration", 0.6],
		["J'entre dans la grotte", "exploration", 0.6],
		
		# Inventaire - doit matcher
		["Je prends la potion", "inventaire", 0.6],
		["J'équipe l'épée magique", "inventaire", 0.6],
		["Je regarde mon inventaire", "inventaire", 0.6],
		
		# Magie - doit matcher
		["Je lance un sort de feu", "magie", 0.6],
		["J'utilise la rune d'ogham", "magie", 0.6],
		["J'invoque un esprit", "magie", 0.6],
		
		# Quête - doit matcher
		["J'accepte la quête", "quete", 0.6],
		["Quel est mon objectif ?", "quete", 0.3],  # Moins certain
		
		# Meta questions - doit être détecté comme meta
		["Comment fonctionne la magie ?", "dialogue", 0.0],  # is_meta = true
		["Explique-moi les règles de combat", "dialogue", 0.0],  # is_meta = true
		
		# Ambigu - doit avoir faible confiance ou vide
		["Je fais quelque chose", "", 0.0],
		["Hmm intéressant", "", 0.0],
	]
	
	var passed := 0
	var failed := 0
	
	for test in test_cases:
		var input: String = test[0]
		var expected_category: String = test[1]
		var min_confidence: float = test[2]
		
		var result := FastRoute.classify(input)
		
		var category_ok := result.category == expected_category or (expected_category == "" and result.confidence < 0.3)
		var confidence_ok := result.confidence >= min_confidence or expected_category == ""
		
		if category_ok and confidence_ok:
			print("✓ PASS: '%s'" % input.substr(0, 40))
			passed += 1
		else:
			print("✗ FAIL: '%s'" % input.substr(0, 40))
			print("  Attendu: %s (>= %.1f)" % [expected_category, min_confidence])
			print("  Obtenu: %s (%.2f) [%s]" % [result.category, result.confidence, result.method])
			failed += 1
	
	print("\n=== Résultats ===")
	print("Passés: %d / %d" % [passed, passed + failed])
	print("Échoués: %d" % failed)
	
	# Debug d'un cas spécifique
	print("\n=== Debug exemple ===")
	var debug = FastRoute.debug_scores("Je lance un sort de feu sur le gobelin")
	for key in debug.keys():
		print("  %s: %s" % [key, debug[key]])
	
	quit()
```

Exécuter avec : `godot --headless --script tests/test_fast_route.gd`

---

## 4. Phase 2 : Remplacement des modèles

**Priorité** : HAUTE  
**Effort** : 1-2 heures (téléchargement + config)  
**Gain attendu** : -60% latence, -50% mémoire

### 4.1 Nouveaux modèles recommandés

#### Option A : Configuration équilibrée (recommandée)

| Rôle | Modèle | Taille | Lien |
|------|--------|--------|------|
| Micro-Router | `Qwen2.5-0.5B-Instruct-Q4_K_M.gguf` | ~400 MB | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) |
| Executor | `Qwen2.5-3B-Instruct-Q4_K_M.gguf` | ~2 GB | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF) |

#### Option B : Configuration ultra-légère (mobile)

| Rôle | Modèle | Taille | Lien |
|------|--------|--------|------|
| Micro-Router | `Qwen2.5-0.5B-Instruct-Q4_0.gguf` | ~350 MB | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF) |
| Executor | `Phi-3.5-mini-instruct-Q4_K_M.gguf` | ~2.2 GB | [HuggingFace](https://huggingface.co/microsoft/Phi-3.5-mini-instruct-gguf) |

#### Option C : Configuration qualité (PC gaming)

| Rôle | Modèle | Taille | Lien |
|------|--------|--------|------|
| Micro-Router | `Qwen2.5-1.5B-Instruct-Q4_K_M.gguf` | ~1 GB | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF) |
| Executor | `Qwen2.5-7B-Instruct-Q4_K_M.gguf` | ~4.5 GB | [HuggingFace](https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF) |

### 4.2 Modification des constantes dans `merlin_ai.gd`

```gdscript
# AVANT
const ROUTER_FILE := "res://addons/merlin_llm/models/llama-3.2-3b-instruct-q6_k.gguf"
const EXECUTOR_FILE := "res://addons/merlin_llm/models/qwen2.5-7b-instruct-q5_k_m.gguf"

# APRÈS (Option A recommandée)
const ROUTER_FILE := "res://addons/merlin_llm/models/qwen2.5-0.5b-instruct-q4_k_m.gguf"
const EXECUTOR_FILE := "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"

# Paramètres optimisés pour les nouveaux modèles
var router_params := {
	"temperature": 0.1,      # Plus bas = plus déterministe pour le routage
	"top_p": 0.9,
	"max_tokens": 32         # Réduit de 64 - on n'a besoin que d'un mot
}

var executor_params := {
	"temperature": 0.7,
	"top_p": 0.9,
	"max_tokens": 256        # Réduit de 512 - réponses plus concises
}
```

### 4.3 Script de téléchargement automatique

Créer `tools/download_models.py` :

```python
#!/usr/bin/env python3
"""
Script de téléchargement des modèles GGUF pour M.E.R.L.I.N
Usage: python download_models.py [--config balanced|lightweight|quality]
"""

import os
import sys
import urllib.request
import hashlib
from pathlib import Path

MODELS_DIR = Path("addons/merlin_llm/models")

CONFIGS = {
    "balanced": {
        "router": {
            "url": "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
            "filename": "qwen2.5-0.5b-instruct-q4_k_m.gguf",
            "size_mb": 400
        },
        "executor": {
            "url": "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf",
            "filename": "qwen2.5-3b-instruct-q4_k_m.gguf",
            "size_mb": 2000
        }
    },
    "lightweight": {
        "router": {
            "url": "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_0.gguf",
            "filename": "qwen2.5-0.5b-instruct-q4_0.gguf",
            "size_mb": 350
        },
        "executor": {
            "url": "https://huggingface.co/microsoft/Phi-3.5-mini-instruct-gguf/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf",
            "filename": "phi-3.5-mini-instruct-q4_k_m.gguf",
            "size_mb": 2200
        }
    },
    "quality": {
        "router": {
            "url": "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
            "filename": "qwen2.5-1.5b-instruct-q4_k_m.gguf",
            "size_mb": 1000
        },
        "executor": {
            "url": "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf",
            "filename": "qwen2.5-7b-instruct-q4_k_m.gguf",
            "size_mb": 4500
        }
    }
}

def download_with_progress(url: str, dest: Path, expected_size_mb: int):
    """Télécharge un fichier avec barre de progression"""
    print(f"Téléchargement: {dest.name}")
    print(f"Taille estimée: {expected_size_mb} MB")
    
    if dest.exists():
        actual_size = dest.stat().st_size / (1024 * 1024)
        if actual_size > expected_size_mb * 0.9:
            print(f"  Fichier existe déjà ({actual_size:.0f} MB), skip.")
            return True
    
    try:
        def report_progress(block_num, block_size, total_size):
            downloaded = block_num * block_size
            if total_size > 0:
                percent = downloaded * 100 / total_size
                mb_down = downloaded / (1024 * 1024)
                mb_total = total_size / (1024 * 1024)
                sys.stdout.write(f"\r  {percent:.1f}% ({mb_down:.0f}/{mb_total:.0f} MB)")
                sys.stdout.flush()
        
        urllib.request.urlretrieve(url, dest, report_progress)
        print("\n  Terminé!")
        return True
    except Exception as e:
        print(f"\n  ERREUR: {e}")
        return False

def main():
    config_name = sys.argv[1] if len(sys.argv) > 1 else "balanced"
    config_name = config_name.replace("--config", "").replace("=", "").strip()
    
    if not config_name or config_name not in CONFIGS:
        config_name = "balanced"
    
    print(f"Configuration: {config_name}")
    print(f"Dossier cible: {MODELS_DIR.absolute()}")
    print()
    
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    
    config = CONFIGS[config_name]
    
    for role, model_info in config.items():
        dest = MODELS_DIR / model_info["filename"]
        success = download_with_progress(
            model_info["url"],
            dest,
            model_info["size_mb"]
        )
        if not success:
            print(f"ÉCHEC du téléchargement de {role}")
            sys.exit(1)
    
    print("\n=== Téléchargements terminés ===")
    print("Modèles disponibles:")
    for f in MODELS_DIR.glob("*.gguf"):
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"  {f.name}: {size_mb:.0f} MB")

if __name__ == "__main__":
    main()
```

---

## 5. Phase 3 : Cache KV persistant

**Priorité** : HAUTE  
**Effort** : 4-6 heures (modification GDExtension)  
**Gain attendu** : -40% latence sur requêtes suivantes

### 5.1 Concept

Le prompt système est identique pour toutes les requêtes. Au lieu de le re-tokeniser et re-calculer à chaque fois, on peut :

1. Calculer le KV cache du prompt système une fois au chargement
2. Sauvegarder ce cache en mémoire
3. Pour chaque requête, reprendre depuis ce cache

### 5.2 Modifications GDExtension (`merlin_llm.cpp`)

```cpp
// Ajouter ces méthodes à la classe MerlinLLM

// Structure pour stocker un cache KV
struct KVCacheState {
    std::vector<llama_token> tokens;
    llama_kv_cache_seq_state* state = nullptr;
    int n_past = 0;
};

std::map<std::string, KVCacheState> kv_caches;

// Créer un cache KV pour un prompt système
Variant create_kv_cache(const String& cache_name, const String& system_prompt) {
    if (!ctx) {
        return Dictionary::make("error", "Context not initialized");
    }
    
    // Tokeniser le prompt système
    std::string prompt_str = system_prompt.utf8().get_data();
    std::vector<llama_token> tokens = llama_tokenize(ctx, prompt_str, true);
    
    // Évaluer les tokens pour remplir le KV cache
    for (int i = 0; i < tokens.size(); i += batch_size) {
        int n_eval = std::min((int)tokens.size() - i, batch_size);
        llama_eval(ctx, tokens.data() + i, n_eval, kv_caches[cache_name.utf8().get_data()].n_past, n_threads);
        kv_caches[cache_name.utf8().get_data()].n_past += n_eval;
    }
    
    // Sauvegarder l'état
    KVCacheState& cache = kv_caches[cache_name.utf8().get_data()];
    cache.tokens = tokens;
    
    Dictionary result;
    result["success"] = true;
    result["cache_name"] = cache_name;
    result["n_tokens"] = (int)tokens.size();
    return result;
}

// Générer en utilisant un cache KV existant
Variant generate_with_kv_cache(const String& cache_name, const String& user_input, 
                                float temperature, float top_p, int max_tokens) {
    auto it = kv_caches.find(cache_name.utf8().get_data());
    if (it == kv_caches.end()) {
        return Dictionary::make("error", "Cache not found: " + cache_name);
    }
    
    // Restaurer le KV cache au point sauvegardé
    // (implémentation dépend de la version de llama.cpp)
    
    // Tokeniser et évaluer l'input utilisateur
    std::string input_str = user_input.utf8().get_data();
    std::vector<llama_token> input_tokens = llama_tokenize(ctx, input_str, false);
    
    // Continuer l'évaluation depuis le cache
    int n_past = it->second.n_past;
    for (int i = 0; i < input_tokens.size(); i += batch_size) {
        int n_eval = std::min((int)input_tokens.size() - i, batch_size);
        llama_eval(ctx, input_tokens.data() + i, n_eval, n_past, n_threads);
        n_past += n_eval;
    }
    
    // Générer la réponse
    std::string response = sample_tokens(temperature, top_p, max_tokens, n_past);
    
    Dictionary result;
    result["text"] = String(response.c_str());
    return result;
}

// Invalider un cache
void invalidate_kv_cache(const String& cache_name) {
    kv_caches.erase(cache_name.utf8().get_data());
}
```

### 5.3 Utilisation côté GDScript

```gdscript
# Dans merlin_ai.gd

var system_cache_name := "merlin_system"
var system_cache_ready := false

func _init_system_cache() -> void:
    if executor_llm == null or not is_ready:
        return
    
    var system_prompt = prompts.get("executor_system", "")
    if system_prompt.is_empty():
        return
    
    _log("Création du cache KV système...")
    var result = executor_llm.create_kv_cache(system_cache_name, system_prompt)
    
    if result.has("success") and result.success:
        system_cache_ready = true
        _log("Cache KV créé: %d tokens pré-calculés" % result.n_tokens)
    else:
        _log("Échec création cache: " + str(result.get("error", "inconnu")))

func _execute_with_context_cached(input_text: String, context: Dictionary, category: String) -> Dictionary:
    if not system_cache_ready:
        # Fallback vers la méthode standard
        return await _execute_with_context(input_text, context, category)
    
    # Construire seulement la partie dynamique du prompt
    var dynamic_prompt = """
Context: {context}
Category: {category}
User: {input}
Assistant:""".format({
        "context": JSON.stringify(context),
        "category": category,
        "input": input_text
    })
    
    # Générer avec le cache
    var result = executor_llm.generate_with_kv_cache(
        system_cache_name,
        dynamic_prompt,
        executor_params.temperature,
        executor_params.top_p,
        executor_params.max_tokens
    )
    
    if result.has("error"):
        return {"response": "Erreur: " + str(result.error), "action": null}
    
    return _parse_executor_response(str(result.get("text", "")))
```

---

## 6. Phase 4 : Réponses templates hybrides

**Priorité** : MOYENNE  
**Effort** : 3-4 heures  
**Gain attendu** : Réponses instantanées pour 30-40% des cas

### 6.1 Nouveau fichier : `addons/merlin_ai/response_templates.gd`

```gdscript
class_name ResponseTemplates
extends RefCounted

## Système de réponses pré-générées pour les actions courantes
## Permet des réponses instantanées sans appel LLM

# Templates de combat
const COMBAT := {
	"attaque_reussie": [
		"Ton {arme} frappe {cible} de plein fouet ! {degats} points de dégâts.",
		"Touché ! {cible} encaisse {degats} dégâts de ton {arme}.",
		"Ton coup porte ! {cible} perd {degats} points de vie."
	],
	"attaque_ratee": [
		"{cible} esquive ton attaque avec agilité.",
		"Tu frappes dans le vide. {cible} a anticipé ton mouvement.",
		"Raté ! {cible} se décale au dernier moment."
	],
	"attaque_critique": [
		"COUP CRITIQUE ! Ton {arme} s'illumine d'une lueur druidique ! {degats} dégâts !",
		"Les runes de ton {arme} brillent ! Coup dévastateur : {degats} dégâts !",
		"Frappe parfaite ! Les esprits guident ton {arme}. {degats} dégâts !"
	],
	"defense_reussie": [
		"Tu bloques l'attaque de {source} avec ton {bouclier}.",
		"Ton {bouclier} absorbe le coup de {source}.",
		"Parade réussie ! L'attaque de {source} glisse sur ta défense."
	],
	"defense_ratee": [
		"L'attaque de {source} passe ta garde ! Tu subis {degats} dégâts.",
		"Tu n'as pas pu bloquer. {degats} points de dégâts encaissés.",
		"{source} te touche malgré ta défense. -{degats} PV."
	],
	"mort_ennemi": [
		"{cible} s'effondre, vaincu par ton {arme}.",
		"Tu as terrassé {cible} ! La voie est libre.",
		"{cible} pousse un dernier cri et tombe inerte."
	],
	"fuite": [
		"Tu te replies prudemment. Le combat attendra.",
		"Sagesse de druide : tu choisis de te retirer.",
		"Tu quittes le combat. Parfois, la retraite est victoire."
	]
}

# Templates d'exploration
const EXPLORATION := {
	"fouille_succes": [
		"Tu fouilles {lieu} et découvres {objet} !",
		"En examinant {lieu}, tu trouves {objet}.",
		"Bonne trouvaille ! {objet} était caché dans {lieu}."
	],
	"fouille_echec": [
		"Tu fouilles {lieu} mais ne trouves rien d'intéressant.",
		"Rien de notable dans {lieu}.",
		"{lieu} ne révèle aucun secret."
	],
	"porte_ouverte": [
		"La porte s'ouvre sur {description}.",
		"Tu ouvres la porte. Devant toi : {description}.",
		"Derrière la porte se trouve {description}."
	],
	"porte_fermee": [
		"La porte est verrouillée. Il te faut une clé ou un sort.",
		"Cette porte refuse de s'ouvrir. Cherche un autre moyen.",
		"Verrouillée. Les runes sur le cadre semblent actives."
	],
	"piege_declenche": [
		"PIÈGE ! {effet}. Tu subis {degats} dégâts.",
		"Tu déclenches un piège ! {effet}. -{degats} PV.",
		"Attention ! Un piège s'active : {effet}."
	],
	"piege_evite": [
		"Tu repères un piège à temps et l'évites.",
		"Ton instinct de druide t'alerte. Piège évité.",
		"Tu contournes prudemment le mécanisme piégé."
	]
}

# Templates d'inventaire
const INVENTAIRE := {
	"objet_ramasse": [
		"Tu ramasses {objet}. Ajouté à ton inventaire.",
		"{objet} rejoint ton sac.",
		"Tu prends {objet}."
	],
	"objet_equipe": [
		"Tu équipes {objet}. {effet}",
		"{objet} est maintenant équipé. {effet}",
		"Tu portes désormais {objet}. {effet}"
	],
	"objet_utilise": [
		"Tu utilises {objet}. {effet}",
		"{objet} activé : {effet}",
		"L'effet de {objet} se manifeste : {effet}"
	],
	"potion_bue": [
		"Tu bois la {potion}. {effet} (+{valeur} PV)",
		"La {potion} te revigore. +{valeur} points de vie.",
		"Tu avales la {potion}. Récupération : +{valeur} PV."
	],
	"inventaire_plein": [
		"Ton inventaire est plein. Dépose quelque chose d'abord.",
		"Plus de place ! Il faut te délester.",
		"Sac plein. Que veux-tu abandonner ?"
	]
}

# Templates de magie
const MAGIE := {
	"sort_lance": [
		"Tu traces la rune {rune} ! {effet}",
		"L'ogham {rune} s'illumine. {effet}",
		"Ta magie druidique invoque {rune}. {effet}"
	],
	"sort_echec": [
		"Le sort échoue. Les énergies se dispersent.",
		"Ta concentration flanche. La rune s'efface.",
		"Échec de l'incantation. Réessaie."
	],
	"mana_insuffisant": [
		"Pas assez de mana pour ce sort.",
		"Ton énergie druidique est trop faible.",
		"Il te faut plus de mana. Médite ou utilise un cristal."
	],
	"buff_actif": [
		"L'aura de {effet} t'enveloppe. Durée : {duree} tours.",
		"Bénédiction de {effet} active pour {duree} tours.",
		"Tu ressens la puissance de {effet}. ({duree} tours)"
	]
}

# Templates de dialogue
const DIALOGUE := {
	"salutation": [
		"« Bien le bonjour, voyageur. Que puis-je pour toi ? »",
		"« Ah, un visiteur ! Sois le bienvenu. »",
		"« Que les esprits te guident. Comment puis-je t'aider ? »"
	],
	"marchand_achat": [
		"« Excellent choix ! Cela fera {prix} pièces d'or. »",
		"« {objet} ? {prix} pièces et il est à toi. »",
		"« Pour {objet}, je demande {prix} or. Marché conclu ? »"
	],
	"marchand_vente": [
		"« Je t'en donne {prix} pièces. Ça te va ? »",
		"« Hmm, {objet}... {prix} or, c'est mon offre. »",
		"« Pour {objet}, je propose {prix} pièces d'or. »"
	],
	"quete_acceptee": [
		"« Parfait ! Je compte sur toi, druide. »",
		"« Merci d'accepter. Reviens quand ce sera fait. »",
		"« Que les anciens te protègent dans cette quête. »"
	],
	"quete_refusee": [
		"« Je comprends. Reviens si tu changes d'avis. »",
		"« Dommage. La porte reste ouverte. »",
		"« Soit. Peut-être une autre fois. »"
	]
}

# Sélectionne aléatoirement un template et le remplit
static func generate(category: String, template_type: String, params: Dictionary = {}) -> String:
	var templates_dict: Dictionary
	match category:
		"combat": templates_dict = COMBAT
		"exploration": templates_dict = EXPLORATION
		"inventaire": templates_dict = INVENTAIRE
		"magie": templates_dict = MAGIE
		"dialogue": templates_dict = DIALOGUE
		_: return ""
	
	if not templates_dict.has(template_type):
		return ""
	
	var templates: Array = templates_dict[template_type]
	var template: String = templates[randi() % templates.size()]
	
	# Remplacer les placeholders
	for key in params.keys():
		template = template.replace("{" + key + "}", str(params[key]))
	
	return template

# Vérifie si un template existe pour cette catégorie/type
static func has_template(category: String, template_type: String) -> bool:
	var templates_dict: Dictionary
	match category:
		"combat": templates_dict = COMBAT
		"exploration": templates_dict = EXPLORATION
		"inventaire": templates_dict = INVENTAIRE
		"magie": templates_dict = MAGIE
		"dialogue": templates_dict = DIALOGUE
		_: return false
	return templates_dict.has(template_type)

# Liste tous les types de templates disponibles pour une catégorie
static func list_template_types(category: String) -> Array:
	var templates_dict: Dictionary
	match category:
		"combat": templates_dict = COMBAT
		"exploration": templates_dict = EXPLORATION
		"inventaire": templates_dict = INVENTAIRE
		"magie": templates_dict = MAGIE
		"dialogue": templates_dict = DIALOGUE
		_: return []
	return templates_dict.keys()
```

### 6.2 Intégration dans le flux principal

```gdscript
# Dans merlin_ai.gd, ajouter :

const ResponseTemplates = preload("res://addons/merlin_ai/response_templates.gd")

## Tente de générer une réponse instantanée via template
## Retourne null si pas de template approprié
func _try_instant_response(input: String, category: String, game_context: Dictionary) -> Variant:
	# Analyser l'input pour déterminer le type d'action
	var action_type := _detect_action_type(input, category)
	
	if action_type.is_empty():
		return null
	
	if not ResponseTemplates.has_template(category, action_type):
		return null
	
	# Construire les paramètres depuis le contexte de jeu
	var params := _build_template_params(action_type, game_context)
	
	var response := ResponseTemplates.generate(category, action_type, params)
	
	if response.is_empty():
		return null
	
	return {
		"response": response,
		"action": _build_action_from_type(action_type, params),
		"source": "template"
	}

func _detect_action_type(input: String, category: String) -> String:
	var lower := input.to_lower()
	
	match category:
		"combat":
			if "attaque" in lower or "frappe" in lower:
				return "attaque_reussie"  # Le résultat sera calculé par le système de combat
			if "défend" in lower or "pare" in lower:
				return "defense_reussie"
			if "fuis" in lower or "retraite" in lower:
				return "fuite"
		"exploration":
			if "fouille" in lower or "cherche" in lower:
				return "fouille_succes"
			if "ouvre" in lower and "porte" in lower:
				return "porte_ouverte"
		"inventaire":
			if "prends" in lower or "ramasse" in lower:
				return "objet_ramasse"
			if "équipe" in lower:
				return "objet_equipe"
			if "bois" in lower and "potion" in lower:
				return "potion_bue"
		"magie":
			if "lance" in lower or "incante" in lower:
				return "sort_lance"
	
	return ""

func _build_template_params(action_type: String, context: Dictionary) -> Dictionary:
	# Extraire les infos pertinentes du contexte de jeu
	var params := {}
	
	# Joueur
	if context.has("player"):
		var player = context.player
		params["arme"] = player.get("equipped_weapon", "arme")
		params["bouclier"] = player.get("equipped_shield", "bouclier")
	
	# Cible actuelle
	if context.has("current_target"):
		params["cible"] = context.current_target.get("name", "l'ennemi")
	
	# Lieu actuel
	if context.has("current_location"):
		params["lieu"] = context.current_location.get("name", "les environs")
	
	# Valeurs par défaut
	params["degats"] = randi_range(5, 20)
	params["valeur"] = randi_range(10, 30)
	params["prix"] = randi_range(10, 100)
	params["duree"] = randi_range(2, 5)
	
	return params
```

---

## 7. Phase 5 : Optimisations GDExtension

**Priorité** : MOYENNE  
**Effort** : 2-4 heures  
**Gain attendu** : +20-50% vitesse d'inférence

### 7.1 Paramètres llama.cpp recommandés

Modifier la création du contexte dans `merlin_llm.cpp` :

```cpp
llama_context_params get_optimized_context_params() {
    llama_context_params params = llama_context_default_params();
    
    // Contexte réduit pour réponses courtes
    params.n_ctx = 2048;           // Au lieu de 4096 par défaut
    
    // Batch processing
    params.n_batch = 512;          // Tokens traités par batch
    params.n_ubatch = 512;         // Micro-batch pour GPU
    
    // Threads CPU (ajuster selon la plateforme)
    #ifdef __ANDROID__
        params.n_threads = 4;      // Mobile
    #else
        params.n_threads = 8;      // Desktop
    #endif
    
    // GPU offloading (si disponible)
    params.n_gpu_layers = 99;      // Tout sur GPU si possible
    
    // Optimisations mémoire
    params.flash_attn = true;      // Flash Attention (si supporté)
    params.no_alloc = false;
    
    // Type de données
    params.type_k = GGML_TYPE_Q8_0;  // Quantification KV cache
    params.type_v = GGML_TYPE_Q8_0;
    
    return params;
}
```

### 7.2 Sampling optimisé

```cpp
// Sampling simplifié pour réponses rapides
std::string fast_sample(int max_tokens, float temperature, float top_p) {
    std::string result;
    llama_token token;
    
    llama_sampling_params sparams;
    sparams.temp = temperature;
    sparams.top_p = top_p;
    sparams.top_k = 40;           // Limiter les candidats
    sparams.repeat_penalty = 1.1f;
    sparams.repeat_last_n = 64;
    
    for (int i = 0; i < max_tokens; i++) {
        token = llama_sampling_sample(ctx, &sparams);
        
        // Arrêt anticipé sur tokens de fin
        if (token == llama_token_eos(model) || 
            token == llama_token_nl(model) && i > 10) {
            break;
        }
        
        result += llama_token_to_str(ctx, token);
        llama_eval(ctx, &token, 1, n_past++, n_threads);
    }
    
    return result;
}
```

### 7.3 Mode "turbo" pour le router

```cpp
// Génération ultra-rapide pour classification (1 seul token)
std::string classify_fast(const std::string& prompt) {
    // Tokeniser
    std::vector<llama_token> tokens = llama_tokenize(ctx, prompt, true);
    
    // Évaluer en une seule passe
    llama_eval(ctx, tokens.data(), tokens.size(), 0, n_threads);
    
    // Sampler un seul token avec température basse
    llama_sampling_params sparams;
    sparams.temp = 0.1f;
    sparams.top_k = 10;
    
    llama_token token = llama_sampling_sample(ctx, &sparams);
    return llama_token_to_str(ctx, token);
}
```

---

## 8. Phase 6 : Speculative Decoding (optionnel)

**Priorité** : BASSE  
**Effort** : 6-10 heures  
**Gain attendu** : 2-3x vitesse sur réponses longues

### 8.1 Concept

Utilise un petit modèle "draft" (0.5B) pour générer des tokens candidats rapidement, puis le modèle principal vérifie en batch. Si le draft a raison (souvent pour du texte prévisible), on gagne du temps.

### 8.2 Implémentation simplifiée

```cpp
struct SpeculativeDecoder {
    llama_context* draft_ctx;   // Petit modèle (0.5B)
    llama_context* main_ctx;    // Modèle principal (3B)
    int speculation_length = 4; // Tokens générés d'avance
    
    std::string generate(const std::string& prompt, int max_tokens) {
        std::string result;
        std::vector<llama_token> prompt_tokens = tokenize(prompt);
        
        // Initialiser les deux modèles
        eval_both(prompt_tokens);
        
        int generated = 0;
        while (generated < max_tokens) {
            // Phase 1: Draft génère N tokens candidats
            std::vector<llama_token> candidates;
            for (int i = 0; i < speculation_length; i++) {
                llama_token t = sample_draft();
                candidates.push_back(t);
                eval_draft(t);
            }
            
            // Phase 2: Main vérifie les candidats en batch
            int accepted = verify_candidates(candidates);
            
            // Ajouter les tokens acceptés
            for (int i = 0; i < accepted; i++) {
                result += token_to_str(candidates[i]);
                generated++;
            }
            
            // Si tout accepté, continuer la spéculation
            // Sinon, resynchroniser les modèles
            if (accepted < speculation_length) {
                resync_contexts();
            }
            
            // Vérifier fin de séquence
            if (is_end_token(candidates[accepted - 1])) {
                break;
            }
        }
        
        return result;
    }
};
```

### 8.3 Quand utiliser le speculative decoding

| Cas d'usage | Utiliser ? | Raison |
|-------------|------------|--------|
| Réponses < 50 tokens | Non | Overhead > gain |
| Réponses 50-200 tokens | Oui | Sweet spot |
| Réponses > 200 tokens | Oui | Gain maximal |
| Classification/routing | Non | Un seul token |

---

## 9. Tests et validation

### 9.1 Benchmark de latence

Créer `tests/benchmark_llm.gd` :

```gdscript
extends SceneTree

var merlin_ai: Node

func _init() -> void:
	print("=== Benchmark LLM M.E.R.L.I.N ===\n")
	
	# Charger MerlinAI
	merlin_ai = load("res://addons/merlin_ai/merlin_ai.gd").new()
	add_child(merlin_ai)
	
	# Attendre initialisation
	await merlin_ai.ready_changed
	
	if not merlin_ai.is_ready:
		print("ERREUR: MerlinAI non prêt")
		quit()
		return
	
	await run_benchmarks()
	quit()

func run_benchmarks() -> void:
	var test_inputs := [
		# Court, simple
		"Bonjour Merlin",
		"J'attaque le gobelin",
		"Je fouille le coffre",
		
		# Moyen
		"Je veux parler au marchand pour acheter une potion",
		"Je lance un sort de feu sur l'ennemi le plus proche",
		
		# Complexe
		"Explique-moi comment fonctionne le système de magie druidique",
		"Quelles sont mes options dans ce combat contre le dragon ?",
	]
	
	var results := []
	
	for input in test_inputs:
		print("Test: '%s'" % input.substr(0, 40))
		
		var start_time := Time.get_ticks_msec()
		
		# Mesurer le fast-route
		var fast_start := Time.get_ticks_msec()
		var fast_result := FastRoute.classify(input)
		var fast_time := Time.get_ticks_msec() - fast_start
		
		# Mesurer la génération complète
		await merlin_ai.process_player_input(input)
		
		var total_time := Time.get_ticks_msec() - start_time
		
		results.append({
			"input": input.substr(0, 40),
			"fast_route_ms": fast_time,
			"fast_route_hit": fast_result.confidence >= 0.6,
			"total_ms": total_time
		})
		
		print("  FastRoute: %d ms (hit: %s)" % [fast_time, fast_result.confidence >= 0.6])
		print("  Total: %d ms" % total_time)
		print()
	
	# Résumé
	print("=== RÉSUMÉ ===")
	var total_fast := 0
	var total_full := 0
	var fast_hits := 0
	
	for r in results:
		total_fast += r.fast_route_ms
		total_full += r.total_ms
		if r.fast_route_hit:
			fast_hits += 1
	
	print("Tests: %d" % results.size())
	print("FastRoute hits: %d / %d (%.0f%%)" % [fast_hits, results.size(), float(fast_hits) / results.size() * 100])
	print("Temps moyen FastRoute: %.1f ms" % (float(total_fast) / results.size()))
	print("Temps moyen total: %.0f ms" % (float(total_full) / results.size()))
	
	# Statistiques de routage
	var stats = merlin_ai.get_routing_stats()
	print("\nStatistiques de routage:")
	for key in stats.keys():
		print("  %s: %s" % [key, stats[key]])
```

### 9.2 Critères de validation

| Métrique | Seuil minimum | Objectif | Critique |
|----------|---------------|----------|----------|
| Latence P50 | < 2000 ms | < 500 ms | < 300 ms |
| Latence P95 | < 5000 ms | < 1500 ms | < 800 ms |
| FastRoute accuracy | > 85% | > 92% | > 95% |
| Mémoire VRAM | < 6 GB | < 4 GB | < 3 GB |
| Réponses cohérentes | > 90% | > 95% | > 98% |

### 9.3 Tests de régression qualité

```gdscript
# tests/test_response_quality.gd
var quality_tests := [
	{
		"input": "J'attaque le gobelin",
		"expected_category": "combat",
		"must_contain": ["attaque", "gobelin", "dégât"],
		"must_not_contain": ["erreur", "impossible", "English"]
	},
	{
		"input": "Raconte-moi une histoire celtique",
		"expected_category": "dialogue",
		"must_contain": [],  # Réponse libre
		"must_not_contain": ["erreur", "cannot", "I don't"]
	}
]
```

---

## 10. Fichiers à modifier

### 10.1 Résumé des modifications

| Fichier | Action | Phase |
|---------|--------|-------|
| `addons/merlin_ai/fast_route.gd` | CRÉER | 1 |
| `addons/merlin_ai/merlin_ai.gd` | MODIFIER | 1, 3, 4 |
| `addons/merlin_ai/response_templates.gd` | CRÉER | 4 |
| `addons/merlin_llm/src/merlin_llm.cpp` | MODIFIER | 3, 5, 6 |
| `tools/download_models.py` | CRÉER | 2 |
| `tests/test_fast_route.gd` | CRÉER | 1 |
| `tests/benchmark_llm.gd` | CRÉER | 9 |
| `data/ai/config/prompts.json` | MODIFIER | 2 |

### 10.2 Structure de dossiers finale

```
addons/
├── merlin_ai/
│   ├── merlin_ai.gd          # Modifié
│   ├── fast_route.gd         # Nouveau
│   ├── response_templates.gd # Nouveau
│   ├── rag_manager.gd        # Existant
│   ├── action_validator.gd   # Existant
│   └── game_state_sync.gd    # Existant
│
└── merlin_llm/
    ├── models/
    │   ├── qwen2.5-0.5b-instruct-q4_k_m.gguf  # Nouveau
    │   └── qwen2.5-3b-instruct-q4_k_m.gguf    # Nouveau
    └── src/
        └── merlin_llm.cpp    # Modifié

tests/
├── test_fast_route.gd        # Nouveau
├── test_response_quality.gd  # Nouveau
└── benchmark_llm.gd          # Nouveau

tools/
└── download_models.py        # Nouveau
```

---

## 11. Ressources et téléchargements

### 11.1 Modèles GGUF

| Modèle | Taille | URL |
|--------|--------|-----|
| Qwen2.5-0.5B-Instruct Q4_K_M | ~400 MB | https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF |
| Qwen2.5-3B-Instruct Q4_K_M | ~2 GB | https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF |
| Phi-3.5-mini-instruct Q4_K_M | ~2.2 GB | https://huggingface.co/microsoft/Phi-3.5-mini-instruct-gguf |

### 11.2 Documentation llama.cpp

- API principale : https://github.com/ggerganov/llama.cpp/blob/master/llama.h
- Exemples : https://github.com/ggerganov/llama.cpp/tree/master/examples
- Speculative decoding : https://github.com/ggerganov/llama.cpp/tree/master/examples/speculative

### 11.3 Outils de test

- llama-bench : Pour benchmarker les modèles
- llama-perplexity : Pour évaluer la qualité

---

## Checklist d'implémentation

- [ ] **Phase 1** : FastRoute
  - [ ] Créer `fast_route.gd`
  - [ ] Intégrer dans `merlin_ai.gd`
  - [ ] Tests unitaires
  - [ ] Valider 70%+ de hit rate

- [ ] **Phase 2** : Nouveaux modèles
  - [ ] Télécharger Qwen2.5-0.5B
  - [ ] Télécharger Qwen2.5-3B
  - [ ] Mettre à jour les constantes
  - [ ] Valider le chargement

- [ ] **Phase 3** : Cache KV
  - [ ] Modifier GDExtension
  - [ ] Implémenter `create_kv_cache`
  - [ ] Implémenter `generate_with_kv_cache`
  - [ ] Intégrer côté GDScript

- [ ] **Phase 4** : Templates
  - [ ] Créer `response_templates.gd`
  - [ ] Intégrer détection d'action
  - [ ] Valider cohérence des réponses

- [ ] **Phase 5** : Optimisations GDExtension
  - [ ] Paramètres contexte optimisés
  - [ ] Sampling rapide
  - [ ] Mode turbo router

- [ ] **Phase 6** : Speculative Decoding (optionnel)
  - [ ] Implémenter la structure
  - [ ] Valider le gain de performance

- [ ] **Validation finale**
  - [ ] Benchmark latence < 500ms P50
  - [ ] Tests de régression qualité
  - [ ] Test sur appareil cible (mobile/desktop)

---

*Document généré pour le projet M.E.R.L.I.N - Le Jeu des Oghams*  
*À utiliser comme référence d'implémentation par l'agent de développement*
