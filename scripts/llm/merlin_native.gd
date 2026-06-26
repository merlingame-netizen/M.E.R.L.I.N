extends Node
## MerlinNative — adaptateur autoload autour de la GDExtension native MerlinLLM (Gemma 4 E2B).
## 100% local, ZÉRO Ollama. API vérifiée : native/src/merlin_llm.cpp / merlin_llm.h.
##
## Pattern d'usage :
##   if MerlinNative.is_ready():
##       var res: Dictionary = await MerlinNative.generate(system_text, user_text, {"creative": true, "max_tokens": 250})
##       if res.has("error"): ... else: var txt: String = res["text"]
##
## Le natif ne streame PAS token-par-token : le texte complet arrive d'un coup
## (R57/R63 : streaming = ajout C++ futur). Le typewriter se fait côté GDScript.

signal model_ready()
signal model_failed(reason: String)
signal generation_finished(result: Dictionary)

const MODEL_E2B: String = "res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf"
# n_ctx 2048 (et NON 4096 R58) : perf-driven. Le C++ note un speedup 3-4x + KV cache /2
# vs gros ctx, et les prompts MVP (system + résumé + situation) tiennent largement dans 2048.
# Critique sur cette machine (RAM libre faible) pour éviter le swap → générations lentes.
const N_CTX: int = 2048

# Régimes de sampling (R59)
const TEMP_CREATIVE: float = 0.85
const TEMP_STRUCTURED: float = 0.45
const TOP_P: float = 0.9
const TOP_K: int = 40
const REPEAT_PENALTY: float = 1.1

# Timeout d'une génération (auto-polling). Le modèle est lent (~3 tok/s) → 90s couvre une longue
# génération ; au-delà = blocage présumé → on annule pour ne pas figer (jeu ou harness).
const GEN_TIMEOUT_MS: int = 90000

# Marqueurs de template/tokens spéciaux que gemma4 émet parfois en TEXTE (pas comme token EOT).
# On TRONQUE la sortie au 1er marqueur (tout ce qui suit = divagation) puis on nettoie les résidus.
const STOP_MARKERS: Array = [
	"<start_of_turn", "</start_of_turn", "<end_of_turn", "</end_of_turn",
	"<turn|", "<|turn", "<|im_", "<eos", "<bos", "<pad", "<unk", "<0x",
]

var _llm: Object = null
var _model_ready: bool = false
var _busy: bool = false
var _t_start_ms: int = 0
var _last_metrics: Dictionary = {}
var _pending_prompt: String = ""
var _pending_result: Dictionary = {}  # résultat de la génération courante (lu par l'auto-polling)
var _result_ready: bool = false
var _gen_id: int = 0  # nonce : invalide les callbacks tardifs (après timeout) → anti-corruption
var _quitting: bool = false  # v10.13 (Fix 7) : garde anti double-_graceful_quit

# Observabilité debug (log Gemma temps réel) : étiquette de l'activité en cours + journal d'événements.
const ACTIVITY_LOG_MAX: int = 24
var _current_label: String = ""
var _activity_log: Array = []  # [{label, ms, chars, ok, t}] (générations terminées, récentes)


func _ready() -> void:
	set_process(false)
	# v10.13 (Fix 7) : on gère la fermeture nous-mêmes — cancel + join borné, PAS de gel 30-60s.
	get_tree().set_auto_accept_quit(false)
	# Charge le modèle après que l'arbre soit prêt (le load bloque ~1-3s).
	call_deferred("_boot")


