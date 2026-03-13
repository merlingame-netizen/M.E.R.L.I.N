class_name ArbrePixelArt
extends Control

## Arbre de Vie — Pixel art procédural dynamique
## Dessine l'arbre celtique avec 34 noeuds de talent positionnés dans l'espace
## Se régénère visuellement à chaque débloquage de talent

signal node_selected(node_id: String)

# === POSITIONS NORMALISÉES (x: 0=gauche→1=droite, y: 0=haut→1=bas) ===

const TRUNK_BASE := Vector2(0.50, 0.90)
const TRUNK_TOP  := Vector2(0.50, 0.55)

const NODE_POSITIONS_RAW := {
	# Druides — bottom-left (racines)
	"druides_1": Vector2(0.18, 0.78),
	"druides_2": Vector2(0.14, 0.66),
	"druides_3": Vector2(0.10, 0.54),
	"druides_4": Vector2(0.14, 0.42),
	"druides_5": Vector2(0.10, 0.30),
	# Anciens — top-left (ramures)
	"anciens_1": Vector2(0.28, 0.62),
	"anciens_2": Vector2(0.24, 0.50),
	"anciens_3": Vector2(0.20, 0.38),
	"anciens_4": Vector2(0.24, 0.26),
	"anciens_5": Vector2(0.20, 0.14),
	# Korrigans — bottom-right (racines droites)
	"korrigans_1": Vector2(0.82, 0.78),
	"korrigans_2": Vector2(0.86, 0.66),
	"korrigans_3": Vector2(0.90, 0.54),
	"korrigans_4": Vector2(0.86, 0.42),
	"korrigans_5": Vector2(0.90, 0.30),
	# Niamh — top-right (feuillage)
	"niamh_1": Vector2(0.72, 0.62),
	"niamh_2": Vector2(0.76, 0.50),
	"niamh_3": Vector2(0.80, 0.38),
	"niamh_4": Vector2(0.76, 0.26),
	"niamh_5": Vector2(0.80, 0.14),
	# Ankou — far-right vertical
	"ankou_1": Vector2(0.94, 0.78),
	"ankou_2": Vector2(0.94, 0.62),
	"ankou_3": Vector2(0.94, 0.46),
	"ankou_4": Vector2(0.94, 0.30),
	"ankou_5": Vector2(0.94, 0.14),
	# Central — vertical center (tronc)
	"central_1": Vector2(0.50, 0.68),
	"central_2": Vector2(0.50, 0.50),
	"central_3": Vector2(0.50, 0.32),
	"central_4": Vector2(0.50, 0.14),
	# Special cross-faction nodes
	"calendrier_des_brumes": Vector2(0.42, 0.50),
	"harmonie_factions": Vector2(0.50, 0.42),
	"pacte_ombre_lumiere": Vector2(0.58, 0.50),
	"eveil_ogham": Vector2(0.38, 0.42),
	"instinct_sauvage": Vector2(0.62, 0.42),
	"boucle_eternelle": Vector2(0.50, 0.06),
}

const TIER_RADIUS := {1: 10.0, 2: 13.0, 3: 16.0, 4: 20.0, 5: 22.0}

# === STATE ===

var _unlocked: Array = []
var _available: Array = []
var _node_progress: Dictionary = {}  # node_id → float (animation scale 0→1)
var _pulse_phase: float = 0.0
var _hovered_id: String = ""
var _edges: Array = []  # Array of {"from": String, "to": String}

# === LIFECYCLE ===

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_build_edges()
	for nid in NODE_POSITIONS_RAW:
		_node_progress[nid] = 1.0

func _process(delta: float) -> void:
	_pulse_phase += delta * TAU / 3.0
	if _pulse_phase > TAU:
		_pulse_phase -= TAU
	queue_redraw()

# === PUBLIC API ===

func setup(p_unlocked: Array, p_available: Array) -> void:
	_unlocked = p_unlocked.duplicate()
	_available = p_available.duplicate()
	for nid: String in _unlocked:
		if not _node_progress.has(nid):
			_node_progress[nid] = 1.0
	queue_redraw()

func animate_unlock(node_id: String) -> void:
	_node_progress[node_id] = 0.0
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("skill_unlock")
	var tween: Tween = create_tween()
	tween.set_trans(MerlinVisual.TRANS_UI)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(v: float) -> void:
			_node_progress[node_id] = v
			queue_redraw(),
		0.0,
		1.0,
		0.5
	)

# === PRIVATE — DATA ===

func _build_edges() -> void:
	_edges.clear()
	for node_id: String in MerlinConstants.TALENT_NODES:
		if not NODE_POSITIONS_RAW.has(node_id):
			continue
		var prereqs: Array = MerlinConstants.TALENT_NODES[node_id].get("prerequisites", [])
		if prereqs.is_empty():
			_edges.append({"from": "__trunk__", "to": node_id})
		else:
			for prereq: String in prereqs:
				if NODE_POSITIONS_RAW.has(prereq):
					_edges.append({"from": prereq, "to": node_id})

func _node_world_pos(node_id: String, canvas_size: Vector2) -> Vector2:
	if node_id == "__trunk__":
		return TRUNK_TOP * canvas_size
	if NODE_POSITIONS_RAW.has(node_id):
		var norm: Vector2 = NODE_POSITIONS_RAW[node_id]
		return norm * canvas_size
	return canvas_size * 0.5

func _tier_for(node_id: String) -> int:
	if not MerlinConstants.TALENT_NODES.has(node_id):
		return 1
	return int(MerlinConstants.TALENT_NODES[node_id].get("tier", 1))

