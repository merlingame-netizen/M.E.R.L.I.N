extends Node3D
class_name SeagullFlock

## Rayon du cercle de vol
@export var flight_radius: float = 25.0
## Hauteur moyenne de vol
@export var flight_height: float = 15.0
## Vitesse de vol
@export var flight_speed: float = 8.0
## Amplitude du battement d'ailes
@export var wing_amplitude: float = 25.0
## Fréquence du battement
@export var wing_frequency: float = 5.0

var seagulls: Array[Node3D] = []
var wing_meshes: Array[Array] = []
var time_offsets: Array[float] = []

func _ready() -> void:
	# Collecter les mouettes
	for child in get_children():
		if child.name.begins_with("Seagull"):
			seagulls.append(child)
			time_offsets.append(randf() * TAU)
			
			# Collecter les ailes
			var wings: Array = []
			for part in child.get_children():
				if part.name.begins_with("Wing"):
					wings.append(part)
			wing_meshes.append(wings)
	
	print("Mouettes initialisées: ", seagulls.size())

func _process(delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	
	for i in range(seagulls.size()):
		var bird = seagulls[i]
		var offset = time_offsets[i]
		
		# Mouvement circulaire
		var angle = time * flight_speed / flight_radius + offset
		var new_x = cos(angle) * (flight_radius + sin(angle * 0.5) * 5)
		var new_z = sin(angle) * (flight_radius + cos(angle * 0.7) * 5)
		var new_y = flight_height + sin(time + offset) * 2
		
		bird.position = Vector3(new_x, new_y, new_z)
		
		# Orientation dans la direction du mouvement
		var direction = Vector3(-sin(angle), 0, cos(angle))
		bird.look_at(bird.position + direction, Vector3.UP)
		
		# Battement d'ailes
		var wings = wing_meshes[i]
		for j in range(wings.size()):
			var wing = wings[j]
			var wing_angle = sin(time * wing_frequency + offset) * wing_amplitude
			if j == 0:  # Aile gauche
				wing.rotation_degrees.z = -wing_angle - 15
			else:  # Aile droite
				wing.rotation_degrees.z = wing_angle + 15