func _boot() -> void:
	# v10.13 (B1) : laisse le 1er frame PEINDRE (le menu s'affiche) avant le load bloquant 1-3s
	# du modèle — sans ça l'app reste sur un écran noir pendant tout le chargement.
	await RenderingServer.frame_post_draw
	if not ClassDB.class_exists("MerlinLLM"):
		push_error("[MerlinNative] GDExtension MerlinLLM absente (DLL non chargée ?)")
		emit_signal("model_failed", "GDExtension MerlinLLM absente")
		return
	_llm = ClassDB.instantiate("MerlinLLM")
	if _llm == null:
		emit_signal("model_failed", "Instanciation MerlinLLM échouée")
		return
	# set_context_size DOIT précéder load_model (ctx créé au chargement).
	_llm.set_context_size(N_CTX)
	var abs_path: String = ProjectSettings.globalize_path(MODEL_E2B)
	var err: int = _llm.load_model(abs_path)
	if err != OK:
		push_error("[MerlinNative] load_model err=%d path=%s" % [err, abs_path])
		emit_signal("model_failed", "load_model err=%d" % err)
		return
	_model_ready = true
	print("[MerlinNative] Gemma 4 E2B charge (n_ctx=%d) : %s" % [N_CTX, abs_path])
	emit_signal("model_ready")
	# v10.17 (track LLM) — warm le cache GBNF + valide les fichiers au boot (observabilité PURE :
	# n'altère NI le load modèle, NI generate/generate_raw, NI le timeout/cancel). preload_all ne lève
	# jamais (fichier absent → push_warning). Enforcement OFF par défaut (MerlinGrammar.USE_GBNF=false).
	var gram: Dictionary = MerlinGrammar.preload_all()
	print("[MerlinNative] GBNF preload : ok=%d enforce=%s missing=%s" % [
		int(gram.get("ok", 0)), str(gram.get("enforcement", false)), str(gram.get("missing", []))])


func is_ready() -> bool:
	return _model_ready and _llm != null


func is_busy() -> bool:
	return _busy


func _process(_delta: float) -> void:
	# poll_result() DOIT être appelé sur le thread principal ; il fire le callback
	# quand le thread d'inférence a terminé.
	if _llm != null and _busy:
		_llm.poll_result()


## Construit le template de chat Gemma (appliqué côté GDScript — le natif tokenise brut).
func build_prompt(system_text: String, user_text: String) -> String:
	return "<start_of_turn>user\n%s\n\n%s<end_of_turn>\n<start_of_turn>model\n" % [system_text, user_text]


func _apply_regime(creative: bool, max_tokens: int) -> void:
	var temp: float = TEMP_CREATIVE if creative else TEMP_STRUCTURED
	_llm.set_sampling_params(temp, TOP_P, max_tokens)
	_llm.set_advanced_sampling(TOP_K, REPEAT_PENALTY)


## Génération principale (applique le template de chat). opts:
##   {creative: bool=true, max_tokens: int=250, grammar: String="", grammar_root: String="root"}
## Retourne {"text": String} ou {"error": String} via await.
func generate(system_text: String, user_text: String, opts: Dictionary = {}) -> Dictionary:
	var prompt: String = build_prompt(system_text, user_text)
	return await generate_raw(prompt, opts)


## Génération sur prompt brut (pas de template) — mode prompt libre du dashboard debug.
func generate_raw(full_prompt: String, opts: Dictionary = {}) -> Dictionary:
	if not is_ready():
		return {"error": "modele non pret"}
	if _busy:
		return {"error": "generation deja en cours"}
	var creative: bool = opts.get("creative", true)
	var max_tokens: int = opts.get("max_tokens", 250)
	var grammar: String = opts.get("grammar", "")
	var grammar_root: String = opts.get("grammar_root", "root")

	_apply_regime(creative, max_tokens)
	if grammar.is_empty():
		_llm.clear_grammar()
	else:
		_llm.set_grammar(grammar, grammar_root)

	_busy = true
	_current_label = str(opts.get("label", "génération"))
	_t_start_ms = Time.get_ticks_msec()
	set_process(true)
	# Démarre la génération en DIFFÉRÉ : garantit que `await generation_finished` est
	# enregistré AVANT que le callback puisse émettre (évite le drop de signal si le
	# natif rappelle de façon synchrone — code-review CRITICAL).
	_pending_prompt = full_prompt
	_result_ready = false
	_pending_result = {}
	_gen_id += 1
	var my_id: int = _gen_id
	call_deferred("_start_generation", my_id)
	# Auto-polling : on pompe poll_result() nous-mêmes CHAQUE frame (ne plus dépendre uniquement
	# de _process, qui peut starver en headless --script → await figé). Timeout borné anti-gel.
	var t0: int = Time.get_ticks_msec()
	while true:
		if _llm != null:
			_llm.poll_result()  # fire _on_result quand le thread d'inférence a terminé
		if _result_ready:
			break
		if Time.get_ticks_msec() - t0 > GEN_TIMEOUT_MS:
			_gen_id += 1  # invalide tout callback tardif de CETTE génération (anti-corruption)
			if _llm != null:
				_llm.cancel_generation()
			_busy = false
			set_process(false)
			push_warning("[MerlinNative] timeout génération (%d ms) — annulée" % GEN_TIMEOUT_MS)
			return {"error": "timeout"}
		await get_tree().process_frame
	return _pending_result


