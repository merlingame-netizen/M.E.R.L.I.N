## ═══════════════════════════════════════════════════════════════════════════════
## Menu3DPC — First-person exterior view of Merlin's cabin (PS1-era main menu)
## ═══════════════════════════════════════════════════════════════════════════════
## All geometry/lighting lives in Menu3DPC.tscn (native nodes, no procedural code).
## This script only routes FPS rig interactions:
##   • cabin_door  → load MerlinCabinHub
##   • quit_sign   → quit application
##
## The first-boot fast path skips this scene entirely (IntroCeltOS goes straight
## to MerlinCabinHub). Menu3DPC is reached only when the player exits via the
## cabin Door, which sets GameManager.show_menu_on_boot.
## ═══════════════════════════════════════════════════════════════════════════════
extends Node3D

const CABIN_SCENE: String = "res://scenes/MerlinCabinHub.tscn"

@onready var _rig: Node = get_node_or_null("FpsRig")
@onready var _hint_label: Label = get_node_or_null("UI/HintLabel")


func _ready() -> void:
	if _rig:
		if _rig.has_signal("interaction_hovered"):
			_rig.connect("interaction_hovered", _on_hovered)
		if _rig.has_signal("interaction_lost"):
			_rig.connect("interaction_lost", _on_hover_lost)
		if _rig.has_signal("interaction_triggered"):
			_rig.connect("interaction_triggered", _on_interact)
	if _hint_label:
		_hint_label.visible = false


func _on_hovered(interact_id: String, _target: Node) -> void:
	if _hint_label == null:
		return
	var prompt: String = ""
	match interact_id:
		"cabin_door":
			prompt = "> Porte de l'Antre  [E] entrer"
		"quit_sign":
			prompt = "> Pierre de fin  [E] quitter"
		_:
			prompt = "> %s  [E]" % interact_id
	_hint_label.text = prompt
	_hint_label.visible = true


func _on_hover_lost() -> void:
	if _hint_label:
		_hint_label.visible = false


func _on_interact(interact_id: String, _target: Node) -> void:
	match interact_id:
		"cabin_door":
			if _rig != null and _rig.has_method("set_mouse_captured"):
				_rig.set_mouse_captured(false)
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm and gm.has_meta("show_menu_on_boot"):
				gm.remove_meta("show_menu_on_boot")
			get_tree().change_scene_to_file(CABIN_SCENE)
		"quit_sign":
			get_tree().quit()
