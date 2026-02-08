extends Node3D

const PALETTE = {
	"bg_deep": Color(0.02, 0.04, 0.08),
	"bg_mid": Color(0.08, 0.12, 0.18),
	"gold": Color(0.85, 0.7, 0.3),
	"gold_bright": Color(0.95, 0.82, 0.4),
	"green": Color(0.22, 0.55, 0.35),
	"green_bright": Color(0.35, 0.85, 0.55),
	"stone": Color(0.33, 0.38, 0.45),
	"wood": Color(0.43, 0.3, 0.2),
	"wood_dark": Color(0.28, 0.2, 0.12),
	"purple": Color(0.55, 0.35, 0.8),
	"mist": Color(0.12, 0.16, 0.24),
}

@onready var pause_panel = $PauseLayer/PausePanel
@onready var pause_btn_menu = $PauseLayer/PausePanel/VBox/BtnMenu
@onready var pause_btn_combat = $PauseLayer/PausePanel/VBox/BtnTestCombat
@onready var pause_btn_aventure = $PauseLayer/PausePanel/VBox/BtnTestAventure
@onready var pause_btn_antre = $PauseLayer/PausePanel/VBox/BtnTestAntre

@onready var merlin_sprite = $Interior/MerlinSprite
@onready var cauldron_light = $Interior/CauldronLight
@onready var cauldron_particles = $Interior/CauldronParticles
@onready var creature_a = $Interior/CreatureA
@onready var creature_b = $Interior/CreatureB
@onready var shelf_sprite = $Interior/ShelfSprite
@onready var vial_sprite = $Interior/VialSprite
@onready var book_sprite = $Interior/BookSprite
@onready var crystal_sprite = $Interior/CrystalSprite
@onready var fireplace_sprite = $Interior/Fireplace

@onready var table_mesh = $Interior/Table
@onready var shelf_mesh = $Interior/Shelf
@onready var crate_a = $Interior/CrateA
@onready var crate_b = $Interior/CrateB
@onready var floor_mesh = $Interior/Floor
@onready var wall_north = $Interior/WallNorth
@onready var wall_south = $Interior/WallSouth
@onready var wall_east = $Interior/WallEast
@onready var wall_west = $Interior/WallWest
@onready var world_env = $WorldEnvironment

var pause_visible := false
var time_accum := 0.0
var merlin_base_scale := Vector3.ONE
var creature_base_y_a := 0.0
var creature_base_y_b := 0.0
var crystal_base_y := 0.0

func _ready():
	pause_panel.visible = false
	pause_btn_menu.pressed.connect(func(): _change_scene("res://scenes/MenuPrincipal.tscn"))
	pause_btn_combat.pressed.connect(func(): _change_scene("res://scenes/TestCombat.tscn"))
	pause_btn_aventure.pressed.connect(func(): _change_scene("res://scenes/TestAventure.tscn"))
	pause_btn_antre.pressed.connect(func(): _change_scene("res://scenes/TestAntreMerlin.tscn"))

	if merlin_sprite:
		merlin_base_scale = merlin_sprite.scale
	if creature_a:
		creature_base_y_a = creature_a.position.y
	if creature_b:
		creature_base_y_b = creature_b.position.y
	if crystal_sprite:
		crystal_base_y = crystal_sprite.position.y

	_apply_palette()
	_setup_billboards()
	_configure_environment()

func _process(delta):
	time_accum += delta
	if merlin_sprite:
		var breathe = 1.0 + sin(time_accum * 2.0) * 0.04
		merlin_sprite.scale = Vector3(merlin_base_scale.x, merlin_base_scale.y * breathe, merlin_base_scale.z)
	if cauldron_light:
		cauldron_light.light_energy = 1.05 + sin(time_accum * 3.4) * 0.25
		cauldron_light.light_color = PALETTE.green_bright.lerp(PALETTE.gold_bright, 0.3 + 0.2 * sin(time_accum * 2.1))
	if creature_a:
		creature_a.position.y = creature_base_y_a + sin(time_accum * 1.6) * 0.08
	if creature_b:
		creature_b.position.y = creature_base_y_b + sin(time_accum * 1.4 + 1.2) * 0.08
	if crystal_sprite:
		crystal_sprite.position.y = crystal_base_y + sin(time_accum * 2.2) * 0.05
		crystal_sprite.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(time_accum * 3.0))

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _toggle_pause():
	pause_visible = not pause_visible
	pause_panel.visible = pause_visible

