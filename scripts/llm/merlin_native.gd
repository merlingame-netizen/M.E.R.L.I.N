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
## Texte CUMULÉ écrit jusqu'ici par la génération en cours. Émis pendant qu'elle écrit, pas
## après : c'est ce qui permet à un écran de montrer le premier résultat sans attendre le
## dernier. Ne remplace pas `generation_finished`, qui reste la seule source du résultat validé.
signal generation_chunk(texte_cumule: String)
signal model_failed(reason: String)
signal generation_finished(result: Dictionary)

const MODEL_E2B: String = "res://addons/merlin_llm/models/gemma4-e2b-q4_k_m.gguf"
# Le e4b quand il est là, le e2b sinon. Le choix est un CONSTAT, pas un jour de bascule : la VM
# ARM dispose du e4b (6,1 Go, meilleure prose) là où le PC livre le e2b à côté de son exe. Aucune
# machine n'a besoin d'être reconfigurée — chacune prend ce qu'elle a.
const MODEL_E4B: String = "res://addons/merlin_llm/models/gemma4-e4b-q4_k_m.gguf"
const MODELES: Array = [MODEL_E4B, MODEL_E2B]
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

# Délai d'une génération. MESURÉ le 2026-08-16 sur la VM, sélection complète (3 titres) :
#   · machine libre ................ 63,2 s → RÉUSSIE
#   · jeu en train de rendre ....... 90,4 s → dépassait les 90 s, donc ANNULÉE
# 90 s laissait 70 % de marge sur le meilleur cas et zéro sur le cas réel. Ce n'est pas un
# garde-fou, c'est un piège : l'annulation coince le fil d'inférence côté C++ et le moteur se
# déclare mort POUR TOUTE LA SESSION (« Previous generation stuck »). Une génération légitime
# était donc transformée en panne définitive.
#
# 150 s laisse une vraie marge au-dessus du pire cas mesuré. Ce n'est PAS masquer la lenteur :
# le joueur ne subit pas ce délai (l'écran de sélection renonce de lui-même à 120 s et le lui
# dit) — il ne sert qu'à éviter qu'une génération un peu longue ne brique le moteur.
const GEN_TIMEOUT_MS: int = 150000

# Marqueurs de template/tokens spéciaux que gemma4 émet parfois en TEXTE (pas comme token EOT).
# On TRONQUE la sortie au 1er marqueur (tout ce qui suit = divagation) puis on nettoie les résidus.
const STOP_MARKERS: Array = [
	"<start_of_turn", "</start_of_turn", "<end_of_turn", "</end_of_turn",
	"<turn|", "<|turn", "<|im_", "<eos", "<bos", "<pad", "<unk", "<0x",
]

var _llm: Object = null
# Raison du renoncement, VIDE tant que tout va bien. `model_failed` ne sert qu'aux auditeurs
# deja branches : `_boot` est appele en differe des le demarrage, donc quiconque arrive une
# fraction de seconde plus tard (un ecran, un harnais de mesure) manque le signal et attend un
# moteur qui a deja renonce. Cet etat repond aux retardataires.
var _boot_error: String = ""
# Reprises déjà tentées après un moteur qui s'est déclaré mort. Bornées : chaque reprise ABANDONNE
# l'ancien objet natif sans le libérer (son fil d'inférence est coincé DANS le contexte llama —
# le libérer serait un use-after-free), donc chacune laisse ~6 Go en mémoire. Une passe est
# abordable sur les 14 Go libres ; en enchaîner sans limite finirait par saturer la machine.
# Posé quand le natif annonce qu'il s'est désactivé. C'est le RÉSULTAT d'une génération qui
# porte ce message, jamais `_boot_error` (qui ne parle que du démarrage) — s'appuyer sur ce
# dernier ne détecterait donc jamais rien.
var _moteur_mort: bool = false
var _reprises: int = 0
const REPRISES_MAX: int = 1
var _model_ready: bool = false
var _busy: bool = false
var _t_start_ms: int = 0
var _last_metrics: Dictionary = {}
var _pending_prompt: String = ""
var _pending_result: Dictionary = {}  # résultat de la génération courante (lu par l'auto-polling)
var _result_ready: bool = false
var _gen_id: int = 0  # nonce : invalide les callbacks tardifs (après timeout) → anti-corruption
var _quitting: bool = false  # v10.13 (Fix 7) : garde anti double-_graceful_quit

