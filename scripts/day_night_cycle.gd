extends Node3D
class_name DayNightCycle

## Utiliser l'heure réelle du système
@export var use_real_time: bool = true
## Vitesse du cycle si pas en temps réel (1.0 = 24min pour un cycle complet)
@export var cycle_speed: float = 1.0
## Décalage horaire (pour tester différentes heures)
@export var hour_offset: float = 0.0

# Références aux éléments de la scène
@onready var sky_plane: MeshInstance3D = $SkyPlane
@onready var sun: Node3D = $Sun
@onready var moon: Node3D = $Moon
@onready var main_light: DirectionalLight3D = $MainLight
@onready var window_light: SpotLight3D = $WindowLight
@onready var stars: GPUParticles3D = $Stars
@onready var forest: Node3D = $Forest

# Couleurs du ciel selon l'heure
var sky_colors = {
	"night": Color(0.02, 0.03, 0.08),        # 0h-5h
	"dawn": Color(0.4, 0.3, 0.35),            # 5h-7h
	"sunrise": Color(0.9, 0.6, 0.4),          # 7h-8h
	"morning": Color(0.5, 0.7, 0.95),         # 8h-10h
	"day": Color(0.4, 0.65, 0.95),            # 10h-16h
	"afternoon": Color(0.6, 0.7, 0.85),       # 16h-18h
	"sunset": Color(0.95, 0.5, 0.3),          # 18h-20h
	"dusk": Color(0.3, 0.2, 0.35),            # 20h-21h
	"evening": Color(0.08, 0.08, 0.15),       # 21h-24h
}

# Couleurs de lumière selon l'heure
var light_colors = {
	"night": Color(0.4, 0.5, 0.8),
	"dawn": Color(0.8, 0.6, 0.7),
	"sunrise": Color(1.0, 0.7, 0.5),
	"morning": Color(1.0, 0.95, 0.85),
	"day": Color(1.0, 0.98, 0.95),
	"afternoon": Color(1.0, 0.95, 0.85),
	"sunset": Color(1.0, 0.6, 0.4),
	"dusk": Color(0.7, 0.5, 0.6),
	"evening": Color(0.5, 0.55, 0.75),
}

var current_hour: float = 12.0
var sim_time: float = 0.0

func _ready() -> void:
	update_time_of_day()

func _process(delta: float) -> void:
	if use_real_time:
		# Obtenir l'heure réelle du système
		var time_dict = Time.get_time_dict_from_system()
		current_hour = time_dict.hour + time_dict.minute / 60.0 + hour_offset
		current_hour = fmod(current_hour + 24.0, 24.0)
	else:
		# Simulation du temps
		sim_time += delta * cycle_speed
		current_hour = fmod(sim_time / 60.0, 24.0)
	
	update_time_of_day()

func update_time_of_day() -> void:
	var period = get_time_period(current_hour)
	var blend = get_blend_factor(current_hour)
	
	# Mise à jour du ciel
	update_sky(period, blend)
	
	# Mise à jour du soleil et de la lune
	update_celestial_bodies(current_hour)
	
	# Mise à jour des lumières
	update_lighting(period, blend)
	
	# Mise à jour des étoiles
	update_stars(current_hour)
	
	# Mise à jour de la forêt
	update_forest(period)

func get_time_period(hour: float) -> String:
	if hour < 5:
		return "night"
	elif hour < 7:
		return "dawn"
	elif hour < 8:
		return "sunrise"
	elif hour < 10:
		return "morning"
	elif hour < 16:
		return "day"
	elif hour < 18:
		return "afternoon"
	elif hour < 20:
		return "sunset"
	elif hour < 21:
		return "dusk"
	else:
		return "evening"

func get_next_period(period: String) -> String:
	var periods = ["night", "dawn", "sunrise", "morning", "day", "afternoon", "sunset", "dusk", "evening"]
	var idx = periods.find(period)
	return periods[(idx + 1) % periods.size()]

