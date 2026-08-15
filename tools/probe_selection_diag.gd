extends SceneTree
## Pourquoi l'écran de sélection reste sans titres — état du moteur SECONDE PAR SECONDE.
##
## Le smoke de l'écran a montré un renoncement SANS génération et SANS motif : ni réussite,
## ni échec déclaré. `ensure_selection_prefetch()` ne lance rien tant que le moteur n'est pas
## `is_ready() and not is_busy()` — si cette condition n'arrive jamais, l'attente tourne à vide
## 120 s puis rend la main au menu, sans que personne ait rien tenté ni rien dit.
##
## Cette sonde ne devine pas : elle relève l'état réel de MerlinNative à chaque seconde pour
## nommer LEQUEL des trois verrous ne s'ouvre pas (chargement, occupation, échec de boot).
##
##   MERLIN_ALLOW_HEADLESS_LLM=1 godot --headless --path . --script res://tools/probe_selection_diag.gd

const DUREE_S: int = 90


func _init() -> void:
	_run()


func _run() -> void:
	var mn: Node = null
	var sc: Node = null
	var t0: int = Time.get_ticks_msec()
	while (mn == null or sc == null) and (Time.get_ticks_msec() - t0) < 10000:
		await create_timer(0.05).timeout
		mn = root.get_node_or_null("MerlinNative")
		sc = root.get_node_or_null("MerlinScenario")
	if mn == null or sc == null:
		print("[DIAG] autoloads absents")
		quit(2)
		return

	print("[DIAG] affichage=%s · suivi sur %d s" % [DisplayServer.get_name(), DUREE_S])
	var precedent: String = ""
	var pret_a: int = -1
	t0 = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < DUREE_S * 1000:
		var s: int = int((Time.get_ticks_msec() - t0) / 1000.0)
		var etat: String = "pret=%s occupe=%s boot_error=%s sel=%s" % [
			str(mn.is_ready()), str(mn.is_busy()),
			str(mn.boot_error()) if mn.has_method("boot_error") else "?",
			str(sc.selection_motif()) if sc.has_method("selection_motif") else "?"]
		# On n'imprime QUE les changements : 90 lignes identiques noieraient le moment qui compte.
		if etat != precedent:
			print("[DIAG] t+%02ds  %s" % [s, etat])
			precedent = etat
		if mn.is_ready() and pret_a < 0:
			pret_a = s
			# Dès que le moteur est prêt, on fait ce que l'écran ferait : demander la sélection.
			# S'il échoue ICI, le motif apparaîtra à la ligne suivante — c'est tout l'intérêt.
			print("[DIAG] moteur prêt à t+%ds → lancement de la sélection" % s)
			sc.ensure_selection_prefetch()
		await create_timer(1.0).timeout

	print("[DIAG] --- bilan ---")
	print("[DIAG] moteur prêt à : %s" % ("jamais" if pret_a < 0 else "t+%ds" % pret_a))
	print("[DIAG] sélection prête : %s" % str(sc.is_selection_ready()))
	print("[DIAG] sélection en échec : %s" % str(sc.is_selection_failed()))
	print("[DIAG] motif : %s" % str(sc.selection_motif() if sc.has_method("selection_motif") else "?"))
	quit(0)
