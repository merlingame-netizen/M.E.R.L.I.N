extends Control

# === CONFIGURATION ===
const MODEL_PATH = "res://addons/merlin_llm/models/qwen2.5-0.5b-instruct-q4_k_m.gguf"
const MAX_RETRIES = 2
const ASIDE_FREQUENCY = 0.15

# === NODES ===
@onready var merlin_sprite = $MarginContainer/MainVBox/MerlinPanel/MerlinHBox/PortraitContainer/MerlinSprite
@onready var mood_label = $MarginContainer/MainVBox/MerlinPanel/MerlinHBox/PortraitContainer/MoodLabel
@onready var aside_label = $MarginContainer/MainVBox/MerlinPanel/MerlinHBox/PortraitContainer/AsideLabel
@onready var dialogue_label = $MarginContainer/MainVBox/MerlinPanel/MerlinHBox/DialogueContainer/DialogueScroll/DialogueLabel
@onready var status_label = $MarginContainer/MainVBox/Header/StatusLabel
@onready var loading_label = $MarginContainer/MainVBox/ChoicesPanel/ChoicesVBox/LoadingLabel
@onready var choices_grid = $MarginContainer/MainVBox/ChoicesPanel/ChoicesVBox/ChoicesGrid
@onready var btn_back = $MarginContainer/MainVBox/Header/BtnBack

# === STATE ===
var llm: Object = null
var conversation_history: Array = []
var coherence_score: int = 0
var retry_count: int = 0
var is_processing: bool = false

var sprites = {
	"neutral": "res://Assets/Sprite/Merlin.png",
	"angry": "res://Assets/Sprite/Merlin Colère.png",
	"thinking": "res://Assets/Sprite/Merlin Pense.png",
	"surprised": "res://Assets/Sprite/Merlin Surpris.png",
	"scared": "res://Assets/Sprite/Merlin Peur.png",
	"questioning": "res://Assets/Sprite/Merlin Question.png"
}

var colors = {
	"friendly": Color("#4ecdc4"),
	"neutral": Color("#00d9ff"),
	"aggressive": Color("#ff6b6b"),
	"curious": Color("#ffe66d")
}

func _ready():
	_init_ui()
	_start_conversation()

func _init_ui():
	btn_back.pressed.connect(_on_back_pressed)
	for child in choices_grid.get_children():
		if child is Button:
			child.visible = false
	_apply_gba_theme()

func _apply_gba_theme():
	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color("#16213e")
	style_panel.border_width_all = 2
	style_panel.border_color = Color("#00d9ff")
	style_panel.corner_radius_all = 4
	
	var merlin_panel = $MarginContainer/MainVBox/MerlinPanel
	var choices_panel = $MarginContainer/MainVBox/ChoicesPanel
	
	merlin_panel.add_theme_stylebox_override("panel", style_panel)
	choices_panel.add_theme_stylebox_override("panel", style_panel.duplicate())

func _start_conversation():
	conversation_history.clear()
	coherence_score = 0
	_update_status()
	
	var welcome = {
		"response": "Ah, te voilà enfin, jeune druide... Les vents m'ont prévenu de ta venue. Que cherches-tu dans ces contrées mystiques ?",
		"mood": "questioning",
		"choices": [
			{"text": "Apprendre les secrets des Oghams", "tone": "curious"},
			{"text": "Comprendre ma destinée", "tone": "neutral"},
			{"text": "Tester ma force contre la tienne", "tone": "aggressive"},
			{"text": "Simplement te saluer, sage Merlin", "tone": "friendly"}
		]
	}
	_process_merlin_response(welcome)

func _process_merlin_response(data: Dictionary):
	conversation_history.append({"role": "assistant", "content": data.response})
	dialogue_label.text = "[center]" + data.response + "[/center]"
	set_merlin_mood(data.mood)
	_generate_choice_buttons(data.choices)
	_show_loading(false)

