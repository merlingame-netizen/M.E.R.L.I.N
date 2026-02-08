## ═══════════════════════════════════════════════════════════════════════════════
## Tone Controller — Controle du Ton de Merlin
## ═══════════════════════════════════════════════════════════════════════════════
## Gere le ton de Merlin selon la confiance et le contexte.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name ToneController

# ═══════════════════════════════════════════════════════════════════════════════
# TONES
# ═══════════════════════════════════════════════════════════════════════════════

enum Tone {
	NEUTRAL,      # Standard, descriptif
	PLAYFUL,      # Taquin, humoristique
	MYSTERIOUS,   # Enigmatique, hints
	WARNING,      # Urgent, protecteur
	MELANCHOLY,   # Rare tristesse
	WARM,         # Chaleureux, supportif
	CRYPTIC,      # Tres ambigu, double-sens
}

var current_tone: Tone = Tone.NEUTRAL

# ═══════════════════════════════════════════════════════════════════════════════
# TONE WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

var tone_weights := {
	Tone.NEUTRAL: 1.0,
	Tone.PLAYFUL: 1.0,
	Tone.MYSTERIOUS: 0.5,
	Tone.WARNING: 0.3,
	Tone.MELANCHOLY: 0.0,  # Only at high trust
	Tone.WARM: 0.2,
	Tone.CRYPTIC: 0.3,
}

# ═══════════════════════════════════════════════════════════════════════════════
# RELATIONSHIP STATE
# ═══════════════════════════════════════════════════════════════════════════════

var trust_tier := 0  # From RelationshipRegistry
var rapport_warmth := 0.0
var rapport_complicity := 0.0
var can_show_darkness := false
var can_show_melancholy := false

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION STATE
# ═══════════════════════════════════════════════════════════════════════════════

var session_seems_frustrated := false
var session_is_long := false
var player_in_flow := false

# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE FROM REGISTRIES
# ═══════════════════════════════════════════════════════════════════════════════

func update_from_relationship(relationship: RelationshipRegistry) -> void:
	if relationship == null:
		return

	trust_tier = relationship.trust_tier

	var rapport = relationship.rapport
	rapport_warmth = float(rapport.get("warmth", 0.0))
	rapport_complicity = float(rapport.get("complicity", 0.0))

	can_show_darkness = relationship.can_show_slip()
	can_show_melancholy = relationship.can_show_melancholy()

	_recalculate_weights()


func update_from_session(session: SessionRegistry) -> void:
	if session == null:
		return

	session_seems_frustrated = session.wellness.frustration_detected
	session_is_long = session.wellness.long_session_warned
	player_in_flow = session.wellness.positive_momentum

	_recalculate_weights()


func _recalculate_weights() -> void:
	# Reset to base
	tone_weights = {
		Tone.NEUTRAL: 1.0,
		Tone.PLAYFUL: 1.0,
		Tone.MYSTERIOUS: 0.5,
		Tone.WARNING: 0.3,
		Tone.MELANCHOLY: 0.0,
		Tone.WARM: 0.2,
		Tone.CRYPTIC: 0.3,
	}

	# Adjust based on trust tier
	match trust_tier:
		0:  # DISTANT
			tone_weights[Tone.PLAYFUL] = 0.5
			tone_weights[Tone.WARM] = 0.0
			tone_weights[Tone.MYSTERIOUS] = 0.8
		1:  # CAUTIOUS
			tone_weights[Tone.PLAYFUL] = 0.8
			tone_weights[Tone.WARM] = 0.3
		2:  # ATTENTIVE
			tone_weights[Tone.PLAYFUL] = 1.0
			tone_weights[Tone.WARM] = 0.5
			tone_weights[Tone.CRYPTIC] = 0.4
		3:  # BOUND
			tone_weights[Tone.PLAYFUL] = 1.2
			tone_weights[Tone.WARM] = 0.7
			tone_weights[Tone.MELANCHOLY] = 0.15
			tone_weights[Tone.CRYPTIC] = 0.5

	# Adjust based on rapport
	tone_weights[Tone.WARM] += rapport_warmth * 0.3
	tone_weights[Tone.PLAYFUL] += rapport_complicity * 0.2

	# Session adjustments
	if session_seems_frustrated:
		tone_weights[Tone.WARM] += 0.3
		tone_weights[Tone.PLAYFUL] -= 0.2
		tone_weights[Tone.WARNING] -= 0.2

	if player_in_flow:
		tone_weights[Tone.PLAYFUL] += 0.2

	if session_is_long:
		tone_weights[Tone.WARM] += 0.1

# ═══════════════════════════════════════════════════════════════════════════════
# TONE SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func get_tone_for_context(context: Dictionary) -> Tone:
	## Selectionne le ton approprie pour le contexte.

	# Check for crisis (warning tone)
	if _is_crisis_context(context):
		if randf() < 0.7:
			current_tone = Tone.WARNING
			return current_tone

	# Check for special narrative moments
	if context.get("is_arc_climax", false):
		current_tone = Tone.MYSTERIOUS
		return current_tone

	# Check for melancholy opportunity
	if can_show_melancholy and randf() < tone_weights[Tone.MELANCHOLY]:
		current_tone = Tone.MELANCHOLY
		return current_tone

	# Weighted random selection
	current_tone = _weighted_tone_selection()
	return current_tone


func _is_crisis_context(context: Dictionary) -> bool:
	var gauges: Dictionary = context.get("gauges", {})
	for gauge in gauges:
		var value: int = int(gauges[gauge])
		if value < 15 or value > 85:
			return true

	var aspects: Dictionary = context.get("aspects", {})
	var extreme_count := 0
	for aspect in aspects:
		if int(aspects[aspect]) != 0:
			extreme_count += 1
	return extreme_count >= 2


