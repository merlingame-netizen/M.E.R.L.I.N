extends Node
class_name GameStateSync

var state: Dictionary = {}

func apply_action(action: Dictionary) -> void:
	# Placeholder: hook into your game systems.
	state["last_action"] = action
