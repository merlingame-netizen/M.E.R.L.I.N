class_name MerlinOrb
extends SubViewportContainer
## DA v8 — Merlin la sphère robot 3D low-poly. Le SEUL élément 3D du jeu.
## SubViewport transparent affiché dans la scène 2D via SubViewportContainer.
## API publique : set_mood(name), look_at_screen(pos), trick(name),
##   speak_pulse(), set_generating(bool).
## 7 humeurs : neutre, taquin, intrigue, inquiet, grave, emerveille, desapprob.
## Figures automatiques toutes les 3,5-6,5 s. Réactions déclenchées.
## Compatible GL Compatibility + export Web.

# ── Couleurs (aliasées MerlinVisual) ──
const COL_CYAN: Color = MerlinVisual.MACHINE_CYAN
const COL_GOLD: Color = MerlinVisual.GOLD
const COL_CREAM: Color = MerlinVisual.CREAM
const GRAYS: Array = MerlinVisual.MERLIN_GRAYS

const MOODS: Dictionary = {
	"neutre":      {"eye_col": Color("9FD3E6"), "eye_h": 0.14, "eye_w": 0.035, "eye_rot": 0.0},
	"taquin":      {"eye_col": Color("9FD3E6"), "eye_h": 0.14, "eye_w": 0.035, "eye_rot": 0.0, "wink": true},
	"intrigue":    {"eye_col": Color("F4E0A8"), "eye_h": 0.17, "eye_w": 0.03,  "eye_rot": 0.12},
	"inquiet":     {"eye_col": Color("C0D0E0"), "eye_h": 0.08, "eye_w": 0.04,  "eye_rot": -0.2},
	"grave":       {"eye_col": Color("5A8AB0"), "eye_h": 0.06, "eye_w": 0.04,  "eye_rot": 0.0},
	"emerveille":  {"eye_col": Color("F4E0A8"), "eye_h": 0.20, "eye_w": 0.03,  "eye_rot": 0.0},
	"desapprob":   {"eye_col": Color("D04848"), "eye_h": 0.07, "eye_w": 0.04,  "eye_rot": 0.15},
}

# Timing
const BLINK_INTERVAL_MIN: float = 2.0
const BLINK_INTERVAL_MAX: float = 5.0
const BLINK_DUR: float = 0.15
const TRICK_INTERVAL_MIN: float = 3.5
const TRICK_INTERVAL_MAX: float = 6.5
const BREATHE_SPEED: float = 1.2
const RING_SPEED: float = 0.4
const SATELLITE_SPEED: float = 0.7
const LOOK_SMOOTH: float = 6.0

# Viewport
const VP_SIZE: int = 512
const RENDER_FPS: float = 30.0

# State
var _mood: String = "neutre"
var _target_look: Vector2 = Vector2.ZERO
var _current_look: Vector2 = Vector2.ZERO
var _generating: bool = false
var _t: float = 0.0
var _blink_timer: float = 3.0
var _blink_progress: float = -1.0
var _trick_timer: float = 5.0
var _trick_active: String = ""
var _trick_progress: float = 0.0
var _speak_pulse: float = 0.0
var _render_acc: float = 0.0

# 3D nodes
var _viewport: SubViewport = null
var _camera: Camera3D = null
var _shell: MeshInstance3D = null
var _core: MeshInstance3D = null
var _visor: MeshInstance3D = null
var _eye_left: MeshInstance3D = null
var _eye_right: MeshInstance3D = null
var _antenna: MeshInstance3D = null
var _antenna_tip: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _satellites: Array = []
var _shell_mesh: ArrayMesh = null
var _base_verts: PackedVector3Array = PackedVector3Array()
var _base_normals: PackedVector3Array = PackedVector3Array()

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(VP_SIZE, VP_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# SubViewport
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VP_SIZE, VP_SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = SubViewport.MSAA_DISABLED
	add_child(_viewport)
	# Camera
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0, 2.8)
	_camera.look_at(Vector3.ZERO)
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	# Lights
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 30, 0)
	light.light_energy = 0.8
	_viewport.add_child(light)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, -60, 0)
	fill.light_energy = 0.3
	_viewport.add_child(fill)
	# World environment
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_color = Color(0.3, 0.3, 0.35, 1.0)
	env.ambient_light_energy = 0.4
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)
	# Build the sphere
	_build_shell()
	_build_core()
	_build_visor()
	_build_eyes()
	_build_antenna()
	_build_ring()
	_build_satellites()
	_rng.randomize()
	_trick_timer = _rng.randf_range(TRICK_INTERVAL_MIN, TRICK_INTERVAL_MAX)
	_blink_timer = _rng.randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)