func _generate_choice_buttons(choices: Array):
	for i in range(choices_grid.get_child_count()):
		var btn = choices_grid.get_child(i)
		if btn is Button:
			btn.visible = false
	
	for i in range(min(4, choices.size())):
		var choice = choices[i]
		var btn = choices_grid.get_child(i)
		
		if btn and btn is Button:
			btn.text = choice.text
			btn.visible = true
			
			var tone = choice.get("tone", "neutral")
			var color = colors.get(tone, colors.neutral)
			
			var style = StyleBoxFlat.new()
			style.bg_color = color
			style.border_width_all = 2
			style.border_color = Color.WHITE
			style.corner_radius_all = 3
			
			btn.add_theme_stylebox_override("normal", style)
			
			var callable = func(): _on_choice_selected(choice.text)
			if btn.is_connected("pressed", callable):
				btn.pressed.disconnect(callable)
			btn.pressed.connect(callable)

func _on_choice_selected(choice_text: String):
	if is_processing:
		return
	print("Choix sélectionné: ", choice_text)
	_show_loading(true)
	await get_tree().create_timer(1.5).timeout
	
	var mock_responses = [
		{
			"response": "Intéressant... Les Oghams ne se révèlent qu'à ceux qui sont prêts. Es-tu certain de vouloir emprunter ce chemin ?",
			"mood": "thinking",
			"choices": [
				{"text": "Oui, je suis prêt à tout", "tone": "aggressive"},
				{"text": "Enseigne-moi avec patience", "tone": "friendly"},
				{"text": "Quels sont les risques ?", "tone": "curious"},
				{"text": "Peut-être ai-je besoin de réfléchir", "tone": "neutral"}
			]
		},
		{
			"response": "Le destin est un fil d'araignée... Fragile, mais d'une force insoupçonnée. Que souhaites-tu savoir vraiment ?",
			"mood": "neutral",
			"choices": [
				{"text": "Mon rôle dans cette prophétie", "tone": "curious"},
				{"text": "Comment devenir plus fort", "tone": "aggressive"},
				{"text": "Les épreuves qui m'attendent", "tone": "neutral"},
				{"text": "Si je peux compter sur ton aide", "tone": "friendly"}
			]
		},
		{
			"response": "Ah, la soif de connaissance... C'est ce qui sépare le druide du simple mortel. Mais attention, certains secrets portent un lourd fardeau.",
			"mood": "surprised",
			"choices": [
				{"text": "J'accepte ce fardeau", "tone": "aggressive"},
				{"text": "Que recommandes-tu, sage Merlin ?", "tone": "friendly"},
				{"text": "Quels secrets cachent les Oghams ?", "tone": "curious"},
				{"text": "Je préfère avancer prudemment", "tone": "neutral"}
			]
		}
	]
	
	var response = mock_responses[randi() % mock_responses.size()]
	coherence_score += 1
	_process_merlin_response(response)
	_update_status()
	is_processing = false

func set_merlin_mood(mood: String):
	if sprites.has(mood):
		merlin_sprite.texture = load(sprites[mood])
		var emoji_map = {
			"neutral": "●",
			"angry": "😠",
			"thinking": "🤔",
			"surprised": "😲",
			"scared": "😨",
			"questioning": "🤨"
		}
		mood_label.text = emoji_map.get(mood, "●") + " " + mood.to_upper()

func _show_loading(show: bool):
	loading_label.visible = show
	for child in choices_grid.get_children():
		if child is Button:
			child.visible = not show

func _update_status():
	status_label.text = "Prêt | cohérence " + str(coherence_score)
	if coherence_score >= 5:
		status_label.add_theme_color_override("font_color", Color("#4ecdc4"))
	elif coherence_score >= 2:
		status_label.add_theme_color_override("font_color", Color("#ffe66d"))
	else:
		status_label.add_theme_color_override("font_color", Color("#ff6b6b"))

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

