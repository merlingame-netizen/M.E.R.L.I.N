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
# 2048, et PAS 4096 malgré la bible (R58) — décision par la mesure, deux fois. Le passage à 4096
# a fait s'effondrer llama_decode (segfault dans graph_compute, backtrace du 2026-08-19) :
# l'attention à fenêtre glissante de Gemma 4 emprunte un autre chemin à cette taille sur ce
# build. Et le « prompt de 2582 tokens » qui avait motivé l'agrandissement était un MENSONGE de
# la course de compteurs (corrigée depuis) : les vrais prompts plafonnent à ~1450 tokens,
# génération comprise — 2048 suffit. Si un jour 4096 redevient nécessaire, c'est llama.cpp qu'il
# faudra monter de version, pas cette constante.
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
# v33 « Les Deux Mains » — TOUT l'état de génération vit PAR VOIE (une par cerveau) : les
# deux moteurs sont des instances séparées avec leurs propres fils d'inférence, et les deux
# voies écrivent EN MÊME TEMPS (2+2 cœurs via set_thread_count à chaud — _partager_les_coeurs).
# id = nonce anti-callback-tardif ; plein = régime demandé (restauré quand la voie redevient seule).
const FILS_PARTAGE: int = 2  # (v33 — conservé pour référence des mesures)
# v35 — asymétrie du duo : le Vif écrit ce que le joueur ATTEND (issues), 3 fils ; le
# Conteur (scènes/arc, personne n'attend devant) continue sur 1. Bande passante mesurée
# v33 : 3 fils ~ 90 % du débit solo — l'issue attendue passe de 40-80 s à ~25-35 s.
const FILS_VIF_DUO: int = 3
const FILS_CONTEUR_DUO: int = 1
# v48.1c — « annulee » : la voie a recu un cancel_generation() pendant que le moteur ecrivait.
# Le C++ casse alors sa boucle SANS poser d'erreur (merlin_llm.cpp:410), si bien que le texte
# partiel remontait comme une reussite. Le drapeau le dit ; _on_result en tire la consequence.
var _voies: Dictionary = {
	"conteur": {"busy": false, "label": "", "t0": 0, "prompt": "", "ready": false,
		"result": {}, "id": 0, "plein": false, "metrics": {}, "annulee": false},
	"vif": {"busy": false, "label": "", "t0": 0, "prompt": "", "ready": false,
		"result": {}, "id": 0, "plein": false, "metrics": {}, "annulee": false},
}
var _last_metrics: Dictionary = {}
var _quitting: bool = false  # v10.13 (Fix 7) : garde anti double-_graceful_quit

# v10.18 — Chargement du modèle DANS UN THREAD (anti-freeze au boot) : le thread principal reste fluide
# (écran de chargement animé). _process poll la fin et émet model_ready SUR le thread principal.
var _load_thread: Thread = null
var _load_path: String = ""
var _load_err: int = 0
var _load_done: bool = false

# --- LE VIF (e2b) — second cerveau, décision d'architecture du 2026-08-19 ---
# Deux modèles résidents, chacun avec SON contexte : la fin de la guerre d'éviction. La tête
# stable du prompt d'issue reste chaude dans le Vif toute la session pendant que les prompts de
# récit vivent dans le Conteur (_llm). Une seule génération à la fois — le CPU est le vrai
# mono-place — mais plus jamais un cache qui se repaie à cause de l'autre.
# Dégradé propre : GGUF absent ou chargement en échec → tout part sur le Conteur, journalisé.
var _llm_vif: Variant = null
var _vif_ready: bool = false
var _vif_thread: Thread = null
var _vif_done: bool = false
var _vif_err: int = 0
var _vif_path: String = ""
signal vif_ready()
# v33 — flux par voie : (cerveau, texte cumulé). L'ancien generation_chunk reste émis (compat).
signal generation_chunk_voie(cerveau: String, texte_cumule: String)


func _moteur_de(cerveau: String) -> Variant:
	return _llm_vif if cerveau == "vif" else _llm

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