func _start_generation(gen_id: int) -> void:
	if gen_id != _gen_id:
		return  # génération invalidée (timeout) avant l'exécution différée
	if _llm == null:
		_on_result({"error": "moteur indisponible"}, gen_id)
		return
	_llm.generate_async(_pending_prompt, Callable(self, "_on_result").bind(gen_id))


func _on_result(result: Dictionary, gen_id: int = 0) -> void:
	if gen_id != _gen_id:
		return  # callback périmé (génération annulée par timeout / remplacée) → ignore
	if _result_ready:
		return  # double-poll (_process + boucle d'auto-polling) → résultat déjà consommé
	var elapsed_ms: int = Time.get_ticks_msec() - _t_start_ms
	_busy = false
	set_process(false)
	var txt: String = _sanitize(str(result.get("text", "")))
	if result.has("text"):
		result["text"] = txt  # le consommateur reçoit le texte NETTOYÉ
	# Approximation tokens (pas de compteur natif sans streaming) : ~4 chars/token.
	var approx_tokens: int = int(txt.length() / 4.0)
	var tok_per_s: float = 0.0
	if elapsed_ms > 0:
		tok_per_s = float(approx_tokens) * 1000.0 / float(elapsed_ms)
	_last_metrics = {
		"total_ms": elapsed_ms,
		"approx_tokens": approx_tokens,
		"tok_per_s": tok_per_s,
		"chars": txt.length(),
		"ok": not result.has("error"),
	}
	_activity_log.append({
		"label": _current_label, "ms": elapsed_ms, "chars": txt.length(),
		"ok": not result.has("error"), "t": Time.get_ticks_msec(),
	})
	while _activity_log.size() > ACTIVITY_LOG_MAX:
		_activity_log.pop_front()
	_pending_result = result
	_result_ready = true
	emit_signal("generation_finished", result)


func last_metrics() -> Dictionary:
	return _last_metrics


# --- Observabilité debug (lus par MerlinDebugOverlay) ---
func get_current_label() -> String:
	return _current_label


func get_activity_log() -> Array:
	return _activity_log


func get_elapsed_ms() -> int:
	return (Time.get_ticks_msec() - _t_start_ms) if _busy else 0


func model_info() -> Dictionary:
	if is_ready():
		return _llm.get_model_info()
	return {}


func cancel() -> void:
	if _llm != null and _busy:
		_llm.cancel_generation()


func _notification(what: int) -> void:
	# Annule toute génération en vol quand l'app ou la scène se ferme. Sans ça, le moteur natif
	# "joine" le thread d'inférence jusqu'à la fin du décodage → Godot fige plusieurs dizaines de
	# secondes au quit si une gen tourne (intro/issue/sélection).
	# EXIT_TREE et WM_CLOSE_REQUEST arrivent alors que _llm est ENCORE valide. On évite PREDELETE :
	# l'objet GDExtension natif peut y être partiellement détruit → appel = crash potentiel.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# v10.13 (Fix 7) : auto_accept_quit=false → c'est NOUS qui quittons, après un join borné.
		_graceful_quit()
	elif what == NOTIFICATION_EXIT_TREE:
		if _llm != null and _busy:
			_llm.cancel_generation()


# v10.13 (Fix 7) — fermeture propre : cancel de la gen en vol + drain BORNÉ (2s, le flag natif est
# lu entre tokens ~1/s) puis quit INCONDITIONNEL. L'app ne fige plus au quit ; à l'échéance le
# process se termine et l'OS récupère le thread d'inférence. (Racine C++ — vérifier le flag pendant
# le prompt-eval chunké — taggée follow-up natif séparé.)
func _graceful_quit() -> void:
	if _quitting:
		return  # double WM_CLOSE (automation) → une seule coroutine de fermeture
	_quitting = true
	if _llm != null and _busy:
		_llm.cancel_generation()
		var dl: int = Time.get_ticks_msec() + 2000
		while _busy and Time.get_ticks_msec() < dl:
			_llm.poll_result()  # le callback de fin (→ _busy=false) se déclenche au poll
			await get_tree().process_frame
	get_tree().quit()


## Nettoie la sortie : tronque au 1er marqueur de template (gemma4 émet parfois
## <start_of_turn>/<turn|>/<0x..> en texte) puis strip les résidus. (bug playtest)
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