func _process(delta: float) -> void:
	var speed_mult: float = 0.5 if _generating else 1.0
	if MerlinVisual.reduced_motion:
		speed_mult *= 0.5
	_t += delta * speed_mult
	# Throttle viewport render to 30fps
	_render_acc += delta
	var interval: float = 1.0 / RENDER_FPS
	if _render_acc < interval:
		return
	_render_acc -= interval
	# Smooth look
	_current_look = _current_look.lerp(_target_look, clampf(delta * LOOK_SMOOTH, 0.0, 1.0))
	# Animations
	_animate_breathe()
	_animate_blink(delta * speed_mult)
	_animate_eyes()
	_animate_ring()
	_animate_satellites()
	_animate_antenna()
	_animate_speak_pulse(delta)
	# Tricks
	if not _generating or not MerlinVisual.reduced_motion:
		_trick_timer -= delta * speed_mult
		if _trick_timer <= 0.0 and _trick_active == "":
			_start_random_trick()
	if _trick_active != "":
		_animate_trick(delta * speed_mult)


# ── PUBLIC API ──

func set_mood(mood_name: String) -> void:
	if MOODS.has(mood_name):
		_mood = mood_name


func look_at_screen(screen_pos: Vector2) -> void:
	var center: Vector2 = global_position + size * 0.5
	var diff: Vector2 = screen_pos - center
	_target_look = Vector2(
		clampf(diff.x / (size.x * 0.5), -1.0, 1.0),
		clampf(-diff.y / (size.y * 0.5), -1.0, 1.0)
	)


func trick(name: String) -> void:
	if _trick_active != "":
		return
	_trick_active = name
	_trick_progress = 0.0


func speak_pulse() -> void:
	_speak_pulse = 1.0


func set_generating(on: bool) -> void:
	_generating = on


func get_generating() -> bool:
	return _generating


# ── BUILD 3D MESHES ──

func _build_shell() -> void:
	_shell = MeshInstance3D.new()
	var ico: ImmediateMesh = ImmediateMesh.new()
	# Build icosphere subdiv 1 (80 faces) using ArrayMesh with per-face vertices
	var base: SphereMesh = SphereMesh.new()
	# Use IcosphereMesh approach: start from icosahedron, subdivide once
	_shell_mesh = ArrayMesh.new()
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	# Generate icosphere vertices
	var ico_verts: Array = _icosphere_verts(0.62, 1)
	for i in range(0, ico_verts.size(), 3):
		var v0: Vector3 = ico_verts[i]
		var v1: Vector3 = ico_verts[i + 1]
		var v2: Vector3 = ico_verts[i + 2]
		var face_normal: Vector3 = (v1 - v0).cross(v2 - v0).normalized()
		verts.append(v0)
		verts.append(v1)
		verts.append(v2)
		normals.append(face_normal)
		normals.append(face_normal)
		normals.append(face_normal)
		# 4 gray shades alternated per face
		var gray_idx: int = (i / 3) % 4
		var col: Color = Color(GRAYS[gray_idx])
		colors.append(col)
		colors.append(col)
		colors.append(col)
	_base_verts = verts.duplicate()
	_base_normals = normals.duplicate()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	_shell_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Material
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.75
	mat.metallic = 0.15
	_shell_mesh.surface_set_material(0, mat)
	_shell.mesh = _shell_mesh
	_viewport.add_child(_shell)


func _build_core() -> void:
	_core = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	mesh.radial_segments = 12
	mesh.rings = 6
	_core.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COL_CYAN
	mat.emission_enabled = true
	mat.emission = COL_CYAN
	mat.emission_energy_multiplier = 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4
	_core.mesh.surface_set_material(0, mat)
	_viewport.add_child(_core)


