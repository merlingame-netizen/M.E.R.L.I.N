## ═══════════════════════════════════════════════════════════════════════════════
## BrocNarrativeDirector — LLM orchestration layer
## ═══════════════════════════════════════════════════════════════════════════════
## Central dispatcher between LLM scene_directive output and visual subsystems.
## The LLM can control: fog, density, creatures, VFX, screen effects, ambient.
## Falls back to keyword-based directive generation if LLM provides no directive.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

var _atmosphere: RefCounted  # BrocAtmosphere
var _creature_spawner: RefCounted  # BrocCreatureSpawner
var _screen_vfx: RefCounted  # BrocScreenVfx
var _event_vfx: RefCounted  # BrocEventVfx
var _chunk_manager: RefCounted  # BrocChunkManager

## Keyword -> directive mapping (fallback when LLM provides no scene_directive)
const KEYWORD_DIRECTIVES: Array[Array] = [
	[["brume", "brouillard", "mist"], {"fog_override": 0.07, "fog_duration": 8.0, "screen_effect": "desaturate"}],
	[["feu", "flamme", "incendie"], {"vfx_trigger": "fire_particles", "screen_effect": "flash_red"}],
	[["tonnerre", "foudre", "eclair"], {"screen_effect": "shake", "vfx_trigger": "thunder_flash"}],
	[["lumiere", "eclat", "aube"], {"screen_effect": "flash", "vfx_trigger": "light_burst"}],
	[["ombre", "tenebres", "nuit"], {"screen_effect": "vignette", "fog_override": 0.06, "fog_duration": 6.0}],
	[["korrigan", "lutin", "fee"], {"creature_spawn": "korrigan", "screen_effect": "glitch", "burst": "sparkle"}],
	[["cerf", "biche"], {"creature_spawn": "white_deer", "burst": "leaves"}],
	[["loup", "hurlement"], {"creature_spawn": "mist_wolf", "screen_effect": "vignette_red"}],
	[["corbeau", "raven"], {"creature_spawn": "giant_raven", "screen_effect": "desaturate"}],
	[["pierre", "menhir", "rune"], {"vfx_trigger": "glow_stone", "screen_effect": "vignette_gold"}],
	[["champignon", "spore"], {"vfx_trigger": "mushroom_circle", "burst": "pollen"}],
	[["eau", "source", "pluie"], {"vfx_trigger": "water_shimmer", "burst": "water"}],
	[["vent", "tempete"], {"screen_effect": "shake", "vfx_trigger": "wind_intensify"}],
]


func setup(
	atmosphere: RefCounted,
	creature_spawner: RefCounted,
	screen_vfx: RefCounted,
	event_vfx: RefCounted,
	chunk_manager: RefCounted,
) -> void:
	_atmosphere = atmosphere
	_creature_spawner = creature_spawner
	_screen_vfx = screen_vfx
	_event_vfx = event_vfx
	_chunk_manager = chunk_manager
	print("[BrocNarrativeDirector] Orchestration layer ready")


## Apply a scene directive from LLM output or auto-generated from keywords
func apply_directive(directive: Dictionary, player_pos: Vector3) -> void:
	# Fog override
	if directive.has("fog_override") and _atmosphere:
		var density: float = float(directive["fog_override"])
		var duration: float = float(directive.get("fog_duration", 6.0))
		_atmosphere.set_fog_override(density, duration)

	# Density multiplier
	if directive.has("density_mult") and _chunk_manager:
		_chunk_manager.set_density_mult(float(directive["density_mult"]))

	# Creature spawn
	if directive.has("creature_spawn") and _creature_spawner:
		var creature_type: String = str(directive["creature_spawn"])
		var pos_hint: String = str(directive.get("creature_pos", "ahead"))
		var spawn_pos: Vector3 = _resolve_creature_pos(player_pos, pos_hint)
		_creature_spawner.spawn_creature(creature_type, spawn_pos)

	# 3D VFX (keyword-triggered lights, particles in world)
	if directive.has("vfx_trigger") and _event_vfx and _event_vfx.has_method("_dispatch_effect"):
		_event_vfx._dispatch_effect(str(directive["vfx_trigger"]), player_pos)

	# Screen effects (shake, flash, glitch, vignette)
	if directive.has("screen_effect") and _screen_vfx:
		var effect: String = str(directive["screen_effect"])
		var intensity: float = float(directive.get("screen_intensity", 1.0))
		var duration: float = float(directive.get("screen_duration", 0.5))
		_screen_vfx.trigger(effect, intensity, duration)

	# Particle burst
	if directive.has("burst") and _screen_vfx:
		_screen_vfx.trigger_burst(str(directive["burst"]), player_pos)

	# Ambient color shift
	if directive.has("ambient_shift") and _atmosphere:
		pass  # Future: shift ambient light color


## Auto-generate a directive from event text keywords (fallback)
func directive_from_text(text: String, player_pos: Vector3) -> void:
	var text_lower: String = text.to_lower()
	for entry: Array in KEYWORD_DIRECTIVES:
		var keywords: Array = entry[0] as Array
		for keyword: String in keywords:
			if keyword in text_lower:
				var directive: Dictionary = (entry[1] as Dictionary).duplicate()
				apply_directive(directive, player_pos)
				return


func _resolve_creature_pos(player_pos: Vector3, hint: String) -> Vector3:
	var offset: Vector3 = Vector3(0.0, 0.0, -6.0)  # default: ahead
	match hint:
		"behind":
			offset = Vector3(0.0, 0.0, 6.0)
		"left":
			offset = Vector3(-6.0, 0.0, 0.0)
		"right":
			offset = Vector3(6.0, 0.0, 0.0)
		"ahead":
			offset = Vector3(0.0, 0.0, -6.0)
	return player_pos + offset
