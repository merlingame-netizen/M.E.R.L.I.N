@tool
extends EditorPlugin

const DOCK_SCENE := preload("res://addons/gd_script_deployer/ui/deployer_dock.tscn")

var _dock_instance: Control

func _enter_tree() -> void:
	if DOCK_SCENE:
		_dock_instance = DOCK_SCENE.instantiate()
		if _dock_instance.has_method("set_plugin"):
			_dock_instance.set_plugin(self)
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock_instance)


func _exit_tree() -> void:
	if _dock_instance:
		remove_control_from_docks(_dock_instance)
		_dock_instance.free()
		_dock_instance = null
