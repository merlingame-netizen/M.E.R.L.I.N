## ═══════════════════════════════════════════════════════════════════════════════
## ScenarioPlanner — Front-loaded scenario generator (v7.7, 2026-05-15 part 21)
## ═══════════════════════════════════════════════════════════════════════════════
## Réf user AskUserQuestion 2026-05-15 part 21 :
##   - 3 titres + glyph ogham (minimal, mystérieux)
##   - Skeleton 5 beats avec faction_tilt + emotion arc
##   - Loading UX : Merlin live narration (Narrator stream en parallèle)
##   - Pre-fetch carte N+1 immédiat après render N (zero-latency in-game)
##   - LLM-judge brain pour divergence detection (Phase 2 stub ici)
##   - Adaptive : LLM ré-écrit beats restants si player diverge (Phase 2 stub ici)
##
## Cascade fallback 3-niveaux :
##   L1 : full LLM (titles → skeleton → JIT cards via BiBrainPipeline)
##   L2 : skeleton OK, cartes via FastRoute pool filtré par biome+beat-tag
##   L3 : skeleton hardcoded (FALLBACK_SKELETONS const ; 1 biome Phase 1, 8 Phase 2)
##
## API Phase 1 (foundation) :
##   var planner := ScenarioPlanner.new(merlin_ai, rag, fastroute_pool)
##   var titles: Array = await planner.generate_titles(biome_id)
##   var skeleton: Dictionary = await planner.generate_skeleton(biome_id, chosen_title)
##   var card: Dictionary = await planner.generate_card_for_beat(skeleton, beat_idx, player_state)
##   var diverged: bool = await planner.judge_divergence(...)  # Phase 2 stub returns false
##   var new_skeleton: Dictionary = await planner.replan_from_beat(...)  # Phase 2 stub returns unchanged
## ═══════════════════════════════════════════════════════════════════════════════

class_name ScenarioPlanner
extends RefCounted

const GBNF_SKELETON_PATH := "res://data/ai/scenario_skeleton.gbnf"
const TITLES_TIMEOUT_S := 8.0
const SKELETON_TIMEOUT_S := 15.0
const JUDGE_TIMEOUT_S := 4.0
const INTRO_TIMEOUT_S := 10.0   # v7.7.23 — LLM #2 (intro) budget

# v7.7 Phase 2.6 — 8 fallback skeletons (1 per biome, baseline emotional arc).
# Each biome leans on its 1-2 dominant factions per the lore. Curiosité→sagesse
# arc preserves the classic 5-act tension. Used by L3 cascade fallback when both
# LLM (L1) and FastRoute pool (L2) are unavailable.
const FALLBACK_SKELETONS: Dictionary = {
	"foret_broceliande": {
		"title": "La Voix de Brocéliande",
		"beats": [
			{"n": 1, "summary": "Tu pénètres la forêt — une présence te guette.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Une rencontre te révèle un secret du chêne.", "faction_tilt": "druides", "emotion": "tension"},
			{"n": 3, "summary": "Un choix moral te divise entre nature et soi.", "faction_tilt": "korrigans", "emotion": "peur"},
			{"n": 4, "summary": "L'épreuve du chêne ancien se dresse devant toi.", "faction_tilt": "ankou", "emotion": "fascination"},
			{"n": 5, "summary": "La forêt te juge — tu deviens ou tu disparais.", "faction_tilt": "niamh", "emotion": "sagesse"},
		],
	},
	"landes_bruyere": {
		"title": "Le Vent de Bruyère",
		"beats": [
			{"n": 1, "summary": "Le vent te porte vers un cairn battu par les bourrasques.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Un voile d'Ankou rôde entre les pierres dressées.", "faction_tilt": "ankou", "emotion": "tension"},
			{"n": 3, "summary": "Une voix t'appelle hors du chemin tracé.", "faction_tilt": "anciens", "emotion": "melancolie"},
			{"n": 4, "summary": "La lande s'ouvre — un seul cairn t'attend.", "faction_tilt": "ankou", "emotion": "peur"},
			{"n": 5, "summary": "Tu choisis : te coucher avec les morts ou marcher.", "faction_tilt": "anciens", "emotion": "sagesse"},
		],
	},
	"cotes_sauvages": {
		"title": "L'Appel des Falaises",
		"beats": [
			{"n": 1, "summary": "Les vagues s'écrasent — un naufrage récent fume sur la grève.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Une grotte béante chante des chants korrigans.", "faction_tilt": "korrigans", "emotion": "fascination"},
			{"n": 3, "summary": "La marée monte — un choix s'impose à toi.", "faction_tilt": "korrigans", "emotion": "tension"},
			{"n": 4, "summary": "Un dieu des profondeurs émerge du brouillard.", "faction_tilt": "ankou", "emotion": "peur"},
			{"n": 5, "summary": "Tu t'élances vers ou tu fuis l'horizon noir.", "faction_tilt": "niamh", "emotion": "espoir"},
		],
	},
	"villages_celtes": {
		"title": "Le Foyer des Anciens",
		"beats": [
			{"n": 1, "summary": "Tu approches d'un village où le feu danse haut.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Un ancien te raconte une légende oubliée.", "faction_tilt": "anciens", "emotion": "emerveillement"},
			{"n": 3, "summary": "Un conflit éclate entre tribus — tu dois trancher.", "faction_tilt": "druides", "emotion": "tension"},
			{"n": 4, "summary": "La nuit tombe — l'épreuve du feu sacré arrive.", "faction_tilt": "druides", "emotion": "fascination"},
			{"n": 5, "summary": "L'aube te trouve allié ou banni.", "faction_tilt": "anciens", "emotion": "sagesse"},
		],
	},
	"cercles_pierres": {
		"title": "Le Chœur des Menhirs",
		"beats": [
			{"n": 1, "summary": "Un cercle de pierres vibre sous tes pas — équinoxe.", "faction_tilt": "neutre", "emotion": "emerveillement"},
			{"n": 2, "summary": "Les ogham gravés s'éveillent en lichen lumineux.", "faction_tilt": "druides", "emotion": "curiosite"},
			{"n": 3, "summary": "Un gardien minéral te défie de prouver ta voie.", "faction_tilt": "anciens", "emotion": "tension"},
			{"n": 4, "summary": "Le ciel ouvre une porte au-dessus du dolmen central.", "faction_tilt": "niamh", "emotion": "fascination"},
			{"n": 5, "summary": "Tu deviens initié ou tu disparais entre les pierres.", "faction_tilt": "druides", "emotion": "sagesse"},
		],
	},
	"marais_korrigans": {
		"title": "La Lumière qui Trompe",
		"beats": [
			{"n": 1, "summary": "La tourbière t'engloutit jusqu'à mi-jambe — une lueur vacille.", "faction_tilt": "neutre", "emotion": "tension"},
			{"n": 2, "summary": "Un will-o-wisp t'invite à le suivre dans les roseaux.", "faction_tilt": "korrigans", "emotion": "fascination"},
			{"n": 3, "summary": "Une voix d'enfant chante — mais sous l'eau.", "faction_tilt": "korrigans", "emotion": "peur"},
			{"n": 4, "summary": "La boue te révèle ce qu'elle a gardé.", "faction_tilt": "ankou", "emotion": "melancolie"},
			{"n": 5, "summary": "Tu sors illuminé ou tu rejoins la danse.", "faction_tilt": "korrigans", "emotion": "sagesse"},
		],
	},
	"collines_dolmens": {
		"title": "Sous le Souffle des Ancêtres",
		"beats": [
			{"n": 1, "summary": "Les collines verdoyantes s'étalent — un dolmen massif perce le ciel.", "faction_tilt": "neutre", "emotion": "curiosite"},
			{"n": 2, "summary": "Un mégalithe s'ouvre — l'écho d'un ancêtre te nomme.", "faction_tilt": "anciens", "emotion": "emerveillement"},
			{"n": 3, "summary": "Un rite tribal te demande de prouver ta lignée.", "faction_tilt": "anciens", "emotion": "tension"},
			{"n": 4, "summary": "Une vision te montre ce que tu pourrais devenir.", "faction_tilt": "druides", "emotion": "fascination"},
			{"n": 5, "summary": "Tu acceptes l'héritage ou tu t'en libères.", "faction_tilt": "anciens", "emotion": "sagesse"},
		],
	},
	"iles_mystiques": {
		"title": "Le Chant de Niamh",
		"beats": [
			{"n": 1, "summary": "Une brume éclatante t'enveloppe — l'île dérive au-dessus de l'eau.", "faction_tilt": "neutre", "emotion": "emerveillement"},
			{"n": 2, "summary": "Une fée te tend une fleur qui ne saurait flétrir.", "faction_tilt": "niamh", "emotion": "fascination"},
			{"n": 3, "summary": "Tu réalises que la brume avale les heures qui passent.", "faction_tilt": "niamh", "emotion": "tension"},
			{"n": 4, "summary": "Niamh elle-même t'offre l'éternité — à un prix.", "faction_tilt": "niamh", "emotion": "espoir"},
			{"n": 5, "summary": "Tu rentres mortel ou tu restes fée.", "faction_tilt": "niamh", "emotion": "sagesse"},
		],
	},
}

