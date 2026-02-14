## ═══════════════════════════════════════════════════════════════════════════════
## Relationship Registry — Lien Merlin-Joueur
## ═══════════════════════════════════════════════════════════════════════════════
## Modele la relation evolutive entre Merlin et le joueur.
## Influence le ton, la profondeur des revelations, et les moments de verite.
## Persistance: Cross-run with decay
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name RelationshipRegistry

signal trust_changed(old_tier: int, new_tier: int, points: int)
signal rapport_updated(dimension: String, value: float)
signal special_moment_triggered(moment: String)

const VERSION := "1.0.0"
const SAVE_PATH := "user://merlin_relationship.json"

# ═══════════════════════════════════════════════════════════════════════════════
# TRUST TIERS
# ═══════════════════════════════════════════════════════════════════════════════

enum TrustTier {
	DISTANT,    # T0: Merlin guarded, short responses, cryptic
	CAUTIOUS,   # T1: Occasional guidance, still testing
	ATTENTIVE,  # T2: Reflects more, hints at patterns
	BOUND       # T3: Warm but ambiguous, rare emotional moments
}

const TRUST_THRESHOLDS := [25, 50, 75]  # Points to reach each tier
const MAX_TRUST_POINTS := 100

var trust_tier: TrustTier = TrustTier.DISTANT
var trust_points: int = 0

# ═══════════════════════════════════════════════════════════════════════════════
# RAPPORT DIMENSIONS (0.0 - 1.0)
# ═══════════════════════════════════════════════════════════════════════════════

