## ═══════════════════════════════════════════════════════════════════════════════
## Run3DController — Minimal run loop: walk forest → encounter → end
## ═══════════════════════════════════════════════════════════════════════════════
extends Node3D
class_name Run3DController

signal run_ended(reason: String, data: Dictionary)

const HUB_SCENE: String = "res://scenes/MerlinCabinHub.tscn"

@onready var _forest: Node3D = get_node_or_null("BroceliandeForest3D")

var _cards_played: int = 0
var _life: int = 100


func _ready() -> void:
	_register_with_gameflow()
	if _forest and _forest.has_signal("encounter_triggered"):
		_forest.connect("encounter_triggered", _on_encounter)


func _register_with_gameflow() -> void:
	var gf: Node = get_node_or_null("/root/GameFlow")
	if gf and gf.has_method("wire_run"):
		gf.wire_run(self)


func _on_encounter() -> void:
	_cards_played += 1
	if _life <= 0 or _cards_played >= 5:
		end_run("natural", {"cards_played": _cards_played, "life": _life})


func end_run(reason: String, data: Dictionary) -> void:
	run_ended.emit(reason, data)