# 18 ogham glyphs — picked at random for the 3 titles displayed at run start.
const OGHAM_GLYPHS: Array = ["beith", "luis", "quert", "fearn", "saille", "nuin",
	"huath", "duir", "tinne", "coll", "muin", "gort", "ngetal", "straif", "ruis",
	"ailm", "ohn", "ur"]


# ═════════ v7.7.22 — Card distribution model (rarity / Pole / cardtype) ═══════
# User mandate : « le LLM doit découper les scénarios en ces cartes, en 1-3
# versions par run chacune (voir quelques unes ne peuvent pas apparaitre ?)
# Attention à l'équilibrage ! »
# Locked decisions :
#   - Caps proposés (NARRATIVE 50-70% share, EVENT 1-4, SHOP 1-2,
#     MERLIN_DIRECT 0-3, PROMISE 0-2, RUNE_UNLOCK 0-1)
#   - Ratio rarity 68/20/8/4 (bible §28.1 aligned)
#   - Pole biaisé par biome (bible §7.1)
#   - Enforcement 2-layer : prompt LLM nudge + post-LLM validator

## Per-cardtype frequency CAPS across a full skeleton.
## "min/max_share" = % of skeleton size ; "min/max_count" = absolute count.
## RUNE_UNLOCK has min=0 so the type can be absent from some runs (user mandate).
const CARD_TYPE_CAPS: Dictionary = {
	"NARRATIVE":     {"min_share": 0.50, "max_share": 0.70},
	"EVENT":         {"min_count": 1,    "max_count": 4},
	"SHOP":          {"min_count": 1,    "max_count": 2},
	"MERLIN_DIRECT": {"min_count": 0,    "max_count": 3},
	"PROMISE":       {"min_count": 0,    "max_count": 2},
	"RUNE_UNLOCK":   {"min_count": 0,    "max_count": 1},
}

## Target rarity distribution per skeleton (bible §28.1 effective per-run shares).
## SHARE values, sum ~= 1.0. Caller rescales to skeleton size.
const RARITY_TARGETS: Dictionary = {
	"COMMUNE":    0.68,
	"RARE":       0.20,
	"EPIQUE":     0.08,
	"LEGENDAIRE": 0.04,
}

## Per-biome Pole bias (bible §7.1) — dominant Pole gets 50%, the two others
## ~25% each. "Neutre" beats are the bridging remainder beyond the 3-Pole budget
## (~40% of total beats expected to be neutre — these are framing/transition beats).
const BIOME_POLE_BIAS: Dictionary = {
	"foret_broceliande": {"dominant": "Liminal", "secondary": ["Ordre", "Chaos"]},
	"landes_bruyere":    {"dominant": "Ordre",   "secondary": ["Chaos", "Liminal"]},
	"cotes_sauvages":    {"dominant": "Liminal", "secondary": ["Chaos", "Ordre"]},
	"villages_celtes":   {"dominant": "Ordre",   "secondary": ["Liminal", "Chaos"]},
	"cercles_pierres":   {"dominant": "Liminal", "secondary": ["Ordre", "Chaos"]},
	"marais_korrigans":  {"dominant": "Chaos",   "secondary": ["Liminal", "Ordre"]},
	"collines_dolmens":  {"dominant": "Ordre",   "secondary": ["Liminal", "Chaos"]},
	"iles_mystiques":    {"dominant": "Chaos",   "secondary": ["Liminal", "Ordre"]},
}

## Adjacency rules — no 2 of these cardtypes in a row (anti-fatigue).
const NO_REPEAT_CARDTYPES: Array = ["SHOP", "MERLIN_DIRECT", "RUNE_UNLOCK"]

## Légendaire only allowed in last 30% of the skeleton (climactic placement).
const LEGENDARY_START_SHARE: float = 0.70

## Legacy 5-faction → 3-Pole mapping (bible v3.0 §3.2). Used by _balance_skeleton
## to derive a Pole assignment from the LLM-provided faction_tilt field.
const FACTION_TO_POLE_PLANNER: Dictionary = {
	"druides":   "Ordre",
	"anciens":   "Ordre",
	"korrigans": "Chaos",
	"ankou":     "Chaos",
	"niamh":     "Liminal",
	"neutre":    "Neutre",
}

## CardType per BEAT_ACT_SEQUENCE act_type. The skeleton's act_type drives the
## DigitalPickerCard CardType enum. Boss = Légendaire MERLIN_DIRECT (climax).
const ACT_TYPE_TO_CARDTYPE: Dictionary = {
	"standard": "NARRATIVE",
	"shop":     "SHOP",
	"event":    "EVENT",
	"boss":     "MERLIN_DIRECT",
}