func _branch_for(node_id: String) -> String:
	if not MerlinConstants.TALENT_NODES.has(node_id):
		return "central"
	return str(MerlinConstants.TALENT_NODES[node_id].get("branch", "Universel"))

func _radius_for(node_id: String) -> float:
	var tier: int = _tier_for(node_id)
	return float(TIER_RADIUS.get(tier, 10.0))

# === DRAW ===

func _draw() -> void:
	var cs: Vector2 = size
	if cs.x < 10.0 or cs.y < 10.0:
		return
	_draw_trunk(cs)
	_draw_edges_layer(cs)
	_draw_nodes_layer(cs)

func _draw_trunk(cs: Vector2) -> void:
	var base: Vector2 = TRUNK_BASE * cs
	var top: Vector2 = TRUNK_TOP * cs
	var c_trunk: Color = MerlinVisual.GBC["dark_gray"]
	# 3 segments s'aminciçant vers le haut
	for i: int in 3:
		var t0: float = float(i) / 3.0
		var t1: float = float(i + 1) / 3.0
		var p0: Vector2 = base.lerp(top, t0)
		var p1: Vector2 = base.lerp(top, t1)
		var w: float = 5.0 - float(i) * 1.5
		draw_line(p0, p1, c_trunk, w, true)

func _draw_edges_layer(cs: Vector2) -> void:
	for edge: Dictionary in _edges:
		var from_id: String = str(edge["from"])
		var to_id: String = str(edge["to"])
		var p_from: Vector2 = _node_world_pos(from_id, cs)
		var p_to: Vector2 = _node_world_pos(to_id, cs)
		var progress: float = float(_node_progress.get(to_id, 1.0))
		# Ligne active si la destination est débloquée
		if _unlocked.has(to_id):
			var branch: String = _branch_for(to_id)
			var c_branch: Color = MerlinConstants.TALENT_BRANCH_COLORS.get(branch, Color.WHITE)
			c_branch.a = progress
			draw_line(p_from, p_to, c_branch, 2.0, true)
		else:
			var c_locked: Color = MerlinVisual.CRT_PALETTE["locked"]
			c_locked.a = 0.25
			draw_line(p_from, p_to, c_locked, 1.0, true)

func _draw_nodes_layer(cs: Vector2) -> void:
	for node_id: String in NODE_POSITIONS_RAW:
		_draw_single_node(node_id, cs)

func _draw_single_node(node_id: String, cs: Vector2) -> void:
	var pos: Vector2 = _node_world_pos(node_id, cs)
	var base_r: float = _radius_for(node_id)
	var progress: float = float(_node_progress.get(node_id, 1.0))
	var scaled_r: float = base_r * progress
	if scaled_r < 1.0:
		return

	var branch: String = _branch_for(node_id)
	var branch_color: Color = MerlinConstants.TALENT_BRANCH_COLORS.get(branch, Color.WHITE)
	var is_unlocked: bool = _unlocked.has(node_id)
	var is_available: bool = _available.has(node_id)

	if is_unlocked:
		var c_fill: Color = branch_color
		c_fill = c_fill.lerp(Color.BLACK, 0.30)
		c_fill.a = 1.0
		draw_circle(pos, scaled_r, c_fill)
		draw_arc(pos, scaled_r, 0.0, TAU, 32, branch_color, 2.0, true)
		# Aura tier 4
		if _tier_for(node_id) >= 4:
			var c_aura: Color = branch_color
			c_aura.a = 0.15
			draw_circle(pos, scaled_r * 1.6, c_aura)

	elif is_available:
		var c_bg: Color = MerlinVisual.CRT_PALETTE["bg_panel"]
		draw_circle(pos, scaled_r, c_bg)
		var pulse: float = (sin(_pulse_phase) + 1.0) * 0.5
		var c_outline: Color = MerlinVisual.CRT_PALETTE["amber_bright"]
		c_outline.a = 0.65 + pulse * 0.35
		draw_arc(pos, scaled_r, 0.0, TAU, 32, c_outline, 2.0, true)
		# Glow pulsant
		var c_glow: Color = MerlinVisual.CRT_PALETTE["amber_bright"]
		c_glow.a = 0.06 + pulse * 0.08
		draw_circle(pos, scaled_r * 1.8, c_glow)

	else:
		# Locked — très discret
		var c_fill_locked: Color = MerlinVisual.CRT_PALETTE["bg_dark"]
		c_fill_locked.a = 0.4
		draw_circle(pos, scaled_r, c_fill_locked)
		var c_out_locked: Color = MerlinVisual.CRT_PALETTE["locked"]
		c_out_locked.a = 0.4
		draw_arc(pos, scaled_r, 0.0, TAU, 16, c_out_locked, 1.0, true)

	# Hover highlight
	if node_id == _hovered_id:
		var c_hover: Color = Color.WHITE
		c_hover.a = 0.18
		draw_circle(pos, scaled_r + 3.0, c_hover)

# === INPUT ===

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: String = _hit_test(mb.position)
			if not hit.is_empty():
				node_selected.emit(hit)
				accept_event()

	elif event is InputEventMouseMotion:
		var new_hover: String = _hit_test(event.position)
		if new_hover != _hovered_id:
			_hovered_id = new_hover

func _hit_test(pos: Vector2) -> String:
	var cs: Vector2 = size
	for node_id: String in NODE_POSITIONS_RAW:
		var node_pos: Vector2 = _node_world_pos(node_id, cs)
		var radius: float = _radius_for(node_id)
		if pos.distance_to(node_pos) <= radius + 5.0:
			return node_id
	return ""
