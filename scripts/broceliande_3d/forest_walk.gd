## ═══════════════════════════════════════════════════════════════════════════════
## ForestWalk — Minimal FPS walk controller for BroceliandeForest3D
## ═══════════════════════════════════════════════════════════════════════════════
## Routes FpsRig signals → encounter triggers → scene transitions.
## All geometry lives in BroceliandeForest3D.tscn (native nodes).
## ═══════════════════════════════════════════════════════════════════════════════
extends Node3D

signal encounter_triggered

const HUB_SCENE: String = "res://scenes/MerlinCabinHub.tscn"

@onready var _rig: Node = get_node_or_null("FpsRig")
@onready var _hint_label: Label = get_node_or_null("HUD/HintLabel")
@onready var _encounter_zone: Area3D = get_node_or_null("EncounterZone")

var _encounter_ready: bool = true


func _ready() -> void:
	if _rig:
		if _rig.has_signal("interaction_hovered"):
			_rig.connect("interaction_hovered", _on_hovered)
		if _rig.has_signal("interaction_lost"):
			_rig.connect("interaction_lost", _on_hover_lost)
		if _rig.has_signal("interaction_triggered"):
			_rig.connect("interaction_triggered", _on_interact)
	if _encounter_zone:
		_encounter_zone.connect("body_entered", _on_encounter_zone_entered)
	if _hint_label:
		_hint_label.visible = false


func _on_hovered(interact_id: String, _target: Node) -> void:
	if _hint_label == null:
		return
	var prompt: String = ""
	match interact_id:
		"return_stone":
			prompt = "> Pierre de retour  [E] rentrer"
		_:
			prompt = "> %s  [E]" % interact_id
	_hint_label.text = prompt
	_hint_label.visible = true


func _on_hover_lost() -> void:
	if _hint_label:
		_hint_label.visible = false


func _on_interact(interact_id: String, _target: Node) -> void:
	match interact_id:
		"return_stone":
			_go_to_hub()


func _on_encounter_zone_entered(body: Node3D) -> void:
	if not _encounter_ready:
		return
	if body == _rig:
		_encounter_ready = false
		encounter_triggered.emit()


func _go_to_hub() -> void:
	if _rig != null and _rig.has_method("set_mouse_captured"):
		_rig.set_mouse_captured(false)
	get_tree().change_scene_to_file(HUB_SCENE)
