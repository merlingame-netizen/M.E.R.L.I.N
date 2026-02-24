## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Context Builder — Agregateur de Contexte
## ═══════════════════════════════════════════════════════════════════════════════
## Construit le contexte complet pour le LLM a partir de tous les registres.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinContextBuilder

var player_profile: PlayerProfileRegistry
var decision_history: DecisionHistoryRegistry
var relationship: RelationshipRegistry
var narrative: NarrativeRegistry
var session: SessionRegistry

func setup(
	p_profile: PlayerProfileRegistry,
	d_history: DecisionHistoryRegistry,
	r_registry: RelationshipRegistry,
	n_registry: NarrativeRegistry,
	s_registry: SessionRegistry
) -> void:
	player_profile = p_profile
	decision_history = d_history
	relationship = r_registry
	narrative = n_registry
	session = s_registry


func build_full_context(game_state: Dictionary) -> Dictionary:
	## Construit le contexte complet pour le LLM.
	var run = game_state.get("run", {})
	var bestiole = game_state.get("bestiole", {})

	return {
		# === GAME STATE ===
		"gauges": run.get("gauges", {}),
		"aspects": run.get("aspects", {}),
		"souffle": int(run.get("souffle", 0)),
		"life_essence": int(run.get("life_essence", 100)),
		"day": int(run.get("day", 1)),
		"cards_played": int(run.get("cards_played", 0)),
		"active_promises": run.get("active_promises", []),
		"active_tags": run.get("active_tags", []),

		# === BESTIOLE ===
		"bestiole": {
			"name": bestiole.get("name", "Bestiole"),
			"bond": int(bestiole.get("bond", 50)),
			"mood": _get_bestiole_mood(bestiole),
			"skills_ready": _get_ready_skills(bestiole),
		},

		# === PLAYER PROFILE ===
		"player": player_profile.get_context_for_llm() if player_profile else {},

		# === PATTERNS ===
		"patterns": decision_history.get_pattern_for_llm() if decision_history else "",

		# === RELATIONSHIP ===
		"trust": relationship.get_context_for_llm() if relationship else {},

		# === NARRATIVE ===
		"narrative": narrative.get_context_for_llm() if narrative else {},

		# === SESSION ===
		"session": session.get_context_for_llm() if session else {},

		# === HIDDEN STATE ===
		"_hidden": {
			"karma": int(run.get("hidden", {}).get("karma", 0)),
			"tension": float(run.get("hidden", {}).get("tension", 0)),
			"theme_weights": _calculate_theme_weights(),
		},
	}


func _get_bestiole_mood(bestiole: Dictionary) -> String:
	var needs = bestiole.get("needs", {})
	var avg_needs := (
		int(needs.get("Hunger", 50)) +
		int(needs.get("Energy", 50)) +
		int(needs.get("Mood", 50)) -
		int(needs.get("Stress", 0))
	) / 4.0

	if avg_needs >= 70:
		return "happy"
	elif avg_needs >= 40:
		return "content"
	elif avg_needs >= 20:
		return "tired"
	else:
		return "distressed"


func _get_ready_skills(bestiole: Dictionary) -> Array:
	var skills_ready := []
	var cooldowns = bestiole.get("skill_cooldowns", {})
	var equipped = bestiole.get("skills_equipped", [])

	for skill_id in equipped:
		if int(cooldowns.get(skill_id, 0)) <= 0:
			skills_ready.append(skill_id)

	return skills_ready


func _calculate_theme_weights() -> Dictionary:
	if narrative == null:
		return {}

	var weights := {}
	var themes := ["mystery", "combat", "social", "survival", "spiritual", "political"]

	for theme in themes:
		weights[theme] = narrative.get_theme_weight(theme)

	return weights


func build_llm_prompt_context(full_context: Dictionary) -> String:
	## Transforme le contexte en texte pour le prompt LLM.
	var lines := []

	# Jauges critiques (pour TRIADE)
	var aspects = full_context.get("aspects", {})
	var critical := []
	for aspect in aspects:
		var state: int = int(aspects[aspect])
		if state != 0:  # Not balanced
			var state_name := "HAUT" if state > 0 else "BAS"
			critical.append("%s %s" % [aspect, state_name])

	if critical.size() > 0:
		lines.append("ATTENTION: " + ", ".join(critical))

	# Souffle
	var souffle: int = int(full_context.get("souffle", 0))
	if souffle <= 1:
		lines.append("SOUFFLE FAIBLE: %d" % souffle)

	# Life essence — danger level
	var life: int = int(full_context.get("life_essence", 100))
	if life <= 15:
		lines.append("VIE CRITIQUE: %d/100 — mort imminente" % life)
	elif life <= 25:
		lines.append("VIE BASSE: %d/100 — danger" % life)
	elif life <= 50:
		lines.append("Vie: %d/100" % life)

	# Jour et progression
	lines.append("Jour %d, %d cartes jouees" % [
		full_context.get("day", 1),
		full_context.get("cards_played", 0)
	])

	# Profil joueur (resume compact via le registry)
	if player_profile:
		var profile_summary: String = player_profile.get_summary_for_prompt()
		if profile_summary != "":
			lines.append(profile_summary)

	# Patterns detectes
	var patterns: String = full_context.get("patterns", "")
	if patterns != "":
		lines.append("Tendances:\n" + patterns)

	# Relation
	var trust = full_context.get("trust", {})
	lines.append("Confiance: %s (%d/100)" % [
		trust.get("tier_name", "Inconnu"),
		int(trust.get("trust_points", 0))
	])

	# Narration
	var narrative_ctx = full_context.get("narrative", {})
	var active_arcs = narrative_ctx.get("active_arcs", [])
	if active_arcs.size() > 0:
		lines.append("Arcs actifs: " + str(active_arcs))

	# Themes
	var fatigued = narrative_ctx.get("fatigued_themes", [])
	if fatigued.size() > 0:
		lines.append("Eviter: " + ", ".join(fatigued))

	var recommended = narrative_ctx.get("recommended_themes", [])
	if recommended.size() > 0:
		lines.append("Privilegier: " + ", ".join(recommended))

	# Session
	var session_ctx = full_context.get("session", {})
	if session_ctx.get("seems_frustrated", false):
		lines.append("NOTE: Joueur semble frustre - adoucir")
	if session_ctx.get("seems_fatigued", false):
		lines.append("NOTE: Joueur fatigue - simplifier")
	if session_ctx.get("is_long_session", false):
		lines.append("NOTE: Longue session - varier le rythme")

	return "\n".join(lines)


func get_critical_gauges(gauges: Dictionary) -> Array:
	## Retourne les jauges critiques (basses ou hautes).
	var critical := []
	const LOW_THRESHOLD := 15
	const HIGH_THRESHOLD := 85

	for gauge_name in gauges:
		var value: int = int(gauges[gauge_name])
		if value <= LOW_THRESHOLD:
			critical.append("%s CRITIQUE BAS (%d)" % [gauge_name, value])
		elif value >= HIGH_THRESHOLD:
			critical.append("%s CRITIQUE HAUT (%d)" % [gauge_name, value])

	return critical


func get_experience_tier() -> String:
	if player_profile == null:
		return "Initie"
	return player_profile.get_experience_tier_name()


func _trust_tier_name(tier: int) -> String:
	match tier:
		0: return "Distant"
		1: return "Prudent"
		2: return "Attentif"
		3: return "Lie"
	return "Inconnu"
