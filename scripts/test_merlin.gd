extends Control

## Test Merlin - Interface de conversation avec le LLM Merlin
## Utilise l'addon merlin_llm pour générer des dialogues et choix dynamiques

# Références UI
@onready var merlin_sprite: TextureRect = $MerlinPanel/MerlinVBox/MerlinSprite
@onready var mood_label: Label = $MerlinPanel/MerlinVBox/MoodLabel
@onready var history_container: VBoxContainer = $DialoguePanel/HistoryPanel/HistoryScroll/HistoryContainer
@onready var choices_container: VBoxContainer = $DialoguePanel/ChoicesPanel/ChoicesContainer/ChoicesButtons
@onready var thinking_button: Button = $DialoguePanel/ChoicesPanel/ChoicesContainer/ThinkingButton
@onready var btn_back: Button = $Header/BtnBack

# Instance du LLM
var llm: Object = null
var is_thinking: bool = false

# Sprites des différentes humeurs de Merlin
var sprites = {
	"neutral": "res://Assets/Sprite/Merlin.png",
	"happy": "res://Assets/Sprite/Merlin.png",  # Utiliser le même pour l'instant
	"angry": "res://Assets/Sprite/Merlin Colère.png",
	"thinking": "res://Assets/Sprite/Merlin Pense.png",
	"surprised": "res://Assets/Sprite/Merlin Surpris.png",
	"scared": "res://Assets/Sprite/Merlin Peur.png",
	"questioning": "res://Assets/Sprite/Merlin Question.png"
}

# Historique de conversation pour le contexte LLM
var conversation_history: Array = []
var current_mood: String = "neutral"

# Prompt système pour Merlin
const SYSTEM_PROMPT = """Tu es Merlin, le druide sage et mystérieux du jeu DRU: Le Jeu des Oghams.
Tu es un guide bienveillant mais aussi un personnage complexe avec des émotions.

Rôle: Guide le joueur dans son aventure, partage ta sagesse druidique et tes connaissances des Oghams.
Personnalité: Sage, mystérieux, parfois taquin, sensible aux émotions du joueur.
Humeurs possibles: neutral, happy, angry, thinking, surprised, scared, questioning

IMPORTANT: Tu dois TOUJOURS répondre au format JSON suivant:
{
  "response": "Ta réponse à afficher au joueur",
  "mood": "une des humeurs (neutral/happy/angry/thinking/surprised/scared/questioning)",
  "choices": [
	{"text": "Premier choix possible", "tone": "friendly/neutral/aggressive"},
	{"text": "Deuxième choix", "tone": "friendly/neutral/aggressive"},
	{"text": "Troisième choix", "tone": "friendly/neutral/aggressive"}
  ]
}

Génère TOUJOURS 3 choix variés qui permettent au joueur de répondre avec différentes tonalités."""


func _ready() -> void:
	# Connexion des signaux
	btn_back.pressed.connect(_on_back_pressed)
	
	# Initialiser le LLM
	_init_llm()
	
	# Message de bienvenue
	_add_to_history("system", "Bienvenue dans la conversation avec Merlin!")
	_start_conversation()


func _init_llm() -> void:
	"""Initialise l'instance du LLM Merlin"""
	llm = null
	if ClassDB.class_exists("MerlinLLM"):
		llm = ClassDB.instantiate("MerlinLLM")
	if llm == null:
		push_warning("MerlinLLM not available; using mock responses.")
		return
	
	# Configuration du modèle
	var model_path = "res://addons/merlin_llm/models/qwen2.5-3b-instruct-q4_k_m.gguf"
	
	# Vérifier si le modèle existe
	if FileAccess.file_exists(model_path):
		llm.model_path = model_path
		llm.n_ctx = 2048
		llm.temperature = 0.8
		llm.top_p = 0.9
		llm.max_tokens = 512
		
		print("✅ LLM Merlin initialisé avec succès")
		print("Modèle: ", model_path)
	else:
		push_error("❌ Modèle LLM non trouvé: " + model_path)
		_add_to_history("system", "Erreur: Modèle LLM non disponible")


