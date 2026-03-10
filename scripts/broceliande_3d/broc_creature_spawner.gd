## ═══════════════════════════════════════════════════════════════════════════════
## BrocCreatureSpawner — Billboard pixel-art creatures
## ═══════════════════════════════════════════════════════════════════════════════
## 4 creature types as pixel-art rigs (BoxMesh cubes, same technique as Merlin).
## Zone-specific spawning, max 2 simultaneous, flee behavior, alpha fade.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

const PX: float = 0.10  # pixel size for creature rigs
const MAX_CREATURES: int = 2
const FLEE_DIST: float = 3.0
const SPAWN_DIST_MIN: float = 5.0
const SPAWN_DIST_MAX: float = 7.0
const DESPAWN_DIST: float = 12.0
const FADE_SPEED: float = 2.0

var _forest_root: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _active: Array[Dictionary] = []  # { node, type, state, alpha, target_pos }
var _spawn_cooldown: float = 0.0

## Zone -> allowed creature types
const ZONE_CREATURES: Dictionary = {
	0: [],
	1: ["korrigan"],
	2: ["white_deer"],
	3: ["korrigan"],
	4: ["mist_wolf"],
	5: ["white_deer"],
	6: ["giant_raven"],
}

## Pixel grids: each row is an array of color indices (0=transparent)
## Kept small (8x8 to 10x10) for performance
const CREATURE_GRIDS: Dictionary = {
	"korrigan": {
		"grid": [
			[0,0,0,1,1,0,0,0],
			[0,0,1,2,2,1,0,0],
			[0,0,1,3,3,1,0,0],
			[0,1,1,4,4,1,1,0],
			[0,1,4,4,4,4,1,0],
			[0,0,1,4,4,1,0,0],
			[0,0,1,0,0,1,0,0],
			[0,0,1,0,0,1,0,0],
		],
		"colors": {
			1: Color(0.15, 0.30, 0.10),  # dark green outline
			2: Color(0.50, 0.80, 0.30),  # bright green hat
			3: Color(0.85, 0.70, 0.55),  # skin
			4: Color(0.20, 0.45, 0.15),  # body
		},
		"scale": 0.6,
	},
	"mist_wolf": {
		"grid": [
			[0,0,1,1,0,0,0,0,0,0],
			[0,1,2,2,1,0,0,0,0,0],
			[1,2,3,2,2,1,1,1,0,0],
			[1,2,2,2,2,2,2,2,1,0],
			[0,1,2,2,2,2,2,2,2,1],
			[0,0,1,2,2,2,2,2,1,0],
			[0,0,1,0,0,1,0,1,0,0],
			[0,0,1,0,0,1,0,1,0,0],
		],
		"colors": {
			1: Color(0.25, 0.25, 0.30),  # dark outline
			2: Color(0.50, 0.50, 0.55),  # grey fur
			3: Color(0.70, 0.85, 0.90),  # pale eye
		},
		"scale": 0.9,
	},
	"white_deer": {
		"grid": [
			[0,0,1,0,0,1,0,0],
			[0,0,1,0,0,1,0,0],
			[0,1,1,1,1,1,1,0],
			[0,1,2,2,2,2,1,0],
			[1,2,3,2,2,3,2,1],
			[1,2,2,2,2,2,2,1],
			[0,1,2,2,2,2,1,0],
			[0,0,1,0,0,1,0,0],
			[0,0,1,0,0,1,0,0],
		],
		"colors": {
			1: Color(0.80, 0.75, 0.70),  # antler/outline
			2: Color(0.95, 0.95, 0.93),  # white body
			3: Color(0.20, 0.20, 0.25),  # dark eye
		},
		"scale": 1.0,
	},
	"giant_raven": {
		"grid": [
			[0,0,0,1,1,0,0,0],
			[0,0,1,1,1,1,0,0],
			[0,1,1,2,1,1,1,0],
			[1,1,1,1,1,1,1,1],
			[1,1,1,1,1,1,1,1],
			[0,1,1,0,0,1,1,0],
			[0,0,3,0,0,3,0,0],
		],
		"colors": {
			1: Color(0.05, 0.05, 0.08),  # black feathers
			2: Color(0.60, 0.60, 0.65),  # pale eye
			3: Color(0.25, 0.20, 0.10),  # talon
		},
		"scale": 0.7,
	},
}


func _init(forest_root: Node3D) -> void:
	_forest_root = forest_root
	_rng.randomize()
	print("[BrocCreatureSpawner] 4 creature types ready")