# v7.7 (code-review MEDIUM fix #3) : 5-beat → act_type mapping as a single
# source-of-truth const, not buried in a match statement. Decision 2026-05-15
# part 21 : [standard, shop, standard, event, boss]. If the bible §1 evolves
# to change this sequence, this const is the single point of edit.
#
# v7.7 Phase 2.7 (2026-05-15 part 22) : extended to 10 entries for variable
# 5-10 beat skeletons. Pattern keeps shop early + boss last + events sprinkled.
# Skeletons of size 5/7/10 truncate to first N entries.
const BEAT_ACT_SEQUENCE: Array = [
	"standard",  # 1 — opening
	"shop",      # 2 — early shop respite
	"standard",  # 3
	"event",     # 4 — first event twist
	"standard",  # 5 — also boss slot for 5-beat skeletons
	"event",     # 6 — second event for 7+ skeletons
	"standard",  # 7 — climax for 7-beat skeletons
	"shop",      # 8 — late shop for epic 10-beat
	"event",     # 9 — penultimate event for 10-beat
	"boss",      # 10 — final climax (any size : last entry becomes boss via clamp)
]

# v7.7 (code-review MEDIUM fix #6) : max acceptable title length from LLM
# (defensive against LLM emitting a synopsis instead of a 3-7 word title).
const MAX_TITLE_LENGTH := 60

var _merlin_ai: Node
var _rag: Node
var _fastroute_pool: Array = []
var _bi_brain: BiBrainPipeline = null
var _gbnf_skeleton: String = ""


func _init(merlin_ai_ref: Node, rag_ref: Node = null, fastroute: Array = []) -> void:
	_merlin_ai = merlin_ai_ref
	_rag = rag_ref
	_fastroute_pool = fastroute
	_bi_brain = BiBrainPipeline.new(merlin_ai_ref, rag_ref)
	_load_gbnf()


func _load_gbnf() -> void:
	if not FileAccess.file_exists(GBNF_SKELETON_PATH):
		push_warning("[ScenarioPlanner] Skeleton GBNF missing : " + GBNF_SKELETON_PATH)
		return
	var f := FileAccess.open(GBNF_SKELETON_PATH, FileAccess.READ)
	if f:
		_gbnf_skeleton = f.get_as_text()
		f.close()


# ═════════ Phase 1.1 : Generate 3 titles + ogham glyphs ══════════════════════

