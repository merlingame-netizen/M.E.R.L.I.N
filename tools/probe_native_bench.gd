extends SceneTree
## Chronomètre le moteur natif (GDExtension MerlinLLM) sur la VRAIE tâche de sélection.
##   godot --headless --path . --script res://tools/probe_native_bench.gd
##
## POURQUOI cette sonde. Partout dans merlin_scenario.gd, les banques de secours sont justifiées
## par « le LLM (~1 tok/s) ne gagne presque jamais la course ». Ce chiffre date du backend Ollama.
## Le moteur natif (llama.cpp compilé dans le jeu, réglé pour les noyaux ARM de la VM) n'a JAMAIS
## été mesuré. Toute décision d'UI sur l'attente repose donc sur un chiffre périmé — cette sonde
## le remplace par un chiffre réel.
##
## Elle exerce sc.generate_selection(), c'est-à-dire EXACTEMENT le chemin du jeu (prompt réel,
## extraction JSON, nettoyage), pas un prompt de laboratoire. Elle sait donc aussi dire si le
## modèle a GAGNÉ ou si le secours en dur s'est substitué à lui — le seul verdict qui compte.
##
## Sortie : une ligne « [BENCH_JSON] {...} » sur stdout (l'agent VM la capture).
## Codes de retour : 0 mesuré · 2 autoloads absents · 3 modèle jamais chargé.

const PASSES_DEFAUT: int = 2
# Le e4b fait 6,1 Go : sur la VM ARM le chargement dépasse largement les 90 s que probe_prose
# s'accorde. Trop court, on conclurait « moteur mort » alors qu'il chargeait encore.
const LOAD_TIMEOUT_MS: int = 300000
const NODE_TIMEOUT_MS: int = 15000
# Filet par génération : au-delà, MerlinNative a de toute façon rendu la main sur son propre
# timeout (GEN_TIMEOUT_MS = 90 s) et generate_selection a renvoyé le secours.
const PASS_TIMEOUT_MS: int = 150000


func _init() -> void:
	_run()


