## BrainSwarmConfig — Paliers materiels pour l'architecture multi-cerveaux Gemma 4
##
## Trois paliers de bureau, choisis sur la RAM PHYSIQUE de la machine :
##
##   LEGER  — RAM < 16 Go   — gemma4:e4b-it-qat   (6,1 Go)  — narrateur + GM partages
##   MOYEN  — 16 a 32 Go    — gemma4:12b-it-qat   (7,2 Go)  — 12B narrateur, E4B GM
##   ELEVE  — RAM >= 32 Go  — gemma4:26b-a4b-it-qat (16 Go) — 26B narrateur, E4B GM
##
## Pourquoi Gemma 4 (avril 2026, Apache 2.0) :
##   - francais : 88,4 % sur MMMLU contre 85,9 % pour Qwen 3.5 ;
##   - controle : JSON structure et function calling NATIFS a toutes les tailles
##     (tau2-bench : 86,4 % pour le 31B contre 6,6 % pour Gemma 3 27B).
##
## Pourquoi le 26B et pas le 31B au palier haut : le 26B-a4b est un
## Mixture-of-Experts — 26 milliards de parametres au total mais ~3,8 actifs par
## token, donc PLUS RAPIDE que le 12B dense tout en ecrivant mieux. Le 31B dense
## tombe sous 1 token/seconde sans GPU, ce que la bible §9.9 interdit (aucune
## attente visible pour le joueur). Il reste choisissable a la main dans le menu
## options pour qui a un gros GPU, jamais choisi automatiquement.
##
## Pourquoi l'E4B en game master a tous les paliers : ce cerveau ne produit que
## du JSON. La taille n'y ajoute rien, et payer deux fois le gros modele
## doublerait l'empreinte memoire sans ameliorer la prose.
##
## Paliers mobiles (MOBILE_*) inchanges : ils passent par la GDExtension
## merlin_llm et relevent du chantier installeur, pas de celui-ci.
extends RefCounted
class_name BrainSwarmConfig

# ── Profile Names ─────────────────────────────────────────────────────────────
enum Profile { LEGER, MOYEN, ELEVE, MOBILE_LOW, MOBILE_MID, MOBILE_HIGH }

# ── Ollama Model Tags (famille Gemma 4) ──────────────────────────────────────
# Les tags `-qat` sont les quantifications Quantization-Aware Training publiees
# par Google : meme qualite qu'en Q8 pour la moitie du poids.
const MODEL_GEMMA4_26B := "gemma4:26b-a4b-it-qat"  # MoE, ~3,8 B actifs — 16 Go
const MODEL_GEMMA4_12B := "gemma4:12b-it-qat"      # dense — 7,2 Go
const MODEL_GEMMA4_E4B := "gemma4:e4b-it-qat"      # dense compact — 6,1 Go
const MODEL_GEMMA4_E2B := "gemma4:e2b-it-qat"      # secours machine tres limitee
# Dense 31B : jamais choisi automatiquement (< 1 tok/s sans GPU), mais
# selectionnable a la main dans le menu options.
const MODEL_GEMMA4_31B := "gemma4:31b-it-qat"

# ── Mobile model file paths (ARM64 via merlin_llm GDExtension recompiled, NOT Ollama) ─
# These are .gguf filenames in addons/merlin_llm/models/ — NOT Ollama tags.
# Loaded directly via merlin_llm GDExtension on Android/iOS (no Ollama daemon).
const MODEL_FILE_LLAMA32_1B := "llama3.2-1b-q4_k_s.gguf"        # ~700 MB — entry mobile
const MODEL_FILE_QWEN25_15B := "qwen2.5-1.5b-q4_k_m.gguf"       # ~1.4 GB — mid mobile
const MODEL_FILE_LLAMA32_3B := "llama3.2-3b-q4_k_m.gguf"        # ~2.5 GB — high mobile

# ── Empreinte memoire par model_key (quantification QAT, cache KV compris) ───
# Indexe par `model_key` (PAS par `ollama_tag` / `model_file`).
const RAM_BY_MODEL := {
	"gemma4_26b": 16000,
	"gemma4_12b": 7200,
	"gemma4_e4b": 6100,
	"gemma4_e2b": 3000,
	"gemma4_31b": 19000,
	"llama32_1b_mobile": 700,
	"qwen25_1.5b_mobile": 1400,
	"llama32_3b_mobile": 2500,
}

