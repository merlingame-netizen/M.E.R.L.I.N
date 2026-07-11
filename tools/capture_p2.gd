extends SceneTree
## Capture QA P2 (« la récompense visible ») : cartes de draft (4 kinds + libellés d'effet +
## nœud de talent nommé) + MerlinEnd RICHE (récap : VOIE, degrés, corruption max, greffes, verbes,
## faits, fragment N/12). VERSION-AGNOSTIQUE : détecte set_effect_line (nouvelle API) pour servir
## BEFORE (code stashé) comme AFTER. Lancer NON-headless :
##   MERLIN_CAP_TAG=after  Godot --path . --script res://tools/capture_p2.gd
## Sortie : output/captures/p2/<tag>/*.png

const OUT_ROOT: String = "res://output/captures/p2/"
var _dir: String = ""


func _init() -> void:
	_run()


func _run() -> void:
	var tag: String = OS.get_environment("MERLIN_CAP_TAG")
	if tag == "":
		tag = "after"
	_dir = OUT_ROOT + tag + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	await process_frame
	await _wait(0.4)
	await _cap_draft_cards()
	for combo in [["accomplissement", "foret"], ["accomplissement", "falaises"], ["mort", "foret"], ["corrompu", "foret"]]:
		await _cap_end(str(combo[0]), str(combo[1]))
	print("[P2CAP] done tag=%s dir=%s" % [tag, _dir])
	quit()


func _wait(sec: float) -> void:
	var dl: int = Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < dl:
		await process_frame


func _cap(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("[P2CAP][ANOMALIE] %s image nulle" % nm)
		return
	var path: String = _dir + nm + ".png"
	if img.save_png(path) == OK:
		print("[P2CAP] %s (%dx%d)" % [nm, img.get_width(), img.get_height()])
	else:
		print("[P2CAP][ANOMALIE] %s save échouée" % nm)


# --- A) rangée de cartes de draft (4 kinds), avec libellés d'effet + badges ---
func _cap_draft_cards() -> void:
	var CardView: GDScript = load("res://scripts/game/merlin_card_view.gd")
	var host: Control = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var bg: ColorRect = ColorRect.new()
	bg.color = MerlinVisual.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var title: Label = Label.new()
	title.text = "Cartes de draft : libellé d'effet + nœud de talent nommé"
	title.add_theme_color_override("font_color", MerlinVisual.GOLD)
	title.add_theme_font_size_override("font_size", 22)
	title.position = Vector2(40, 24)
	host.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.position = Vector2(40, 90)
	host.add_child(row)
	# 4 cartes de présentation, une par kind
	var specs: Array = [
		{"kind": "roll", "name": "La Charge du Déchu", "tags": [], "rar": "Rare", "eff": "", "ev": 0, "amount": 1, "line": "+1 à tes jets sur ce verbe"},
		{"kind": "tag", "name": "Le Pacte de Lisière", "tags": ["Vision"], "rar": "Commune", "eff": "", "ev": 0, "corr": 1, "line": "Ce verbe répondra à plus de scènes"},
		{"kind": "charge", "name": "Le Bras de Fer", "tags": [], "rar": "Commune", "eff": "HEAL", "ev": 1, "line": "Apaise ta blessure (+1) · 2 fois"},
		{"kind": "talent", "name": "Renforcer PARLER", "tags": ["Verbe"], "rar": "Mythique", "eff": "", "ev": 0, "amount": 1, "verb": "PARLER", "line": "Ce verbe frappe plus juste"},
	]
	var new_api: bool = false
	for sp in specs:
		var card: MerlinCard = MerlinCard.make(str(sp.get("kind", "")) + "_demo", str(sp["name"]), sp["tags"], "Évocation de démonstration.", int(sp.get("corr", 0)), str(sp["rar"]), str(sp["eff"]), int(sp["ev"]))
		var cv: Control = CardView.new()
		row.add_child(cv)
		cv.setup(card)
		new_api = cv.has_method("set_effect_line")
		if str(sp["kind"]) == "talent":
			if new_api:
				cv.set_talent_node(int(sp.get("amount", 1)), str(sp.get("verb", "")))
			else:
				cv.set_talent_node(int(sp.get("amount", 1)))
		elif str(sp["kind"]) == "roll":
			cv.set_roll_bonus(int(sp.get("amount", 1)))
		if new_api:
			cv.set_effect_line(str(sp["line"]))
	await _wait(1.4)
	await _cap("draft_cards")
	host.queue_free()
	await _wait(0.2)


# --- B) MerlinEnd riche : peuple la run autoload puis charge la scène de fin ---
func _cap_end(end_type: String, biome: String) -> void:
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		print("[P2CAP][ANOMALIE] autoloads absents pour end")
		return
	run.biome = biome
	var skel: Dictionary = sc.build_skeleton("La Fontaine qui Rêve", "Sonde la source noire où dorment les visages.")
	run.new_run(skel)
	# Récap déterministe (champs descriptifs directs + quelques greffes réelles).
	run.set("degree_counts", {"eclatante": 3, "reussite": 6, "partiel": 2, "echec": 1})
	run.set("corruption_max", 9 if end_type == "corrompu" else 6)
	run.set("archetype_scores", {"Social": 7, "Mystique": 2, "Défensif": 1})
	run.set("talent", {"PERCEVOIR": 1, "AGIR": 0, "PARLER": 2, "RESSENTIR": 0})
	run.set("cartes_notables", ["La Voix d'Autorité", "Le Serment Tenu", "La Transe Druidique"])
	run.set("faits_marquants", ["Le Chœur des Druides t'a béni", "Tu as tenu ta promesse à l'Enfant"])
	# 3 greffes réelles sur PERCEVOIR pour un total_grafts non nul
	var banks: Array = MerlinCard.graft_banks("")
	var act_id: String = ""
	for a in run.actions:
		if a is MerlinCard and (a as MerlinCard).card_name == "PERCEVOIR":
			act_id = str((a as MerlinCard).id)
	for gi in mini(3, banks.size()):
		if act_id != "":
			run.apply_graft(act_id, banks[gi])
	if end_type == "corrompu":
		run.set("integrite", 4)
		run.set("corruption", 18)
	elif end_type == "mort":
		run.set("integrite", 0)
		run.set("corruption", 7)
	else:
		run.set("integrite", 8)
		run.set("corruption", 5)
	run.set("end_type", end_type)
	change_scene_to_file("res://scenes/MerlinEnd.tscn")
	await _wait(2.6)  # _ready + call_deferred(_run_end) + entrance anim + typewriter start
	await _cap("end_%s_%s" % [end_type, biome])
