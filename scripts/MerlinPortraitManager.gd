class_name MerlinPortraitManager
extends Control

# MerlinPortraitManager - Gère les portraits de Merlin avec émotions
# Supporte les assets textures et les fallback ColorRect

signal emotion_changed(emotion: int)

enum Emotion {
	SAGE,      # Neutre, réfléchi - violet
	MYSTIQUE,  # Révélation magique - violet profond
	SERIEUX,   # Avertissement grave - rouge sombre
	AMUSE,     # Léger sourire - vert druide
	PENSIF     # Songeur - bleu nuit
}

# Configuration des assets
const ASSET_PATH = "res://Assets/merlin/"
const EMOTION_FILES = {
	Emotion.SAGE: "merlin_sage",
	Emotion.MYSTIQUE: "merlin_mystique", 
	Emotion.SERIEUX: "merlin_serieux",
	Emotion.AMUSE: "merlin_amuse",
	Emotion.PENSIF: "merlin_pensif"
}

# Couleurs de fallback (quand les assets ne sont pas disponibles)
const EMOTION_COLORS = {
	Emotion.SAGE: Color(0.42, 0.302, 0.541),
	Emotion.MYSTIQUE: Color(0.29, 0.078, 0.549),
	Emotion.SERIEUX: Color(0.545, 0.0, 0.0),
	Emotion.AMUSE: Color(0.18, 0.49, 0.196),
	Emotion.PENSIF: Color(0.082, 0.396, 0.753)
}

# Couleurs de bordure par émotion
const FRAME_COLORS = {
	Emotion.SAGE: Color(0.788, 0.635, 0.153),      # Or celtique
	Emotion.MYSTIQUE: Color(0.576, 0.439, 0.859),  # Violet lumineux
	Emotion.SERIEUX: Color(0.545, 0.0, 0.0),       # Rouge sombre
	Emotion.AMUSE: Color(0.208, 0.557, 0.22),      # Vert druide
	Emotion.PENSIF: Color(0.255, 0.412, 0.882)     # Bleu mystique
}

# Mots-clés pour la détection automatique
const EMOTION_KEYWORDS = {
	Emotion.MYSTIQUE: ["magie", "ogham", "pouvoir", "secret", "ancien", "rune", "mystère", "esprit", "vision", "arcane", "éléments"],
	Emotion.SERIEUX: ["danger", "ombre", "prudent", "attention", "mort", "ténèbres", "mal", "menace", "garde", "péril", "sombre"],
	Emotion.AMUSE: ["bien", "bravo", "courage", "sourire", "petit", "jeune", "drôle", "amusant", "ha ha", "excellent"],
	Emotion.PENSIF: ["destin", "temps", "mémoire", "jadis", "autrefois", "souvenir", "passé", "tristesse", "mélancolie", "songeur"]
}

var current_emotion: Emotion = Emotion.SAGE
var portrait_textures: Dictionary = {}
var portrait_nodes: Dictionary = {}
var frame_node: ColorRect = null
var use_textures: bool = false
var particles_layer: Control = null

func _ready():
	load_assets()
	
func setup(nodes: Dictionary, frame: ColorRect, particles: Control = null):
	portrait_nodes = nodes
	frame_node = frame
	particles_layer = particles
	
	# Essayer de charger les textures
	load_assets()
	
	# Afficher l'émotion initiale
	set_emotion(Emotion.SAGE)

func load_assets():
	use_textures = false
	portrait_textures.clear()
	
	for emotion in EMOTION_FILES:
		var file_base = EMOTION_FILES[emotion]
		var texture: Texture2D = null
		
		# Essayer différents formats
		for ext in [".png", ".jpg", ".webp"]:
			var path = ASSET_PATH + file_base + ext
			if ResourceLoader.exists(path):
				texture = load(path)
				break
		
		if texture:
			portrait_textures[emotion] = texture
			use_textures = true
			print("✓ Asset chargé: ", file_base)
		else:
			print("⚠ Asset non trouvé: ", file_base, " - utilisation du fallback couleur")