func _build_visor() -> void:
	_visor = MeshInstance3D.new()
	# Use a flat cylinder as the visor band
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.58
	cyl.bottom_radius = 0.58
	cyl.height = 0.18
	cyl.radial_segments = 16
	cyl.rings = 1
	_visor.mesh = cyl
	_visor.position = Vector3(0, 0, 0.15)
	_visor.rotation_degrees = Vector3(90, 0, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.06, 1.0)
	mat.roughness = 0.3
	_visor.mesh.surface_set_material(0, mat)
	_viewport.add_child(_visor)


func _build_eyes() -> void:
	# Two bar-shaped eyes (stretched boxes)
	_eye_left = _make_eye_bar(Vector3(-0.1, 0.02, 0.58))
	_eye_right = _make_eye_bar(Vector3(0.1, 0.02, 0.58))
	_viewport.add_child(_eye_left)
	_viewport.add_child(_eye_right)


func _make_eye_bar(pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.035, 0.14, 0.02)
	mi.mesh = box
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COL_CYAN
	mat.emission_enabled = true
	mat.emission = COL_CYAN
	mat.emission_energy_multiplier = 2.0
	mi.mesh.surface_set_material(0, mat)
	return mi


func _build_antenna() -> void:
	_antenna = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.018
	cyl.height = 0.22
	cyl.radial_segments = 6
	_antenna.mesh = cyl
	_antenna.position = Vector3(0, 0.68, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(GRAYS[2])
	_antenna.mesh.surface_set_material(0, mat)
	_viewport.add_child(_antenna)
	# Tip (small octahedron = sphere with 4 segments)
	_antenna_tip = MeshInstance3D.new()
	var tip: SphereMesh = SphereMesh.new()
	tip.radius = 0.035
	tip.height = 0.07
	tip.radial_segments = 4
	tip.rings = 2
	_antenna_tip.mesh = tip
	_antenna_tip.position = Vector3(0, 0.82, 0)
	var tip_mat: StandardMaterial3D = StandardMaterial3D.new()
	tip_mat.albedo_color = COL_CYAN
	tip_mat.emission_enabled = true
	tip_mat.emission = COL_CYAN
	tip_mat.emission_energy_multiplier = 1.5
	_antenna_tip.mesh.surface_set_material(0, tip_mat)
	_viewport.add_child(_antenna_tip)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.76
	torus.rings = 24
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.rotation_degrees = Vector3(25, 0, 15)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COL_GOLD
	mat.roughness = 0.4
	mat.metallic = 0.5
	_ring.mesh.surface_set_material(0, mat)
	_viewport.add_child(_ring)


func _build_satellites() -> void:
	var sat_colors: Array = [COL_GOLD, COL_CYAN, COL_CREAM]
	var sat_orbits: Array = [
		{"radius": 1.0, "tilt_x": 30.0, "tilt_z": 0.0, "speed": 1.0},
		{"radius": 0.95, "tilt_x": -20.0, "tilt_z": 40.0, "speed": 1.3},
		{"radius": 1.05, "tilt_x": 10.0, "tilt_z": -30.0, "speed": 0.8},
	]
	for i in 3:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var oct: SphereMesh = SphereMesh.new()
		oct.radius = 0.04
		oct.height = 0.08
		oct.radial_segments = 4
		oct.rings = 2
		mi.mesh = oct
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = sat_colors[i]
		mat.emission_enabled = true
		mat.emission = sat_colors[i]
		mat.emission_energy_multiplier = 0.8
		mi.mesh.surface_set_material(0, mat)
		_viewport.add_child(mi)
		_satellites.append({"node": mi, "orbit": sat_orbits[i], "phase": float(i) * TAU / 3.0})


# ── ANIMATIONS ──

func _animate_breathe() -> void:
	if _shell_mesh == null or _base_verts.size() == 0:
		return
	var verts: PackedVector3Array = _base_verts.duplicate()
	var face_count: int = verts.size() / 3
	for fi in face_count:
		var phase: float = float(fi) * 0.37
		var disp: float = sin(_t * BREATHE_SPEED + phase) * 0.008
		if _speak_pulse > 0.0:
			disp += sin(_t * 12.0 + phase) * 0.012 * _speak_pulse
		var n: Vector3 = _base_normals[fi * 3]
		for vi in 3:
			verts[fi * 3 + vi] += n * disp
	var arrays: Array = _shell_mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_VERTEX] = verts
	_shell_mesh.clear_surfaces()
	_shell_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Re-apply material
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.75
	mat.metallic = 0.15
	_shell_mesh.surface_set_material(0, mat)
	# Float bob (2 sines)
	if _shell != null:
		var bob: float = sin(_t * 0.8) * 0.03 + sin(_t * 1.3) * 0.015
		_shell.position.y = bob
		if _core != null:
			_core.position.y = bob
		if _visor != null:
			_visor.position.y = bob + 0.15


