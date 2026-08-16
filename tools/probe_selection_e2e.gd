extends SceneTree
## LE test : la sélection rend-elle trois titres, oui ou non ?
##
## POURQUOI IL EXISTE. J'ai livré trois correctifs d'affilée en annonçant une cause, sans jamais
## avoir VU la sélection réussir — en me contentant d'un smoke « ça ne plante pas », qui ne dit
## rien de ce qui intéresse le joueur. Maxime : « test en smoke TOUJOURS avant de livrer ».
## Ce fichier est ce test. Verdict binaire, jamais une impression.
##
## Il ne simule rien : il pose un biome et appelle `warmup_and_prefetch_selection`, exactement
## comme `_on_biome_picked` au tap du joueur, puis interroge le même état que l'écran
## (`is_selection_ready`, `is_selection_failed`, `selection_motif`).
##
##   MERLIN_ALLOW_HEADLESS_LLM=1 godot --headless --path . --script res://tools/probe_selection_e2e.gd
##
## Réglages : MERLIN_E2E_BIOME (défaut foret), MERLIN_E2E_TOURS (défaut 1 — nombre de sélections
## enchaînées DANS LA MÊME session, pour éprouver la reprise après un moteur coincé).

const CHARGE_TIMEOUT_MS: int = 120000   # laisser le modèle se charger (mesuré ~4 s, marge large)
const SEL_TIMEOUT_MS: int = 240000      # au-delà, c'est un échec — même si ça finirait par venir


func _init() -> void:
	_run()


func _attendre_noeud(nom: String, budget_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < budget_ms:
		var n: Node = root.get_node_or_null(nom)
		if n != null:
			return n
		await create_timer(0.05).timeout
	return null


func _run() -> void:
	var mn: Node = await _attendre_noeud("MerlinNative", 15000)
	var sc: Node = await _attendre_noeud("MerlinScenario", 15000)
	var run: Node = await _attendre_noeud("MerlinRun", 15000)
	if mn == null or sc == null or run == null:
		_verdict(false, "autoloads absents", 0, [])
		return

	var biome: String = OS.get_environment("MERLIN_E2E_BIOME")
	if biome == "":
		biome = "foret"
	run.biome = biome
	var tours: int = maxi(1, int(OS.get_environment("MERLIN_E2E_TOURS")))

	# Le modèle doit être chargé AVANT de lancer quoi que ce soit : sans ça on mesurerait le
	# chargement en plus de la génération, et le chiffre ne serait comparable à rien.
	var t0: int = Time.get_ticks_msec()
	while not mn.is_ready() and (Time.get_ticks_msec() - t0) < CHARGE_TIMEOUT_MS:
		if mn.has_method("boot_error") and str(mn.boot_error()) != "":
			_verdict(false, "moteur indisponible : %s" % str(mn.boot_error()), 0, [])
			return
		await create_timer(0.25).timeout
	if not mn.is_ready():
		_verdict(false, "modèle jamais chargé", Time.get_ticks_msec() - t0, [])
		return
	print("[E2E] modèle prêt en %.1f s · biome=%s · %d tour(s)"
			% [(Time.get_ticks_msec() - t0) / 1000.0, biome, tours])

	var durees: Array = []
	for tour in tours:
		# EXACTEMENT ce que fait _on_biome_picked : on repart d'un crédit neuf puis on lance.
		sc.invalidate_selection()
		var t_sel: int = Time.get_ticks_msec()
		sc.warmup_and_prefetch_selection()

		# On boucle comme l'écran : ensure_selection_prefetch relance si besoin (2e essai).
		while not sc.is_selection_ready() and not sc.is_selection_failed() \
				and (Time.get_ticks_msec() - t_sel) < SEL_TIMEOUT_MS:
			sc.ensure_selection_prefetch()
			await create_timer(0.25).timeout
		var mur: int = Time.get_ticks_msec() - t_sel
		durees.append(mur)

		if not sc.is_selection_ready():
			var motif: String = str(sc.selection_motif()) if sc.has_method("selection_motif") else ""
			_verdict(false, "tour %d : %s" % [tour + 1, motif if motif != "" else "délai dépassé"],
					mur, durees)
			return
		var sels: Array = await sc.take_selection()
		if sels.size() < 3:
			_verdict(false, "tour %d : seulement %d titre(s)" % [tour + 1, sels.size()], mur, durees)
			return
		var titres: Array = []
		for s in sels:
			titres.append(str((s as Dictionary).get("title", "")))
		print("[E2E] tour %d : %.1f s · %s" % [tour + 1, mur / 1000.0, str(titres)])

	_verdict(true, "%d sélection(s) réussie(s)" % tours, durees[durees.size() - 1], durees)


func _verdict(ok: bool, detail: String, mur_ms: int, durees: Array) -> void:
	# Une ligne JSON pour l'agent, une ligne lisible pour l'humain. Le code de sortie porte le
	# verdict : un test qui rend toujours 0 ne peut bloquer aucune livraison.
	var d: Dictionary = {
		"ok": ok, "detail": detail, "mur_ms": mur_ms,
		"durees_ms": durees, "t": Time.get_datetime_string_from_system(true),
	}
	print("[E2E_JSON] " + JSON.stringify(d))
	print("[E2E] %s — %s (%.1f s)" % ["RÉUSSI" if ok else "ÉCHOUÉ", detail, mur_ms / 1000.0])
	quit(0 if ok else 1)