func _start_conversation() -> void:
	"""Démarre la conversation initiale avec Merlin"""
	set_merlin_mood("neutral")
	
	# Premier message de Merlin
	var initial_message = {
		"response": "Ah, te voilà enfin, jeune apprenti. Je suis Merlin, gardien des anciens Oghams. Que cherches-tu dans ces terres mystiques?",
		"mood": "neutral",
		"choices": [
			{"text": "Je viens apprendre les secrets des Oghams", "tone": "friendly"},
			{"text": "Qui es-tu vraiment, vieil homme?", "tone": "aggressive"},
			{"text": "Je suis perdu... peux-tu m'aider?", "tone": "neutral"}
		]
	}
	
	_process_merlin_response(initial_message)


func _generate_llm_response(user_message: String) -> void:
	"""Génère une réponse du LLM basée sur le message de l'utilisateur"""
	if is_thinking:
		return
	
	is_thinking = true
	_show_thinking_state(true)
	
	# Ajouter le message du joueur à l'historique
	_add_to_history("user", user_message)
	conversation_history.append({"role": "user", "content": user_message})
	
	# Construire le prompt avec l'historique
	var full_prompt = SYSTEM_PROMPT + "\n\nHistorique:\n"
	for msg in conversation_history:
		full_prompt += msg.role + ": " + msg.content + "\n"
	
	full_prompt += "\nRéponds maintenant au format JSON avec response, mood, et 3 choices."
	
	# Générer la réponse (asynchrone)
	if llm:
		var response = await _call_llm_async(full_prompt)
		_handle_llm_response(response)
	else:
		# Fallback si LLM non disponible
		_handle_llm_fallback(user_message)


func _call_llm_async(prompt: String) -> String:
	"""Appelle le LLM de manière asynchrone"""
	# Simuler un délai pour l'instant (à remplacer par l'appel réel au LLM)
	await get_tree().create_timer(1.5).timeout
	
	# TODO: Implémenter l'appel réel au LLM via MerlinLLM
	# Pour l'instant, retourner une réponse mock
	var mock_responses = [
		{
			"response": "Intéressant... Les Oghams sont bien plus que de simples symboles. Ils sont l'essence même de la magie druidique.",
			"mood": "thinking",
			"choices": [
				{"text": "Parle-moi des différents types d'Oghams", "tone": "friendly"},
				{"text": "Je n'ai pas de temps pour tes énigmes!", "tone": "aggressive"},
				{"text": "Comment puis-je apprendre à les utiliser?", "tone": "neutral"}
			]
		},
		{
			"response": "Ha! Tu me défies? La jeunesse d'aujourd'hui... Mais soit, je respecte ton audace.",
			"mood": "surprised",
			"choices": [
				{"text": "Excuse-moi, je ne voulais pas être irrespectueux", "tone": "friendly"},
				{"text": "Et alors? Tu vas faire quoi?", "tone": "aggressive"},
				{"text": "Pouvons-nous recommencer?", "tone": "neutral"}
			]
		},
		{
			"response": "Perdu? Personne n'arrive ici par hasard, jeune druide. Le destin t'a guidé vers moi.",
			"mood": "questioning",
			"choices": [
				{"text": "Le destin? Je n'y crois pas vraiment...", "tone": "neutral"},
				{"text": "Alors aide-moi à comprendre mon chemin", "tone": "friendly"},
				{"text": "C'est n'importe quoi, je suis juste là", "tone": "aggressive"}
			]
		}
	]
	
	var random_response = mock_responses[randi() % mock_responses.size()]
	return JSON.stringify(random_response)


func _handle_llm_response(response_json: String) -> void:
	"""Traite la réponse du LLM"""
	is_thinking = false
	_show_thinking_state(false)
	
	var json = JSON.new()
	var parse_result = json.parse(response_json)
	
	if parse_result == OK:
		var data = json.data
		_process_merlin_response(data)
		
		# Ajouter à l'historique
		conversation_history.append({
			"role": "assistant", 
			"content": data.response
		})
	else:
		push_error("Erreur de parsing JSON: " + response_json)
		_handle_llm_fallback("...")