func _animate_blink(dt: float) -> void:
	_blink_timer -= dt
	if _blink_timer <= 0.0:
		_blink_progress = 0.0
		_blink_timer = _rng.randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)
	if _blink_progress >= 0.0:
		_blink_progress += dt / BLINK_DUR
		if _blink_progress >= 1.0:
			_blink_progress = -1.0


func _animate_eyes() -> void:
	if _eye_left == null or _eye_right == null:
		return
	var md: Dictionary = MOODS.get(_mood, MOODS["neutre"])
	var eye_col: Color = md.get("eye_col", COL_CYAN)
	var eye_h: float = md.get("eye_h", 0.14)
	var eye_w: float = md.get("eye_w", 0.035)
	var eye_rot: float = md.get("eye_rot", 0.0)
	var is_wink: bool = md.get("wink", false)
	# Blink squeeze
	var blink_fac: float = 1.0
	if _blink_progress >= 0.0:
		blink_fac = 1.0 - sin(_blink_progress * PI)
	# Look offset
	var look_off: Vector3 = Vector3(_current_look.x * 0.06, _current_look.y * 0.04, 0)
	var bob: float = _shell.position.y if _shell != null else 0.0
	# Left eye
	_eye_left.position = Vector3(-0.1, 0.02 + bob, 0.58) + look_off
	var left_h: float = eye_h * blink_fac
	if is_wink:
		left_h = eye_h * 0.15 * blink_fac
	(_eye_left.mesh as BoxMesh).size = Vector3(eye_w, left_h, 0.02)
	_eye_left.rotation.z = -eye_rot
	var left_mat: StandardMaterial3D = _eye_left.mesh.surface_get_material(0)
	if left_mat != null:
		left_mat.albedo_color = eye_col
		left_mat.emission = eye_col
	# Right eye
	_eye_right.position = Vector3(0.1, 0.02 + bob, 0.58) + look_off
	(_eye_right.mesh as BoxMesh).size = Vector3(eye_w, eye_h * blink_fac, 0.02)
	_eye_right.rotation.z = eye_rot
	var right_mat: StandardMaterial3D = _eye_right.mesh.surface_get_material(0)
	if right_mat != null:
		right_mat.albedo_color = eye_col
		right_mat.emission = eye_col


func _animate_ring() -> void:
	if _ring == null:
		return
	_ring.rotation.y = _t * RING_SPEED


func _animate_satellites() -> void:
	for sat in _satellites:
		var node: MeshInstance3D = sat["node"]
		var orb: Dictionary = sat["orbit"]
		var phase: float = sat["phase"]
		var angle: float = _t * SATELLITE_SPEED * orb.get("speed", 1.0) + phase
		var r: float = orb.get("radius", 1.0)
		var x: float = cos(angle) * r
		var z: float = sin(angle) * r
		var tilt_x: float = deg_to_rad(orb.get("tilt_x", 0.0))
		var tilt_z: float = deg_to_rad(orb.get("tilt_z", 0.0))
		# Rotate around tilted orbit
		var pos: Vector3 = Vector3(x, 0, z)
		pos = pos.rotated(Vector3.RIGHT, tilt_x)
		pos = pos.rotated(Vector3.FORWARD, tilt_z)
		node.position = pos


func _animate_antenna() -> void:
	if _antenna_tip == null:
		return
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var mat: StandardMaterial3D = _antenna_tip.mesh.surface_get_material(0)
	if mat != null:
		mat.emission_energy_multiplier = 0.5 + pulse * 2.0
	var bob: float = _shell.position.y if _shell != null else 0.0
	_antenna.position.y = 0.68 + bob
	_antenna_tip.position.y = 0.82 + bob


func _animate_speak_pulse(delta: float) -> void:
	if _speak_pulse > 0.0:
		_speak_pulse = maxf(0.0, _speak_pulse - delta * 3.0)
	# Core pulse
	if _core != null:
		var pulse: float = 1.0 + sin(_t * 2.0) * 0.05
		if _speak_pulse > 0.0:
			pulse += _speak_pulse * 0.1
		_core.scale = Vector3.ONE * pulse