func _monter_vif() -> void:
	if _vif_thread != null:
		return  # un chargement est déjà en route — l'écraser orphelinerait son thread
	_vif_ready = false
	var chemin: String = ""
	if OS.has_feature("editor"):
		chemin = ProjectSettings.globalize_path(MODEL_E2B)
	else:
		var exe_dir: String = OS.get_executable_path().get_base_dir()
		var fname: String = MODEL_E2B.get_file()
		for cand in [exe_dir.path_join("models").path_join(fname), exe_dir.path_join(fname)]:
			if FileAccess.file_exists(cand):
				chemin = cand
				break
	if chemin == "" or not FileAccess.file_exists(chemin):
		print("[MerlinNative] Vif — GGUF e2b introuvable : mono-cerveau (tout sur le Conteur)")
		return
	_llm_vif = ClassDB.instantiate("MerlinLLM")
	if _llm_vif == null:
		push_warning("[MerlinNative] Vif — instanciation échouée : mono-cerveau")
		return
	_llm_vif.set_context_size(N_CTX)
	_vif_path = chemin
	_vif_done = false
	_vif_thread = Thread.new()
	_vif_thread.start(_threaded_load_vif)
	set_process(true)


func _threaded_load_vif() -> void:
	_vif_err = _llm_vif.load_model(_vif_path)
	_vif_done = true


func _finish_load_vif() -> void:
	if _vif_thread != null:
		_vif_thread.wait_to_finish()
		_vif_thread = null
	if _peut_dormir():
		set_process(false)
	if _vif_err != OK:
		push_warning("[MerlinNative] Vif — load_model err=%d : mono-cerveau (tout sur le Conteur)" % _vif_err)
		_llm_vif = null
		return
	_vif_ready = true
	print("[MerlinNative] Vif chargé (n_ctx=%d) : %s" % [N_CTX, _vif_path])
	emit_signal("vif_ready")


# Le processus ne s'endort que si plus RIEN ne l'attend : ni génération, ni chargement en fond.
# Avant le Vif, `not _busy` suffisait ; l'oublier ici aurait gelé le second chargement.
func _peut_dormir() -> bool:
	return not is_busy() and _load_thread == null and _vif_thread == null


func est_vif_pret() -> bool:
	return _vif_ready and _llm_vif != null


# TEC-07-A — résout le chemin DISQUE du GGUF (llama.cpp lit par fopen : jamais depuis le .pck).
# Éditeur (feature "editor", inclut smoke/soak via binaire dev) : res:// globalisé — inchangé.
# Build EXPORTÉ : globalize_path(res://) ne fonctionne PAS hors éditeur et le modèle (3,3 GB)
# n'est pas embarqué — il est livré À CÔTÉ de l'exe : <exe_dir>/models/<nom>, sinon <exe_dir>/<nom>.
func _resolve_model_path() -> String:
	# BASCULE DE MESURE (2026-08-18). La bible R58 prescrit le e2b « pour la rapidité CPU » et
	# réserve le e4b à « l'option qualité » ; le jeu tourne en e4b depuis toujours, sans que les
	# deux aient jamais été comparés sur la même tâche. MERLIN_MODELE=e2b|e4b permet de les
	# opposer sans toucher au code — la décision se prendra sur les sorties CÔTE À CÔTE, pas sur
	# une préférence. Chemin absolu accepté aussi, pour un GGUF hors du dépôt.
	var force: String = OS.get_environment("MERLIN_MODELE")
	if force != "":
		var choisi: String = force
		if force == "e2b":
			choisi = MODEL_E2B
		elif force == "e4b":
			choisi = MODEL_E4B
		if choisi.begins_with("res://"):
			choisi = ProjectSettings.globalize_path(choisi)
		if FileAccess.file_exists(choisi):
			print("[MerlinNative] modele force par MERLIN_MODELE : %s" % choisi)
			return choisi
		push_warning("[MerlinNative] MERLIN_MODELE=%s introuvable (%s) — resolution normale"
				% [force, choisi])
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
	if _peut_dormir():
		set_process(false)
	if _load_err != OK:
		push_error("[MerlinNative] load_model err=%d path=%s" % [_load_err, _load_path])
		_boot_error = "load_model err=%d" % _load_err
		emit_signal("model_failed", "load_model err=%d" % _load_err)
		return
	_model_ready = true
	print("[MerlinNative] Conteur chargé (n_ctx=%d) : %s" % [N_CTX, _load_path])
	emit_signal("model_ready")
	# Le Vif se charge APRÈS le Conteur, jamais en même temps : deux lectures disque de 4-6 Go en
	# parallèle se voleraient la bande passante, et le Conteur doit être prêt d'abord — c'est lui
	# le repli de tout.
	#
	# PREMIER DÉMARRAGE UNIQUEMENT (revue adversariale 2026-08-19, CRITIQUE) : _finish_load
	# repasse ici lors d'une REPRISE après moteur mort, et remonter le Vif écrasait une instance
	# SAINE par une coquille vide pendant que _vif_ready restait vrai — la génération suivante
	# était routée sur un moteur sans modèle, en course avec son propre load_model.
	if _llm_vif == null and not _vif_ready and _vif_thread == null:
		_monter_vif()


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
func _noter_si_moteur_mort(err: String, cerveau: String = "conteur") -> void:
	# La mort du VIF n'est pas celle du jeu : on le débranche (repli Conteur) sans reprise —
	# perdre 20 s par issue vaut mieux qu'une reprise de 4 Go en pleine partie.
	if cerveau == "vif":
		if err.contains("stuck") or err.contains("LLM disabled"):
			push_warning("[MerlinNative] Vif mort — repli mono-cerveau sur le Conteur")
			_vif_ready = false
			_llm_vif = null
		return
	_noter_si_moteur_mort_conteur(err)


