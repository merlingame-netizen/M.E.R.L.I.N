extends Control

@onready var player = $Map/Player
@onready var path_line = $Map/PathLine
@onready var event_label = $HUD/EventLabel
@onready var hint_label = $HUD/HintLabel
@onready var pause_panel = $PauseLayer/PausePanel
@onready var pause_btn_menu = $PauseLayer/PausePanel/VBox/BtnMenu
@onready var pause_btn_combat = $PauseLayer/PausePanel/VBox/BtnTestCombat
@onready var pause_btn_aventure = $PauseLayer/PausePanel/VBox/BtnTestAventure
@onready var pause_btn_antre = $PauseLayer/PausePanel/VBox/BtnTestAntre

var points := [
	Vector2(120, 180),
	Vector2(260, 140),
	Vector2(420, 200),
	Vector2(580, 160),
	Vector2(740, 220)
]

var events := [
	"You found a strange rune.",
	"A breeze whispers old names.",
	"You spot a hidden trail.",
	"A tiny spirit greets you.",
	"The path is quiet and calm."
]

var current_index := 0
var pause_visible := false

func _ready():
	randomize()
	path_line.points = points
	_move_to_point(0)
	hint_label.text = "Left/Right: move   Enter: event"
	_show_event("Your journey begins...")
	pause_panel.visible = false
	pause_btn_menu.pressed.connect(func(): _change_scene("res://scenes/MenuPrincipal.tscn"))
	pause_btn_combat.pressed.connect(func(): _change_scene("res://scenes/TestCombat.tscn"))
	pause_btn_aventure.pressed.connect(func(): _change_scene("res://scenes/TestAventure.tscn"))
	pause_btn_antre.pressed.connect(func(): _change_scene("res://scenes/TestAntreMerlin.tscn"))

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if pause_visible:
		return
	if event.is_action_pressed("ui_right"):
		_step(1)
	elif event.is_action_pressed("ui_left"):
		_step(-1)
	elif event.is_action_pressed("ui_accept"):
		_show_event(_random_event())

func _step(dir: int):
	var next_index = clamp(current_index + dir, 0, points.size() - 1)
	if next_index == current_index:
		return
	current_index = next_index
	_move_to_point(current_index)
	_show_event(_random_event())

func _move_to_point(index: int):
	player.position = points[index]

func _random_event() -> String:
	return events[randi() % events.size()]

func _show_event(text: String):
	event_label.text = "Event: " + text

func _toggle_pause():
	pause_visible = not pause_visible
	pause_panel.visible = pause_visible

func _change_scene(path: String):
	pause_visible = false
	pause_panel.visible = false
	get_tree().change_scene_to_file(path)
