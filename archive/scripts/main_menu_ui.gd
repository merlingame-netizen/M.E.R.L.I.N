extends CanvasLayer
class_name MainMenuUI

## Main Menu UI Controller
## Handles button interactions and menu navigation

signal play_pressed
signal continue_pressed
signal grimoire_pressed
signal options_pressed
signal quit_pressed

# UI References
@onready var new_game_btn: Button = $MainContainer/ButtonContainer/NouvellePartie
@onready var continue_btn: Button = $MainContainer/ButtonContainer/Continuer
@onready var grimoire_btn: Button = $MainContainer/ButtonContainer/Grimoire
@onready var options_btn: Button = $MainContainer/ButtonContainer/Options
@onready var quit_btn: Button = $MainContainer/ButtonContainer/Quitter
@onready var quote_label: Label = $MainContainer/QuoteContainer/MerlinQuote

# Animation parameters
var button_hover_scale: float = 1.05
var button_normal_scale: float = 1.0
var animation_duration: float = 0.15

# Merlin quotes pool
var merlin_quotes: Array[String] = [
	"\"Les mots sont les racines de la magie, et la magie est la voix des arbres.\"",
	"\"Chaque rune porte en elle le souffle des anciens druides.\"",
	"\"La sagesse ne se trouve pas dans la victoire, mais dans la compréhension.\"",
	"\"Les oghams murmurent à ceux qui savent écouter.\"",
	"\"Le temps est un cercle, comme les anneaux d'un chêne millénaire.\"",
	"\"La vraie puissance réside dans l'harmonie des éléments.\"",
	"\"Celui qui maîtrise les mots maîtrise le monde.\"",
	"\"Les étoiles guident ceux qui cherchent leur chemin dans l'obscurité.\""
]

var quote_timer: Timer
var current_quote_index: int = 0

func _ready() -> void:
	_connect_buttons()
	_setup_quote_rotation()
	_animate_intro()

func _connect_buttons() -> void:
	if new_game_btn:
		new_game_btn.pressed.connect(_on_new_game_pressed)
		new_game_btn.mouse_entered.connect(_on_button_hover.bind(new_game_btn))
		new_game_btn.mouse_exited.connect(_on_button_exit.bind(new_game_btn))
	
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
		continue_btn.mouse_entered.connect(_on_button_hover.bind(continue_btn))
		continue_btn.mouse_exited.connect(_on_button_exit.bind(continue_btn))
	
	if grimoire_btn:
		grimoire_btn.pressed.connect(_on_grimoire_pressed)
		grimoire_btn.mouse_entered.connect(_on_button_hover.bind(grimoire_btn))
		grimoire_btn.mouse_exited.connect(_on_button_exit.bind(grimoire_btn))
	
	if options_btn:
		options_btn.pressed.connect(_on_options_pressed)
		options_btn.mouse_entered.connect(_on_button_hover.bind(options_btn))
		options_btn.mouse_exited.connect(_on_button_exit.bind(options_btn))
	
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
		quit_btn.mouse_entered.connect(_on_button_hover.bind(quit_btn))
		quit_btn.mouse_exited.connect(_on_button_exit.bind(quit_btn))

func _setup_quote_rotation() -> void:
	quote_timer = Timer.new()
	quote_timer.wait_time = 15.0
	quote_timer.autostart = true
	quote_timer.timeout.connect(_rotate_quote)
	add_child(quote_timer)

func _rotate_quote() -> void:
	if not quote_label:
		return
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(quote_label, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	# Change quote
	current_quote_index = (current_quote_index + 1) % merlin_quotes.size()
	quote_label.text = merlin_quotes[current_quote_index]
	
	# Fade in
	var tween2 = create_tween()
	tween2.tween_property(quote_label, "modulate:a", 1.0, 0.5)

func _animate_intro() -> void:
	# Animate buttons appearing one by one
	var buttons = [new_game_btn, continue_btn, grimoire_btn, options_btn, quit_btn]
	
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn:
			btn.modulate.a = 0.0
			btn.position.x += 50
			
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(i * 0.1)
			tween.tween_property(btn, "position:x", btn.position.x - 50, 0.3).set_delay(i * 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_button_hover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(button_hover_scale, button_hover_scale), animation_duration).set_ease(Tween.EASE_OUT)

func _on_button_exit(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(button_normal_scale, button_normal_scale), animation_duration).set_ease(Tween.EASE_OUT)

func _on_new_game_pressed() -> void:
	print("New Game pressed")
	play_pressed.emit()
	# Transition animation could be added here

func _on_continue_pressed() -> void:
	print("Continue pressed")
	continue_pressed.emit()

func _on_grimoire_pressed() -> void:
	print("Grimoire pressed")
	grimoire_pressed.emit()

func _on_options_pressed() -> void:
	print("Options pressed")
	options_pressed.emit()

func _on_quit_pressed() -> void:
	print("Quit pressed")
	quit_pressed.emit()
	# Fade out and quit
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	get_tree().quit()
