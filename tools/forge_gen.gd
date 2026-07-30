extends SceneTree
## forge_gen.gd - Runner headless GENERIQUE pour la forge de scenarios (BIBLE §25, W4).
## Execute une liste de jobs de generation sur le Gemma NATIF du jeu et ecrit les
## resultats de facon INCREMENTALE (un batch interrompu garde ses pieces payees).
##
##   godot --headless --path . --script res://tools/forge_gen.gd -- --jobs <in.json> --out <out.json>
##
## POURQUOI la GDExtension MerlinLLM est pilotee EN DIRECT (et pas via l'autoload
## MerlinNative) : MerlinNative._boot() attend `RenderingServer.frame_post_draw` avant
## de charger le modele ; en --headless ce signal ne tombe JAMAIS -> is_ready() reste
## false a perpetuite (mesure : timeout 120 s, zero erreur). Ce runner replique donc a
## l'IDENTIQUE les constantes et la sequence de MerlinNative (merlin_native.gd) :
## meme GGUF, n_ctx 2048, temp creative 0.85 / structured 0.45, top_p 0.9, top_k 40,
## repeat 1.1, timeout 90 s, template de chat gemma, troncature aux STOP_MARKERS.
## La mesure vaut donc pour le moteur du jeu. Si merlin_native.gd change ses
## constantes, reporter ici (drift verifiable par diff des constantes).
##
## Format d'entree  : {"jobs": [{"id", "system", "user", "max_tokens", "creative"}]}
## Format de sortie : {"model": {...}, "results": {id: {text, ms, tok_per_s,
##                     approx_tokens, error}}}

const MODEL_PATH: String = "res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf"
const N_CTX: int = 2048
const TEMP_CREATIVE: float = 0.85
const TEMP_STRUCTURED: float = 0.45
const TOP_P: float = 0.9
const TOP_K: int = 40
const REPEAT_PENALTY: float = 1.1
const GEN_TIMEOUT_MS: int = 90000
const STOP_MARKERS: Array = [
	"<start_of_turn", "</start_of_turn", "<end_of_turn", "</end_of_turn",
	"<turn|", "<|turn", "<|im_", "<eos", "<bos", "<pad", "<unk", "<0x",
]

var _llm: Object = null
var _result_ready: bool = false
var _pending_result: Dictionary = {}


func _init() -> void:
	_run()


func _arg(args: PackedStringArray, key: String) -> String:
	var idx: int = args.find(key)
	if idx != -1 and idx + 1 < args.size():
		return args[idx + 1]
	return ""


func _run() -> void:
	var uargs: PackedStringArray = OS.get_cmdline_user_args()
	var jobs_path: String = _arg(uargs, "--jobs")
	var out_path: String = _arg(uargs, "--out")
	if jobs_path == "" or out_path == "":
		print("[FORGE] usage: -- --jobs <in.json> --out <out.json>")
		quit(2)
		return

	var jf: FileAccess = FileAccess.open(jobs_path, FileAccess.READ)
	if jf == null:
		print("[FORGE] jobs introuvable: %s" % jobs_path)
		quit(2)
		return
	var parsed: Variant = JSON.parse_string(jf.get_as_text())
	jf.close()
	if not (parsed is Dictionary) or not (parsed as Dictionary).has("jobs"):
		print("[FORGE] jobs JSON invalide")
		quit(2)
		return
	var jobs: Array = (parsed as Dictionary)["jobs"]

	if not ClassDB.class_exists("MerlinLLM"):
		print("[FORGE] GDExtension MerlinLLM absente")
		quit(3)
		return
	_llm = ClassDB.instantiate("MerlinLLM")
	if _llm == null:
		print("[FORGE] instanciation MerlinLLM echouee")
		quit(3)
		return
	_llm.set_context_size(N_CTX)
	var model_path: String = ProjectSettings.globalize_path(MODEL_PATH)
	var t0: int = Time.get_ticks_msec()
	var err: int = _llm.load_model(model_path)
	if err != OK:
		print("[FORGE] load_model err=%d path=%s" % [err, model_path])
		quit(3)
		return
	print("[FORGE] modele charge en %d ms : %s" % [Time.get_ticks_msec() - t0, model_path])

	var out: Dictionary = {"model": _llm.get_model_info(), "results": {}}
	for j in jobs:
		var jd: Dictionary = j
		var jid: String = str(jd.get("id", ""))
		var entry: Dictionary = await _generate_one(jd)
		(out["results"] as Dictionary)[jid] = entry
		_write(out_path, out)  # incremental : jamais perdre une piece deja payee
		print("[FORGE] %s : %d chars, %d ms, %.2f tok/s%s" % [
			jid, str(entry["text"]).length(), int(entry["ms"]), float(entry["tok_per_s"]),
			("" if str(entry["error"]) == "" else " ERROR=" + str(entry["error"])),
		])
	print("[FORGE] DONE %d jobs -> %s" % [jobs.size(), out_path])
	quit(0)


