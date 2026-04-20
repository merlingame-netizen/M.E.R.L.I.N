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
	var run: Dictionary = game_state.get("run", {})
	var meta: Dictionary = game_state.get("meta", {})

	return {
		# === GAME STATE ===
		"tour": int(run.get("tour", 1)),
		"ogham_actif": str(run.get("ogham_actif", "")),
		"oghams_decouverts": run.get("oghams_decouverts", []),
		"factions": meta.get("faction_rep", {
			"druides": 0, "anciens": 0, "korrigans": 0, "niamh": 0, "ankou": 0
		}),
		"heure_normalisee": float(run.get("heure_normalisee", 0.0)),
		"life_essence": int(run.get("life_essence", 100)),
		"day": int(run.get("day", 1)),
		"cards_played": int(run.get("cards_played", 0)),
		"active_promises": run.get("active_promises", []),
		"active_tags": run.get("active_tags", []),

		# === CROSS-RUN MEMORY ===
		"echo_memory": meta.get("echo_memory", {}),
		"total_runs": int(meta.get("total_runs", 0)),

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

	# Tour, Ogham actif, Oghams découverts
	var tour: int = int(full_context.get("tour", 1))
	var ogham_actif: String = str(full_context.get("ogham_actif", ""))
	var oghams_decouverts: Array = full_context.get("oghams_decouverts", [])
	lines.append("Tour: %d" % tour)
	if ogham_actif != "":
		lines.append("Ogham actif: %s" % ogham_actif)
	if oghams_decouverts.size() > 0:
		var ogham_strs: Array[String] = []
		for og in oghams_decouverts:
			ogham_strs.append(str(og))
		lines.append("Oghams découverts: %s" % ", ".join(ogham_strs))

	# Réputation des 5 factions
	var factions: Dictionary = full_context.get("factions", {})
	lines.append("Réputation — Druides: %d, Anciens: %d, Korrigans: %d, Niamh: %d, Ankou: %d" % [
		int(factions.get("druides", 0)),
		int(factions.get("anciens", 0)),
		int(factions.get("korrigans", 0)),
		int(factions.get("niamh", 0)),
		int(factions.get("ankou", 0)),
	])

	# Heure normalisée et période
	var heure: float = float(full_context.get("heure_normalisee", 0.0))
	var periode := "nuit"
	if heure < 0.25:
		periode = "aube"
	elif heure < 0.5:
		periode = "jour"
	elif heure < 0.75:
		periode = "crépuscule"
	lines.append("Heure: %.2f (période: %s)" % [heure, periode])

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


## DEPRECATED — Gauge system suppressed in bible v2.4. Always returns [].
## Kept for test compatibility; callers always pass {} so output is always [].
func get_critical_gauges(_gauges: Dictionary) -> Array:
	return []


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