func _handle_llm_fallback(user_message: String) -> void:
	"""Gestion de secours si le LLM ne répond pas"""
	is_thinking = false
	_show_thinking_state(false)
	
	var fallback = {
		"response": "Hmm... mes pensées sont confuses en ce moment. Peux-tu répéter?",
		"mood": "thinking",
		"choices": [
			{"text": "Bien sûr, je disais...", "tone": "friendly"},
			{"text": "Laisse tomber", "tone": "neutral"},
			{"text": "Tu perds la tête, vieux druide?", "tone": "aggressive"}
		]
	}
	_process_merlin_response(fallback)


func _process_merlin_response(data: Dictionary) -> void:
	"""Traite et affiche une réponse de Merlin"""
	# Mettre à jour l'humeur
	if data.has("mood"):
		set_merlin_mood(data.mood)
	
	# Afficher la réponse
	if data.has("response"):
		_add_to_history("merlin", data.response)
	
	# Générer les boutons de choix
	if data.has("choices"):
		_generate_choice_buttons(data.choices)


func _generate_choice_buttons(choices: Array) -> void:
	"""Génère les boutons de choix pour le joueur"""
	# Nettoyer les anciens boutons
	for child in choices_container.get_children():
		child.queue_free()
	
	# Créer les nouveaux boutons
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = choice.text
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 12)
		
		# Style selon le ton
		var tone = choice.get("tone", "neutral")
		match tone:
			"friendly":
				btn.add_theme_color_override("font_color", Color("#48a028"))  # Vert
			"aggressive":
				btn.add_theme_color_override("font_color", Color("#d03028"))  # Rouge
			_:
				btn.add_theme_color_override("font_color", Color("#181810"))  # Noir
		
		# Connecter le signal
		btn.pressed.connect(_on_choice_selected.bind(choice.text))
		
		choices_container.add_child(btn)


func _on_choice_selected(choice_text: String) -> void:
	"""Gère la sélection d'un choix par le joueur"""
	print("Choix sélectionné: ", choice_text)
	_generate_llm_response(choice_text)


func _add_to_history(speaker: String, message: String) -> void:
	"""Ajoute un message à l'historique visible"""
	var entry = PanelContainer.new()
	var vbox = VBoxContainer.new()
	entry.add_child(vbox)
	
	# Label du speaker
	var speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 10)
	
	match speaker:
		"merlin":
			speaker_label.text = "🧙 MERLIN"
			speaker_label.add_theme_color_override("font_color", Color("#8868b0"))
		"user":
			speaker_label.text = "🗣️ VOUS"
			speaker_label.add_theme_color_override("font_color", Color("#48a028"))
		_:
			speaker_label.text = "ℹ️ SYSTÈME"
			speaker_label.add_theme_color_override("font_color", Color("#787870"))
	
	vbox.add_child(speaker_label)
	
	# Message
	var msg_label = Label.new()
	msg_label.text = message
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(msg_label)
	
	history_container.add_child(entry)
	
	# Scroll vers le bas
	await get_tree().process_frame
	var scroll = $DialoguePanel/HistoryPanel/HistoryScroll
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value


func set_merlin_mood(mood: String) -> void:
	"""Change le sprite de Merlin selon son humeur"""
	if mood == current_mood:
		return
	
	current_mood = mood
	
	if sprites.has(mood):
		merlin_sprite.texture = load(sprites[mood])
	
	# Mettre à jour le label d'humeur
	var mood_text = {
		"neutral": "😊 Neutre",
		"happy": "😄 Joyeux",
		"angry": "😠 En colère",
		"thinking": "🤔 Pensif",
		"surprised": "😲 Surpris",
		"scared": "😨 Effrayé",
		"questioning": "🤨 Interrogateur"
	}
	
	mood_label.text = mood_text.get(mood, "😊 Neutre")
	
	print("Humeur de Merlin: ", mood)


func _show_thinking_state(show: bool) -> void:
	"""Affiche ou masque l'état de réflexion"""
	thinking_button.visible = show
	
	# Désactiver les boutons de choix pendant la réflexion
	for btn in choices_container.get_children():
		if btn is Button:
			btn.disabled = show


func _on_back_pressed() -> void:
	"""Retour au menu principal"""
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
