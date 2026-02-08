extends Node3D
class_name SeaAnimation

## Amplitude du mouvement vertical des vagues
@export var wave_amplitude: float = 0.3
## Vitesse des vagues
@export var wave_speed: float = 1.5

var waves: Array[MeshInstance3D] = []
var foam: Array[MeshInstance3D] = []
var initial_positions: Array[Vector3] = []

func _ready() -> void:
	for child in get_children():
		if child.name.begins_with("Wave") and child is MeshInstance3D:
			waves.append(child)
			initial_positions.append(child.position)
		elif child.name.begins_with("Foam") and child is MeshInstance3D:
			foam.append(child)

func _process(delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	
	# Animer les vagues
	for i in range(waves.size()):
		var wave = waves[i]
		var init_pos = initial_positions[i]
		var offset = i * 0.5
		
		wave.position.y = init_pos.y + sin(time * wave_speed + offset) * wave_amplitude
		wave.rotation_degrees.x = sin(time * wave_speed * 0.8 + offset) * 3
	
	# Animer l'écume
	for i in range(foam.size()):
		var f = foam[i]
		f.position.y = -2.3 + sin(time * wave_speed * 1.2 + i) * 0.15
