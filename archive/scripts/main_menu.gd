extends Control

## Menu Principal du jeu DRU: Le Jeu des Oghams
## Gère la navigation et les options du menu de démarrage

# Références aux boutons
@onready var btn_nouvelle_partie: Button = $CenterContainer/MenuContainer/BtnNouvellePartie
@onready var btn_continuer: Button = $CenterContainer/MenuContainer/BtnContinuer
@onready var btn_test: Button = $CenterContainer/MenuContainer/BtnTest


func _ready() -> void:
	# Connexion des signaux des boutons
	btn_nouvelle_partie.pressed.connect(_on_nouvelle_partie_pressed)
	btn_continuer.pressed.connect(_on_continuer_pressed)
	btn_test.pressed.connect(_on_test_pressed)
	
	# Vérifier si une sauvegarde existe pour activer/désactiver le bouton Continuer
	_check_save_exists()
	
	# Jouer l'animation d'entrée (optionnel)
	_play_intro_animation()
	
	print("Menu Principal initialisé")


func _check_save_exists() -> void:
	"""Vérifie si une sauvegarde existe et active/désactive le bouton Continuer"""
	# TODO: Implémenter la vérification de sauvegarde
	# Pour l'instant, on le laisse actif
	btn_continuer.disabled = false


func _play_intro_animation() -> void:
	"""Animation d'apparition du menu (style GBC)"""
	# TODO: Ajouter une animation de fade-in ou slide-in
	pass


func _on_nouvelle_partie_pressed() -> void:
	"""Démarre une nouvelle partie"""
	print("🌟 Nouvelle Partie sélectionnée")
	
	# TODO: Afficher un dialogue de confirmation si une sauvegarde existe
	# TODO: Charger la scène d'intro ou directement le hub
	
	# Pour l'instant, on affiche juste un message
	_show_message("Démarrage d'une nouvelle partie...")
	
	# Exemple de changement de scène (à décommenter quand la scène existe)
	# get_tree().change_scene_to_file("res://scenes/Intro.tscn")


func _on_continuer_pressed() -> void:
	"""Continue la partie sauvegardée"""
	print("▶ Continuer sélectionné")
	
	# TODO: Charger la sauvegarde
	# TODO: Restaurer l'état du jeu
	# TODO: Charger la scène appropriée (carte, hub, etc.)
	
	_show_message("Chargement de la sauvegarde...")
	
	# Exemple de changement de scène
	# get_tree().change_scene_to_file("res://scenes/Map.tscn")


func _on_test_pressed() -> void:
	"""Mode test pour le développement - Lance Test Merlin"""
	print("🔧 Mode Test activé - Lancement de Test Merlin")
	
	# Charger la scène TestMerlin
	get_tree().change_scene_to_file("res://scenes/TestMerlin.tscn")


func _show_message(message: String) -> void:
	"""Affiche un message temporaire à l'écran (style GBC)"""
	# TODO: Créer un système de notification style Game Boy Color
	print("📢 ", message)


# Gestion du clavier (optionnel, pour navigation au clavier)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# ESC pour quitter (optionnel)
		# get_tree().quit()
		pass