# v10.18 — Chargement du modèle DANS UN THREAD (anti-freeze au boot) : le thread principal reste fluide
# (écran de chargement animé). _process poll la fin et émet model_ready SUR le thread principal.
var _load_thread: Thread = null
var _load_path: String = ""
var _load_err: int = 0
var _load_done: bool = false

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
	# HEADLESS (mesuré 2026-08-15) : `RenderingServer.frame_post_draw` ne se déclenche JAMAIS sans
	# serveur d'affichage. L'attente ci-dessous ne rendait donc pas la main : `_boot` restait
	# suspendu pour toujours, `is_ready()` restait faux, et AUCUN outil headless (smoke, soak, CI,
	# sonde de mesure) n'a jamais pu charger le modèle — ils exerçaient tous les banques de secours
	# en silence, sans qu'aucune erreur ne le signale. C'est ce blocage muet qui a laissé vivre le
	# « ~1 tok/s » jamais vérifié.
	#
	# Par défaut on ne charge PAS le modèle en headless : un smoke de 8 s n'a pas à payer 4 Go de
	# lecture disque. Mais on le DIT (`model_failed`) au lieu de se figer — un échec visible vaut
	# mieux qu'une attente éternelle. Un harnais qui veut vraiment le moteur pose
	# MERLIN_ALLOW_HEADLESS_LLM=1 et paie le chargement en connaissance de cause.
	if DisplayServer.get_name() == "headless":
		if not OS.has_environment("MERLIN_ALLOW_HEADLESS_LLM"):
			_boot_error = "headless sans MERLIN_ALLOW_HEADLESS_LLM"
			emit_signal("model_failed", "headless sans MERLIN_ALLOW_HEADLESS_LLM")
			return
	else:
		# v10.13 (B1) : laisse le 1er frame PEINDRE (le menu s'affiche) avant le load bloquant 1-3s
		# du modèle — sans ça l'app reste sur un écran noir pendant tout le chargement.
		await RenderingServer.frame_post_draw
	if not ClassDB.class_exists("MerlinLLM"):
		push_error("[MerlinNative] GDExtension MerlinLLM absente (DLL non chargée ?)")
		_boot_error = "GDExtension MerlinLLM absente"
		emit_signal("model_failed", "GDExtension MerlinLLM absente")
		return
	if not _monter_moteur():
		return


# Construit un objet natif NEUF et lance son chargement en tâche de fond. Partagé par le
# démarrage et par la reprise après panne : les deux ont exactement le même besoin, et les
# dupliquer garantirait qu'un jour l'un des deux dérive de l'autre.
func _monter_moteur() -> bool:
	_llm = ClassDB.instantiate("MerlinLLM")
	if _llm == null:
		_boot_error = "Instanciation MerlinLLM échouée"
		emit_signal("model_failed", "Instanciation MerlinLLM échouée")
		return false
	# set_context_size DOIT précéder load_model (ctx créé au chargement) — sur le thread principal.
	_llm.set_context_size(N_CTX)
	# v10.18 — load_model (bloquant ~2-3s) lancé DANS UN THREAD → ZÉRO freeze : l'écran de chargement
	# anime pendant ce temps. _process détecte la fin (_load_done) et appelle _finish_load (thread principal).
	_load_path = _resolve_model_path()
	_load_done = false
	_load_err = 0
	_model_ready = false
	_load_thread = Thread.new()
	_load_thread.start(_threaded_load)
	set_process(true)  # pour poller la fin du thread de chargement
	return true


# TEC-07-A — résout le chemin DISQUE du GGUF (llama.cpp lit par fopen : jamais depuis le .pck).
# Éditeur (feature "editor", inclut smoke/soak via binaire dev) : res:// globalisé — inchangé.
# Build EXPORTÉ : globalize_path(res://) ne fonctionne PAS hors éditeur et le modèle (3,3 GB)
# n'est pas embarqué — il est livré À CÔTÉ de l'exe : <exe_dir>/models/<nom>, sinon <exe_dir>/<nom>.
func _resolve_model_path() -> String:
	# Le e4b passe en premier partout : présent → il l'emporte ; absent → le e2b, comme avant.
	if OS.has_feature("editor"):
		for res_path in MODELES:
			var abs_path: String = ProjectSettings.globalize_path(res_path)
			if FileAccess.file_exists(abs_path):
				return abs_path
		return ProjectSettings.globalize_path(MODEL_E2B)  # échec propre → model_failed
	var exe_dir: String = OS.get_executable_path().get_base_dir()
	var candidates: Array = []
	for res_path in MODELES:
		var fname: String = res_path.get_file()
		candidates.append(exe_dir.path_join("models").path_join(fname))
		candidates.append(exe_dir.path_join(fname))
	for cand in candidates:
		if FileAccess.file_exists(cand):
			return cand
	push_error("[MerlinNative] GGUF introuvable à côté de l'exe (%s) — attendu : %s"
			% [exe_dir, MODEL_E2B.get_file()])
	return candidates[candidates.size() - 1]  # load_model échouera proprement → model_failed


