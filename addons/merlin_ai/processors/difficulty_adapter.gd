## ═══════════════════════════════════════════════════════════════════════════════
## Difficulty Adapter — Adaptation Dynamique de Difficulte
## ═══════════════════════════════════════════════════════════════════════════════
## Ajuste invisiblement les effets des cartes selon le niveau du joueur.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name DifficultyAdapter

signal difficulty_adjusted(factor: float, reason: String)

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var player_skill := 0.5  # 0=novice, 1=maitre

# Pity system
var consecutive_deaths := 0
var cards_since_crisis := 999
var pity_mode_active := false
var pity_cards_remaining := 0

# Session state
var session_deaths := 0
var session_quick_deaths := 0  # Morts < 20 cartes

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const PITY_THRESHOLD_DEATHS := 3
const PITY_DURATION_CARDS := 10
const QUICK_DEATH_THRESHOLD := 20

# Skill factor range
const MIN_SKILL_FACTOR := 0.6
const MAX_SKILL_FACTOR := 1.4

# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE FROM PROFILE
# ═══════════════════════════════════════════════════════════════════════════════

func update_from_profile(profile: PlayerProfileRegistry) -> void:
	if profile == null:
		return

	# Calculate skill from assessment
	var skill_data = profile.skill_assessment
	var total := 0.0
	var count := 0

	for skill in skill_data:
		total += float(skill_data[skill])
		count += 1

	if count > 0:
		player_skill = total / float(count)

	# Adjust for experience
	var experience: int = profile.get_experience_tier()
	match experience:
		profile.ExperienceTier.INITIATE:
			player_skill = minf(player_skill, 0.4)
		profile.ExperienceTier.APPRENTICE:
			player_skill = clampf(player_skill, 0.3, 0.6)
		profile.ExperienceTier.MASTER:
			player_skill = maxf(player_skill, 0.7)


func update_from_session(session: SessionRegistry) -> void:
	if session == null:
		return

	session_deaths = session.current.deaths_this_session

	# Check for frustration indicators
	if session.wellness.frustration_detected:
		enable_pity_mode()


# ═══════════════════════════════════════════════════════════════════════════════
# PITY SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func on_death(run_length: int) -> void:
	consecutive_deaths += 1

	if run_length < QUICK_DEATH_THRESHOLD:
		session_quick_deaths += 1

	# Auto-enable pity after threshold
	if consecutive_deaths >= PITY_THRESHOLD_DEATHS:
		enable_pity_mode()


func on_run_start() -> void:
	cards_since_crisis = 999
	# Don't reset consecutive_deaths here - that's session-based


func on_successful_run() -> void:
	consecutive_deaths = 0
	pity_mode_active = false


func enable_pity_mode() -> void:
	pity_mode_active = true
	pity_cards_remaining = PITY_DURATION_CARDS
	difficulty_adjusted.emit(0.6, "pity_mode_enabled")


func disable_pity_mode() -> void:
	pity_mode_active = false
	pity_cards_remaining = 0


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT SCALING
# ═══════════════════════════════════════════════════════════════════════════════

func scale_effect(base_value: int, effect_type: String, context: Dictionary) -> int:
	## Ajuste un effet selon le contexte.
	if base_value == 0:
		return 0

	var factor := _calculate_scaling_factor(effect_type, context)
	return roundi(float(base_value) * factor)


func _calculate_scaling_factor(effect_type: String, context: Dictionary) -> float:
	var factor := 1.0

	# Base skill factor
	var skill_factor := lerpf(MIN_SKILL_FACTOR, MAX_SKILL_FACTOR, player_skill)

	# Invert for negative effects (higher skill = harder)
	if effect_type == "negative":
		factor = skill_factor
	else:
		factor = 2.0 - skill_factor  # Inverse: higher skill = smaller positive

	# Pity mode adjustments
	if pity_mode_active:
		if effect_type == "negative":
			factor *= 0.6  # 40% reduction in negative effects
		else:
			factor *= 1.4  # 40% increase in positive effects
		pity_cards_remaining -= 1
		if pity_cards_remaining <= 0:
			disable_pity_mode()

	# Crisis protection
	if _is_in_crisis(context):
		if effect_type == "negative":
			factor *= 0.5  # Half damage in crisis
		else:
			factor *= 1.5  # Bonus recovery

	# Consecutive deaths mercy
	if consecutive_deaths > 0:
		var mercy_factor := 1.0 - (consecutive_deaths * 0.1)  # -10% per death
		if effect_type == "negative":
			factor *= maxf(0.5, mercy_factor)

	return factor


func _is_in_crisis(context: Dictionary) -> bool:
	# Check gauges
	var gauges: Dictionary = context.get("gauges", {})
	for gauge in gauges:
		var value: int = int(gauges[gauge])
		if value < 15 or value > 85:
			return true

	# Check aspects (for TRIADE)
	var aspects: Dictionary = context.get("aspects", {})
	var extreme_count := 0
	for aspect in aspects:
		var state: int = int(aspects[aspect])
		if state != 0:  # Not balanced
			extreme_count += 1
	if extreme_count >= 2:
		return true

	return false


# ═══════════════════════════════════════════════════════════════════════════════
# CARD WEIGHTING
# ═══════════════════════════════════════════════════════════════════════════════

func get_card_weight_modifier(card: Dictionary, context: Dictionary) -> float:
	## Retourne un modificateur de poids pour la selection de carte.
	var weight := 1.0

	var max_negative := _get_max_negative_effect(card)
	var is_crisis := _is_in_crisis(context)
	var is_recovery := _is_recovery_card(card)

	# Reduce dangerous cards for struggling players
	if max_negative > 20:
		if consecutive_deaths > 0 or pity_mode_active:
			weight *= 0.3

	# Increase recovery cards in crisis
	if is_crisis and is_recovery:
		weight *= 2.5

	# Reduce complex cards for novices
	if player_skill < 0.3:
		var complexity := _get_card_complexity(card)
		if complexity > 0.7:
			weight *= 0.5

	return weight


func _get_max_negative_effect(card: Dictionary) -> int:
	var max_neg := 0
	for option in card.get("options", []):
		for effect in option.get("effects", []):
			var value: int = int(effect.get("value", 0))
			if value < 0:
				max_neg = maxi(max_neg, abs(value))
	return max_neg


func _is_recovery_card(card: Dictionary) -> bool:
	var tags: Array = card.get("tags", [])
	return "recovery" in tags or "healing" in tags or "rest" in tags


func _get_card_complexity(card: Dictionary) -> float:
	var complexity := 0.0

	# More options = more complex
	var options: Array = card.get("options", [])
	if options.size() > 2:
		complexity += 0.3

	# More effects = more complex
	var total_effects := 0
	for option in options:
		total_effects += option.get("effects", []).size()
	complexity += minf(0.4, total_effects * 0.1)

	# Certain tags indicate complexity
	var tags: Array = card.get("tags", [])
	if "promise" in tags:
		complexity += 0.2
	if "arc" in tags:
		complexity += 0.1

	return minf(1.0, complexity)


# ═══════════════════════════════════════════════════════════════════════════════
# DEBUG
# ═══════════════════════════════════════════════════════════════════════════════

func get_debug_info() -> Dictionary:
	return {
		"player_skill": player_skill,
		"consecutive_deaths": consecutive_deaths,
		"pity_mode_active": pity_mode_active,
		"pity_cards_remaining": pity_cards_remaining,
		"session_deaths": session_deaths,
		"session_quick_deaths": session_quick_deaths,
	}
