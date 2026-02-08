extends Node3D
class_name Menu3DController

@onready var viewport: SubViewport = $MenuViewportContainer/MenuViewport
@onready var display: Sprite3D = $MenuDisplay
@onready var rune_circle: Node3D = $RuneCircle
@onready var magic_particles: GPUParticles3D = $MagicParticles

var rune_rotation_speed: float = 12.0
var rune_pulse_speed: float = 2.5
var rune_hover_amplitude: float = 0.01
var time: float = 0.0
var is_hovered: bool = false

func _ready() -> void:
	# Lier la texture du viewport au Sprite3D
	if viewport and display:
		await get_tree().process_frame
		await get_tree().process_frame
		display.texture = viewport.get_texture()
		print("Menu 3D initialisé!")

func _process(delta: float) -> void:
	time += delta
	
	# Animation des runes
	if rune_circle:
		rune_circle.rotation.y += deg_to_rad(rune_rotation_speed) * delta
		
		# Pulsation et lévitation des runes
		for i in range(rune_circle.get_child_count()):
			var rune = rune_circle.get_child(i)
			if rune is MeshInstance3D:
				# Pulsation lumineuse
				var pulse = (sin(time * rune_pulse_speed + i * 0.8) + 1.0) * 0.5
				if rune.material_override:
					var mat = rune.material_override as StandardMaterial3D
					if mat:
						mat.emission_energy_multiplier = 1.2 + pulse * 1.8
				
				# Légère lévitation
				var base_y = 0.04
				rune.position.y = base_y + sin(time * 1.5 + i * 0.5) * rune_hover_amplitude
	
	# Animation du grimoire (légère respiration)
	var grimoire = get_node_or_null("GrimoirePages")
	if grimoire:
		var breath = sin(time * 0.8) * 0.002
		grimoire.position.y = 0.02 + breath
	
	# Intensifier les particules si survolé
	if magic_particles:
		if is_hovered:
			magic_particles.amount_ratio = 1.0
			magic_particles.speed_scale = 1.5
		else:
			magic_particles.amount_ratio = 0.6
			magic_particles.speed_scale = 1.0

func _on_click_area_mouse_entered() -> void:
	is_hovered = true

func _on_click_area_mouse_exited() -> void:
	is_hovered = false