func _weighted_tone_selection() -> Tone:
	var total_weight := 0.0
	for tone in tone_weights:
		total_weight += tone_weights[tone]

	var roll := randf() * total_weight
	var cumulative := 0.0

	for tone in tone_weights:
		cumulative += tone_weights[tone]
		if roll < cumulative:
			return tone

	return Tone.NEUTRAL


func get_current_tone() -> String:
	return tone_to_string(current_tone)


func tone_to_string(tone: Tone) -> String:
	match tone:
		Tone.NEUTRAL: return "neutral"
		Tone.PLAYFUL: return "playful"
		Tone.MYSTERIOUS: return "mysterious"
		Tone.WARNING: return "warning"
		Tone.MELANCHOLY: return "melancholy"
		Tone.WARM: return "warm"
		Tone.CRYPTIC: return "cryptic"
	return "neutral"

# ═══════════════════════════════════════════════════════════════════════════════
# TONE CHARACTERISTICS
# ═══════════════════════════════════════════════════════════════════════════════

func get_tone_characteristics(tone: Tone = current_tone) -> Dictionary:
	## Retourne les caracteristiques pour guider la generation.
	match tone:
		Tone.NEUTRAL:
			return {
				"sentence_length": "medium",
				"punctuation": "normal",
				"vocabulary": "standard",
				"emotion": "detached",
			}
		Tone.PLAYFUL:
			return {
				"sentence_length": "short",
				"punctuation": "exclamation",
				"vocabulary": "colorful",
				"emotion": "amused",
			}
		Tone.MYSTERIOUS:
			return {
				"sentence_length": "varied",
				"punctuation": "ellipsis",
				"vocabulary": "archaic",
				"emotion": "enigmatic",
			}
		Tone.WARNING:
			return {
				"sentence_length": "short",
				"punctuation": "urgent",
				"vocabulary": "direct",
				"emotion": "concerned",
			}
		Tone.MELANCHOLY:
			return {
				"sentence_length": "long",
				"punctuation": "pauses",
				"vocabulary": "poetic",
				"emotion": "wistful",
			}
		Tone.WARM:
			return {
				"sentence_length": "medium",
				"punctuation": "gentle",
				"vocabulary": "familiar",
				"emotion": "caring",
			}
		Tone.CRYPTIC:
			return {
				"sentence_length": "short",
				"punctuation": "mysterious",
				"vocabulary": "symbolic",
				"emotion": "knowing",
			}

	return {}


func get_sentence_prefix(tone: Tone = current_tone) -> String:
	## Retourne un prefixe typique pour ce ton.
	var prefixes := {
		Tone.NEUTRAL: ["", "Alors, ", "Voyons, "],
		Tone.PLAYFUL: ["Ah! ", "Ho ho! ", "Tiens, tiens, "],
		Tone.MYSTERIOUS: ["...", "Hm, ", "Les signes montrent que "],
		Tone.WARNING: ["Attention! ", "Prends garde, ", "Ecoute bien: "],
		Tone.MELANCHOLY: ["...", "Parfois, ", "Il fut un temps ou "],
		Tone.WARM: ["Mon ami, ", "Voyageur, ", "Tu sais, "],
		Tone.CRYPTIC: ["On dit que ", "Certains voient ", "Le vent murmure que "],
	}

	var options: Array = prefixes.get(tone, [""])
	return options[randi() % options.size()]


func get_sentence_suffix(tone: Tone = current_tone) -> String:
	## Retourne un suffixe typique pour ce ton.
	var suffixes := {
		Tone.NEUTRAL: [".", ".", "."],
		Tone.PLAYFUL: ["!", "... ou pas?", ", hehe."],
		Tone.MYSTERIOUS: ["...", ".", "... peut-etre."],
		Tone.WARNING: [".", "!", ". Fais attention."],
		Tone.MELANCHOLY: ["...", ".", "... mais c'est une autre histoire."],
		Tone.WARM: [".", ", n'est-ce pas?", "."],
		Tone.CRYPTIC: ["...", "... ou l'inverse.", ". Qui sait?"],
	}

	var options: Array = suffixes.get(tone, ["."])
	return options[randi() % options.size()]

# ═══════════════════════════════════════════════════════════════════════════════
# PROMPT GUIDANCE
# ═══════════════════════════════════════════════════════════════════════════════

func get_tone_prompt_guidance() -> String:
	## Retourne des instructions de ton pour le LLM.
	var chars := get_tone_characteristics()
	var lines := []

	lines.append("Ton actuel: %s" % get_current_tone())

	match current_tone:
		Tone.NEUTRAL:
			lines.append("Voix descriptive et equilibree")
		Tone.PLAYFUL:
			lines.append("Taquiner gentiment, humour leger")
			lines.append("Phrases courtes et vives")
		Tone.MYSTERIOUS:
			lines.append("Laisser des indices ambigus")
			lines.append("Utiliser des ellipses...")
		Tone.WARNING:
			lines.append("Ton urgent mais pas paniquant")
			lines.append("Conseils directs")
		Tone.MELANCHOLY:
			lines.append("RARE: Un moment de vraie tristesse")
			lines.append("Bref, puis retour a la normale")
		Tone.WARM:
			lines.append("Chaleureux, supportif")
			lines.append("Encourager le joueur")
		Tone.CRYPTIC:
			lines.append("Double-sens, symbolisme")
			lines.append("Plusieurs interpretations possibles")

	return "\n".join(lines)