# Exécuté sur un thread SÉPARÉ : seule l'opération CPU de chargement (aucune interaction SceneTree).
func _threaded_load() -> void:
	_load_err = _llm.load_model(_load_path)
	_load_done = true  # lu par _process sur le thread principal (flag one-shot)


# Appelé sur le thread PRINCIPAL (via _process) quand le thread de chargement a fini : join + signal.
func _finish_load() -> void:
	if _load_thread != null:
		_load_thread.wait_to_finish()
		_load_thread = null
	if not _busy:
		set_process(false)
	if _load_err != OK:
		push_error("[MerlinNative] load_model err=%d path=%s" % [_load_err, _load_path])
		_boot_error = "load_model err=%d" % _load_err
		emit_signal("model_failed", "load_model err=%d" % _load_err)
		return
	_model_ready = true
	print("[MerlinNative] Gemma 4 E2B charge (n_ctx=%d) : %s" % [N_CTX, _load_path])
	emit_signal("model_ready")


# Pourquoi le moteur n'est pas la — chaine vide s'il va bien ou s'il charge encore.
func boot_error() -> String:
	return _boot_error


# Le natif ne publie pas `engine_dead` ; on le déduit de son propre message d'erreur, seul
# canal disponible sans recompiler l'extension. Fragile par nature (on lit une chaîne), donc on
# teste les DEUX formulations émises par merlin_llm.cpp et on garde la vérification à un seul
# endroit plutôt que dispersée.
func _reprise_necessaire() -> bool:
	return _moteur_mort


# Le natif ne publie pas son drapeau `engine_dead` : son message d'erreur est le seul canal
# disponible sans recompiler l'extension. Lire une chaîne est fragile par nature, d'où les DEUX
# formulations émises par merlin_llm.cpp (lignes 121 et 144) testées ici, à un seul endroit.
func _noter_si_moteur_mort(err: String) -> void:
	if err.contains("stuck") or err.contains("LLM disabled"):
		_moteur_mort = true


func is_ready() -> bool:
	return _model_ready and _llm != null


func is_busy() -> bool:
	return _busy


func _process(_delta: float) -> void:
	# v10.18 — fin du chargement THREADÉ détectée sur le thread principal → join + model_ready.
	if _load_done and _load_thread != null:
		_load_done = false
		_finish_load()
	# poll_result() DOIT être appelé sur le thread principal ; il fire le callback
	# quand le thread d'inférence a terminé.
	if _llm != null and _busy:
		_llm.poll_result()


## Construit le template de chat Gemma (appliqué côté GDScript — le natif tokenise brut).
func build_prompt(system_text: String, user_text: String) -> String:
	return "<start_of_turn>user\n%s\n\n%s<end_of_turn>\n<start_of_turn>model\n" % [system_text, user_text]


## AMORÇAGE DU PRÉFIXE — fait lire à Merlin, une fois pour toutes, la partie de son prompt qui
## ne change jamais.
##
## LE CHIFFRE (mesuré 2026-08-18, en jeu) : une sélection coûte 65,4 s au moteur, dont **26,9 s
## rien qu'à relire son prompt** — 655 tokens, dont l'essentiel est sa propre voix, identique
## d'un appel à l'autre. Depuis que la réutilisation du cache est réparée côté C++, ce qui a
## déjà été lu n'est plus relu ; encore faut-il l'avoir lu UNE fois.
##
## D'où cet appel-là, lancé dès que le modèle est chargé — pendant que le joueur regarde le menu,
## donc dans un temps qui ne lui coûte rien. Il ne produit qu'un token, aussitôt jeté : ce qu'on
## garde, c'est l'empreinte du système dans le cache.
##
## Silencieux par construction : aucun signal, aucune erreur remontée. S'il échoue, la sélection
## paiera simplement la lecture complète, comme avant — un amorçage raté ne doit jamais devenir
## une panne visible.
func amorcer_prefixe(system_text: String) -> void:
	if not is_ready() or _busy or system_text == "":
		return
	await generate(system_text, "", {"creative": false, "max_tokens": 1,
			"plein_regime": true, "label": "amorçage du préfixe"})