func set_emotion(emotion: Emotion, animate: bool = true):
	if emotion == current_emotion and portrait_nodes.size() > 0:
		# Déjà à cette émotion, juste rafraîchir
		pass
	
	current_emotion = emotion
	
	# Cacher tous les portraits
	for e in portrait_nodes:
		if portrait_nodes[e]:
			portrait_nodes[e].visible = false
	
	# Afficher le portrait correspondant
	if portrait_nodes.has(emotion) and portrait_nodes[emotion]:
		var node = portrait_nodes[emotion]
		node.visible = true
		
		# Si on a une texture, l'appliquer
		if use_textures and portrait_textures.has(emotion):
			if node is TextureRect:
				node.texture = portrait_textures[emotion]
			# Pour ColorRect, on garde la couleur
		
		# Animation d'apparition
		if animate:
			animate_portrait_appear(node)
	
	# Mettre à jour la couleur du cadre
	if frame_node:
		var target_color = FRAME_COLORS.get(emotion, FRAME_COLORS[Emotion.SAGE])
		if animate:
			var tween = create_tween()
			tween.tween_property(frame_node, "color", target_color, 0.3)
		else:
			frame_node.color = target_color
	
	# Effets spéciaux selon l'émotion
	if animate:
		play_emotion_effect(emotion)
	
	emit_signal("emotion_changed", emotion)

func animate_portrait_appear(node: CanvasItem):
	var tween = create_tween()
	node.modulate.a = 0
	tween.tween_property(node, "modulate:a", 1.0, 0.2)

func play_emotion_effect(emotion: Emotion):
	match emotion:
		Emotion.MYSTIQUE:
			play_mystique_effect()
		Emotion.SERIEUX:
			play_serious_effect()
		Emotion.AMUSE:
			play_amused_effect()
		Emotion.PENSIF:
			play_pensif_effect()

func play_mystique_effect():
	# Effet de particules brillantes
	if particles_layer:
		var tween = create_tween()
		tween.tween_property(particles_layer, "modulate:a", 0.9, 0.2)
		tween.tween_property(particles_layer, "modulate:a", 0.3, 0.3)
		tween.set_loops(2)

func play_serious_effect():
	# Léger tremblement
	if portrait_nodes.has(current_emotion):
		var node = portrait_nodes[current_emotion]
		if node:
			var orig_pos = node.position
			var tween = create_tween()
			tween.tween_property(node, "position", orig_pos + Vector2(2, 0), 0.05)
			tween.tween_property(node, "position", orig_pos - Vector2(2, 0), 0.05)
			tween.tween_property(node, "position", orig_pos, 0.05)

func play_amused_effect():
	# Léger rebond
	if portrait_nodes.has(current_emotion):
		var node = portrait_nodes[current_emotion]
		if node:
			var tween = create_tween()
			tween.tween_property(node, "scale", Vector2(1.05, 0.95), 0.1)
			tween.tween_property(node, "scale", Vector2(1.0, 1.0), 0.1)

func play_pensif_effect():
	# Assombrissement léger
	if portrait_nodes.has(current_emotion):
		var node = portrait_nodes[current_emotion]
		if node:
			var tween = create_tween()
			tween.tween_property(node, "modulate", Color(0.8, 0.8, 0.9, 1.0), 0.3)
			tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

func detect_emotion_from_text(text: String) -> Emotion:
	var text_lower = text.to_lower()
	var best_emotion = Emotion.SAGE
	var best_score = 0
	
	for emotion in EMOTION_KEYWORDS:
		var score = 0
		for keyword in EMOTION_KEYWORDS[emotion]:
			if keyword in text_lower:
				score += 1
		if score > best_score:
			best_score = score
			best_emotion = emotion
	
	return best_emotion

func set_emotion_from_text(text: String, animate: bool = true):
	var emotion = detect_emotion_from_text(text)
	set_emotion(emotion, animate)

func get_current_emotion() -> Emotion:
	return current_emotion

func get_emotion_name(emotion: Emotion) -> String:
	match emotion:
		Emotion.SAGE: return "Sage"
		Emotion.MYSTIQUE: return "Mystique"
		Emotion.SERIEUX: return "Sérieux"
		Emotion.AMUSE: return "Amusé"
		Emotion.PENSIF: return "Pensif"
		_: return "Inconnu"