func _noter_si_moteur_mort_conteur(err: String) -> void:
	if err.contains("stuck") or err.contains("LLM disabled"):
		_moteur_mort = true


func is_ready() -> bool:
	return _model_ready and _llm != null


func is_busy() -> bool:
	return bool(_voies["conteur"]["busy"]) or bool(_voies["vif"]["busy"])


## v33 — occupation d'UNE voie : le prefetch d'issue ne regarde que le Vif, le lookahead
## et l'arc ne regardent que le Conteur. is_busy() (OU des deux) reste pour les harnais.
func est_occupe(cerveau: String) -> bool:
	return bool((_voies.get(cerveau, {}) as Dictionary).get("busy", false))


## L'étiquette d'une génération en cours ("" si tout est libre) — compat observabilité.
func label_en_cours() -> String:
	for c in ["vif", "conteur"]:
		if _voies[c]["busy"]:
			return str(_voies[c]["label"])
	return ""


# v33 — 2+2 : les DEUX voies actives → chacune la moitié des cœurs (batch plein pour
# l'évaluation du prompt) ; une voie seule → son régime demandé. Appliqué À CHAUD
# (llama_set_n_threads), à chaque départ ET à chaque fin de génération.
func _partager_les_coeurs() -> void:
	var deux: bool = _voies["conteur"]["busy"] and _voies["vif"]["busy"]
	for c in ["conteur", "vif"]:
		var m: Variant = _moteur_de(c)
		if m == null or not _voies[c]["busy"] or not m.has_method("set_thread_count"):
			continue
		if deux:
			m.set_thread_count(FILS_VIF_DUO if c == "vif" else FILS_CONTEUR_DUO, _fils_plein())
		else:
			m.set_thread_count(_fils_plein() if _voies[c]["plein"] else _fils_menage(), _fils_plein())