# ── Profile Definitions ──────────────────────────────────────────────────────
# Each brain: {role, model_key, ollama_tag, n_ctx, ram_mb, thinking}
const PROFILES := {
	# ── LEGER — machine limitee (moins de 16 Go) ─────────────────────────────
	# Un seul modele resident, partage narrateur/game master. L'E4B tient dans
	# 6,1 Go et sait deja produire du JSON structure : c'est le plancher
	# utilisable, pas un modele au rabais.
	Profile.LEGER: {
		"name": "Leger (Gemma 4 E4B, tous roles)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 8192, "ram_mb": 6100, "thinking": false},
		],
		"total_ram_mb": 6100,
		"min_threads": 2,
		"min_ram_mb": 8000,
		"prefetch_depth": 0,
	},
	# ── MOYEN — 16 a 32 Go ───────────────────────────────────────────────────
	# Le 12B seul, partage lui aussi. Deliberement PAS de second cerveau ici :
	# 12B (7,2 Go) + E4B (6,1 Go) resident cote a cote font 13,3 Go, ce qui ne
	# laisse rien au systeme ni au jeu sur une machine de 16 Go. Ollama
	# evincerait un modele a chaque bascule et rechargerait 7 Go entre deux
	# cartes. Un seul modele, jamais evince.
	Profile.MOYEN: {
		"name": "Moyen (Gemma 4 12B, tous roles)",
		"mode": "resident",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_12b", "ollama_tag": MODEL_GEMMA4_12B, "n_ctx": 8192, "ram_mb": 7200, "thinking": false},
		],
		"total_ram_mb": 7200,
		"min_threads": 4,
		"min_ram_mb": 16000,
		"prefetch_depth": 1,
	},
	# ── ELEVE — 32 Go et plus ────────────────────────────────────────────────
	# Le 26B-a4b ecrit, l'E4B arbitre. Les deux tiennent en memoire en meme
	# temps (22,1 Go sur 32), donc generation en parallele : Merlin peut narrer
	# la carte suivante pendant que le game master resout la courante.
	Profile.ELEVE: {
		"name": "Eleve (Gemma 4 26B narrateur + E4B game master)",
		"mode": "parallel",
		"brains": [
			{"role": "narrator", "model_key": "gemma4_26b", "ollama_tag": MODEL_GEMMA4_26B, "n_ctx": 8192, "ram_mb": 16000, "thinking": false},
			{"role": "gamemaster", "model_key": "gemma4_e4b", "ollama_tag": MODEL_GEMMA4_E4B, "n_ctx": 4096, "ram_mb": 6100, "thinking": true},
		],
		"total_ram_mb": 22100,  # les deux resident simultanement
		"min_threads": 4,
		"min_ram_mb": 32000,
		"prefetch_depth": 2,
	},
	# ── MOBILE TIERS — single brain strict, ARM64 via merlin_llm GDExtension ──
	# Backend = "merlin_llm_native" (NOT Ollama HTTP). Cross-compile required.
	# No multi-instance on mobile (battery/RAM/thermal constraints).
	# Mobile brains use `model_file` (.gguf path) instead of `ollama_tag`.
	# `ollama_tag` set to "" on mobile to make it explicit that no Ollama is involved.
	Profile.MOBILE_LOW: {
		"name": "Mobile Low (Llama 3.2 1B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "llama32_1b_mobile", "model_file": MODEL_FILE_LLAMA32_1B, "ollama_tag": "", "n_ctx": 1024, "ram_mb": 700, "thinking": false},
		],
		"total_ram_mb": 700,
		"min_threads": 4,
		"min_ram_mb": 3000,
		"prefetch_depth": 0,
	},
	Profile.MOBILE_MID: {
		"name": "Mobile Mid (Qwen 2.5 1.5B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "qwen25_1.5b_mobile", "model_file": MODEL_FILE_QWEN25_15B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 1400, "thinking": false},
		],
		"total_ram_mb": 1400,
		"min_threads": 6,
		"min_ram_mb": 5000,
		"prefetch_depth": 0,
	},
	Profile.MOBILE_HIGH: {
		"name": "Mobile High (Llama 3.2 3B)",
		"mode": "resident",
		"platform": "mobile",
		"backend": "merlin_llm_native",
		"brains": [
			{"role": "narrator", "model_key": "llama32_3b_mobile", "model_file": MODEL_FILE_LLAMA32_3B, "ollama_tag": "", "n_ctx": 2048, "ram_mb": 2500, "thinking": false},
		],
		"total_ram_mb": 2500,
		"min_threads": 6,
		"min_ram_mb": 7000,
		"prefetch_depth": 0,
	},
}


