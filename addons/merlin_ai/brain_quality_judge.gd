## BrainQualityJudge — Scoring, best-of-N selection, and quality pipeline for swarm output
##
## Centralizes text quality evaluation and provides:
## - Multi-criteria scoring (French%, repetition, length, Celtic vocabulary)
## - Best-of-N: generate N variants, pick the best
## - Pipeline integration: Narrator → Judge → Game Master
extends RefCounted
class_name BrainQualityJudge

# ── Scoring Weights ───────────────────────────────────────────────────────────
const W_FRENCH := 0.25       # Language check
const W_REPETITION := 0.25   # Novelty vs recent texts
const W_LENGTH := 0.15       # Appropriate length
const W_CELTIC := 0.20       # Celtic/druidic vocabulary
const W_STRUCTURE := 0.15    # Has narrative + 3 choices

# ── Thresholds ────────────────────────────────────────────────────────────────
const MIN_ACCEPTABLE_SCORE := 0.4    # Below this = reject
const GOOD_SCORE := 0.6              # Above this = accept immediately
const BEST_OF_N_DEFAULT := 2         # Generate 2 variants by default

# ── French Detection ──────────────────────────────────────────────────────────
const FR_KEYWORDS := ["le", "la", "de", "un", "une", "du", "les", "des", "en", "et",
	"est", "que", "qui", "dans", "pour", "sur", "avec", "pas", "ce", "cette",
	"sont", "mais", "ou", "il", "elle", "nous", "vous", "leur", "au", "aux"]
const FR_MIN_MATCHES := 3

# ── Celtic Vocabulary ─────────────────────────────────────────────────────────
const CELTIC_KEYWORDS := [
	"druide", "ogham", "broceliande", "merlin", "chene", "gui", "dolmen",
	"menhir", "korrigan", "foret", "brume", "mystique", "sacre", "sacree",
	"ancestral", "celtique", "rune", "barde", "sanglier", "corbeau", "cerf",
	"clairiere", "equinoxe", "solstice", "lune", "etoile", "souffle",
	"esprit", "ame", "monde", "corps", "equilibre", "destin", "voyage",
	"sentier", "ancien", "antique", "cristal", "pierre", "source",
	"enchante", "enchantee", "magie", "sortilege", "incantation",
]

# ── Internal State ────────────────────────────────────────────────────────────
var _recent_texts: Array[String] = []
const RECENT_MEMORY := 20
const JACCARD_THRESHOLD := 0.7

# ── Target lengths ────────────────────────────────────────────────────────────
const IDEAL_MIN_LEN := 80
const IDEAL_MAX_LEN := 600


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Score a generated text. Returns Dictionary with total score and per-criteria breakdown.
func score_text(text: String) -> Dictionary:
	var scores := {
		"french": _score_french(text),
		"repetition": _score_repetition(text),
		"length": _score_length(text),
		"celtic": _score_celtic(text),
		"structure": _score_structure(text),
	}
	var total: float = (
		scores.french * W_FRENCH +
		scores.repetition * W_REPETITION +
		scores.length * W_LENGTH +
		scores.celtic * W_CELTIC +
		scores.structure * W_STRUCTURE
	)
	return {
		"total": total,
		"scores": scores,
		"acceptable": total >= MIN_ACCEPTABLE_SCORE,
		"good": total >= GOOD_SCORE,
	}