func get_blend_factor(hour: float) -> float:
	# Retourne un facteur de 0 à 1 pour le blend entre périodes
	var transitions = {
		5.0: 2.0,   # night -> dawn
		7.0: 1.0,   # dawn -> sunrise
		8.0: 2.0,   # sunrise -> morning
		10.0: 6.0,  # morning -> day
		16.0: 2.0,  # day -> afternoon
		18.0: 2.0,  # afternoon -> sunset
		20.0: 1.0,  # sunset -> dusk
		21.0: 3.0,  # dusk -> evening
	}
	
	for start_hour in transitions.keys():
		var duration = transitions[start_hour]
		if hour >= start_hour and hour < start_hour + duration:
			return (hour - start_hour) / duration
	
	return 0.0

func update_sky(period: String, blend: float) -> void:
	if not sky_plane or not sky_plane.material_override:
		return
	
	var mat = sky_plane.material_override as StandardMaterial3D
	var current_color = sky_colors[period]
	var next_color = sky_colors[get_next_period(period)]
	
	var final_color = current_color.lerp(next_color, blend)
	mat.albedo_color = final_color
	mat.emission = final_color * 0.3

func update_celestial_bodies(hour: float) -> void:
	if not sun or not moon:
		return
	
	# Soleil visible de 6h à 20h
	var sun_visible = hour >= 6 and hour <= 20
	sun.visible = sun_visible
	
	# Lune visible de 19h à 7h
	var moon_visible = hour >= 19 or hour <= 7
	moon.visible = moon_visible
	
	# Position du soleil dans le ciel (arc)
	if sun_visible:
		var sun_progress = (hour - 6) / 14.0  # 0 à 1 sur la journée
		var sun_angle = sun_progress * PI
		var sun_height = sin(sun_angle) * 4 + 1
		var sun_x = cos(sun_angle) * 3
		sun.position = Vector3(sun_x, sun_height, -6)
	
	# Position de la lune
	if moon_visible:
		var moon_hour = hour if hour >= 19 else hour + 24
		var moon_progress = (moon_hour - 19) / 12.0
		var moon_angle = moon_progress * PI
		var moon_height = sin(moon_angle) * 3.5 + 1.5
		var moon_x = -cos(moon_angle) * 2.5
		moon.position = Vector3(moon_x, moon_height, -6)

func update_lighting(period: String, blend: float) -> void:
	if not main_light or not window_light:
		return
	
	var current_color = light_colors[period]
	var next_color = light_colors[get_next_period(period)]
	var final_color = current_color.lerp(next_color, blend)
	
	main_light.light_color = final_color
	window_light.light_color = final_color
	
	# Intensité selon l'heure
	var is_night = current_hour < 6 or current_hour > 20
	if is_night:
		main_light.light_energy = 0.15
		window_light.light_energy = 0.4
	else:
		var day_factor = 1.0 - abs(current_hour - 13) / 7.0  # Max à 13h
		main_light.light_energy = 0.3 + day_factor * 0.7
		window_light.light_energy = 0.8 + day_factor * 1.2

func update_stars(hour: float) -> void:
	if not stars:
		return
	
	# Étoiles visibles de 20h à 6h
	var stars_visible = hour >= 20 or hour <= 6
	stars.visible = stars_visible
	
	if stars_visible:
		# Opacité des étoiles (plus brillantes à minuit)
		var star_intensity = 1.0
		if hour >= 20:
			star_intensity = (hour - 20) / 4.0  # Fade in
		elif hour <= 6:
			star_intensity = 1.0 - hour / 6.0  # Fade out
		
		stars.amount_ratio = clamp(star_intensity, 0.2, 1.0)

func update_forest(period: String) -> void:
	if not forest:
		return
	
	# Couleur de la forêt selon l'heure
	var forest_colors = {
		"night": Color(0.02, 0.03, 0.02),
		"dawn": Color(0.1, 0.12, 0.08),
		"sunrise": Color(0.15, 0.18, 0.1),
		"morning": Color(0.1, 0.2, 0.08),
		"day": Color(0.08, 0.18, 0.06),
		"afternoon": Color(0.1, 0.18, 0.07),
		"sunset": Color(0.12, 0.1, 0.06),
		"dusk": Color(0.06, 0.06, 0.04),
		"evening": Color(0.03, 0.04, 0.02),
	}
	
	var color = forest_colors.get(period, Color(0.08, 0.15, 0.05))
	
	for child in forest.get_children():
		if child is MeshInstance3D and child.material_override:
			var mat = child.material_override as StandardMaterial3D
			mat.albedo_color = color
