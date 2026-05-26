extends SceneTree
## Probe Gemma — vérifie le chemin de PRODUCTION (post-fixes v9.1) :
## nouveau prompt narrateur (sans apostrophe) + sanitize tokens template.
## Imprime brut vs nettoyé pour prouver que les bugs playtest sont réglés.
##   Godot --headless --script res://tools/probe_gemma.gd

const MODEL := "res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf"
const SYS := "Tu es le narrateur de la foret de Broceliande (legende celtique). REGLES: ecris en francais, ton merveilleux-inquietant, bref (2 phrases). Raconte la SCENE et l'EFFET des actes en recit direct. N'APOSTROPHE JAMAIS le joueur: INTERDIT 'Ah voyageur', 'voyageur', 'mon ami'. Pas de 4e mur. Pas d'anglicismes."
const STOP := ["<start_of_turn", "</start_of_turn", "<end_of_turn", "</end_of_turn", "<turn|", "<|turn", "<|im_", "<eos", "<bos", "<pad", "<unk", "<0x"]

func _init() -> void:
	var llm: Object = ClassDB.instantiate("MerlinLLM")
	llm.set_context_size(2048)
	var t0: int = Time.get_ticks_msec()
	var err: int = llm.load_model(ProjectSettings.globalize_path(MODEL))
	print("[PROBE] LOAD err=%d in %d ms" % [err, Time.get_ticks_msec() - t0])
	if err != OK:
		quit()
		return
	llm.set_sampling_params(0.85, 0.9, 90)
	llm.set_advanced_sampling(40, 1.1)
	llm.clear_grammar()
	var prompt: String = "<start_of_turn>user\n%s\n\nDecris UNE scene (type Rencontre) a Broceliande: 2 phrases, recit direct SANS apostropher le joueur. Fais sentir, sans les lister: Empathie, Verbe.<end_of_turn>\n<start_of_turn>model\n" % SYS
	_run(llm, prompt)
	print("[PROBE] DONE")
	quit()


func _run(llm: Object, prompt: String) -> void:
	var done: Array = [false]
	var out: Array = [""]
	var tg0: int = Time.get_ticks_msec()
	llm.generate_async(prompt, func(res: Dictionary) -> void:
		out[0] = res.get("text", "[error] " + str(res.get("error", "?")))
		done[0] = true)
	var guard: int = 0
	while not done[0] and guard < 2400:
		llm.poll_result()
		OS.delay_msec(50)
		guard += 1
	var raw: String = str(out[0])
	var clean: String = _sanitize(raw)
	print("[PROBE] %d ms" % (Time.get_ticks_msec() - tg0))
	print("[PROBE] RAW  : %s" % raw)
	print("[PROBE] CLEAN: %s" % clean)
	print("[PROBE] dit 'voyageur' ? %s | contient '<...turn' ? %s" % [
		str(clean.to_lower().contains("voyageur")), str(clean.contains("turn|") or clean.contains("_of_turn"))])


func _sanitize(t: String) -> String:
	var s: String = t
	var cut: int = -1
	for m in STOP:
		var idx: int = s.find(m)
		if idx != -1 and (cut == -1 or idx < cut):
			cut = idx
	if cut != -1:
		s = s.substr(0, cut)
	for tok in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>", "<pad>", "<unk>"]:
		s = s.replace(tok, "")
	return s.strip_edges()
