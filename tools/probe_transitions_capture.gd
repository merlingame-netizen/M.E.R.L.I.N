extends SceneTree
## Capture l'encre en mouvement (menu → jeu « depuis » Merlin, jeu → fin « bas ») et le verdict lisible
## (la marge sous le dé, la lune teintée, les yeux) sur un sentier écrit. Elle rend des images.
##
##     MERLIN_CAP_OUT=/un/dossier/ xvfb-run -a godot --path . --script res://tools/probe_transitions_capture.gd

var _out: String = ""


func _init() -> void:
	_run()


func _run() -> void:
	_out = OS.get_environment("MERLIN_CAP_OUT")
	if _out == "":
		_out = "user://"
	if not _out.ends_with("/"):
		_out += "/"
	await process_frame
	change_scene_to_file("res://scenes/MerlinMenu.tscn")
	await create_timer(3.0).timeout
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var s: Dictionary = MerlinSentier.charger("le_compte_juste")
	if run == null or s.is_empty():
		printerr("[TRANS] pas de run ou de sentier")
		quit(1)
		return
	run.biome = "falaises"
	run.new_run(s)
	run.beat_index = 1   # le beat 2 : Kado parle — le portrait doit s'ouvrir (09/09)
	var menu: Node = current_scene
	var origine: Vector2 = Vector2(-1.0, -1.0)
	if menu != null and menu.has_method("_origine_de_merlin"):
		origine = menu.call("_origine_de_merlin")
	print("[TRANS] origine de l'encre : %s" % str(origine))
	root.get_node("/root/MerlinTransition").change_scene("res://scenes/MerlinGame.tscn", "", "depuis", origine)
	await create_timer(0.55).timeout
	await _capturer("encre_depuis_merlin")
	await create_timer(6.0).timeout
	var jeu: Node = current_scene
	var en_jeu: bool = jeu != null and jeu.scene_file_path.ends_with("MerlinGame.tscn")
	print("[TRANS] en jeu : %s" % str(en_jeu))
	# LA PAGE QUI TOURNE revient exactement à sa place : l'encart vit dans un VBoxContainer, la glisse
	# ne doit pas le laisser décalé d'un pixel.
	var page_ok: bool = true
	if en_jeu:
		var encart: Variant = jeu.get("_situ_panel")
		if encart is Control:
			var repos: Vector2 = (encart as Control).position
			jeu.call("_present_current_beat")
			await create_timer(0.12).timeout
			var en_vol: Vector2 = (encart as Control).position
			await create_timer(1.2).timeout
			var apres: Vector2 = (encart as Control).position
			page_ok = apres.is_equal_approx(repos)
			print("[TRANS] encart : repos=%s en vol=%s après=%s → %s" % [str(repos), str(en_vol), str(apres),
				"revenu" if page_ok else "DÉCALÉ"])
			en_jeu = en_jeu and page_ok and not en_vol.is_equal_approx(repos)
	if en_jeu:
		await _capturer("portrait_kado")
		# 09/09 : Kado se souvient — on lui prête une aide passée, on re-présente : le portrait porte
		# « bien disposé · votre aide », et Merlin le présente (posture « presente »).
		var run_p: Node = root.get_node("/root/MerlinRun")
		if run_p.has_method("figure_reagit"):
			run_p.call("figure_reagit", "kado", "reussite", "PARLER", 1)
			jeu.call("_present_current_beat")
			await create_timer(1.4).timeout
			await _capturer("portrait_kado_memoire")
		# 09/09 : le registre de continuité se lit dans le Journal (« Ce que vous savez »).
		var run_j: Node = root.get_node("/root/MerlinRun")
		if run_j.has_method("noter_acquis"):
			run_j.call("noter_acquis", "Kado a menti sur le compte")
			run_j.call("noter_acquis", "la corde est trop courte de deux brasses")
		if jeu.has_method("_ouvrir_le_journal"):
			jeu.call("_ouvrir_le_journal")
			await create_timer(0.6).timeout
			await _capturer("journal_de_quete")
			var ov: Node = jeu.get_node_or_null("JournalOverlay")
			if ov != null:
				ov.queue_free()
			await create_timer(0.3).timeout
	# 09/09 : LE COUP DOUBLE armé — une tuile, deux cartes levées, le bouton qui dit « Coup double ».
	if en_jeu:
		var run_c: Node = root.get_node("/root/MerlinRun")
		jeu.set("_choice_open", true)
		jeu.set("_state", 1)
		var acts: Array = run_c.actions
		var vues: Array = []
		# La main se distribue quand la scène finit de s'écrire : on l'attend (8 s au plus), sinon on la distribue.
		for essai in 20:
			vues = []
			for c in (jeu.get("_hand_box") as Node).get_children():
				if c is MerlinCardView and not c.is_queued_for_deletion():
					vues.append(c)
			if vues.size() >= 2:
				break
			if essai == 12 and jeu.has_method("_render_hand"):
				jeu.call("_render_hand", false)
			await create_timer(0.4).timeout
		jeu.set("_choice_open", true)
		jeu.set("_state", 1)
		print("[TRANS] coup double : %d actions, %d vues de carte, main de %d" % [acts.size(), vues.size(), (run_c.hand as Array).size()])
		if acts.size() > 0 and vues.size() >= 2:
			jeu.call("_on_action_tile", acts[0])
			jeu.call("_on_trait_card", (vues[0] as MerlinCardView).card)
			jeu.call("_on_trait_card", (vues[1] as MerlinCardView).card)
			await create_timer(0.8).timeout
			print("[TRANS] coup double : bouton « %s », second trait %s" % [str((jeu.get("_resolve_btn") as Button).text),
				"posé" if jeu.get("_selected_trait2") != null else "ABSENT"])
			await _capturer("coup_double_arme")
			jeu.call("_on_trait_card", (vues[1] as MerlinCardView).card)
			jeu.call("_on_trait_card", (vues[0] as MerlinCardView).card)
			jeu.call("_on_action_tile", acts[0])
			await create_timer(0.3).timeout
	# 08/09 : le Voyageur qui marche sur le sentier d'encre de la frise, capturé en vol.
	if en_jeu:
		var carte: Variant = jeu.get("_beat_map")
		if carte is Node and (carte as Node).has_method("animate_advance"):
			(carte as Node).call("animate_advance", 4)
			await create_timer(0.3).timeout
			await _capturer("frise_voyageur_en_marche")
			await create_timer(1.0).timeout
	if en_jeu and jeu.has_method("_reagir_au_verdict"):
		jeu.call("_reagir_au_verdict", {"die": 7, "total": 10, "dc": 9, "margin": 1}, "reussite")
		await create_timer(0.6).timeout
		await _capturer("verdict_reussite")
		await create_timer(2.5).timeout
		jeu.call("_reagir_au_verdict", {"die": 4, "total": 6, "dc": 12, "margin": -6}, "echec")
		await create_timer(0.6).timeout
		await _capturer("verdict_echec")
		await create_timer(2.5).timeout
	root.get_node("/root/MerlinTransition").change_scene("res://scenes/MerlinEnd.tscn", "", "bas")
	await create_timer(0.55).timeout
	await _capturer("encre_vers_la_fin")
	await create_timer(4.0).timeout
	await _capturer("ecran_de_fin")
	print("[TRANS] %s" % ("SONDE PASSÉE" if en_jeu else "SONDE ÉCHOUÉE"))
	quit(0 if en_jeu else 1)


func _capturer(nom: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		return
	var chemin: String = "%s%s.png" % [_out, nom]
	if img.save_png(chemin) == OK:
		print("[TRANS] %s" % chemin)
