extends Node3D
class_name LighthouseBeacon

## Vitesse de rotation (degrés par seconde)
@export var rotation_speed: float = 30.0

## Lumières du phare
var beacon_lights: Array[SpotLight3D] = []

func _ready() -> void:
	# Trouver les lumières du phare
	for child in get_children():
		if child is SpotLight3D:
			beacon_lights.append(child)
	
	print("Phare initialisé avec ", beacon_lights.size(), " lumières")

func _process(delta: float) -> void:
	# Rotation continue
	rotate_y(deg_to_rad(rotation_speed * delta))