# Fils d'exécution de la GÉNÉRATION, choisis SELON LE MOMENT (mesuré 2026-08-15 : 2,93 tok/s
# avec 2 fils sur les 4 cœurs de la VM). Le natif se règle par défaut sur la moitié des cœurs,
# volontairement, pour « laisser du CPU au jeu » — sur cette VM le rendu est logiciel (llvmpipe),
# il coûte cher, et lui voler ses cœurs ferait saccader la marche.
#
# Mais ce compromis n'a de sens QUE pendant que tu joues. Devant un voile d'attente — l'écran
# qui rêve les sentiers, un chargement — plus rien ne réclame la machine : s'y limiter à la
# moitié, c'est te faire patienter deux fois plus longtemps pour préserver des images que
# personne ne regarde. D'où deux régimes, et un choix explicite à chaque génération.
static func _fils_plein() -> int:
	return maxi(2, OS.get_processor_count())


static func _fils_menage() -> int:
	return maxi(2, int(OS.get_processor_count() / 2.0))


func _apply_regime(creative: bool, max_tokens: int, plein_regime: bool = false) -> void:
	var temp: float = TEMP_CREATIVE if creative else TEMP_STRUCTURED
	_llm.set_sampling_params(temp, TOP_P, max_tokens)
	_llm.set_advanced_sampling(TOP_K, REPEAT_PENALTY)
	# `llama_set_n_threads` s'applique à chaud sur le contexte : le régime peut donc changer
	# d'une génération à l'autre sans recharger quoi que ce soit.
	#
	# `has_method` OBLIGATOIRE, pas de la prudence décorative : le .so est compilé séparément et
	# déployé séparément du GDScript. Une machine peut très bien tourner avec une extension plus
	# ancienne que ce fichier — appeler un symbole absent ferait échouer TOUTES les générations,
	# et le jeu retomberait silencieusement sur ses banques de secours. Sans le réglage, on garde
	# simplement le défaut du natif (moitié des cœurs) : dégradé, jamais cassé.
	if _llm.has_method("set_thread_count"):
		var fils: int = _fils_plein() if plein_regime else _fils_menage()
		_llm.set_thread_count(fils, _fils_plein())  # batch (évaluation du prompt) toujours à fond


