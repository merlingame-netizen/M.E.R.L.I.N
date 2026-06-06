extends SceneTree
## Test INSTANTANÉ (zéro LLM) de la LONGUEUR VARIABLE des fallbacks procéduraux (user 2026-06-06).
## Vérifie que fallback_resolution sert COURT en routine et LONG aux moments forts (Climax / éclatante).
##   "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" --headless --path . --script res://tools/probe_fallback_len.gd
## Sortie : C:/Users/PGNK2128/Downloads/merlin_fallback_len.json (mesurable, pas de timeout possible).

const OUT := "C:/Users/PGNK2128/Downloads/merlin_fallback_len.json"


func _init() -> void:
	_run()


func _await_node(path: String, max_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	var n: Node = root.get_node_or_null(path)
	while n == null and (Time.get_ticks_msec() - t0) < max_ms:
		await create_timer(0.05).timeout
		n = root.get_node_or_null(path)
	return n


func _run() -> void:
	var sc: Node = await _await_node("MerlinScenario", 8000)
	if sc == null:
		quit()
		return
	var cases: Array = [
		{"label": "routine Exploration reussite", "type": "Exploration", "degree": "reussite"},
		{"label": "routine Rencontre partiel", "type": "Rencontre", "degree": "partiel"},
		{"label": "FORT Climax reussite", "type": "Climax", "degree": "reussite"},
		{"label": "FORT Dilemme eclatante", "type": "Dilemme", "degree": "eclatante"},
	]
	var out: Dictionary = {"results": []}
	for tc in cases:
		var lens: Array = []
		var sample: String = ""
		for i in 6:
			var s: String = sc.fallback_resolution(str(tc["degree"]), str(tc["type"]))
			lens.append(s.length())
			sample = s
		out["results"].append({
			"label": tc["label"],
			"type": tc["type"],
			"degree": tc["degree"],
			"strong_moment": sc.is_strong_moment(str(tc["type"]), str(tc["degree"])),
			"char_len_samples": lens,
			"sample": sample,
		})
	var f: FileAccess = FileAccess.open(OUT, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("[FALLBACK_LEN] DONE -> %s" % OUT)
	quit()
