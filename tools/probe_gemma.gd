extends SceneTree
## Probe de dérisquage (R94 #1 = perf E2B) — headless, hors jeu.
## Charge Gemma 4 E2B nativement, fait 1 génération créative + 1 génération GBNF (situation),
## imprime le texte + les temps réels, puis quitte. Lancer :
##   Godot --headless --script res://tools/probe_gemma.gd

const MODEL := "res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf"

const SITUATION_GBNF := """
root ::= "{" ws "\\"narration\\":" ws string "," ws "\\"required_tags\\":" ws tags "," ws "\\"difficulte\\":" ws diff "," ws "\\"type\\":" ws type ws "}"
tags ::= "[" ws string (ws "," ws string)* ws "]"
diff ::= "1" | "2" | "3"
type ::= "\\"Rencontre\\"" | "\\"Epreuve\\"" | "\\"Exploration\\"" | "\\"Dilemme\\"" | "\\"Climax\\""
string ::= "\\"" ([^"\\\\] | "\\\\" .)* "\\""
ws ::= [ \\t\\n]*
"""

func _init() -> void:
	var llm: Object = ClassDB.instantiate("MerlinLLM")
	if llm == null:
		print("PROBE FAIL: MerlinLLM introuvable")
		quit()
		return
	llm.set_context_size(4096)
	var t0: int = Time.get_ticks_msec()
	var err: int = llm.load_model(ProjectSettings.globalize_path(MODEL))
	print("[PROBE] LOAD err=%d in %d ms" % [err, Time.get_ticks_msec() - t0])
	if err != OK:
		quit()
		return

	# --- Test A : grammaire triviale (isole si TOUT GBNF casse) ---
	llm.set_sampling_params(0.45, 0.9, 8)
	llm.set_advanced_sampling(40, 1.1)
	llm.set_grammar("root ::= \"OUI\" | \"NON\"", "root")
	_run(llm, "<start_of_turn>user\nReponds seulement OUI ou NON : la foret est-elle vivante ?<end_of_turn>\n<start_of_turn>model\n", "GBNF_TRIVIAL")

	# --- Test B : grammaire situation depuis fichier ---
	var gbnf: String = FileAccess.get_file_as_string("res://data/ai/situation.gbnf")
	print("[PROBE] grammar loaded %d chars" % gbnf.length())
	llm.set_sampling_params(0.45, 0.9, 160)
	llm.set_advanced_sampling(40, 1.1)
	llm.set_grammar(gbnf, "root")
	var p2: String = "<start_of_turn>user\nTu es Merlin. Genere UNE situation (type Exploration, difficulte 1) en JSON. narration en francais 2 phrases. required_tags depuis: Sens, Mystere, Nature, Ruse.<end_of_turn>\n<start_of_turn>model\n"
	_run(llm, p2, "GBNF_SITUATION")

	print("[PROBE] DONE")
	quit()


func _run(llm: Object, prompt: String, label: String) -> void:
	var done: Array = [false]
	var out: Array = [""]
	var tg0: int = Time.get_ticks_msec()
	llm.generate_async(prompt, func(res: Dictionary) -> void:
		out[0] = res.get("text", "[error] " + str(res.get("error", "?")))
		done[0] = true)
	var guard: int = 0
	while not done[0] and guard < 2400:  # ~120s max @50ms
		llm.poll_result()
		OS.delay_msec(50)
		guard += 1
	var dt: int = Time.get_ticks_msec() - tg0
	var txt: String = str(out[0])
	var ntok: int = int(txt.length() / 4.0)
	var tps: float = (float(ntok) * 1000.0 / float(dt)) if dt > 0 else 0.0
	print("[PROBE] %s : %d ms | ~%d tok | ~%.1f tok/s\n----\n%s\n----" % [label, dt, ntok, tps, txt])