func update(delta: float, player_pos: Vector3, zone_idx: int, is_night: bool) -> void:
	_spawn_cooldown = maxf(_spawn_cooldown - delta, 0.0)

	# Update existing creatures
	var to_remove: Array[int] = []
	for i in _active.size():
		var c: Dictionary = _active[i]
		var node: Node3D = c["node"] as Node3D
		if not is_instance_valid(node):
			to_remove.append(i)
			continue

		var dist: float = player_pos.distance_to(node.position)

		match c["state"]:
			"spawning":
				c["alpha"] = minf(float(c["alpha"]) + FADE_SPEED * delta, 1.0)
				_set_creature_alpha(node, float(c["alpha"]))
				if float(c["alpha"]) >= 1.0:
					c["state"] = "idle"
			"idle":
				# Gentle sway
				node.position.y = float(c.get("base_y", 0.0)) + sin(float(c.get("time", 0.0))) * 0.05
				c["time"] = float(c.get("time", 0.0)) + delta * 1.5
				# Flee if player too close
				if dist < FLEE_DIST:
					c["state"] = "fleeing"
			"fleeing":
				# Move away from player
				var away: Vector3 = (node.position - player_pos).normalized()
				away.y = 0.0
				node.position += away * 3.0 * delta
				c["alpha"] = maxf(float(c["alpha"]) - FADE_SPEED * 0.8 * delta, 0.0)
				_set_creature_alpha(node, float(c["alpha"]))
				if float(c["alpha"]) <= 0.0:
					node.queue_free()
					to_remove.append(i)

		# Despawn if too far
		if dist > DESPAWN_DIST and c["state"] != "fleeing":
			c["state"] = "fleeing"

	# Remove despawned (reverse order)
	to_remove.sort()
	for i in range(to_remove.size() - 1, -1, -1):
		_active.remove_at(to_remove[i])

	# Try to spawn new creatures
	if _active.size() < MAX_CREATURES and _spawn_cooldown <= 0.0:
		_try_spawn(player_pos, zone_idx, is_night)


func spawn_creature(creature_type: String, pos: Vector3) -> void:
	if not CREATURE_GRIDS.has(creature_type):
		return
	if _active.size() >= MAX_CREATURES:
		return
	var node: Node3D = _build_pixel_rig(creature_type)
	node.position = pos
	_set_creature_alpha(node, 0.0)
	_forest_root.add_child(node)
	_active.append({
		"node": node,
		"type": creature_type,
		"state": "spawning",
		"alpha": 0.0,
		"base_y": pos.y,
		"time": _rng.randf() * TAU,
	})
	_spawn_cooldown = 15.0


func _try_spawn(player_pos: Vector3, zone_idx: int, is_night: bool) -> void:
	var types: Array = ZONE_CREATURES.get(zone_idx, []) as Array
	# Raven spawns anywhere at night
	if is_night and not types.has("giant_raven"):
		types = types.duplicate()
		types.append("giant_raven")
	if types.is_empty():
		return

	var creature_type: String = types[_rng.randi_range(0, types.size() - 1)] as String
	if not CREATURE_GRIDS.has(creature_type):
		return

	# Spawn at random position around player
	var angle: float = _rng.randf_range(0.0, TAU)
	var dist: float = _rng.randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX)
	var pos: Vector3 = player_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	spawn_creature(creature_type, pos)


func _build_pixel_rig(creature_type: String) -> Node3D:
	var data: Dictionary = CREATURE_GRIDS[creature_type]
	var grid: Array = data["grid"] as Array
	var colors: Dictionary = data["colors"] as Dictionary
	var creature_scale: float = float(data.get("scale", 1.0))

	var root: Node3D = Node3D.new()
	root.name = "Creature_%s" % creature_type

	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(PX, PX, PX) * creature_scale

	for row_idx in grid.size():
		var row: Array = grid[row_idx] as Array
		for col_idx in row.size():
			var ci: int = int(row[col_idx])
			if ci == 0:
				continue
			if not colors.has(ci):
				continue

			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = box_mesh

			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = colors[ci] as Color
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			var x_off: float = (float(col_idx) - float(row.size()) * 0.5) * PX * creature_scale
			var y_off: float = (float(grid.size()) - float(row_idx) - float(grid.size()) * 0.5) * PX * creature_scale
			mi.position = Vector3(x_off, y_off, 0.0)
			root.add_child(mi)

	return root


func _set_creature_alpha(node: Node3D, alpha: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = alpha
