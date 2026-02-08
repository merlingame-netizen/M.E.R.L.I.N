@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("ACVoicebox", "AudioStreamPlayer", preload("res://addons/acvoicebox/acvoicebox.gd"), null)

func _exit_tree() -> void:
	remove_custom_type("ACVoicebox")