func _process(_delta: float) -> void:
	# v10.18 — fin du chargement THREADÉ détectée sur le thread principal → join + model_ready.
	if _vif_done and _vif_thread != null:
		_vif_done = false
		_finish_load_vif()
	if _load_done and _load_thread != null:
		_load_done = false
		_finish_load()
	# poll_result() DOIT être appelé sur le thread principal ; il fire le callback
	# quand le thread d'inférence a terminé.
	if _llm != null and _voies["conteur"]["busy"]:
		_llm.poll_result()
	if _llm_vif != null and _voies["vif"]["busy"]:
		_llm_vif.poll_result()


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
func amorcer_prefixe(system_text: String, cerveau: String = "conteur", user_text: String = "") -> void:
	var voie_amorce: String = "vif" if (cerveau == "vif" and est_vif_pret()) else "conteur"
	if not is_ready() or est_occupe(voie_amorce) or (system_text == "" and user_text == ""):
		return
	await generate(system_text, user_text, {"creative": false, "max_tokens": 1,
			"plein_regime": true, "cerveau": cerveau,
			"label": "amorçage du préfixe (%s)" % cerveau})


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


func _apply_regime(moteur: Variant, creative: bool, max_tokens: int, plein_regime: bool = false) -> void:
	var temp: float = TEMP_CREATIVE if creative else TEMP_STRUCTURED
	moteur.set_sampling_params(temp, TOP_P, max_tokens)
	moteur.set_advanced_sampling(TOP_K, REPEAT_PENALTY)
	# `llama_set_n_threads` s'applique à chaud sur le contexte : le régime peut donc changer
	# d'une génération à l'autre sans recharger quoi que ce soit.
	#
	# `has_method` OBLIGATOIRE, pas de la prudence décorative : le .so est compilé séparément et
	# déployé séparément du GDScript. Une machine peut très bien tourner avec une extension plus
	# ancienne que ce fichier — appeler un symbole absent ferait échouer TOUTES les générations,
	# et le jeu retomberait silencieusement sur ses banques de secours. Sans le réglage, on garde
	# simplement le défaut du natif (moitié des cœurs) : dégradé, jamais cassé.
	if moteur.has_method("set_thread_count"):
		var fils: int = _fils_plein() if plein_regime else _fils_menage()
		moteur.set_thread_count(fils, _fils_plein())  # batch (évaluation du prompt) toujours à fond


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
	# v33 — la voie se résout AVANT tout : deux générations peuvent vivre ensemble, une par
	# cerveau. Une voie occupée refuse — l'appelant draine SA voie, jamais celle de l'autre.
	var cerveau: String = str(opts.get("cerveau", "conteur"))
	if not (cerveau == "vif" and est_vif_pret()):
		cerveau = "conteur"
	var v: Dictionary = _voies[cerveau]
	if v["busy"]:
		return {"error": "generation deja en cours"}
	# REPRISE APRÈS MORT DU MOTEUR (2026-08-16) — ne concerne que le Conteur : la mort du Vif
	# est un simple repli mono-cerveau (_noter_si_moteur_mort), jamais une reprise de 6 Go.
	if cerveau == "conteur" and _reprise_necessaire():
		if _reprises >= REPRISES_MAX:
			return {"error": "moteur mort — reprise déjà tentée, relancer le jeu"}
		_reprises += 1
		push_warning("[MerlinNative] moteur mort après une génération coincée — reprise %d/%d"
				% [_reprises, REPRISES_MAX])
		if not _monter_moteur():
			return {"error": "moteur mort — reprise impossible"}
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
	var moteur: Variant = _moteur_de(cerveau)
	_apply_regime(moteur, creative, max_tokens, plein_regime)
	v["plein"] = plein_regime
	if grammar.is_empty():
		moteur.clear_grammar()
	else:
		moteur.set_grammar(grammar, grammar_root)
	# Arrêt doux : opt-in par tâche (fin_phrase). Jamais pour du JSON.
	if moteur.has_method("set_soft_stop"):
		moteur.set_soft_stop(bool(opts.get("fin_phrase", false)))
	v["busy"] = true
	v["label"] = str(opts.get("label", "génération"))
	v["t0"] = Time.get_ticks_msec()
	_partager_les_coeurs()
	set_process(true)
	# Démarre en DIFFÉRÉ (le await generation_finished doit être enregistré avant émission).
	v["prompt"] = full_prompt
	v["ready"] = false
	v["result"] = {}
	v["annulee"] = false  # v48.1c — nouvelle generation : l'annulation precedente est soldee
	v["id"] = int(v["id"]) + 1
	var my_id: int = int(v["id"])
	call_deferred("_start_generation", cerveau, my_id)
	# Auto-polling par VOIE : chaque generate_raw pompe SA voie à chaque frame — deux appels
	# concurrents cohabitent, chacun draine son moteur et émet son flux.
	var t0: int = Time.get_ticks_msec()
	var cumul: String = ""
	while true:
		if moteur != null:
			# AU FIL DE L'EAU : le tampon du moteur est vidé chaque image. Pas de flux pour un
			# AMORÇAGE (1 token, aussitôt jeté) — il polluait la mesure du premier texte.
			if max_tokens > 1 and moteur.has_method("poll_stream"):
				var morceau: String = str(moteur.poll_stream())
				if morceau != "":
					cumul += morceau
					emit_signal("generation_chunk", cumul)
					emit_signal("generation_chunk_voie", cerveau, cumul)
			moteur.poll_result()
		if v["ready"]:
			break
		if Time.get_ticks_msec() - t0 > GEN_TIMEOUT_MS:
			v["id"] = int(v["id"]) + 1
			if moteur != null:
				moteur.cancel_generation()
			v["busy"] = false
			_partager_les_coeurs()
			if _peut_dormir():
				set_process(false)
			push_warning("[MerlinNative] timeout génération (%d ms) [%s] — annulée" % [GEN_TIMEOUT_MS, cerveau])
			return {"error": "timeout"}
		await get_tree().process_frame
	return v["result"]