## Get the mobile model file path for a brain role in a profile.
## Returns "" if not a mobile profile or role not found.
static func get_model_file_for_role(profile_id: int, role: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return str(brain_cfg.get("model_file", ""))
	if brain_list.size() > 0:
		return str(brain_list[0].get("model_file", ""))
	return ""


## Auto-detect mobile profile based on available RAM + threads.
## Returns MOBILE_HIGH > MOBILE_MID > MOBILE_LOW (largest that fits).
## Use this on mobile platforms (Android/iOS); use detect_profile() on desktop.
static func detect_profile_mobile(available_ram_mb: int, cpu_threads: int) -> int:
	for profile_id in [Profile.MOBILE_HIGH, Profile.MOBILE_MID, Profile.MOBILE_LOW]:
		var profile: Dictionary = PROFILES[profile_id]
		if available_ram_mb >= int(profile.min_ram_mb) and cpu_threads >= int(profile.min_threads):
			return profile_id
	return Profile.MOBILE_LOW  # Fallback (always works on min mobile)


## True if profile is targeted at mobile platforms (Android/iOS).
static func is_mobile_profile(profile_id: int) -> bool:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("platform", "desktop")) == "mobile"


## Get backend hint for a profile ("ollama_http" or "merlin_llm_native").
static func get_backend_hint(profile_id: int) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("backend", "ollama_http"))


## Choisit le palier d'apres le materiel : du plus grand au plus petit qui rentre.
##
## `available_ram_mb` est la RAM PHYSIQUE de la machine (cf.
## merlin_ai.gd::_lire_ram_mb) — la regle du jeu porte sur la RAM installee,
## pas sur la RAM libre a l'instant du lancement.
static func detect_profile(available_ram_mb: int, cpu_threads: int) -> int:
	for profile_id in [Profile.ELEVE, Profile.MOYEN, Profile.LEGER]:
		var profile: Dictionary = PROFILES[profile_id]
		if available_ram_mb >= int(profile.min_ram_mb) and cpu_threads >= int(profile.min_threads):
			return profile_id
	return Profile.LEGER


## Palier nomme -> identifiant, pour le selecteur du menu options.
## Retourne -1 si la chaine ne designe aucun palier (« auto », vide, inconnu).
static func profile_from_name(nom: String) -> int:
	match nom.strip_edges().to_lower():
		"leger", "léger": return Profile.LEGER
		"moyen": return Profile.MOYEN
		"eleve", "élevé": return Profile.ELEVE
		_: return -1


## Get profile definition by ID.
static func get_profile(profile_id: int) -> Dictionary:
	return PROFILES.get(profile_id, PROFILES[Profile.LEGER])


## Get the prefetch depth for a profile.
static func get_prefetch_depth(profile_id: int) -> int:
	var profile: Dictionary = get_profile(profile_id)
	return int(profile.get("prefetch_depth", 0))


## Get profile name for display.
static func get_profile_name(profile_id: int) -> String:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("name", "Unknown"))


## Check if a profile uses time-sharing mode (one model at a time).
static func is_time_sharing(profile_id: int) -> bool:
	var profile: Dictionary = get_profile(profile_id)
	return str(profile.get("mode", "resident")) == "time_sharing"


## Get the Ollama model tag for a specific brain role in a profile.
static func get_model_for_role(profile_id: int, role: String) -> String:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return str(brain_cfg.get("ollama_tag", ""))
	# Fallback: use first brain's model (SINGLE/NANO mode)
	if brain_list.size() > 0:
		return str(brain_list[0].get("ollama_tag", ""))
	return ""


## Get brain config for a specific role.
static func get_brain_config(profile_id: int, role: String) -> Dictionary:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	for brain_cfg in brain_list:
		if str(brain_cfg.get("role", "")) == role:
			return brain_cfg
	return {}


## Get all unique Ollama model tags needed for a profile (for pre-pulling).
static func get_required_models(profile_id: int) -> Array:
	var profile: Dictionary = get_profile(profile_id)
	var brain_list: Array = profile.get("brains", [])
	var models: Array = []
	for brain_cfg in brain_list:
		var tag: String = str(brain_cfg.get("ollama_tag", ""))
		if tag != "" and tag not in models:
			models.append(tag)
	return models


## Get RAM estimate for the peak usage of a profile.
static func get_peak_ram_mb(profile_id: int) -> int:
	var profile: Dictionary = get_profile(profile_id)
	return int(profile.get("total_ram_mb", 800))