func generate_titles(biome_id: String) -> Array:
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return _fallback_titles(biome_id)
	# v7.7.23 — RAG few-shot : retrieve 5 reference titles matching the biome so
	# the LLM produces titles in the same druidic idiom as the 100 reference set.
	var few_shot_titles: String = await _rag_titles_few_shot(biome_id)
	var system_prompt: String = (
		"Tu produis EXACTEMENT 3 titres mystérieux pour une aventure dans le biome %s.\n" +
		"Format STRICT : 1 ligne par titre, 3-7 mots chacun, francais, ton druidique.\n" +
		"Pas de numérotation, pas de synopsis, pas de tirets. Une ligne = un titre.\n" +
		"%s"
	) % [biome_id, few_shot_titles]
	var user_input: String = "Génère 3 titres pour ce biome."
	var params: Dictionary = {
		"max_tokens": 80,
		"temperature": 0.95,
		"timeout_ms": int(TITLES_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Title LLM error : %s — falling back" % result.get("error"))
		return _fallback_titles(biome_id)
	var raw: String = str(result.get("text", result.get("output", ""))).strip_edges()
	return _parse_titles_with_oghams(raw, biome_id)


## v7.7.23 — Retrieve 5 reference titles via ScenariosRAG autoload (kNN cosine).
## Returns a multi-line bullet list ready for prompt injection, or empty string if
## RAG is unavailable.
func _rag_titles_few_shot(biome_id: String) -> String:
	var rag: Node = _get_scenarios_rag()
	if rag == null:
		return ""
	var matches: Array = await rag.query_similar("titres mystérieux pour " + biome_id, 5, "")
	if matches.is_empty():
		return ""
	var block: String = rag.format_titles_as_few_shot(matches)
	return "\nExemples de titres canoniques pour ce biome (style à suivre, ne pas copier) :\n" + block


## v7.7.23 — Resolve the ScenariosRAG autoload. Returns null if not registered
## (graceful : caller skips RAG injection and uses base prompt only).
func _get_scenarios_rag() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("ScenariosRAG")


# ═════════ v7.7.23 Phase 4 : Generate intro (LLM #2, post title-pick) ═════════

## Generate a 6-8 sentence lore-aware intro for the chosen scenario title.
## Displayed on a parchment scroll (ScenarioLoading scene) before the run starts.
## POV : young druide in initiation. Second-person. NO 4th-wall break (the
## simulation aspect of MERLIN's world is hidden from the player).
##
## Pipeline :
##   1. RAG retrieval : 3 reference intros most similar to (chosen_title + biome)
##   2. LLM call with few-shot examples + canon constraints
##   3. Fallback : pick a random reference intro matching the archetype keyword
func generate_intro(biome_id: String, chosen_title: String) -> String:
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return await _fallback_intro(biome_id, chosen_title)
	# v7.7.23 — RAG few-shot : 3 reference intros for style guidance.
	var few_shot_intros: String = await _rag_intros_few_shot(biome_id, chosen_title)
	var system_prompt: String = (
		"Tu rédiges l'intro d'une marche druidique dans le bois de Brocéliande.\n" +
		"POV : second-person, jeune druide en initiation. Le monde druidique est réel pour ce personnage.\n" +
		"CONTRAINTES :\n" +
		"  - EXACTEMENT 6 à 8 phrases (pas plus, pas moins).\n" +
		"  - Français celtique, ton druidique mystique.\n" +
		"  - JAMAIS d'anglicismes, JAMAIS de termes techniques/cyber/numériques.\n" +
		"  - JAMAIS rompre le 4e mur : pas de mention de \"jeu\", \"simulation\", \"joueur\", \"écran\".\n" +
		"  - Place le jeune druide dans son contexte : maître, clan, mission, état d'esprit.\n" +
		"  - Termine sur le seuil de l'aventure (le premier pas qui va déclencher la marche).\n" +
		"%s\n" +
		"Maintenant rédige l'intro pour le titre choisi : \"%s\"."
	) % [few_shot_intros, chosen_title]
	var user_input: String = "Rédige l'intro de 6-8 phrases."
	var params: Dictionary = {
		"max_tokens": 400,
		"temperature": 0.85,
		"timeout_ms": int(INTRO_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Intro LLM error : %s — falling back" % result.get("error"))
		return await _fallback_intro(biome_id, chosen_title)
	var raw: String = str(result.get("text", result.get("output", ""))).strip_edges()
	# Validate : minimum 5 sentences (LLM may under-produce). Falls back if shy.
	var sentence_count: int = raw.count(".") + raw.count("!") + raw.count("?")
	if sentence_count < 5:
		push_warning("[ScenarioPlanner] Intro too short (%d sentences) — falling back" % sentence_count)
		return await _fallback_intro(biome_id, chosen_title)
	# v7.7.24 — Guardrails : check forbidden words + 4e mur + anglicisms via
	# ScenariosRAG.validate_llm_text. If rejected, fall back to canon reference.
	var rag: Node = _get_scenarios_rag()
	if rag != null and rag.has_method("validate_llm_text"):
		var validation: Dictionary = rag.validate_llm_text(raw, "intro")
		if not bool(validation.get("valid", true)):
			push_warning("[ScenarioPlanner] Intro guardrail reject : %s — falling back to canon" % str(validation.get("reason", "?")))
			return await _fallback_intro(biome_id, chosen_title)
	return raw


## v7.7.23 — Retrieve 3 reference intros via ScenariosRAG (kNN cosine on
## title+biome). Returns formatted few-shot block ready for prompt injection.
func _rag_intros_few_shot(biome_id: String, chosen_title: String) -> String:
	var rag: Node = _get_scenarios_rag()
	if rag == null:
		return ""
	var query: String = "%s · %s" % [chosen_title, biome_id]
	var matches: Array = await rag.query_similar(query, 3, "")
	if matches.is_empty():
		return ""
	var block: String = rag.format_intros_as_few_shot(matches, 700)
	return "\nExemples d'intros canoniques (qualité à atteindre, ne pas copier) :\n" + block


## v7.7.23 — Fallback intro when LLM unavailable or output too short.
## Picks a random reference intro matching the title's archetype keyword.
func _fallback_intro(_biome_id: String, chosen_title: String) -> String:
	var rag: Node = _get_scenarios_rag()
	if rag != null:
		# Use RAG with the title text — even without Ollama embed, the fallback
		# match() function does keyword-based archetype lookup.
		var matches: Array = await rag.query_similar(chosen_title, 1, "")
		if not matches.is_empty():
			var first: Dictionary = matches[0]
			var intro: String = str(first.get("intro", ""))
			if intro != "":
				return intro
	# Last-resort generic intro (covers offline-with-broken-RAG case).
	return (
		"Tu es un jeune druide, fraîchement sorti de tes années d'apprentissage. " +
		"Ton maître t'a confié une marche dans le bois sacré de Brocéliande, seul, " +
		"sans carte précise — il te suffit d'écouter. " +
		"Tu portes une cape de lin écru, un couteau d'os à la ceinture, et une " +
		"intention claire : %s. " +
		"Tu sais que la forêt jaugera ton premier pas autant que ton dernier. " +
		"Tu inspires profondément, et tu poses le pied sur la mousse."
	) % chosen_title


func _parse_titles_with_oghams(raw: String, biome_id: String) -> Array:
	var lines: Array = []
	for ln in raw.split("\n", false):
		var s: String = (ln as String).strip_edges()
		# Strip leading numbering/bullets defensively.
		if s.length() > 2 and (s[0].is_valid_int() or s[0] == "-" or s[0] == "*"):
			var i: int = 1
			while i < s.length() and (s[i] == "." or s[i] == ")" or s[i] == " "):
				i += 1
			s = s.substr(i).strip_edges()
		# v7.7 (code-review MEDIUM fix #6) : reject overlong lines that signal
		# the LLM emitted a synopsis instead of a title. Silently dropped lines
		# cascade to _fallback_titles via the size<3 check below.
		if s != "" and s.length() <= MAX_TITLE_LENGTH:
			lines.append(s)
	if lines.size() < 3:
		return _fallback_titles(biome_id)
	var ogham_pool: Array = OGHAM_GLYPHS.duplicate()
	ogham_pool.shuffle()
	var out: Array = []
	for i in range(3):
		out.append({"title": str(lines[i]), "ogham": str(ogham_pool[i])})
	return out


func _fallback_titles(biome_id: String) -> Array:
	# Level-3 cascade : 3 hardcoded titles per biome (8 × 3 = 24 templates).
	var bank: Dictionary = {
		"foret_broceliande": ["La Voix de Brocéliande", "Le Chêne Brisé", "L'Ombre des Korrigans"],
		"landes_bruyere": ["Le Cairn Oublié", "Sous le Vent d'Ankou", "La Bruyère qui Saigne"],
		"cotes_sauvages": ["L'Appel des Falaises", "Naufrage Ancien", "La Grotte Bleue"],
		"villages_celtes": ["Le Conteur du Foyer", "La Veille des Anciens", "Le Feu qui Dure"],
		"cercles_pierres": ["L'Équinoxe Oublié", "Les Pierres qui Parlent", "Le Cercle Brisé"],
		"marais_korrigans": ["Le Marais des Mensonges", "Voix dans la Tourbière", "La Lumière qui Trompe"],
		"collines_dolmens": ["Sous le Dolmen", "L'Écho des Ancêtres", "La Colline qui Respire"],
		"iles_mystiques": ["L'Île de Niamh", "La Brume Éternelle", "Le Chant des Fées"],
	}
	var titles: Array = bank.get(biome_id, bank["foret_broceliande"])
	var ogham_pool: Array = OGHAM_GLYPHS.duplicate()
	ogham_pool.shuffle()
	var out: Array = []
	for i in range(3):
		out.append({"title": str(titles[i]), "ogham": str(ogham_pool[i])})
	return out


# ═════════ Phase 1.2 : Generate 5-beat skeleton ═══════════════════════════════

func generate_skeleton(biome_id: String, chosen_title: String) -> Dictionary:
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return _fallback_skeleton(biome_id, chosen_title)
	# v7.7.23 — RAG few-shot : retrieve 2 reference scenarios with similar
	# title+biome and inject their beat sequences as structural examples.
	var few_shot_block: String = await _rag_skeleton_few_shot(biome_id, chosen_title)
	var system_prompt: String = _skeleton_system_prompt(biome_id, chosen_title, few_shot_block)
	var user_input: String = "Génère le skeleton du scénario pour le titre choisi."
	var params: Dictionary = {
		"grammar": _gbnf_skeleton,
		"max_tokens": 500,
		"temperature": 0.8,
		"timeout_ms": int(SKELETON_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Skeleton LLM error : %s — falling back" % result.get("error"))
		return _fallback_skeleton(biome_id, chosen_title)
	var raw: String = str(result.get("text", result.get("output", "")))
	return _parse_skeleton(raw, biome_id, chosen_title)


## v7.7.23 — Retrieve 2 reference scenarios + format their beat sequences as
## structural few-shot. Returns empty string if RAG unavailable.
func _rag_skeleton_few_shot(biome_id: String, chosen_title: String) -> String:
	var rag: Node = _get_scenarios_rag()
	if rag == null:
		return ""
	var query: String = "%s · %s · structure narrative" % [chosen_title, biome_id]
	var matches: Array = await rag.query_similar(query, 2, "")
	if matches.is_empty():
		return ""
	var block: String = rag.format_skeleton_as_few_shot(matches, 5)
	return "\nExemples de structures de scénarios canoniques (style à suivre) :\n" + block


func _skeleton_system_prompt(biome_id: String, chosen_title: String, references_block: String = "") -> String:
	# v7.7 Phase 2.7 — chain-of-thought : LLM choisit 5/7/10 actes selon l'ambition.
	# v7.7.22 — Layer 1 enforcement : distribution targets nudge the LLM toward
	# balanced rarity / Pole / cardtype before _balance_skeleton validates.
	var biome_bias: Dictionary = BIOME_POLE_BIAS.get(biome_id, {"dominant": "Neutre", "secondary": []})
	var dominant_pole: String = str(biome_bias.get("dominant", "Neutre"))
	return ("Tu es le Gamemaster M.E.R.L.I.N..\n" +
		"Génère un SKELETON narratif au format JSON strict (GBNF imposé) pour le titre :\n" +
		"  \"%s\" (biome : %s)\n\n" +
		"ÉTAPE 1 (réflexion) : décide d'abord du nombre d'actes selon l'ambition du titre :\n" +
		"  - SIMPLE (5 actes) : intro mystique, une seule épreuve\n" +
		"  - CLASSIQUE (7 actes) : voyage complet, twist au milieu\n" +
		"  - ÉPIQUE (10 actes) : saga riche, multiples bifurcations\n\n" +
		"ÉTAPE 2 (écriture) : écris EXACTEMENT ce nombre de beats dans le JSON.\n\n" +
		"Structure : {title, beats:[N entries]}. Chaque beat = {n: 1..N, summary, faction_tilt, emotion}.\n" +
		"Arc émotionnel : beat 1=curiosite/intro, beats milieu=tension/peur/twist, beat N=résolution/sagesse.\n" +
		"faction_tilt ∈ {druides, anciens, korrigans, niamh, ankou, neutre}.\n" +
		"emotion ∈ {curiosite, tension, peur, espoir, sagesse, fascination, colere, melancolie, emerveillement}.\n" +
		"Summaries : 1 phrase 10-20 mots, narratif celtique évocateur.\n\n" +
		"%s\n" +
		"ÉQUILIBRAGE (v7.7.22) — biome '%s' dominant Pole = %s :\n" +
		"  - Privilégie faction_tilt aligné avec le Pole dominant (~50%% des beats).\n" +
		"  - Varie les emotions : pas 2 emotions identiques consécutives.\n" +
		"  - Le dernier beat doit être climactique (faction_tilt fort, emotion=sagesse/peur/emerveillement)."
	) % [chosen_title, biome_id, references_block, biome_id, dominant_pole]


## v7.7 Phase 2.7c — Parse skeleton + clamp beats to [5..10] :
##   - >10 beats : truncate to first 10
##   - <5 beats  : pad with fallback skeleton beats (matching biome)
##   - Renumber `n` field to 1..final-size
##   - Returns fallback skeleton if parse fails entirely
const MIN_BEATS := 5
const MAX_BEATS := 10

func _parse_skeleton(raw_text: String, biome_id: String, chosen_title: String) -> Dictionary:
	var trimmed: String = raw_text.strip_edges()
	if trimmed.begins_with("```"):
		var first_nl: int = trimmed.find("\n")
		if first_nl >= 0:
			trimmed = trimmed.substr(first_nl + 1)
		if trimmed.ends_with("```"):
			trimmed = trimmed.substr(0, trimmed.length() - 3)
	var json := JSON.new()
	var err: Error = json.parse(trimmed)
	if err != OK:
		push_warning("[ScenarioPlanner] Skeleton JSON parse error : %s — falling back" % json.get_error_message())
		return _fallback_skeleton(biome_id, chosen_title)
	var parsed = json.data
	if not (parsed is Dictionary):
		return _fallback_skeleton(biome_id, chosen_title)
	var dict: Dictionary = parsed as Dictionary
	var beats_any = dict.get("beats", [])
	if not (beats_any is Array):
		return _fallback_skeleton(biome_id, chosen_title)
	var beats: Array = beats_any as Array

	# v7.7 Phase 2.7c — clamp to [MIN_BEATS..MAX_BEATS].
	if beats.size() > MAX_BEATS:
		push_warning("[ScenarioPlanner] LLM emitted %d beats, truncating to %d" % [beats.size(), MAX_BEATS])
		beats = beats.slice(0, MAX_BEATS)
	elif beats.size() < MIN_BEATS:
		push_warning("[ScenarioPlanner] LLM emitted %d beats (<%d), padding from fallback" % [beats.size(), MIN_BEATS])
		var fallback: Dictionary = _fallback_skeleton(biome_id, chosen_title)
		var fb_beats: Array = fallback.get("beats", [])
		while beats.size() < MIN_BEATS and beats.size() < fb_beats.size():
			beats.append((fb_beats[beats.size()] as Dictionary).duplicate(true))
		# If even fallback is short (shouldn't happen — fallback is 5), fail to fallback.
		if beats.size() < MIN_BEATS:
			return fallback

	# Renumber `n` to 1..final-size (defensive : LLM may have emitted any values).
	for i in range(beats.size()):
		if beats[i] is Dictionary:
			(beats[i] as Dictionary)["n"] = i + 1

	dict["beats"] = beats
	# Override title to match user pick (in case LLM rewrote it).
	dict["title"] = chosen_title
	# v7.7.22 — Layer 2 enforcement : balance the rarity/Pole/cardtype distribution
	# regardless of whether the LLM populated those fields. Fills defaults + caps.
	return _balance_skeleton(dict, biome_id)


func _fallback_skeleton(biome_id: String, chosen_title: String) -> Dictionary:
	# v7.7 (code-review MEDIUM fix #4) : surface thematic mismatch when a biome
	# falls back to Brocéliande (Phase 2 will fill the 7 missing biomes).
	if not FALLBACK_SKELETONS.has(biome_id):
		push_warning("[ScenarioPlanner] No fallback skeleton for biome '%s' — using Brocéliande baseline. Phase 2 TODO." % biome_id)
	var base: Dictionary = FALLBACK_SKELETONS.get(biome_id, FALLBACK_SKELETONS["foret_broceliande"])
	var out: Dictionary = base.duplicate(true)
	out["title"] = chosen_title  # respect user choice
	# v7.7.22 — apply the balance pass to hardcoded fallbacks too so every code
	# path produces beats with rarity/Pole/cardtype metadata. Consumers can rely
	# on these fields being present even when the LLM is unavailable.
	return _balance_skeleton(out, biome_id)


# ═════════ v7.7.22 — Balance validator (Layer 2 enforcement) ════════════════════
#
# Post-LLM (and post-fallback) validator that ensures each beat has rarity / pole /
# card_type fields, and enforces the CARD_TYPE_CAPS / RARITY_TARGETS / BIOME_POLE_BIAS
# constraints. The LLM is nudged via the system prompt (Layer 1) ; this is the safety
# net (Layer 2). Strategy : assign defaults where missing → count → demote excess →
# promote shortfalls. Returns a NEW Dict (does not mutate the input).

static func _balance_skeleton(skeleton: Dictionary, biome_id: String) -> Dictionary:
	if not (skeleton is Dictionary):
		return skeleton
	var beats_any = skeleton.get("beats", [])
	if not (beats_any is Array):
		return skeleton
	var beats: Array = (beats_any as Array).duplicate(true)
	var total: int = beats.size()
	if total <= 0:
		return skeleton

	# 1. Assign defaults to missing fields (rarity / pole / card_type).
	# v7.7.22 reviewer MEDIUM fix : NORMALIZE case for any LLM-provided value.
	# The LLM may emit "legendaire" / "shop" / "ordre" in French/lowercase ; we
	# canonicalize to UPPER for enums (rarity/cardtype) and TitleCase for Pole.
	for i in range(total):
		var b: Dictionary = beats[i] as Dictionary
		var n: int = int(b.get("n", i + 1))
		# Card type — UPPER enum string ("NARRATIVE" / "EVENT" / "SHOP" / ...).
		var raw_ct: String = str(b.get("card_type", "")).to_upper().strip_edges()
		b["card_type"] = raw_ct if raw_ct != "" else _default_cardtype_for_beat(n, total)
		# Pole — TitleCase ("Ordre" / "Chaos" / "Liminal" / "Neutre").
		var raw_pole: String = str(b.get("pole", "")).strip_edges()
		if raw_pole != "":
			# Capitalize first letter to match POLE constants.
			raw_pole = raw_pole.substr(0, 1).to_upper() + raw_pole.substr(1).to_lower()
		b["pole"] = raw_pole if raw_pole != "" else _default_pole_for_beat(b, biome_id)
		# Rarity — UPPER enum string ("COMMUNE" / "RARE" / "EPIQUE" / "LEGENDAIRE").
		var raw_rarity: String = str(b.get("rarity", "")).to_upper().strip_edges()
		b["rarity"] = raw_rarity if raw_rarity != "" else _default_rarity_for_beat(n, total)
		beats[i] = b

	# 2. Enforce hard CAPS per cardtype (demote excess to NARRATIVE Commune).
	var counts: Dictionary = _count_card_types(beats)
	for ct in CARD_TYPE_CAPS.keys():
		var rules: Dictionary = CARD_TYPE_CAPS[ct]
		# Skip share-based rules in this loop (handled in step 4).
		if not rules.has("max_count"):
			continue
		var max_cnt: int = int(rules.get("max_count", 99))
		var have: int = int(counts.get(ct, 0))
		if have > max_cnt:
			# Demote the LAST few beats of this type to NARRATIVE Commune.
			# v7.7.22 reviewer HIGH fix : NEVER demote the climax (index total-1) —
			# `_default_cardtype_for_beat` forces it to MERLIN_DIRECT/boss, and
			# step 4 only handles rarity, not card_type. Skipping it here keeps the
			# climax intact even when LLM emits >max_count beats of the same type.
			var excess: int = have - max_cnt
			for j in range(beats.size() - 1, -1, -1):
				if excess <= 0:
					break
				if j == total - 1:
					continue   # preserve climax
				var bj: Dictionary = beats[j]
				if str(bj.get("card_type", "")) == ct:
					bj["card_type"] = "NARRATIVE"
					bj["rarity"] = "COMMUNE"
					beats[j] = bj
					excess -= 1
			counts = _count_card_types(beats)

	# 3. Enforce ADJACENCY (no 2 NO_REPEAT_CARDTYPES in a row).
	for i in range(1, beats.size()):
		var prev_ct: String = str((beats[i - 1] as Dictionary).get("card_type", ""))
		var curr_ct: String = str((beats[i] as Dictionary).get("card_type", ""))
		if prev_ct == curr_ct and NO_REPEAT_CARDTYPES.has(curr_ct):
			# Demote the current to NARRATIVE Commune to break the streak.
			var bi: Dictionary = beats[i]
			bi["card_type"] = "NARRATIVE"
			bi["rarity"] = "COMMUNE"
			beats[i] = bi

	# 4. Enforce LEGENDARY placement (only in last 30% of skeleton).
	var legendary_threshold: int = int(ceil(float(total) * LEGENDARY_START_SHARE))
	for i in range(total):
		var bi: Dictionary = beats[i]
		if str(bi.get("rarity", "")) == "LEGENDAIRE" and (i + 1) < legendary_threshold:
			bi["rarity"] = "EPIQUE"   # demote to next-tier
			beats[i] = bi

	# 5. Soft MINIMUMS — promote NARRATIVE COMMUNE beats if a required type is missing.
	counts = _count_card_types(beats)
	for ct in CARD_TYPE_CAPS.keys():
		var rules2: Dictionary = CARD_TYPE_CAPS[ct]
		if not rules2.has("min_count"):
			continue
		var min_cnt: int = int(rules2.get("min_count", 0))
		var have2: int = int(counts.get(ct, 0))
		if have2 < min_cnt and ct != "NARRATIVE":
			# Promote middle-of-skeleton NARRATIVE beats to this cardtype.
			var need: int = min_cnt - have2
			for j in range(beats.size()):
				if need <= 0:
					break
				var bj2: Dictionary = beats[j]
				# Don't touch first (intro) or last (climax) beat.
				if j == 0 or j == total - 1:
					continue
				if str(bj2.get("card_type", "")) == "NARRATIVE" and str(bj2.get("rarity", "")) == "COMMUNE":
					bj2["card_type"] = ct
					# EVENT/SHOP get RARE, others stay COMMUNE.
					if ct == "EVENT" or ct == "SHOP":
						bj2["rarity"] = "RARE"
					beats[j] = bj2
					need -= 1

	# 6. Write back + log a one-line summary for debug.
	# v7.7.22 reviewer MEDIUM fix : push_warning (matches file convention) +
	# debug-build guard so prod exports don't spam the log.
	counts = _count_card_types(beats)
	if OS.is_debug_build():
		var summary_parts: Array = []
		for ct in ["NARRATIVE", "EVENT", "SHOP", "MERLIN_DIRECT", "PROMISE", "RUNE_UNLOCK"]:
			if int(counts.get(ct, 0)) > 0:
				summary_parts.append("%s=%d" % [ct, int(counts.get(ct, 0))])
		push_warning("[ScenarioPlanner] v7.7.22 balance for biome '%s' (n=%d): %s" % [
			biome_id, total, ", ".join(summary_parts)
		])

	var out: Dictionary = skeleton.duplicate(true)
	out["beats"] = beats
	return out


## Returns a Dict<card_type_name: String, count: int> for the beats array.
static func _count_card_types(beats: Array) -> Dictionary:
	var counts: Dictionary = {}
	for b in beats:
		if not (b is Dictionary):
			continue
		var ct: String = str((b as Dictionary).get("card_type", ""))
		if ct == "":
			continue
		counts[ct] = int(counts.get(ct, 0)) + 1
	return counts


## Default CardType for a beat at position (n, total) using BEAT_ACT_SEQUENCE +
## last-beat-is-boss invariant. Returns DigitalPickerCard.CardType string keys.
static func _default_cardtype_for_beat(beat_n: int, total: int) -> String:
	var act: String = _beat_to_act_type(beat_n, total)
	return str(ACT_TYPE_TO_CARDTYPE.get(act, "NARRATIVE"))


## Default Pole for a beat — uses beat's `faction_tilt` if present, else biome bias.
static func _default_pole_for_beat(beat: Dictionary, biome_id: String) -> String:
	var faction: String = str(beat.get("faction_tilt", ""))
	if faction != "" and FACTION_TO_POLE_PLANNER.has(faction):
		return str(FACTION_TO_POLE_PLANNER[faction])
	# No faction info — fall back to biome dominant Pole.
	var bias: Dictionary = BIOME_POLE_BIAS.get(biome_id, {"dominant": "Neutre"})
	return str(bias.get("dominant", "Neutre"))


## Default Rarity for a beat at position (n, total) following bible §28.1 ratios.
## Last beat = LEGENDAIRE (climax) ; penultimate = EPIQUE ; first beat = COMMUNE
## (intro should be calm) ; middle = mostly COMMUNE with occasional RARE.
static func _default_rarity_for_beat(beat_n: int, total: int) -> String:
	if total <= 0:
		return "COMMUNE"
	if beat_n == total:
		return "LEGENDAIRE"   # climax always Légendaire
	if beat_n == total - 1:
		return "EPIQUE"        # penultimate twist
	if beat_n == 1:
		return "COMMUNE"       # intro stays calm
	# Middle beats : ~70% COMMUNE, ~30% RARE (deterministic via beat_n parity).
	return "RARE" if (beat_n % 3) == 0 else "COMMUNE"


# ═════════ Phase 1.3 : Per-beat card generation (delegates to BiBrainPipeline) ═

## Generate the card for beat[beat_idx] using the skeleton context + player state.
## v7.7 Phase 2.3 : passes the full beat Dict (faction_tilt + emotion + summary)
## as beat_context to BiBrainPipeline → GM + Narrator system prompts inject it.
func generate_card_for_beat(skeleton: Dictionary, beat_idx: int, player_state: Dictionary) -> Dictionary:
	if _bi_brain == null:
		return {}
	var beats: Array = skeleton.get("beats", [])
	if beat_idx < 0 or beat_idx >= beats.size():
		return {}
	var beat: Dictionary = beats[beat_idx]
	# v7.7 Phase 2.7 — pass total count so last beat is always "boss" regardless
	# of skeleton size (5/7/10). Without this, 5-beat skeletons would have a
	# "standard" final beat instead of climactic boss.
	var act_type: String = _beat_to_act_type(int(beat.get("n", beat_idx + 1)), beats.size())
	var ogham_used: String = str(player_state.get("active_ogham", ""))
	var biome_id: String = str(player_state.get("biome", "foret_broceliande"))
	return await _bi_brain.generate_card(biome_id, act_type, ogham_used, beat)


static func _beat_to_act_type(beat_n: int, total: int = 5) -> String:
	# v7.7 (code-review MEDIUM fix #3 + Phase 2.7) : driven from BEAT_ACT_SEQUENCE
	# const + last-beat-always-boss invariant for variable-size skeletons (5..10).
	# Without the invariant, 5-beat skeletons would have a "standard" final beat
	# instead of climactic boss. The const remains the source of truth for the
	# middle beats; only the last index is forced to "boss".
	if total > 0 and beat_n == total:
		return "boss"
	var idx: int = beat_n - 1
	if idx < 0 or idx >= BEAT_ACT_SEQUENCE.size():
		return "standard"
	return str(BEAT_ACT_SEQUENCE[idx])


# ═════════ Phase 2 stubs : judge + replan (TODO) ══════════════════════════════

## v7.7 Phase 2.4 — LLM-judge primary + heuristic fallback.
## Hybrid : if MerlinAI available → mini LLM call (~1-2s, gemma4:e4b via narrator path; qwen3.5:2b legacy).
## Else → heuristic comparison of dominant faction in player_choice.effects vs beat.faction_tilt.
## Returns true if the player diverged from the expected arc (caller should replan).
##
## Conservative defaults : returns false on any error or ambiguous signal.
## "neutre" beats never count as diverged (any choice is on-arc).
func judge_divergence(skeleton: Dictionary, beat_idx: int,
		_last_card: Dictionary, player_choice: Dictionary) -> bool:
	var beats: Array = skeleton.get("beats", [])
	if not (beats is Array) or beat_idx < 0 or beat_idx >= beats.size():
		return false
	var beat: Dictionary = beats[beat_idx]
	var expected_tilt: String = str(beat.get("faction_tilt", "neutre"))
	# Neutral beats accept anything — no divergence possible.
	if expected_tilt == "neutre":
		return false

	# Step 1 : extract dominant faction signal from player's choice effects.
	var effects: Array = player_choice.get("effects", [])
	var actual_dominant: String = _extract_dominant_faction_from_effects(effects)
	# If no faction signal at all, heuristic = no divergence.
	if actual_dominant == "":
		return false

	# Step 2 : LLM-judge if available, heuristic otherwise.
	if _merlin_ai != null and _merlin_ai.has_method("generate_with_system"):
		return await _llm_judge_divergence(expected_tilt, actual_dominant,
			str(beat.get("emotion", "")), player_choice)
	# Heuristic fallback : direct comparison.
	return actual_dominant != expected_tilt


static func _extract_dominant_faction_from_effects(effects: Array) -> String:
	# Sum ADD_REPUTATION amounts per faction, return the faction the player
	# STRENGTHENED the most (max POSITIVE signed delta). Ignores HEAL/DAMAGE/ANAM.
	#
	# v7.7 code-review HIGH fix (commit 8dbbe1cc) : was `abs(int)` which incorrectly
	# returned the BURNED faction as "dominant" when the player penalized it.
	# Example pre-fix : card with [-10 druides, +5 ankou] → returned "druides"
	# (|-10|=10 > 5). Judge compared "druides" == expected_tilt="druides" → false
	# divergence. WRONG : the player actively chose against the druide arc.
	# Post-fix : returns "ankou" (the faction the player actually strengthened).
	# If no faction has a positive net delta, returns "" → judge defaults to no
	# divergence (conservative — the player only burned factions, no alignment signal).
	var deltas: Dictionary = {}
	for e in effects:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e as Dictionary
		if str(ed.get("type", "")) != "ADD_REPUTATION":
			continue
		var fac: String = str(ed.get("faction", ""))
		if fac == "":
			continue
		var amt: int = int(ed.get("amount", 0))
		deltas[fac] = int(deltas.get(fac, 0)) + amt
	if deltas.is_empty():
		return ""
	var best: String = ""
	var best_signed: int = 0  # only positive deltas qualify as "strengthened"
	for fac in deltas.keys():
		var v: int = int(deltas[fac])
		if v > best_signed:
			best_signed = v
			best = str(fac)
	return best


func _llm_judge_divergence(expected_tilt: String, actual_dominant: String,
		expected_emotion: String, player_choice: Dictionary) -> bool:
	var label: String = str(player_choice.get("label", "?"))
	var system_prompt: String = ("Tu juges si le choix du joueur a dévié de l'arc narratif attendu.\n" +
		"Beat attendu : faction_tilt=%s, emotion=%s\n" +
		"Joueur a fait : \"%s\" → faction dominante du choix=%s\n" +
		"Le joueur a-t-il DÉVIÉ ? Réponds UNIQUEMENT par OUI ou NON. Pas d'explication."
	) % [expected_tilt, expected_emotion, label, actual_dominant]
	var params: Dictionary = {
		"max_tokens": 8,
		"temperature": 0.1,  # déterministe pour décision binaire
		"timeout_ms": int(JUDGE_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, "Réponds.", params)
	if result.get("error", "") != "":
		# LLM fail → fallback heuristic.
		# Heuristic semantics (intentional) : ANY faction mismatch counts as
		# divergence. The 5 factions are independent axes (bible §13) — there
		# are no "family groups" of aligned factions, so cross-faction = divergent.
		return actual_dominant != expected_tilt
	var raw: String = str(result.get("text", result.get("output", ""))).strip_edges().to_lower()
	# Look for explicit OUI / YES tokens. Default to false (conservative).
	if raw.begins_with("oui") or raw.begins_with("yes"):
		return true
	if raw.begins_with("non") or raw.begins_with("no"):
		return false
	# Ambiguous response → fall back to heuristic.
	return actual_dominant != expected_tilt


## v7.7 Phase 2.5 — Re-plan beats[from_beat..4] given player divergence.
## Preserves beats[0..from_beat-1] (already played), regenerates the remainder
## via LLM with context = preserved beats + player_state (faction_rep + life).
## Falls back to the original skeleton on any failure (graceful).
##
## from_beat is 0-indexed in the `beats` array (NOT the 1-indexed `n` field).
func replan_from_beat(skeleton: Dictionary, from_beat: int,
		player_state: Dictionary) -> Dictionary:
	# Guard rails.
	# v7.7 Phase 2.7 : accept variable-size skeletons [MIN_BEATS..MAX_BEATS].
	var beats: Array = skeleton.get("beats", [])
	if not (beats is Array) or beats.size() < MIN_BEATS or beats.size() > MAX_BEATS:
		return skeleton
	if from_beat <= 0 or from_beat >= beats.size():
		# from_beat==0 means "regenerate from start" → equivalent to a fresh skeleton.
		# from_beat>=size means nothing to replan (last beat or beyond).
		return skeleton
	if _merlin_ai == null or not _merlin_ai.has_method("generate_with_system"):
		return skeleton

	# Build the divergence-aware system prompt.
	var preserved: Array = beats.slice(0, from_beat)
	var biome_id: String = str(player_state.get("biome", "foret_broceliande"))
	var chosen_title: String = str(skeleton.get("title", "L'Aventure"))
	var system_prompt: String = _replan_system_prompt(
		biome_id, chosen_title, preserved, player_state, beats.size()
	)
	var user_input: String = "Régénère le skeleton avec les nouveaux beats post-divergence."
	var params: Dictionary = {
		"grammar": _gbnf_skeleton,
		"max_tokens": 500,
		"temperature": 0.85,
		"timeout_ms": int(SKELETON_TIMEOUT_S * 1000),
	}
	var result: Dictionary = await _merlin_ai.generate_with_system(system_prompt, user_input, params)
	if result.get("error", "") != "":
		push_warning("[ScenarioPlanner] Replan LLM error : %s — keeping original skeleton" % result.get("error"))
		return skeleton
	var raw: String = str(result.get("text", result.get("output", "")))
	var fresh: Dictionary = _parse_skeleton(raw, biome_id, chosen_title)
	var fresh_beats: Array = fresh.get("beats", [])
	# v7.7 Phase 2.7 : accept variable fresh size [MIN_BEATS..MAX_BEATS].
	if not (fresh_beats is Array) or fresh_beats.size() < MIN_BEATS or fresh_beats.size() > MAX_BEATS:
		return skeleton

	# Splice : preserve [0..from_beat-1] + take fresh [from_beat..end].
	# Final size matches original skeleton size (we don't shrink/grow mid-run).
	var target_size: int = beats.size()
	var out_beats: Array = []
	for i in range(from_beat):
		out_beats.append(beats[i])
	for j in range(from_beat, target_size):
		# Take from fresh_beats if available, else preserve original beat
		# (graceful : LLM may have emitted fewer beats than target).
		if j < fresh_beats.size():
			out_beats.append(fresh_beats[j])
		else:
			out_beats.append(beats[j])
	# Renumber n to stay 1..size in case LLM emitted different n values.
	for k in range(out_beats.size()):
		(out_beats[k] as Dictionary)["n"] = k + 1

	var out: Dictionary = skeleton.duplicate(true)
	out["beats"] = out_beats
	return out


func _replan_system_prompt(biome_id: String, chosen_title: String,
		preserved_beats: Array, player_state: Dictionary, target_size: int = 5) -> String:
	# v7.7 Phase 2.7 / code-review MEDIUM fix : target_size is the original skeleton
	# size (5/7/10) — was hardcoded "5 beats" which truncated 7/10-beat skeletons.
	var faction_rep: Dictionary = player_state.get("faction_rep", {})
	var life: int = int(player_state.get("life_essence", 100))
	var rep_lines: Array = []
	for fac in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		var v: int = int(faction_rep.get(fac, 0))
		if v != 0:
			rep_lines.append("  - %s: %+d" % [fac, v])
	var preserved_summary: Array = []
	for b in preserved_beats:
		if b is Dictionary:
			preserved_summary.append("  - beat %d (%s) : %s" % [
				int(b.get("n", 0)), str(b.get("faction_tilt", "?")), str(b.get("summary", ""))
			])
	return ("Tu es le Gamemaster M.E.R.L.I.N.. Le joueur a DIVERGÉ de l'arc initial.\n" +
		"Tu régénères le skeleton complet (%d beats au total) en PRÉSERVANT les beats déjà vécus.\n" +
		"Format JSON strict imposé par GBNF.\n\n" +
		"Titre : \"%s\" (biome : %s)\n" +
		"Vie joueur actuelle : %d/100\n" +
		"Réputations factions :\n%s\n\n" +
		"Beats déjà vécus (REPRENDS-LES TELS QUELS dans la sortie) :\n%s\n\n" +
		"Les beats restants doivent réagir à la trajectoire actuelle du joueur."
	) % [target_size, chosen_title, biome_id, life,
		"\n".join(rep_lines) if not rep_lines.is_empty() else "  (aucune)",
		"\n".join(preserved_summary)]