func _start_generation(cerveau: String, gen_id: int) -> void:
	var v: Dictionary = _voies[cerveau]
	if gen_id != int(v["id"]):
		return  # génération invalidée (timeout) avant l'exécution différée
	var moteur: Variant = _moteur_de(cerveau)
	if moteur == null:
		_on_result({"error": "moteur indisponible"}, cerveau, gen_id)
		return
	moteur.generate_async(str(v["prompt"]), Callable(self, "_on_result").bind(cerveau, gen_id))


func _on_result(result: Dictionary, cerveau: String = "conteur", gen_id: int = 0) -> void:
	var v: Dictionary = _voies[cerveau]
	if gen_id != int(v["id"]):
		return  # callback périmé (annulé/remplacé) → ignore
	if v["ready"]:
		return  # double-poll → résultat déjà consommé
	# v48.1c — UNE ANNULATION N'EST PAS UNE REUSSITE. Le texte partiel qui remonte apres un
	# cancel_generation() n'a pas d'erreur attachee (le C++ casse sa boucle sans en poser) : sans
	# cette conversion, un demi-mot etait servi au joueur comme une prose finie, et ses compteurs
	# entraient dans _last_metrics — donc dans le journal, ou il ressemblait a une generation
	# normale. Le reste du menage (busy, ready, partage des coeurs, metriques) suit son cours.
	if bool(v.get("annulee", false)):
		v["annulee"] = false
		result = {"error": "annulee"}
	var elapsed_ms: int = Time.get_ticks_msec() - int(v["t0"])
	v["busy"] = false
	_partager_les_coeurs()
	if _peut_dormir():
		set_process(false)
	if result.has("error"):
		_noter_si_moteur_mort(str(result["error"]), cerveau)
	var txt: String = _sanitize(str(result.get("text", "")))
	if result.has("text"):
		result["text"] = txt
	# COMPTEURS RÉELS (llama_perf_context) quand fournis, sinon approximation ~4 car./token.
	var p_eval_ms: float = float(result.get("prompt_eval_ms", 0.0))
	var eval_ms: float = float(result.get("eval_ms", 0.0))
	var n_prompt: int = int(result.get("prompt_tokens", 0))
	var n_ecrits: int = int(result.get("eval_tokens", 0))
	var reels: bool = n_ecrits > 0 or n_prompt > 0
	var approx_tokens: int = n_ecrits if reels else int(txt.length() / 4.0)
	var tok_per_s: float = 0.0
	if reels and eval_ms > 0.0:
		tok_per_s = float(n_ecrits) * 1000.0 / eval_ms
	elif elapsed_ms > 0:
		tok_per_s = float(approx_tokens) * 1000.0 / float(elapsed_ms)
	var met: Dictionary = {
		# v48.1e — LE NOM DE LA MESURE. _last_metrics est ecrase par chaque generation qui
		# se termine, toutes voies confondues ; sans nom, un releve pris apres coup (le champ
		# « gen » du journal de la sonde) pouvait decrire une scene du Conteur en croyant
		# decrire l'issue du beat. La mesure se nomme, on ne devine plus.
		"label": str(v["label"]),
		"cerveau": cerveau,
		"total_ms": elapsed_ms,
		"approx_tokens": approx_tokens,
		"tok_per_s": tok_per_s,
		"chars": txt.length(),
		"ok": not result.has("error"),
		"compteurs_reels": reels,
		"prompt_ms": p_eval_ms, "prompt_tokens": n_prompt,
		"ecriture_ms": eval_ms, "tokens_ecrits": n_ecrits,
	}
	v["metrics"] = met
	_last_metrics = met
	if reels:
		var vp: float = (float(n_prompt) * 1000.0 / p_eval_ms) if p_eval_ms > 0.0 else 0.0
		print("[MerlinNative] %s [%s] : prompt %d tok en %.1f s (%.1f tok/s) · ecriture %d tok en %.1f s (%.1f tok/s) · total %.1f s"
				% [str(v["label"]), cerveau, n_prompt, p_eval_ms / 1000.0, vp,
					n_ecrits, eval_ms / 1000.0, tok_per_s, elapsed_ms / 1000.0])
	_activity_log.append({
		"label": str(v["label"]), "ms": elapsed_ms, "chars": txt.length(),
		"ok": not result.has("error"), "t": Time.get_ticks_msec(),
	})
	while _activity_log.size() > ACTIVITY_LOG_MAX:
		_activity_log.pop_front()
	v["result"] = result
	v["ready"] = true
	emit_signal("generation_finished", result)


