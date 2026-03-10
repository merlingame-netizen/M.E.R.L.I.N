## ═══════════════════════════════════════════════════════════════════════════════
## BrocEventVfx — Keyword-triggered visual effects for LLM events
## ═══════════════════════════════════════════════════════════════════════════════
## Scans LLM-generated text for keywords and triggers matching 3D VFX.
## Effects are temporary (auto-cleanup after duration).
## Reuses patterns from BrocEvents atmospheric system.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

var _forest_root: Node3D
var _env: WorldEnvironment
var _sun: DirectionalLight3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _active_nodes: Array[Node3D] = []
var _cleanup_timer: float = 0.0
var _restore: Dictionary = {}  # saved values to restore after VFX

# ═══════════════════════════════════════════════════════════════════════════════
# KEYWORD → EFFECT MAPPING
# ═══════════════════════════════════════════════════════════════════════════════

const KEYWORDS: Array[Array] = [
	["brume", "brouillard", "mist"],
	["feu", "flamme", "incendie", "bruler"],
	["vent", "souffle", "tempete", "bourrasque"],
	["lumiere", "eclat", "rayons", "soleil", "aube"],
	["ombre", "tenebres", "obscurite", "nuit"],
	["tonnerre", "foudre", "eclair", "orage"],
	["korrigan", "lutin", "fee", "esprit"],
	["pierre", "menhir", "dolmen", "rune"],
	["champignon", "spore", "mycose"],
	["eau", "source", "ruisseau", "mare", "pluie"],
]

# Index matches KEYWORDS array
const EFFECT_NAMES: Array[String] = [
	"thick_mist",
	"fire_particles",
	"wind_intensify",
	"light_burst",
	"shadow_pass",
	"thunder_flash",
	"spawn_glow",
	"glow_stone",
	"mushroom_circle",
	"water_shimmer",
]

const VFX_DURATION: float = 6.0


func _init(forest_root: Node3D, env: WorldEnvironment, sun: DirectionalLight3D) -> void:
	_forest_root = forest_root
	_env = env
	_sun = sun
	_rng.randomize()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func trigger_for_text(text: String, player_pos: Vector3) -> String:
	var text_lower: String = text.to_lower()
	for i in KEYWORDS.size():
		for keyword: String in KEYWORDS[i]:
			if keyword in text_lower:
				_dispatch_effect(EFFECT_NAMES[i], player_pos)
				return EFFECT_NAMES[i]
	return ""


func update(delta: float) -> void:
	if _cleanup_timer <= 0.0:
		return
	_cleanup_timer -= delta
	if _cleanup_timer <= 0.0:
		_cleanup_all()


# ═══════════════════════════════════════════════════════════════════════════════
# DISPATCH
# ═══════════════════════════════════════════════════════════════════════════════

func _dispatch_effect(effect_name: String, player_pos: Vector3) -> void:
	# Cleanup previous VFX first
	_cleanup_all()
	_cleanup_timer = VFX_DURATION

	match effect_name:
		"thick_mist": _vfx_thick_mist()
		"fire_particles": _vfx_fire_particles(player_pos)
		"wind_intensify": _vfx_wind_intensify()
		"light_burst": _vfx_light_burst(player_pos)
		"shadow_pass": _vfx_shadow_pass(player_pos)
		"thunder_flash": _vfx_thunder_flash()
		"spawn_glow": _vfx_spawn_glow(player_pos)
		"glow_stone": _vfx_glow_stone(player_pos)
		"mushroom_circle": _vfx_mushroom_circle(player_pos)
		"water_shimmer": _vfx_water_shimmer(player_pos)


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECTS (each spawns nodes in _forest_root, stored in _active_nodes)
# ═══════════════════════════════════════════════════════════════════════════════

func _vfx_thick_mist() -> void:
	if _env and _env.environment:
		_restore["fog_density"] = _env.environment.fog_density
		_env.environment.fog_density = _env.environment.fog_density + 0.03