## Génération principale (applique le template de chat). opts:
##   {creative: bool=true, max_tokens: int=250, grammar: String="", grammar_root: String="root",
##    plein_regime: bool=false}
## `plein_regime` : true quand le joueur ATTEND devant un voile (rien à rendre → tous les cœurs),
## false quand il joue (on laisse au rendu de quoi tenir la cadence). Voir _apply_regime.
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
	# REPRISE APRÈS MORT DU MOTEUR (mesuré chez Maxime le 2026-08-16). Enchaînement observé :
	# une génération dépasse GEN_TIMEOUT_MS, on l'annule, le fil d'inférence C++ reste coincé dans
	# le contexte llama, et à l'appel suivant le natif pose `engine_dead` — DÉFINITIVEMENT. Toute
	# la session est alors perdue : « Merlin réfléchit » puis retour au menu, à chaque partie,
	# jusqu'à ce qu'on relance le jeu. Personne ne peut deviner qu'il faut relancer.
	#
	# On repart d'un objet natif NEUF plutôt que de rappeler `load_model` sur le mort : celui-ci
	# libère le contexte que le fil coincé utilise encore — un use-after-free, donc un plantage
	# possible. L'ancien objet est ABANDONNÉ tel quel (le C++ détache déjà son fil) ; il emporte
	# sa mémoire, d'où la borne REPRISES_MAX.
	if _reprise_necessaire():
		if _reprises >= REPRISES_MAX:
			return {"error": "moteur mort — reprise déjà tentée, relancer le jeu"}
		_reprises += 1
		push_warning("[MerlinNative] moteur mort après une génération coincée — reprise %d/%d"
				% [_reprises, REPRISES_MAX])
		if not _monter_moteur():
			return {"error": "moteur mort — reprise impossible"}
		# Le rechargement tourne dans un thread ; on l'attend, borné. Sans cette attente on
		# rendrait « modèle non prêt » juste après avoir annoncé une reprise — incompréhensible.
		var dl: int = Time.get_ticks_msec() + 60000
		while not _model_ready and Time.get_ticks_msec() < dl:
			await get_tree().process_frame
		if not _model_ready:
			return {"error": "moteur mort — rechargement trop long"}
		_moteur_mort = false
		_boot_error = ""
	var creative: bool = opts.get("creative", true)
	var max_tokens: int = opts.get("max_tokens", 250)
	var grammar: String = opts.get("grammar", "")
	var grammar_root: String = opts.get("grammar_root", "root")
	var plein_regime: bool = opts.get("plein_regime", false)

	_apply_regime(creative, max_tokens, plein_regime)
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
	var cumul: String = ""
	while true:
		if _llm != null:
			# AU FIL DE L'EAU : on vide le tampon du moteur à chaque image. Mesuré le 2026-08-18,
			# l'écriture prend 38 s en jeu — attendre la fin pour montrer quoi que ce soit gâche
			# le tiers du temps où le premier résultat est déjà écrit.
			if _llm.has_method("poll_stream"):
				var morceau: String = str(_llm.poll_stream())
				if morceau != "":
					cumul += morceau
					emit_signal("generation_chunk", cumul)
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
	if result.has("error"):
		_noter_si_moteur_mort(str(result["error"]))
	var txt: String = _sanitize(str(result.get("text", "")))
	if result.has("text"):
		result["text"] = txt  # le consommateur reçoit le texte NETTOYÉ
	# COMPTEURS RÉELS quand le moteur les fournit (llama_perf_context, ajouté 2026-08-18), sinon
	# l'ancienne approximation « ~4 caractères par token ». La distinction n'est pas cosmétique :
	# l'approximation additionnait l'évaluation du prompt et l'écriture dans un seul chiffre, donc
	# elle ne pouvait pas dire laquelle des deux coûte les secondes — la question ouverte depuis
	# qu'une sélection prend 112 s en jeu contre 31 s sans rien dessiner.
	var p_eval_ms: float = float(result.get("prompt_eval_ms", 0.0))
	var eval_ms: float = float(result.get("eval_ms", 0.0))
	var n_prompt: int = int(result.get("prompt_tokens", 0))
	var n_ecrits: int = int(result.get("eval_tokens", 0))
	var reels: bool = n_ecrits > 0 or n_prompt > 0
	var approx_tokens: int = n_ecrits if reels else int(txt.length() / 4.0)
	var tok_per_s: float = 0.0
	if reels and eval_ms > 0.0:
		tok_per_s = float(n_ecrits) * 1000.0 / eval_ms   # vitesse d'ÉCRITURE seule, comparable à Ollama
	elif elapsed_ms > 0:
		tok_per_s = float(approx_tokens) * 1000.0 / float(elapsed_ms)
	_last_metrics = {
		"total_ms": elapsed_ms,
		"approx_tokens": approx_tokens,
		"tok_per_s": tok_per_s,
		"chars": txt.length(),
		"ok": not result.has("error"),
		"compteurs_reels": reels,
		"prompt_ms": p_eval_ms, "prompt_tokens": n_prompt,
		"ecriture_ms": eval_ms, "tokens_ecrits": n_ecrits,
	}
	if reels:
		var vp: float = (float(n_prompt) * 1000.0 / p_eval_ms) if p_eval_ms > 0.0 else 0.0
		print("[MerlinNative] %s : prompt %d tok en %.1f s (%.1f tok/s) · ecriture %d tok en %.1f s (%.1f tok/s) · total %.1f s"
				% [_current_label, n_prompt, p_eval_ms / 1000.0, vp,
					n_ecrits, eval_ms / 1000.0, tok_per_s, elapsed_ms / 1000.0])
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
		if _load_thread != null:
			_load_thread.wait_to_finish()
			_load_thread = null
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
	# v10.18 — si le chargement threadé tourne encore, on le JOINE (pas de thread orphelin au quit).
	if _load_thread != null:
		_load_thread.wait_to_finish()
		_load_thread = null
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