func last_metrics() -> Dictionary:
	return _last_metrics


# --- Observabilité debug (lus par MerlinDebugOverlay) ---
func get_current_label() -> String:
	return label_en_cours()


func get_activity_log() -> Array:
	return _activity_log


func get_elapsed_ms() -> int:
	var t_actif: int = 0
	for c in ["conteur", "vif"]:
		if _voies[c]["busy"]:
			t_actif = maxi(t_actif, Time.get_ticks_msec() - int(_voies[c]["t0"]))
	return t_actif


func model_info() -> Dictionary:
	if not is_ready():
		return {}
	var d: Dictionary = _llm.get_model_info()
	d["vif"] = _llm_vif.get_model_info() if est_vif_pret() else {}
	return d


func cancel(cerveau: String = "") -> void:
	for c in (["conteur", "vif"] if cerveau == "" else [cerveau]):
		if not _voies.has(c):
			continue
		var m: Variant = _moteur_de(c)
		if m != null and _voies[c]["busy"]:
			# v48.1c — MARQUER avant d'annuler. Le C++ casse sa boucle sans poser d'erreur
			# (merlin_llm.cpp:410), et cancel() n'incremente pas v["id"] — contrairement au
			# timeout (l.567) — donc le callback n'etait pas perime et le demi-texte etait
			# servi comme une reussite. On ne touche ni a busy ni a l'id : le fil d'inference
			# tourne encore, liberer la voie ici lancerait une gen sur un moteur occupe.
			_voies[c]["annulee"] = true
			m.cancel_generation()


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
		cancel()


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
	if is_busy():
		cancel()
		var dl: int = Time.get_ticks_msec() + 2000
		while is_busy() and Time.get_ticks_msec() < dl:
			for c in ["conteur", "vif"]:
				var m: Variant = _moteur_de(c)
				if m != null and _voies[c]["busy"]:
					m.poll_result()  # le callback de fin (→ busy=false) se déclenche au poll
			await get_tree().process_frame
	if _vif_thread != null:
		_vif_thread.wait_to_finish()
		_vif_thread = null
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