func _vfx_fire_particles(player_pos: Vector3) -> void:
	for i in 3:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.1)
		light.light_energy = 0.6 + _rng.randf() * 0.4
		light.omni_range = 4.0
		light.shadow_enabled = false
		light.position = player_pos + Vector3(
			_rng.randf_range(-4.0, 4.0), 0.5 + _rng.randf() * 1.5,
			_rng.randf_range(-4.0, 4.0))
		_forest_root.add_child(light)
		_active_nodes.append(light)


func _vfx_wind_intensify() -> void:
	if _env and _env.environment:
		_restore["fog_density"] = _env.environment.fog_density
		_env.environment.fog_density = maxf(_env.environment.fog_density - 0.01, 0.005)
	if _sun:
		_restore["sun_energy"] = _sun.light_energy
		_sun.light_energy = _sun.light_energy * 0.8


func _vfx_light_burst(player_pos: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.7)
	light.light_energy = 2.0
	light.omni_range = 12.0
	light.shadow_enabled = false
	light.position = player_pos + Vector3(0.0, 4.0, 0.0)
	_forest_root.add_child(light)
	_active_nodes.append(light)
	if _sun:
		_restore["sun_energy"] = _sun.light_energy
		_sun.light_energy = _sun.light_energy + 0.5


func _vfx_shadow_pass(player_pos: Vector3) -> void:
	var shadow: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.4, 1.8, 0.3)
	shadow.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.08, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position = player_pos + Vector3(12.0, 0.9, _rng.randf_range(-3.0, 3.0))
	_forest_root.add_child(shadow)
	_active_nodes.append(shadow)


func _vfx_thunder_flash() -> void:
	if _sun:
		_restore["sun_energy"] = _sun.light_energy
		_restore["sun_color"] = _sun.light_color
		_sun.light_energy = 3.0
		_sun.light_color = Color(0.9, 0.9, 1.0)


func _vfx_spawn_glow(player_pos: Vector3) -> void:
	for i in 4:
		var orb: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.12
		mesh.radial_segments = 8
		mesh.rings = 4
		orb.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.9, 0.5, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 0.5)
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orb.material_override = mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.position = player_pos + Vector3(
			_rng.randf_range(-5.0, 5.0), 0.5 + _rng.randf() * 2.0,
			_rng.randf_range(-5.0, 5.0))
		_forest_root.add_child(orb)
		_active_nodes.append(orb)


func _vfx_glow_stone(player_pos: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.3, 0.5, 0.9)
	light.light_energy = 1.0
	light.omni_range = 6.0
	light.shadow_enabled = false
	light.position = player_pos + Vector3(
		_rng.randf_range(-4.0, 4.0), 0.3,
		_rng.randf_range(-4.0, 4.0))
	_forest_root.add_child(light)
	_active_nodes.append(light)


func _vfx_mushroom_circle(player_pos: Vector3) -> void:
	var center: Vector3 = player_pos + Vector3(
		_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-5.0, 5.0))
	for i in 8:
		var angle: float = float(i) * TAU / 8.0
		var pos: Vector3 = center + Vector3(cos(angle) * 1.5, 0.0, sin(angle) * 1.5)
		var mush: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.height = 0.3
		mesh.bottom_radius = 0.08
		mesh.top_radius = 0.15
		mesh.radial_segments = 6
		mush.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.3, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.4, 0.2)
		mat.emission_energy_multiplier = 1.5
		mush.material_override = mat
		mush.position = pos
		mush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_forest_root.add_child(mush)
		_active_nodes.append(mush)


func _vfx_water_shimmer(player_pos: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(0.3, 0.6, 0.9)
	light.light_energy = 0.5
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.position = player_pos + Vector3(0.0, -0.2, 0.0)
	_forest_root.add_child(light)
	_active_nodes.append(light)


# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func _cleanup_all() -> void:
	for node: Node3D in _active_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_active_nodes.clear()

	# Restore environment values
	if _restore.has("fog_density") and _env and _env.environment:
		_env.environment.fog_density = _restore["fog_density"]
	if _restore.has("sun_energy") and _sun:
		_sun.light_energy = _restore["sun_energy"]
	if _restore.has("sun_color") and _sun:
		_sun.light_color = _restore["sun_color"]
	_restore.clear()