## Une generation : template de chat gemma + sampling du regime + polling borne 90 s.
## Sequence identique a MerlinNative.generate_raw (auto-polling chaque frame).
func _generate_one(jd: Dictionary) -> Dictionary:
	var creative: bool = bool(jd.get("creative", true))
	var max_tokens: int = int(jd.get("max_tokens", 120))
	var temp: float = TEMP_CREATIVE if creative else TEMP_STRUCTURED
	_llm.set_sampling_params(temp, TOP_P, max_tokens)
	_llm.set_advanced_sampling(TOP_K, REPEAT_PENALTY)
	_llm.clear_grammar()
	var prompt: String = "<start_of_turn>user\n%s\n\n%s<end_of_turn>\n<start_of_turn>model\n" % [
		str(jd.get("system", "")), str(jd.get("user", ""))]
	_result_ready = false
	_pending_result = {}
	var t1: int = Time.get_ticks_msec()
	_llm.generate_async(prompt, Callable(self, "_on_result"))
	while not _result_ready:
		_llm.poll_result()
		if Time.get_ticks_msec() - t1 > GEN_TIMEOUT_MS:
			_llm.cancel_generation()
			# drain borne : laisse le thread d'inference rendre la main proprement
			var dl: int = Time.get_ticks_msec() + 3000
			while not _result_ready and Time.get_ticks_msec() < dl:
				_llm.poll_result()
				await create_timer(0.05).timeout
			break
		await create_timer(0.02).timeout
	var ms: int = Time.get_ticks_msec() - t1
	var txt: String = ""
	var err_msg: String = ""
	if _result_ready:
		txt = _sanitize(str(_pending_result.get("text", "")))
		err_msg = str(_pending_result.get("error", ""))
	else:
		err_msg = "timeout %d ms" % GEN_TIMEOUT_MS
	var approx_tokens: int = int(txt.length() / 4.0)
	var tok_per_s: float = 0.0
	if ms > 0:
		tok_per_s = float(approx_tokens) * 1000.0 / float(ms)
	return {"text": txt, "error": err_msg, "ms": ms,
			"tok_per_s": tok_per_s, "approx_tokens": approx_tokens}


func _on_result(result: Dictionary) -> void:
	_pending_result = result
	_result_ready = true


## Copie de MerlinNative._sanitize : troncature au 1er marqueur + strip des residus.
func _sanitize(t: String) -> String:
	var s: String = t
	var cut: int = -1
	for m in STOP_MARKERS:
		var idx: int = s.find(m)
		if idx != -1 and (cut == -1 or idx < cut):
			cut = idx
	if cut != -1:
		s = s.substr(0, cut)
	for tok in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>", "<pad>", "<unk>"]:
		s = s.replace(tok, "")
	return s.strip_edges()


func _write(path: String, out: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, " "))
		f.close()
	else:
		print("[FORGE] ERREUR ecriture %s (err %d)" % [path, FileAccess.get_open_error()])