func _change_scene(path: String):
	pause_visible = false
	pause_panel.visible = false
	get_tree().change_scene_to_file(path)

func _apply_palette():
	_set_mesh_color(floor_mesh, PALETTE.bg_mid)
	_set_mesh_color(wall_north, PALETTE.stone)
	_set_mesh_color(wall_south, PALETTE.stone.darkened(0.08))
	_set_mesh_color(wall_east, PALETTE.stone.darkened(0.12))
	_set_mesh_color(wall_west, PALETTE.stone.darkened(0.12))
	_set_mesh_color(table_mesh, PALETTE.wood)
	_set_mesh_color(shelf_mesh, PALETTE.wood_dark)
	_set_mesh_color(crate_a, PALETTE.wood.darkened(0.2))
	_set_mesh_color(crate_b, PALETTE.wood.darkened(0.25))
	if cauldron_light:
		cauldron_light.light_color = PALETTE.green_bright
	if fireplace_sprite:
		_apply_sprite_material(fireplace_sprite, fireplace_sprite.texture, Color(1, 1, 1, 0.9))

func _set_mesh_color(node: Node, color: Color) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		mat.metallic = 0.0
		node.material_override = mat

func _configure_environment():
	if world_env == null:
		return
	var env = world_env.environment
	if env == null:
		return
	env.ambient_light_color = PALETTE.mist
	env.ambient_light_energy = 1.1
	env.fog_light_color = PALETTE.bg_mid
	env.fog_density = 0.035
	env.fog_height = 4.0
	env.fog_height_density = 0.18

func _setup_billboards():
	_apply_billboard(shelf_sprite, _make_shelf_texture(), PALETTE.gold)
	_apply_billboard(vial_sprite, _make_vial_texture(), PALETTE.green_bright)
	_apply_billboard(book_sprite, _make_book_texture(), PALETTE.gold_bright)
	_apply_billboard(crystal_sprite, _make_crystal_texture(), PALETTE.purple)
	_apply_billboard(creature_a, _make_creature_texture(), PALETTE.purple)
	_apply_billboard(creature_b, _make_creature_texture(), PALETTE.purple.darkened(0.1))
	if merlin_sprite:
		_apply_sprite_material(merlin_sprite, merlin_sprite.texture, Color(1, 1, 1, 1))

func _apply_billboard(sprite: Sprite3D, tex: Texture2D, tint: Color) -> void:
	if sprite == null or tex == null:
		return
	sprite.texture = tex
	_apply_sprite_material(sprite, tex, tint)

func _apply_sprite_material(sprite: Sprite3D, tex: Texture2D, tint: Color) -> void:
	if sprite == null:
		return
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = tint
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sprite.material_override = mat

func _make_shelf_texture() -> Texture2D:
	var img = Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(PALETTE.wood_dark)
	for x in range(2, 30, 4):
		var c = PALETTE.wood if x % 8 == 0 else PALETTE.wood.darkened(0.1)
		for y in range(2, 14):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _make_vial_texture() -> Texture2D:
	var img = Image.create(12, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(3, 9):
		for y in range(4, 16):
			img.set_pixel(x, y, PALETTE.green_bright)
	for x in range(4, 8):
		img.set_pixel(x, 3, PALETTE.gold_bright)
	return ImageTexture.create_from_image(img)

func _make_book_texture() -> Texture2D:
	var img = Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(PALETTE.wood)
	for x in range(2, 14):
		img.set_pixel(x, 2, PALETTE.gold_bright)
		img.set_pixel(x, 9, PALETTE.gold)
	for y in range(3, 9):
		img.set_pixel(2, y, PALETTE.wood_dark)
		img.set_pixel(13, y, PALETTE.wood_dark)
	return ImageTexture.create_from_image(img)

func _make_crystal_texture() -> Texture2D:
	var img = Image.create(14, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, 16):
		var width = 1 + int(min(y, 16 - y) * 0.7)
		for x in range(7 - width, 7 + width):
			img.set_pixel(x, y, PALETTE.purple)
	img.set_pixel(7, 3, PALETTE.gold_bright)
	img.set_pixel(6, 5, PALETTE.gold_bright)
	return ImageTexture.create_from_image(img)

func _make_creature_texture() -> Texture2D:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(4, 12):
		for y in range(5, 12):
			img.set_pixel(x, y, PALETTE.purple)
	img.set_pixel(6, 7, PALETTE.gold_bright)
	img.set_pixel(9, 7, PALETTE.gold_bright)
	return ImageTexture.create_from_image(img)
