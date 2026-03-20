## ═══════════════════════════════════════════════════════════════════════════════
## BrocFaunaBubble — CRT-style dialogue bubbles above forest creatures
## ═══════════════════════════════════════════════════════════════════════════════
## Small ambient bubbles that appear when creatures are idle and nearby.
## Projected from 3D creature position to 2D screen overlay.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

const BUBBLE_RANGE: float = 8.0
const BUBBLE_DURATION: float = 4.0
const BUBBLE_COOLDOWN: float = 20.0
const MAX_BUBBLES: int = 2

const DIALOGUE_POOLS: Dictionary = {
	"korrigan": ["Zzz...", "Brillant !", "Chut...", "He he", "*glousse*"],
	"white_deer": ["...", "*brame*", "*observe*", "*renifle*"],
	"mist_wolf": ["Grrrr", "*renifle*", "...", "*grogne*"],
	"giant_raven": ["Croa !", "Kra kra", "*observe*", "*croasse*"],
	"flora": ["*bruisse*", "*craque*", "*murmure*", "*frémit*"],
}

var _canvas_layer: CanvasLayer
var _parent: Node
var _active_count: int = 0
var _cooldowns: Dictionary = {}  # position_hash -> time_remaining
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(parent: Node) -> void:
	_parent = parent
	_rng.randomize()
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 12
	_canvas_layer.name = "FaunaBubbleLayer"
	_parent.add_child(_canvas_layer)


func update(delta: float, camera: Camera3D, creatures: Array) -> void:
	if not is_instance_valid(_canvas_layer) or not is_instance_valid(camera):
		return

	# Tick cooldowns
	var expired_keys: Array = []
	for key: int in _cooldowns:
		_cooldowns[key] = float(_cooldowns[key]) - delta
		if float(_cooldowns[key]) <= 0.0:
			expired_keys.append(key)
	for key: int in expired_keys:
		_cooldowns.erase(key)

	# Count active bubbles (children of canvas layer)
	_active_count = _canvas_layer.get_child_count()

	for creature_data: Dictionary in creatures:
		if _active_count >= MAX_BUBBLES:
			break

		var state: String = str(creature_data.get("state", ""))
		if state != "idle":
			continue

		var pos: Vector3 = creature_data.get("position", Vector3.ZERO) as Vector3
		var creature_type: String = str(creature_data.get("type", ""))

		var dist: float = camera.global_position.distance_to(pos)
		if dist > BUBBLE_RANGE:
			continue

		var pos_hash: int = _hash_position(pos)
		if _cooldowns.has(pos_hash):
			continue

		if not DIALOGUE_POOLS.has(creature_type):
			continue

		# Project to screen
		var screen_pos: Vector2 = camera.unproject_position(pos + Vector3(0.0, 0.8, 0.0))
		var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
		if screen_pos.x < 0.0 or screen_pos.x > viewport_size.x:
			continue
		if screen_pos.y < 0.0 or screen_pos.y > viewport_size.y:
			continue
		# Also skip if behind camera
		if camera.is_position_behind(pos + Vector3(0.0, 0.8, 0.0)):
			continue

		# Pick random dialogue
		var pool: Array = DIALOGUE_POOLS[creature_type] as Array
		var text: String = pool[_rng.randi_range(0, pool.size() - 1)] as String

		# Create bubble
		_spawn_bubble(screen_pos, text)
		_cooldowns[pos_hash] = BUBBLE_COOLDOWN
		_active_count += 1


func _spawn_bubble(screen_pos: Vector2, text: String) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "FaunaBubble"

	# Style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var bg_color: Color = MerlinVisual.CRT_PALETTE["bg_dark"]
	style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.85)
	var border_color: Color = MerlinVisual.CRT_PALETTE["border"]
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	panel.add_theme_stylebox_override("panel", style)

	# Label
	var label: Label = Label.new()
	label.text = text
	var font: Font = MerlinVisual.get_font("terminal")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 12)
	var phosphor_color: Color = MerlinVisual.CRT_PALETTE["phosphor"]
	label.add_theme_color_override("font_color", phosphor_color)
	panel.add_child(label)

	# Position (centered on screen coords)
	panel.position = Vector2(screen_pos.x - 30.0, screen_pos.y - 20.0)
	panel.modulate.a = 0.0

	_canvas_layer.add_child(panel)

	# Tween: fade in -> hold -> fade out -> free
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(BUBBLE_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


func _hash_position(pos: Vector3) -> int:
	# Simple spatial hash for cooldown tracking
	var hx: int = int(pos.x * 100.0)
	var hy: int = int(pos.y * 100.0)
	var hz: int = int(pos.z * 100.0)
	return hx * 73856093 ^ hy * 19349663 ^ hz * 83492791
