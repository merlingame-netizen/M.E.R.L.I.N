## ═══════════════════════════════════════════════════════════════════════════════
## MerlinCabinHub — Controller for the 3D PS1-era cabin hub
## ═══════════════════════════════════════════════════════════════════════════════
## All geometry and lighting live in the .tscn scene file (MerlinCabinHub.tscn).
## This script only:
##   • registers with GameFlowController via wire_hub()
##   • routes FPS rig interaction signals → run_requested / talent_tree_requested
##   • manages the interaction hint label
## ═══════════════════════════════════════════════════════════════════════════════
extends Node3D
class_name MerlinCabinHub

# Hub contract signals consumed by GameFlow.wire_hub()
signal run_requested(biome_id: String, selected_oghams: Array)
signal talent_tree_requested()
signal quit_requested()

@onready var _rig: Node = get_node_or_null("FpsRig")
@onready var _hint_label: Label = get_node_or_null("UI/HintLabel")

var _selected_biome: String = "foret_broceliande"
var _selected_oghams: Array = ["beith"]


func _ready() -> void:
	_pull_oghams_from_store()
	_wire_rig_signals()
	_register_with_gameflow()
	if _hint_label:
		_hint_label.visible = false


func _pull_oghams_from_store() -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store == null or not "state" in store:
		return
	var oghams: Dictionary = store.state.get("oghams", {})
	var equipped: Array = oghams.get("skills_equipped", [])
	if equipped.size() > 0:
		_selected_oghams = equipped.duplicate()


func _wire_rig_signals() -> void:
	if _rig == null:
		return
	if _rig.has_signal("interaction_hovered"):
		_rig.connect("interaction_hovered", _on_hovered)
	if _rig.has_signal("interaction_lost"):
		_rig.connect("interaction_lost", _on_hover_lost)
	if _rig.has_signal("interaction_triggered"):
		_rig.connect("interaction_triggered", _on_interact)


func _register_with_gameflow() -> void:
	var gf: Node = get_node_or_null("/root/GameFlow")
	if gf != null and gf.has_method("wire_hub"):
		gf.wire_hub(self)


func _on_hovered(interact_id: String, _target: Node) -> void:
	if _hint_label == null:
		return
	var prompt: String = ""
	match interact_id:
		"wall_map":
			prompt = "> Carte de Broceliande  [E] partir en quete"
		"tapestry":
			prompt = "> Tapisserie des Talents  [E] consulter"
		"cauldron":
			prompt = "> Chaudron  [E] (bientot)"
		"door":
			prompt = "> Porte de sortie  [E] retour au menu"
		_:
			prompt = "> %s  [E]" % interact_id
	_hint_label.text = prompt
	_hint_label.visible = true


func _on_hover_lost() -> void:
	if _hint_label:
		_hint_label.visible = false


func _on_interact(interact_id: String, _target: Node) -> void:
	match interact_id:
		"wall_map":
			if _rig != null and _rig.has_method("set_mouse_captured"):
				_rig.set_mouse_captured(false)
			run_requested.emit(_selected_biome, _selected_oghams)
		"tapestry":
			talent_tree_requested.emit()
		"door":
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm:
				gm.set_meta("show_menu_on_boot", true)
			quit_requested.emit()
		"cauldron":
			pass  # Merlin dialogue (future)
