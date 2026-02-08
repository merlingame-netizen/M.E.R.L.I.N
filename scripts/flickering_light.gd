extends OmniLight3D
class_name FlickeringLight

## Énergie de base de la lumière
@export var base_energy: float = 2.0
## Amplitude du scintillement
@export var flicker_amount: float = 0.5
## Vitesse du scintillement
@export var flicker_speed: float = 8.0
## Variation de couleur
@export var color_variation: float = 0.1

var time_offset: float = 0.0

func _ready() -> void:
	time_offset = randf() * 100.0

func _process(delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0 + time_offset
	
	# Scintillement basé sur plusieurs fréquences de bruit
	var flicker = sin(time * flicker_speed) * 0.3
	flicker += sin(time * flicker_speed * 1.7 + 0.5) * 0.2
	flicker += sin(time * flicker_speed * 3.1 + 1.2) * 0.15
	flicker += randf_range(-0.1, 0.1)  # Bruit aléatoire
	
	light_energy = base_energy + (flicker * flicker_amount)
	
	# Légère variation de couleur (du rouge-orange au jaune)
	var color_shift = (flicker + 1.0) * 0.5 * color_variation
	light_color = Color(
		1.0,
		0.5 + color_shift,
		0.2 + color_shift * 0.3
	)
