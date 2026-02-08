extends Control

@onready var enemy_hp = $EnemyHP
@onready var player_hp = $PlayerHP
@onready var battle_text = $DialoguePanel/DialogueHBox/TextBox/BattleText
@onready var btn_fight = $DialoguePanel/DialogueHBox/Menu/BtnFight
@onready var btn_bag = $DialoguePanel/DialogueHBox/Menu/BtnBag
@onready var btn_run = $DialoguePanel/DialogueHBox/Menu/BtnRun
@onready var pause_panel = $PauseLayer/PausePanel
@onready var pause_btn_menu = $PauseLayer/PausePanel/VBox/BtnMenu
@onready var pause_btn_combat = $PauseLayer/PausePanel/VBox/BtnTestCombat
@onready var pause_btn_aventure = $PauseLayer/PausePanel/VBox/BtnTestAventure
@onready var pause_btn_antre = $PauseLayer/PausePanel/VBox/BtnTestAntre

var enemy_max := 100
var player_max := 120
var enemy_name := "Forest Foe"
var player_name := "Bestiole"
var battle_over := false
var pause_visible := false

func _ready():
	randomize()
	enemy_hp.max_value = enemy_max
	enemy_hp.value = enemy_max
	player_hp.max_value = player_max
	player_hp.value = player_max
	btn_fight.pressed.connect(_on_fight_pressed)
	btn_bag.pressed.connect(_on_bag_pressed)
	btn_run.pressed.connect(_on_run_pressed)
	pause_panel.visible = false
	pause_btn_menu.pressed.connect(func(): _change_scene("res://scenes/MenuPrincipal.tscn"))
	pause_btn_combat.pressed.connect(func(): _change_scene("res://scenes/TestCombat.tscn"))
	pause_btn_aventure.pressed.connect(func(): _change_scene("res://scenes/TestAventure.tscn"))
	pause_btn_antre.pressed.connect(func(): _change_scene("res://scenes/TestAntreMerlin.tscn"))
	_set_text("A wild " + enemy_name + " appears!")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		return
	if pause_visible:
		return
	if battle_over:
		return
	if event.is_action_pressed("ui_accept"):
		_on_fight_pressed()

func _on_fight_pressed():
	if battle_over:
		return
	var dmg = randi_range(8, 18)
	enemy_hp.value = max(enemy_hp.value - dmg, 0)
	_set_text("You strike for " + str(dmg) + " damage!")
	if enemy_hp.value <= 0:
		battle_over = true
		_set_text(enemy_name + " fainted!")

func _on_bag_pressed():
	if battle_over:
		return
	_set_text("Your bag is empty...")

func _on_run_pressed():
	if battle_over:
		return
	_set_text("You cannot run now!")

func _set_text(text: String):
	battle_text.text = text

func _toggle_pause():
	pause_visible = not pause_visible
	pause_panel.visible = pause_visible

func _change_scene(path: String):
	pause_visible = false
	pause_panel.visible = false
	get_tree().change_scene_to_file(path)
