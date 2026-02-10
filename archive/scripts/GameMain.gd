extends Control

func _ready():
	print("GameMain chargé - Appuyez sur ÉCHAP pour retourner au menu")

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
