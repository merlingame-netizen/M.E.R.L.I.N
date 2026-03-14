## ═══════════════════════════════════════════════════════════════════════════════
## Tutorial Manager — Diegetic onboarding (Phase 9, DEV_PLAN_V2.5)
## ═══════════════════════════════════════════════════════════════════════════════
## Scripted first 2-3 cards for new players, progressive tooltips.
## Tooltip flags stored in profile to show only once.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TutorialManager

signal tooltip_shown(key: String, text: String)
signal tutorial_card_injected(card: Dictionary)

# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL CARDS — Scripted first run (2-3 cards)
# ═══════════════════════════════════════════════════════════════════════════════

const TUTORIAL_CARDS: Array[Dictionary] = [
	{
		"id": "tutorial_001",
		"type": "narrative",
		"text": "Tu te reveilles au pied d'un chene immense. La foret de Broceliande t'entoure de ses murmures. Merlin apparait, esquissant un sourire.",
		"options": [
			{"label": "Observer les alentours", "verb": "observer", "field": "observation", "minigame": "fouille",
			 "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "Parler a Merlin", "verb": "parler", "field": "esprit", "minigame": "apaisement",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]},
			{"label": "Avancer dans la foret", "verb": "s'approcher", "field": "esprit", "minigame": "sang_froid",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 3}]},
		],
		"tags": ["tutorial", "intro"],
		"tutorial_tooltip": "choose_option",
	},
	{
		"id": "tutorial_002",
		"type": "narrative",
		"text": "Un symbole ogham brille sur l'ecorce du chene. Merlin pointe du doigt : 'Voici Beith, le Bouleau. Ton premier pouvoir. Utilise-le au bon moment.'",
		"options": [
			{"label": "Toucher l'ogham", "verb": "s'approcher", "field": "esprit", "minigame": "apaisement",
			 "effects": [{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]},
			{"label": "Dechiffrer les runes", "verb": "dechiffrer", "field": "logique", "minigame": "runes",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 8}]},
			{"label": "Demander a Merlin", "verb": "parler", "field": "esprit", "minigame": "volonte",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 3}, {"type": "HEAL_LIFE", "amount": 3}]},
		],
		"tags": ["tutorial", "ogham"],
		"tutorial_tooltip": "ogham_activation",
	},
	{
		"id": "tutorial_003",
		"type": "narrative",
		"text": "Le sentier se retrecit. Des bruits inquietants viennent de l'ombre. Merlin murmure : 'Tes choix ont des consequences. Chaque option mene a une epreuve differente.'",
		"options": [
			{"label": "Ecouter les bruits", "verb": "ecouter", "field": "perception", "minigame": "echo",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "ankou", "amount": 5}]},
			{"label": "Se faufiler dans l'ombre", "verb": "se faufiler", "field": "finesse", "minigame": "ombres",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": 5}]},
			{"label": "Affronter l'inconnu", "verb": "combattre", "field": "vigueur", "minigame": "combat_rituel",
			 "effects": [{"type": "ADD_REPUTATION", "faction": "anciens", "amount": 8}, {"type": "DAMAGE_LIFE", "amount": 3}]},
		],
		"tags": ["tutorial", "minigame"],
		"tutorial_tooltip": "minigame_intro",
	},
]


# ═══════════════════════════════════════════════════════════════════════════════
# TOOLTIPS — Progressive hints, shown once per flag
# ═══════════════════════════════════════════════════════════════════════════════

const TOOLTIPS: Dictionary = {
	"choose_option": "Choisis une des 3 options. Chaque choix mene a une epreuve (minigame) differente selon le verbe d'action.",
	"ogham_activation": "Appuie sur le bouton Ogham pour activer ton pouvoir avant de choisir. Chaque ogham a un cooldown.",
	"minigame_intro": "L'epreuve teste ton habilete. Ton score (0-100) determine la puissance des effets.",
	"promise_intro": "Merlin te propose un pacte. Accepter engage ta confiance — tiens ta promesse ou perds sa confiance.",
	"faction_rep": "Tes choix influencent 5 factions. Atteindre 80+ avec une faction debloque une fin narrative unique.",
	"biome_currency": "Ramasse la monnaie de biome pendant la marche 3D. Utilise-la chez les marchands PNJ.",
	"life_low": "Ta vie est basse ! Cherche des options de soin ou utilise un ogham de guerison.",
	"end_run": "A la fin du run, tu gagnes de l'Anam. Plus tu joues de cartes, plus tu en gagnes.",
}


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _tutorial_flags: Dictionary = {}
var _tutorial_card_index: int = 0
var _is_first_run: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func setup(profile: Dictionary) -> void:
	_tutorial_flags = profile.get("tutorial_flags", {})
	var total_runs: int = int(profile.get("total_runs", 0))
	_is_first_run = total_runs == 0
	_tutorial_card_index = 0


func is_first_run() -> bool:
	return _is_first_run


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL CARD INJECTION — First 2-3 cards of first run
# ═══════════════════════════════════════════════════════════════════════════════

func should_inject_tutorial_card(card_index: int) -> bool:
	if not _is_first_run:
		return false
	return card_index < TUTORIAL_CARDS.size()


func get_tutorial_card(card_index: int) -> Dictionary:
	if card_index < 0 or card_index >= TUTORIAL_CARDS.size():
		return {}

	var card: Dictionary = TUTORIAL_CARDS[card_index].duplicate(true)
	_tutorial_card_index = card_index + 1

	# Show associated tooltip
	var tooltip_key: String = str(card.get("tutorial_tooltip", ""))
	if not tooltip_key.is_empty():
		show_tooltip(tooltip_key)

	tutorial_card_injected.emit(card)
	return card


# ═══════════════════════════════════════════════════════════════════════════════
# TOOLTIP SYSTEM — Show once, persist in profile
# ═══════════════════════════════════════════════════════════════════════════════

func show_tooltip(key: String) -> bool:
	if _tutorial_flags.get(key, false):
		return false  # Already shown
	if not TOOLTIPS.has(key):
		return false

	_tutorial_flags[key] = true
	var text: String = str(TOOLTIPS[key])
	tooltip_shown.emit(key, text)
	return true


func try_contextual_tooltip(context: String) -> bool:
	match context:
		"promise_card":
			return show_tooltip("promise_intro")
		"faction_gain":
			return show_tooltip("faction_rep")
		"collectible":
			return show_tooltip("biome_currency")
		"life_low":
			return show_tooltip("life_low")
		"run_end":
			return show_tooltip("end_run")
	return false


func has_seen_tooltip(key: String) -> bool:
	return _tutorial_flags.get(key, false)


# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE — Save/load tutorial flags to profile
# ═══════════════════════════════════════════════════════════════════════════════

func get_tutorial_flags() -> Dictionary:
	return _tutorial_flags.duplicate()


func save_to_profile(profile: Dictionary) -> void:
	profile["tutorial_flags"] = _tutorial_flags.duplicate()