## Pick the best text from an array of candidates. Returns {text, score, index}.
func pick_best(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var best_score := -1.0
	var best_index := 0
	var best_result := {}
	for i in range(candidates.size()):
		var text: String = str(candidates[i])
		var result := score_text(text)
		if result.total > best_score:
			best_score = result.total
			best_index = i
			best_result = result
	return {
		"text": str(candidates[best_index]),
		"score": best_score,
		"index": best_index,
		"detail": best_result,
	}


## Register a text as "recently generated" (for repetition detection).
func register_text(text: String) -> void:
	_recent_texts.append(text.to_lower())
	if _recent_texts.size() > RECENT_MEMORY:
		_recent_texts = _recent_texts.slice(-RECENT_MEMORY) as Array[String]


## Check if a text passes minimum quality. Returns {ok: bool, reason: String}.
func check_minimum_quality(text: String) -> Dictionary:
	if text.strip_edges().length() < 10:
		return {"ok": false, "reason": "too_short"}
	var result := score_text(text)
	if not result.acceptable:
		# Identify worst criterion
		var scores: Dictionary = result.scores
		var worst_name := ""
		var worst_val := 1.0
		for key in scores:
			if float(scores[key]) < worst_val:
				worst_val = float(scores[key])
				worst_name = key
		return {"ok": false, "reason": "low_score_%s" % worst_name, "score": result.total}
	return {"ok": true, "reason": "", "score": result.total}


## Generate a refinement prompt to improve a low-scoring text.
func suggest_refinement(text: String, score_result: Dictionary) -> String:
	var scores: Dictionary = score_result.get("scores", {})
	var suggestions: PackedStringArray = []

	if float(scores.get("french", 1.0)) < 0.5:
		suggestions.append("Reecris en francais correct, avec des articles et prepositions francaises.")
	if float(scores.get("celtic", 1.0)) < 0.3:
		suggestions.append("Ajoute du vocabulaire celtique et druidique (druide, ogham, foret sacree, brume, etc).")
	if float(scores.get("repetition", 1.0)) < 0.3:
		suggestions.append("Varie le vocabulaire et les tournures par rapport aux textes precedents.")
	if float(scores.get("structure", 1.0)) < 0.5:
		suggestions.append("Assure-toi d'inclure une narration ET 3 choix distincts (A, B, C).")
	if float(scores.get("length", 1.0)) < 0.3:
		suggestions.append("Le texte doit faire entre 80 et 600 caracteres.")

	if suggestions.is_empty():
		return ""
	return "Ameliore ce texte: " + "\n".join(suggestions) + "\n\nTexte original:\n" + text


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Scoring Functions (each returns 0.0 to 1.0)
# ═══════════════════════════════════════════════════════════════════════════════

func _score_french(text: String) -> float:
	var lower := text.to_lower()
	var matches := 0
	for kw in FR_KEYWORDS:
		if lower.contains(" " + kw + " ") or lower.begins_with(kw + " ") or lower.ends_with(" " + kw):
			matches += 1
	# 0 matches = 0.0, FR_MIN_MATCHES+ = 1.0, linear between
	return clampf(float(matches) / float(FR_MIN_MATCHES), 0.0, 1.0)


func _score_repetition(text: String) -> float:
	## 1.0 = fully novel, 0.0 = very repetitive.
	if _recent_texts.is_empty():
		return 1.0
	var lower := text.to_lower()
	var max_sim := 0.0
	for recent in _recent_texts:
		var sim := _jaccard_similarity(lower, recent)
		if sim > max_sim:
			max_sim = sim
	# Invert: high similarity = low score
	if max_sim >= JACCARD_THRESHOLD:
		return 0.0
	return 1.0 - (max_sim / JACCARD_THRESHOLD)


func _score_length(text: String) -> float:
	var len_val: int = text.strip_edges().length()
	if len_val < 10:
		return 0.0
	if len_val >= IDEAL_MIN_LEN and len_val <= IDEAL_MAX_LEN:
		return 1.0
	if len_val < IDEAL_MIN_LEN:
		return clampf(float(len_val) / float(IDEAL_MIN_LEN), 0.0, 1.0)
	# Too long — gentle penalty
	if len_val > IDEAL_MAX_LEN * 2:
		return 0.3
	return clampf(1.0 - float(len_val - IDEAL_MAX_LEN) / float(IDEAL_MAX_LEN), 0.3, 1.0)


func _score_celtic(text: String) -> float:
	var lower := text.to_lower()
	var matches := 0
	for kw in CELTIC_KEYWORDS:
		if lower.contains(kw):
			matches += 1
	# 0 = 0.0, 1 = 0.3, 2 = 0.6, 3+ = 1.0
	return clampf(float(matches) / 3.0, 0.0, 1.0)


func _score_structure(text: String) -> float:
	## Check if text has narrative + choices structure.
	var score := 0.0
	var stripped := text.strip_edges()

	# Has some narrative (at least 2 sentences)
	var sentence_count := 0
	for c in [".", "!", "?"]:
		sentence_count += stripped.count(c)
	if sentence_count >= 2:
		score += 0.4
	elif sentence_count >= 1:
		score += 0.2

	# Has choice markers (A/B/C, 1/2/3, or bullet points)
	var has_choices := false
	for marker in ["A)", "B)", "C)", "A.", "B.", "C.", "1)", "2)", "3)", "1.", "2.", "3.",
		"a)", "b)", "c)", "- ", "* ", "Gauche", "Centre", "Droite"]:
		if stripped.contains(marker):
			has_choices = true
			break
	if has_choices:
		score += 0.4

	# Has paragraph breaks (narrative structure)
	if stripped.contains("\n"):
		score += 0.2

	return clampf(score, 0.0, 1.0)


func _jaccard_similarity(a: String, b: String) -> float:
	var words_a := a.split(" ", false)
	var words_b := b.split(" ", false)
	if words_a.is_empty() or words_b.is_empty():
		return 0.0
	var set_a := {}
	for w in words_a:
		set_a[w] = true
	var set_b := {}
	for w in words_b:
		set_b[w] = true
	var intersection := 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)