# ── TRICKS ──

func _start_random_trick() -> void:
	if _generating and not MerlinVisual.reduced_motion:
		_trick_timer = _rng.randf_range(TRICK_INTERVAL_MIN * 2.0, TRICK_INTERVAL_MAX * 2.0)
		return
	var tricks: Array = ["spin", "hop", "ripple", "scan"]
	_trick_active = tricks[_rng.randi() % tricks.size()]
	_trick_progress = 0.0
	_trick_timer = _rng.randf_range(TRICK_INTERVAL_MIN, TRICK_INTERVAL_MAX)


func _animate_trick(dt: float) -> void:
	match _trick_active:
		"spin":
			_trick_progress += dt / 0.75
			if _shell != null:
				_shell.rotation.y = _trick_progress * TAU * 2.0
			if _trick_progress >= 1.0:
				if _shell != null:
					_shell.rotation.y = 0.0
				_trick_active = ""
		"hop":
			_trick_progress += dt / 0.5
			if _shell != null:
				var hop_h: float = sin(_trick_progress * PI) * 0.15
				var squash: float = 1.0 - sin(_trick_progress * PI) * 0.1
				_shell.position.y += hop_h
				_shell.scale = Vector3(1.0 / squash, squash, 1.0 / squash)
			if _trick_progress >= 1.0:
				if _shell != null:
					_shell.scale = Vector3.ONE
				_trick_active = ""
		"ripple":
			_trick_progress += dt / 0.6
			# Wave through shell faces handled in breathe via pulse
			_speak_pulse = maxf(_speak_pulse, (1.0 - _trick_progress) * 0.8)
			if _trick_progress >= 1.0:
				_trick_active = ""
		"scan":
			_trick_progress += dt / 1.3
			# Antenna tip brightens
			if _antenna_tip != null:
				var mat: StandardMaterial3D = _antenna_tip.mesh.surface_get_material(0)
				if mat != null:
					mat.emission_energy_multiplier = 3.0 + sin(_trick_progress * PI * 4.0) * 2.0
			if _trick_progress >= 1.0:
				_trick_active = ""
		_:
			_trick_active = ""


# ── ICOSPHERE GENERATION ──
# Returns a flat array of Vector3 (3 verts per triangle, non-indexed).
# Subdivision 1 on an icosahedron = 80 faces.

static func _icosphere_verts(radius: float, subdivisions: int) -> Array:
	var phi: float = (1.0 + sqrt(5.0)) / 2.0
	# 12 vertices of icosahedron
	var base: Array = [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
	]
	for i in base.size():
		base[i] = (base[i] as Vector3).normalized() * radius
	# 20 faces of icosahedron
	var faces: Array = [
		[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],
		[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
		[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],
		[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1],
	]
	# Subdivide
	for _s in subdivisions:
		var new_faces: Array = []
		var midpoint_cache: Dictionary = {}
		for face in faces:
			var a: int = face[0]
			var b: int = face[1]
			var c: int = face[2]
			var ab: int = _get_midpoint(base, midpoint_cache, a, b, radius)
			var bc: int = _get_midpoint(base, midpoint_cache, b, c, radius)
			var ca: int = _get_midpoint(base, midpoint_cache, c, a, radius)
			new_faces.append([a, ab, ca])
			new_faces.append([b, bc, ab])
			new_faces.append([c, ca, bc])
			new_faces.append([ab, bc, ca])
		faces = new_faces
	# Flatten to vertex array (non-indexed, for flat shading)
	var result: Array = []
	for face in faces:
		result.append(base[face[0]])
		result.append(base[face[1]])
		result.append(base[face[2]])
	return result


static func _get_midpoint(verts: Array, cache: Dictionary, a: int, b: int, radius: float) -> int:
	var key: int = mini(a, b) * 10000 + maxi(a, b)
	if cache.has(key):
		return cache[key]
	var mid: Vector3 = ((verts[a] as Vector3) + (verts[b] as Vector3)) * 0.5
	mid = mid.normalized() * radius
	verts.append(mid)
	var idx: int = verts.size() - 1
	cache[key] = idx
	return idx