func _await_node(path: String, max_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	var n: Node = root.get_node_or_null(path)
	while n == null and (Time.get_ticks_msec() - t0) < max_ms:
		await create_timer(0.05).timeout
		n = root.get_node_or_null(path)
	return n


# Tous les titres écrits en dur, tous biomes confondus. Sert de juge : si un titre rendu par
# generate_selection en fait partie, le modèle a perdu la course (ou échoué) sur cette passe.
func _titres_de_secours(sc: Node) -> Dictionary:
	var connus: Dictionary = {}
	var par_biome: Dictionary = sc.SEL_FALLBACK_BY_BIOME
	for biome in par_biome.keys():
		var pool: Array = par_biome[biome]
		for entree in pool:
			var d: Dictionary = entree
			connus[str(d.get("title", ""))] = true
	return connus


func _run() -> void:
	var t_boot: int = Time.get_ticks_msec()
	var out: Dictionary = {
		"t": Time.get_datetime_string_from_system(true),
		"ok": false,
		"etape": "demarrage",
		"charge_ms": -1,
		"passes": [],
	}

	var mn: Node = await _await_node("MerlinNative", NODE_TIMEOUT_MS)
	var sc: Node = await _await_node("MerlinScenario", NODE_TIMEOUT_MS)
	if mn == null or sc == null:
		out["etape"] = "autoloads absents (MerlinNative / MerlinScenario)"
		_emettre(out)
		quit(2)
		return

	# Sans cette variable, MerlinNative REFUSE de charger le modèle en headless (et avant le
	# correctif du 2026-08-15, il restait suspendu sans rien dire — cette sonde a attendu ses
	# 300 s pour un événement de rendu qui ne vient jamais sans écran). Le lanceur la pose ; on
	# le vérifie ICI pour qu'une mesure lancée à la main échoue en une seconde, avec la raison.
	if DisplayServer.get_name() == "headless" and not OS.has_environment("MERLIN_ALLOW_HEADLESS_LLM"):
		out["etape"] = "MERLIN_ALLOW_HEADLESS_LLM absente — le moteur ne se charge pas en headless"
		_emettre(out)
		quit(4)
		return

	# Juge lu MAINTENANT, pas après l'attente du modèle : si la lecture des banques casse, on veut
	# le savoir en une seconde, pas au bout des cinq minutes de chargement (le parse check ne voit
	# pas ce genre d'erreur — elle n'existe qu'à l'exécution).
	var secours: Dictionary = _titres_de_secours(sc)
	# Publié pour être vérifiable : un juge VIDE ferait passer toutes les passes pour des victoires
	# du modèle. Zéro ici invalide le verdict `modele_gagne_toujours`, il ne le confirme pas.
	out["titres_de_secours_connus"] = secours.size()

	# ── 1) Chargement du modèle ────────────────────────────────────────────────
	# Mesuré depuis le DÉMARRAGE du moteur, pas depuis le début de l'attente : c'est ce délai-là
	# qui se compare à la durée du générique d'ouverture (si le générique est plus court, on
	# arrive au menu avant que Merlin soit réveillé, et la pré-génération part en retard).
	# Surchargeable pour éprouver le chemin d'échec sans attendre cinq minutes (mise au point).
	var load_timeout_ms: int = LOAD_TIMEOUT_MS
	if OS.has_environment("MERLIN_BENCH_LOAD_TIMEOUT_MS"):
		var v: int = int(OS.get_environment("MERLIN_BENCH_LOAD_TIMEOUT_MS"))
		if v > 0:
			load_timeout_ms = v
	# On INTERROGE l'état plutôt que d'écouter `model_failed` : `_boot` est appelé en différé dès le
	# démarrage, donc le signal part souvent AVANT que cette sonde soit branchée. S'y fier, c'est
	# attendre cinq minutes un moteur qui a renoncé à la première seconde — le piège exact du
	# 2026-08-15.
	while not mn.is_ready() and str(mn.boot_error()) == "" \
			and (Time.get_ticks_msec() - t_boot) < load_timeout_ms:
		await create_timer(0.25).timeout
	out["charge_ms"] = Time.get_ticks_msec() - t_boot
	if not mn.is_ready():
		var raison: String = str(mn.boot_error())
		out["etape"] = ("le moteur a renonce : %s" % raison) if raison != "" \
				else "modele jamais charge (aucune raison donnee — trop lent ?)"
		_emettre(out)
		quit(3)
		return
	out["modele"] = mn.model_info()

	# ── 2) Passes de génération, sur le vrai chemin du jeu ────────────────────
	# Plusieurs passes parce que la première paie l'évaluation du prompt sur un cache vide :
	# la retenir seule ferait passer le moteur pour plus lent qu'il ne l'est en jeu (où le menu
	# a déjà chauffé). On rapporte chaque passe, sans moyenne qui masquerait l'écart.
	var passes_voulues: int = PASSES_DEFAUT
	if OS.has_environment("MERLIN_BENCH_PASSES"):
		var n: int = int(OS.get_environment("MERLIN_BENCH_PASSES"))
		if n > 0:
			passes_voulues = n
	var resultats: Array = []

	for i in passes_voulues:
		sc.invalidate_selection()  # sinon la passe 2 lirait le cache de la passe 1 : mesure vide
		var t0: int = Time.get_ticks_msec()
		var sels: Array = await sc.generate_selection()
		var mur_ms: int = Time.get_ticks_msec() - t0
		var m: Dictionary = mn.last_metrics()
		var titres: Array = []
		var du_secours: bool = false
		for s in sels:
			var d: Dictionary = s
			var titre: String = str(d.get("title", ""))
			titres.append(titre)
			if secours.has(titre):
				du_secours = true
		resultats.append({
			"mur_ms": mur_ms,
			"tok_par_s": float(m.get("tok_per_s", 0.0)),
			"tokens": int(m.get("approx_tokens", 0)),
			"caracteres": int(m.get("chars", 0)),
			"secours": du_secours,
			"titres": titres,
		})
		if mur_ms > PASS_TIMEOUT_MS:
			break  # le moteur patine : inutile de brûler la nuit à le confirmer

	out["passes"] = resultats
	out["etape"] = "mesure"
	out["ok"] = resultats.size() > 0

	# Résumé décisionnel. `tok_par_s_max` = le meilleur régime observé (le jeu tourne en tiède,
	# pas à froid) ; `mur_ms_max` = le pire cas, le seul comparable au temps que le jeu peut cacher.
	if resultats.size() > 0:
		var meilleur: float = 0.0
		var pire_mur: int = 0
		var jamais_secours: bool = true
		for r in resultats:
			var d: Dictionary = r
			meilleur = maxf(meilleur, float(d.get("tok_par_s", 0.0)))
			pire_mur = maxi(pire_mur, int(d.get("mur_ms", 0)))
			if bool(d.get("secours", false)):
				jamais_secours = false
		out["tok_par_s_max"] = meilleur
		out["mur_ms_max"] = pire_mur
		out["modele_gagne_toujours"] = jamais_secours

	_emettre(out)
	quit(0)


func _emettre(out: Dictionary) -> void:
	# Une seule ligne, préfixée : l'agent VM la retrouve sans dépendre de l'ordre des logs Godot
	# (le moteur natif écrit ses propres traces sur stdout).
	print("[BENCH_JSON] %s" % JSON.stringify(out))
