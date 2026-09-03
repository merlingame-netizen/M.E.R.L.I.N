extends SceneTree
## Épreuve de l'ÉCRAN des chroniques — celui qu'on ouvre, pas seulement le stockage.
##
##     godot --headless --path . --script res://tools/tests/test_ecran_chroniques.gd
##
## POURQUOI SÉPARÉE DE `test_journal`. Celle-là prouve que les chroniques s'écrivent et se
## relisent ; rien n'y prouve qu'on peut les OUVRIR. Un écran qui plante au premier clic laisserait
## un journal parfait et illisible — et le parse check ne le verrait pas, puisque la faute serait
## dans un `Callable` déclenché par un bouton.
##
## Elle fabrique deux chroniques, monte le menu, ouvre l'écran, entre dans une chronique, revient
## à la liste, puis nettoie exactement ce qu'elle a créé.

var _rates: int = 0
var _crees: Array = []


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	print("=== ÉPREUVE DE L'ÉCRAN DES CHRONIQUES ===\n")
	var avant: int = MerlinJournal.liste().size()

	MerlinJournal.ouvrir("La fin du rite", "foret")
	MerlinJournal.beat_pose(1, "Exploration", "Le Chœur chante à vingt pas.", "arc", 9, 7, 20, 0)
	MerlinJournal.beat_geste("OBSERVER", "La Patience")
	MerlinJournal.beat_resolu("reussite", "[i]Vous restez dans les fougères.[/i] Vous comptez.", 20, 0)
	MerlinJournal.clore("accomplissement", 20, 0, "Le rite s'achève.")
	MerlinJournal.ouvrir("La pierre couchée", "foret")
	MerlinJournal.beat_pose(1, "Exploration", "Le douzième menhir est couché.", "arc", 9, 11, 20, 0)
	MerlinJournal.beat_geste("OBSERVER", "La Méfiance")   # jouée : sans geste, elle n'existerait pas
	MerlinJournal.clore("mort", 0, 6)
	for l in MerlinJournal.liste().slice(0, 2):
		_crees.append(str((l as Dictionary).get("id", "")))

	var menu: Node = load("res://scenes/MerlinMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame

	# ── OUVRIR
	menu._on_chronicles()
	await process_frame
	var voile: Node = menu.get_node_or_null("ChroniclesOverlay")
	_verifier("l'écran s'ouvre", voile != null)
	if voile == null:
		_finir()
		return
	var panneau: Node = voile.get_node_or_null("Panneau")
	_verifier("le panneau est là", panneau != null)
	if panneau == null:
		_finir()
		return
	var boutons: Array = _boutons(panneau)
	_verifier("les traversées sont listées comme lignes cliquables", boutons.size() >= 2,
		"%d bouton(s)" % boutons.size())
	_verifier("une ligne porte le titre de la traversée",
		_texte_contient(panneau, "La pierre couchée"), _tout_le_texte(panneau).substr(0, 120))
	_verifier("l'écran ne s'ouvre pas deux fois",
		(func() -> bool:
			menu._on_chronicles()
			var n: int = 0
			for e in menu.get_children():
				if e.name == "ChroniclesOverlay":
					n += 1
			return n == 1).call())

	# ── ENTRER DANS UNE CHRONIQUE
	if not boutons.is_empty():
		(boutons[0] as Button).emit_signal("pressed")
		await process_frame
		_verifier("le détail montre la prose du beat",
			_texte_contient(panneau, "menhir") or _texte_contient(panneau, "Chœur"),
			_tout_le_texte(panneau).substr(0, 160))
		var retours: Array = _boutons(panneau)
		_verifier("le détail offre un retour", not retours.is_empty())
		# ── REVENIR
		if not retours.is_empty():
			(retours[retours.size() - 1] as Button).emit_signal("pressed")
			await process_frame
			_verifier("le retour ramène à la liste",
				_boutons(panneau).size() >= 2, "%d bouton(s)" % _boutons(panneau).size())

	# ── LA LISTE VIDE DIT POURQUOI (cas du tout premier lancement)
	_nettoyer()
	voile.queue_free()
	await process_frame
	menu._on_chronicles()
	await process_frame
	var v2: Node = menu.get_node_or_null("ChroniclesOverlay")
	var p2: Node = v2.get_node_or_null("Panneau") if v2 != null else null
	_verifier("sans aucune chronique, l'écran explique au lieu de rester muet",
		p2 != null and _texte_contient(p2, "Aucune traversée enregistrée"),
		_tout_le_texte(p2).substr(0, 120) if p2 != null else "pas de panneau")

	print("\nindex remis à %d (départ : %d)" % [MerlinJournal.liste().size(), avant])
	_finir()


func _finir() -> void:
	_nettoyer()
	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE",
		_rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)


func _boutons(n: Node) -> Array:
	var out: Array = []
	for e in n.get_children():
		if e is Button:
			out.append(e)
		out.append_array(_boutons(e))
	return out


func _tout_le_texte(n: Node) -> String:
	var s: String = ""
	for e in n.get_children():
		if e is Label:
			s += str((e as Label).text) + " "
		elif e is RichTextLabel:
			s += str((e as RichTextLabel).text) + " "   # la prose vit ici depuis p93
		elif e is Button:
			s += str((e as Button).text) + " "
		s += _tout_le_texte(e)
	return s


func _texte_contient(n: Node, quoi: String) -> bool:
	return _tout_le_texte(n).contains(quoi)


## Retire UNIQUEMENT les chroniques fabriquées ici — les vraies parties ne sont pas des déchets
## de test. Sûr à appeler deux fois.
func _nettoyer() -> void:
	if _crees.is_empty():
		return
	var d: DirAccess = DirAccess.open(MerlinJournal.DOSSIER)
	if d != null:
		for id in _crees:
			if id != "":
				d.remove("%s.json" % id)
	var lignes: Array = []
	var f: FileAccess = FileAccess.open(MerlinJournal.INDEX, FileAccess.READ)
	if f != null:
		var brut: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(brut) == TYPE_ARRAY:
			for l in (brut as Array):
				if not _crees.has(str((l as Dictionary).get("id", ""))):
					lignes.append(l)
	var g: FileAccess = FileAccess.open(MerlinJournal.INDEX, FileAccess.WRITE)
	if g != null:
		g.store_string(JSON.stringify(lignes, " "))
		g.close()
	_crees.clear()