var rapport := {
	"respect": 0.3,       # Reconnaissance des competences du joueur
	"warmth": 0.2,        # Connection emotionnelle
	"complicity": 0.2,    # Moments partages, blagues comprises
	"reverence": 0.1,     # Respect quasi-mystique envers Merlin
	"familiarity": 0.2,   # A quel point Merlin "connait" le joueur
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTION HISTORY
# ═══════════════════════════════════════════════════════════════════════════════

var interactions := {
	"promises_proposed": 0,
	"promises_accepted": 0,
	"promises_kept": 0,
	"promises_broken": 0,
	"direct_addresses": 0,      # Fois ou Merlin parle directement
	"hints_followed": 0,        # Joueur a suivi un conseil
	"warnings_ignored": 0,      # Joueur a ignore un avertissement
	"questions_asked": 0,       # Fois ou le joueur interroge Merlin
	"thank_yous": 0,            # Gratitude exprimee
	"defiances": 0,             # Opposition deliberee
}

# ═══════════════════════════════════════════════════════════════════════════════
# SPECIAL MOMENTS (Flags uniques)
# ═══════════════════════════════════════════════════════════════════════════════

var special_moments := {
	"has_seen_melancholy": false,     # A vu la tristesse de Merlin
	"has_seen_slip": false,           # A vu un glissement de masque
	"questioned_merlin_nature": false, # A questionne sa nature
	"thanked_merlin_sincerely": false, # Gratitude sincere
	"defied_merlin": false,            # Opposition deliberee reussie
	"shared_silence": false,           # Moment de silence partage
	"witnessed_prophecy": false,       # A vu une prophetie se realiser
	"saved_by_merlin": false,          # Merlin a aide in extremis
	"1000_runs_revelation": false,     # Easter egg des 1000 runs
}

# ═══════════════════════════════════════════════════════════════════════════════
# TRUST CHANGE VALUES
# ═══════════════════════════════════════════════════════════════════════════════

const TRUST_CHANGES := {
	# Positive events
	"promise_kept": 10,
	"followed_hint": 3,
	"ignored_warning_survived": 5,  # Respect for autonomy
	"long_run_100": 5,
	"long_run_150": 8,
	"discovered_lore": 2,
	"thanked_merlin": 4,
	"asked_good_question": 3,
	"survived_crisis": 2,
	"completed_arc": 5,

	# Negative events
	"promise_broken": -15,
	"ignored_warning_died": -5,
	"quick_death": -2,
	"rushed_many_decisions": -3,
	"abandoned_run": -5,
	"skipped_dialogue": -1,
}

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION DECAY
# ═══════════════════════════════════════════════════════════════════════════════

const TRUST_DECAY_PER_DAY := 1  # Points perdus par jour d'absence
const MAX_DECAY_DAYS := 30       # Maximum de jours de decay
var last_session_date: int = 0

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	load_from_disk()
	_apply_absence_decay()


func reset() -> void:
	trust_tier = TrustTier.DISTANT
	trust_points = 0
	rapport = {
		"respect": 0.3,
		"warmth": 0.2,
		"complicity": 0.2,
		"reverence": 0.1,
		"familiarity": 0.2,
	}
	interactions = {
		"promises_proposed": 0,
		"promises_accepted": 0,
		"promises_kept": 0,
		"promises_broken": 0,
		"direct_addresses": 0,
		"hints_followed": 0,
		"warnings_ignored": 0,
		"questions_asked": 0,
		"thank_yous": 0,
		"defiances": 0,
	}

# ═══════════════════════════════════════════════════════════════════════════════
# TRUST MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func update_trust(event: String) -> void:
	## Met a jour les points de confiance suite a un evenement.
	var change: int = TRUST_CHANGES.get(event, 0)
	if change == 0:
		return

	var old_points := trust_points
	var old_tier := trust_tier

	trust_points = clampi(trust_points + change, 0, MAX_TRUST_POINTS)
	_update_tier()

	if old_tier != trust_tier:
		trust_changed.emit(old_tier, trust_tier, trust_points)

	# Update rapport based on event type
	_update_rapport_from_event(event, change)


func _update_tier() -> void:
	var old_tier := trust_tier

	if trust_points >= TRUST_THRESHOLDS[2]:
		trust_tier = TrustTier.BOUND
	elif trust_points >= TRUST_THRESHOLDS[1]:
		trust_tier = TrustTier.ATTENTIVE
	elif trust_points >= TRUST_THRESHOLDS[0]:
		trust_tier = TrustTier.CAUTIOUS
	else:
		trust_tier = TrustTier.DISTANT


func _update_rapport_from_event(event: String, change: int) -> void:
	match event:
		"promise_kept":
			_shift_rapport("respect", 0.05)
			_shift_rapport("warmth", 0.03)
		"promise_broken":
			_shift_rapport("warmth", -0.08)
			_shift_rapport("respect", -0.03)
		"followed_hint":
			_shift_rapport("reverence", 0.02)
			_shift_rapport("familiarity", 0.01)
		"ignored_warning_survived":
			_shift_rapport("respect", 0.05)  # Merlin respects autonomy
		"ignored_warning_died":
			_shift_rapport("warmth", 0.02)  # Merlin cares despite failure
		"thanked_merlin":
			_shift_rapport("warmth", 0.05)
			_shift_rapport("complicity", 0.03)
		"asked_good_question":
			_shift_rapport("familiarity", 0.03)
		"long_run_100", "long_run_150":
			_shift_rapport("familiarity", 0.05)
			_shift_rapport("complicity", 0.03)


func _shift_rapport(dimension: String, delta: float) -> void:
	if not rapport.has(dimension):
		return
	var old_value: float = rapport[dimension]
	rapport[dimension] = clampf(old_value + delta, 0.0, 1.0)
	if absf(old_value - rapport[dimension]) > 0.01:
		rapport_updated.emit(dimension, rapport[dimension])

# ═══════════════════════════════════════════════════════════════════════════════
# INTERACTION TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

func record_interaction(interaction_type: String) -> void:
	## Enregistre une interaction.
	if interactions.has(interaction_type):
		interactions[interaction_type] += 1

	match interaction_type:
		"promises_proposed":
			pass
		"promises_accepted":
			pass
		"promises_kept":
			update_trust("promise_kept")
		"promises_broken":
			update_trust("promise_broken")
		"hints_followed":
			update_trust("followed_hint")
		"warnings_ignored":
			pass  # Outcome determines trust change
		"thank_yous":
			update_trust("thanked_merlin")
			_check_special_moment("thanked_merlin_sincerely")
		"defiances":
			_check_special_moment("defied_merlin")

# ═══════════════════════════════════════════════════════════════════════════════
# SPECIAL MOMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func trigger_special_moment(moment: String) -> bool:
	## Declenche un moment special s'il n'a pas deja eu lieu.
	if not special_moments.has(moment):
		return false
	if special_moments[moment]:
		return false  # Already triggered

	special_moments[moment] = true
	special_moment_triggered.emit(moment)

	# Bonus trust for special moments
	update_trust("discovered_lore")

	return true


func _check_special_moment(moment: String) -> void:
	match moment:
		"thanked_merlin_sincerely":
			if interactions.thank_yous >= 3:
				trigger_special_moment(moment)
		"defied_merlin":
			if interactions.defiances >= 2:
				trigger_special_moment(moment)


func can_show_melancholy() -> bool:
	## Merlin peut-il montrer sa tristesse?
	return trust_tier >= TrustTier.BOUND or special_moments.has_seen_melancholy


func can_show_slip() -> bool:
	## Merlin peut-il laisser glisser son masque?
	return trust_tier >= TrustTier.ATTENTIVE

# ═══════════════════════════════════════════════════════════════════════════════
# TONE MODIFIERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_tone_modifiers() -> Dictionary:
	## Retourne les modificateurs de ton selon le niveau de confiance.
	var base := {}

	match trust_tier:
		TrustTier.DISTANT:
			base = {"humor": 1.0, "darkness": 0.0, "warmth": 0.0, "verbosity": 0.7}
		TrustTier.CAUTIOUS:
			base = {"humor": 0.95, "darkness": 0.05, "warmth": 0.1, "verbosity": 0.85}
		TrustTier.ATTENTIVE:
			base = {"humor": 0.90, "darkness": 0.10, "warmth": 0.3, "verbosity": 1.0}
		TrustTier.BOUND:
			base = {"humor": 0.85, "darkness": 0.15, "warmth": 0.5, "verbosity": 1.2}

	# Adjust based on rapport
	base.warmth = lerpf(base.warmth, 1.0, rapport.warmth * 0.5)
	base.humor = lerpf(base.humor, 0.7, rapport.complicity * 0.3)

	return base


func get_trust_tier_name() -> String:
	match trust_tier:
		TrustTier.DISTANT: return "Distant"
		TrustTier.CAUTIOUS: return "Prudent"
		TrustTier.ATTENTIVE: return "Attentif"
		TrustTier.BOUND: return "Lie"
	return "Inconnu"

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN'S VOICE PATTERNS
# ═══════════════════════════════════════════════════════════════════════════════

func get_sentence_length_modifier() -> float:
	## Retourne un multiplicateur pour la longueur des phrases.
	# Merlin parle moins quand distant, plus quand lie
	match trust_tier:
		TrustTier.DISTANT: return 0.7
		TrustTier.CAUTIOUS: return 0.85
		TrustTier.ATTENTIVE: return 1.0
		TrustTier.BOUND: return 1.15
	return 1.0


func should_use_player_name() -> bool:
	## Merlin doit-il utiliser un surnom pour le joueur?
	return trust_tier >= TrustTier.CAUTIOUS


func get_taunt_intensity() -> float:
	## Intensite des moqueries de Merlin (0.0-1.0).
	# Plus intense avec confiance (car playful, pas mechant)
	var base: float = 0.3
	match trust_tier:
		TrustTier.DISTANT: base = 0.2
		TrustTier.CAUTIOUS: base = 0.4
		TrustTier.ATTENTIVE: base = 0.6
		TrustTier.BOUND: base = 0.8

	# Reduce if warmth is high
	base *= 1.0 - (rapport.warmth * 0.3)

	return base


func can_reveal_lore_depth(depth: int) -> bool:
	## Peut-on reveler du lore de cette profondeur?
	## depth: 1=surface, 2=medium, 3=deep, 4=secret, 5=ultimate
	match trust_tier:
		TrustTier.DISTANT: return depth <= 1
		TrustTier.CAUTIOUS: return depth <= 2
		TrustTier.ATTENTIVE: return depth <= 3
		TrustTier.BOUND: return depth <= 4
	return false

# ═══════════════════════════════════════════════════════════════════════════════
# ABSENCE DECAY
# ═══════════════════════════════════════════════════════════════════════════════

func _apply_absence_decay() -> void:
	## Applique le decay pour absence prolongee.
	if last_session_date == 0:
		last_session_date = int(Time.get_unix_time_from_system())
		return

	var now := int(Time.get_unix_time_from_system())
	var days_away := int((now - last_session_date) / 86400.0)  # Seconds per day
	days_away = mini(days_away, MAX_DECAY_DAYS)

	if days_away > 0:
		var decay := days_away * TRUST_DECAY_PER_DAY
		trust_points = maxi(0, trust_points - decay)
		_update_tier()

	last_session_date = now

# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT FOR LLM
# ═══════════════════════════════════════════════════════════════════════════════

func get_context_for_llm() -> Dictionary:
	return {
		"trust_tier": trust_tier,
		"trust_tier_name": get_trust_tier_name(),
		"trust_points": trust_points,
		"rapport": rapport.duplicate(),
		"tone_mods": get_tone_modifiers(),
		"can_show_darkness": trust_tier >= TrustTier.CAUTIOUS,
		"can_show_melancholy": can_show_melancholy(),
		"taunt_intensity": get_taunt_intensity(),
	}


func get_summary_for_prompt() -> String:
	## Resume textuel pour le prompt LLM.
	var lines := []

	lines.append("Confiance: %s (%d/100)" % [get_trust_tier_name(), trust_points])

	if trust_tier >= TrustTier.ATTENTIVE:
		lines.append("Ton: Peut montrer de la profondeur")
	if trust_tier >= TrustTier.BOUND:
		lines.append("Ton: Moments de vulnerabilite possibles")

	if rapport.warmth > 0.6:
		lines.append("Rapport chaleureux etabli")
	if rapport.complicity > 0.5:
		lines.append("Complicite avec le joueur")

	# Special moments
	if special_moments.has_seen_melancholy:
		lines.append("A deja vu la melancolie de Merlin")

	return "\n".join(lines)

# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func save_to_disk() -> void:
	var data := {
		"version": VERSION,
		"trust_tier": trust_tier,
		"trust_points": trust_points,
		"rapport": rapport,
		"interactions": interactions,
		"special_moments": special_moments,
		"last_session_date": int(Time.get_unix_time_from_system()),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if typeof(data) != TYPE_DICTIONARY:
		return

	trust_tier = int(data.get("trust_tier", TrustTier.DISTANT))
	trust_points = int(data.get("trust_points", 0))
	last_session_date = int(data.get("last_session_date", 0))

	if data.has("rapport"):
		for key in data.rapport:
			if rapport.has(key):
				rapport[key] = float(data.rapport[key])

	if data.has("interactions"):
		for key in data.interactions:
			if interactions.has(key):
				interactions[key] = int(data.interactions[key])

	if data.has("special_moments"):
		for key in data.special_moments:
			if special_moments.has(key):
				special_moments[key] = bool(data.special_moments[key])
