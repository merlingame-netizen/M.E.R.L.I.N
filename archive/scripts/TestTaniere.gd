extends Control

const NEED_MIN := 0
const NEED_MAX := 100
const MAX_BOND := 12

const FORMS := [
	"Veil",
	"Stone",
	"Ember",
	"River",
	"Thorn",
	"Gale",
	"Root",
	"Tide",
	"Emberglass",
	"Moss"
]

const MINI_TYPES := ["pulse", "balance", "memory"]

const ITEM_EFFECTS := {
	"herbal_pack": {"mood": 12, "clean": 4},
	"glow_berry": {"energy": 14},
	"stone_treat": {"bond": 2, "vitality": 1},
	"mist_tea": {"mood": 8, "spirit": 1}
}

const TALENT_DEFS := {
	"root": {
		"name": "Lien Primordial",
		"short": "Lien",
		"desc": "Anchor the bond and unlock the three paths.",
		"req": [],
		"unlocked": true
	},
	"bond": {
		"name": "Serment",
		"short": "Serment",
		"desc": "Promises weigh more. +1 bond and +4 mood.",
		"req": ["root"],
		"unlocked": false
	},
	"essence": {
		"name": "Essence",
		"short": "Essence",
		"desc": "Bestiole drinks the world. +1 spirit and +1 essence.",
		"req": ["root"],
		"unlocked": false
	},
	"feral": {
		"name": "Feral",
		"short": "Feral",
		"desc": "Wild instincts. +1 agility and +6 energy.",
		"req": ["root"],
		"unlocked": false
	},
	"oath": {
		"name": "Oathkeeper",
		"short": "Oath",
		"desc": "Mini game success grants extra mood.",
		"req": ["bond"],
		"unlocked": false
	},
	"rune": {
		"name": "Rune Attune",
		"short": "Rune",
		"desc": "Equipping runes adds +1 focus.",
		"req": ["essence"],
		"unlocked": false
	},
	"prowl": {
		"name": "Prowl",
		"short": "Prowl",
		"desc": "Day decay softens for hunger and energy.",
		"req": ["feral"],
		"unlocked": false
	}
}

const TALENT_BUTTON_MAP := {
	"TalentRoot": "root",
	"TalentBond": "bond",
	"TalentEssence": "essence",
	"TalentFeral": "feral",
	"TalentOath": "oath",
	"TalentRune": "rune",
	"TalentProwl": "prowl"
}

@onready var tabs: TabContainer = $MainContainer/LeftPanel/LeftVBox/Tabs

@onready var bestiole_sprite: TextureRect = $MainContainer/CenterPanel/CenterVBox/BestioleSprite
@onready var bestiole_material: ShaderMaterial = bestiole_sprite.material as ShaderMaterial
@onready var mood_icon: Label = $MainContainer/CenterPanel/CenterVBox/InfoRow/MoodIcon
@onready var mood_label: Label = $MainContainer/CenterPanel/CenterVBox/InfoRow/MoodLabel
@onready var form_label: Label = $MainContainer/CenterPanel/CenterVBox/InfoRow/FormLabel
@onready var time_label: Label = $MainContainer/CenterPanel/CenterVBox/InfoRow/TimeLabel

@onready var hunger_bar: ProgressBar = $MainContainer/CenterPanel/CenterVBox/NeedGrid/HungerRow/HungerBar
@onready var energy_bar: ProgressBar = $MainContainer/CenterPanel/CenterVBox/NeedGrid/EnergyRow/EnergyBar
@onready var mood_bar: ProgressBar = $MainContainer/CenterPanel/CenterVBox/NeedGrid/MoodRowBar/MoodBar
@onready var clean_bar: ProgressBar = $MainContainer/CenterPanel/CenterVBox/NeedGrid/CleanRow/CleanBar
@onready var bond_bar: ProgressBar = $MainContainer/CenterPanel/CenterVBox/BondRow/BondBar

@onready var skill_points_label: Label = $MainContainer/LeftPanel/LeftVBox/Tabs/StatsTab/SkillPointsLabel
@onready var vitality_bar: ProgressBar = $MainContainer/LeftPanel/LeftVBox/Tabs/StatsTab/StatVitality/VitalityBar
@onready var focus_bar: ProgressBar = $MainContainer/LeftPanel/LeftVBox/Tabs/StatsTab/StatFocus/FocusBar
@onready var spirit_bar: ProgressBar = $MainContainer/LeftPanel/LeftVBox/Tabs/StatsTab/StatSpirit/SpiritBar
@onready var agility_bar: ProgressBar = $MainContainer/LeftPanel/LeftVBox/Tabs/StatsTab/StatAgility/AgilityBar

@onready var talent_points_label: Label = $MainContainer/LeftPanel/LeftVBox/Tabs/TalentsTab/TalentPointsLabel
@onready var talent_info: Label = $MainContainer/LeftPanel/LeftVBox/Tabs/TalentsTab/TalentInfo
@onready var talent_grid: GridContainer = $MainContainer/LeftPanel/LeftVBox/Tabs/TalentsTab/TalentGrid

@onready var skills_list: ItemList = $MainContainer/LeftPanel/LeftVBox/Tabs/SkillsTab/SkillsList
@onready var inventory_list: ItemList = $MainContainer/LeftPanel/LeftVBox/Tabs/InventoryTab/InventoryList
@onready var runes_list: ItemList = $MainContainer/LeftPanel/LeftVBox/Tabs/RunesTab/RunesList

@onready var rune_slot_1: Label = $MainContainer/LeftPanel/LeftVBox/Tabs/RunesTab/RuneSlots/RuneSlot1
@onready var rune_slot_2: Label = $MainContainer/LeftPanel/LeftVBox/Tabs/RunesTab/RuneSlots/RuneSlot2
@onready var rune_slot_3: Label = $MainContainer/LeftPanel/LeftVBox/Tabs/RunesTab/RuneSlots/RuneSlot3

@onready var resources_text: RichTextLabel = $MainContainer/RightPanel/RightVBox/ResourcesText
@onready var combat_text: RichTextLabel = $MainContainer/RightPanel/RightVBox/CombatStatsText
@onready var log_text: RichTextLabel = $MainContainer/RightPanel/RightVBox/LogText

@onready var minigame_panel: PanelContainer = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel
@onready var minigame_title: Label = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniGameTitle
@onready var minigame_info: Label = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniGameInfo
@onready var mini_area: Control = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniArea
@onready var mini_bar: ProgressBar = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniArea/MiniBar
@onready var mini_target: ColorRect = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniArea/MiniTarget
@onready var mini_cursor: ColorRect = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniArea/MiniCursor
@onready var btn_mini_hit: Button = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniActionRow/BtnMiniHit
@onready var btn_mini_stop: Button = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MiniActionRow/BtnMiniStop
@onready var mem_row: HBoxContainer = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MemoryRow
@onready var btn_mem_a: Button = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MemoryRow/BtnMemA
@onready var btn_mem_b: Button = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MemoryRow/BtnMemB
@onready var btn_mem_c: Button = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MemoryRow/BtnMemC
@onready var mem_sequence_label: Label = $MainContainer/CenterPanel/CenterVBox/MiniGamePanel/MiniGameVBox/MemSequenceLabel

var bestiole_active := true
var hunger := 70
var energy := 60
var mood := 65
var cleanliness := 70
var bond := 2
var form_index := 0
var is_night := false
var days_since_care := 0

var resources := {
	"nourriture": 5,
	"essence": 3,
	"materiel": 4,
	"faveur": 2
}

var combat_stats := {
	"vitality": 2,
	"focus": 2,
	"spirit": 2,
	"agility": 2
}

var skill_points := 3
var talent_points := 2
var talents := {}
var talent_buttons: Dictionary = {}
var talent_flags := {"oath": false, "rune": false, "prowl": false}

var skills := [
	{"name": "Guard", "level": 1},
	{"name": "Scout", "level": 1},
	{"name": "Nudge", "level": 1},
	{"name": "Ward", "level": 0}
]

var inventory := [
	{"id": "herbal_pack", "name": "Herbal Pack", "count": 2},
	{"id": "glow_berry", "name": "Glow Berry", "count": 3},
	{"id": "stone_treat", "name": "Stone Treat", "count": 1},
	{"id": "mist_tea", "name": "Mist Tea", "count": 1}
]

var runes := [
	"Rune Brume",
	"Rune Pierre",
	"Rune Source",
	"Rune Feu"
]

var rune_slots := ["", "", ""]

var minigame_active := false
var minigame_type := ""
var minigame_time := 0.0
var minigame_duration := 3.5
var cursor_value := 0.0
var cursor_dir := 1.0
var target_min := 0.35
var target_max := 0.55
var balance_score := 0.0
var memory_sequence: Array[String] = []
var memory_input: Array[String] = []

var log_lines: Array[String] = []
var time_accum := 0.0
var rng := RandomNumberGenerator.new()

var press_time := 0.0
var pressing_bestiole := false
var press_uv := Vector2(0.5, 0.5)
var press_strength := 0.0
var press_radius := 0.23

func _ready() -> void:
	set_process(true)
	rng.randomize()
	_bind_buttons()
	_bind_bestiole_input()
	_bind_talent_buttons()
	_reset_state(false)
	_refresh_lists()
	_refresh_talents()
	_update_ui()

func _process(delta: float) -> void:
	time_accum += delta
	_update_bestiole_anim(delta)
	if minigame_active:
		_update_minigame(delta)

func _bind_buttons() -> void:
	var buttons = get_tree().get_nodes_in_group("bestiole_buttons")
	if buttons.is_empty():
		_register_buttons_recursive(self)
	for child in get_tree().get_nodes_in_group("bestiole_buttons"):
		if child is Button:
			child.pressed.connect(_on_button_pressed.bind(child))

func _register_buttons_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.add_to_group("bestiole_buttons")
		_register_buttons_recursive(child)

func _bind_talent_buttons() -> void:
	talent_buttons.clear()
	if not talent_grid:
		return
	for child in talent_grid.get_children():
		if child is Button and TALENT_BUTTON_MAP.has(child.name):
			var talent_id = TALENT_BUTTON_MAP[child.name]
			talent_buttons[talent_id] = child
			child.pressed.connect(_on_talent_pressed.bind(talent_id))

func _bind_bestiole_input() -> void:
	if bestiole_sprite:
		bestiole_sprite.gui_input.connect(_on_bestiole_input)
		bestiole_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
		bestiole_sprite.pivot_offset = bestiole_sprite.size / 2
		_update_press_material()

func _on_bestiole_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressing_bestiole = true
			press_time = 0.0
			_set_press_uv(event.position)
		else:
			pressing_bestiole = false
			_press_release_anim()
	elif event is InputEventMouseMotion and pressing_bestiole:
		_set_press_uv(event.position)

func _update_bestiole_anim(delta: float) -> void:
	if not bestiole_sprite:
		return
	var pulse = 1.0 + 0.015 * sin(time_accum * 1.6)
	if pressing_bestiole:
		press_time = min(1.0, press_time + delta * 1.8)
		press_strength = lerp(press_strength, press_time, 0.25)
	else:
		press_time = max(0.0, press_time - delta * 2.2)
		press_strength = max(0.0, press_strength - delta * 2.4)
	bestiole_sprite.scale = Vector2(pulse, pulse)
	_update_press_material()

func _press_release_anim() -> void:
	press_strength = max(press_strength, 0.4)

func _set_press_uv(local_pos: Vector2) -> void:
	if not bestiole_sprite or bestiole_sprite.size == Vector2.ZERO:
		return
	var uv = local_pos / bestiole_sprite.size
	press_uv = Vector2(clampf(uv.x, 0.0, 1.0), clampf(uv.y, 0.0, 1.0))
	_update_press_material()

func _update_press_material() -> void:
	if not bestiole_material:
		return
	bestiole_material.set_shader_parameter("press_uv", press_uv)
	bestiole_material.set_shader_parameter("press_strength", press_strength)
	bestiole_material.set_shader_parameter("press_radius", press_radius)

func _on_button_pressed(btn: Button) -> void:
	match btn.name:
		"BtnStartPulse":
			_start_minigame("pulse")
		"BtnStartBalance":
			_start_minigame("balance")
		"BtnStartMemory":
			_start_minigame("memory")
		"BtnMiniHit":
			_resolve_pulse()
		"BtnMiniStop":
			_stop_minigame()
		"BtnMemA":
			_memory_input("A")
		"BtnMemB":
			_memory_input("B")
		"BtnMemC":
			_memory_input("C")
		"BtnUpVitality":
			_upgrade_stat("vitality")
		"BtnUpFocus":
			_upgrade_stat("focus")
		"BtnUpSpirit":
			_upgrade_stat("spirit")
		"BtnUpAgility":
			_upgrade_stat("agility")
		"BtnUpgradeSkill":
			_upgrade_skill()
		"BtnUseItem":
			_use_item()
		"BtnEquipRune1":
			_equip_rune(0)
		"BtnEquipRune2":
			_equip_rune(1)
		"BtnEquipRune3":
			_equip_rune(2)
		"BtnAddResources":
			_add_resources()
		"BtnSimDay":
			_simulate_day()
		"BtnToggleNight":
			_toggle_night()
		"BtnReset":
			_reset_state(true)
		"BtnSpawn":
			_toggle_spawn()

func _start_minigame(kind: String) -> void:
	if not bestiole_active:
		_log("No Bestiole active")
		return
	minigame_type = kind
	minigame_active = true
	minigame_time = 0.0
	balance_score = 0.0
	cursor_value = 0.0
	cursor_dir = 1.0
	target_min = rng.randf_range(0.2, 0.6)
	target_max = target_min + 0.18
	minigame_panel.visible = true
	var area_width = maxf(1.0, mini_area.size.x)
	if area_width <= 1.0:
		area_width = maxf(1.0, mini_area.custom_minimum_size.x)
	mini_target.position.x = target_min * area_width
	mini_target.size.x = (target_max - target_min) * area_width
	mem_row.visible = (kind == "memory")
	btn_mini_hit.visible = (kind == "pulse")
	minigame_title.text = "Mini Game: " + kind.capitalize()
	if kind == "pulse":
		minigame_info.text = "Hit when cursor is inside the green zone"
	elif kind == "balance":
		minigame_info.text = "Hold click on Bestiole to stabilize"
	else:
		_memory_generate()
		minigame_info.text = "Repeat the sequence"
	_log("Mini game started: " + kind)

func _stop_minigame() -> void:
	minigame_active = false
	minigame_panel.visible = false
	_log("Mini game stopped")

func _update_minigame(delta: float) -> void:
	minigame_time += delta
	if minigame_type == "pulse":
		cursor_value += delta * cursor_dir * 0.6
		if cursor_value >= 1.0:
			cursor_value = 1.0
			cursor_dir = -1.0
		elif cursor_value <= 0.0:
			cursor_value = 0.0
			cursor_dir = 1.0
		_update_cursor()
		if minigame_time > minigame_duration:
			_stop_minigame()
	elif minigame_type == "balance":
		var drift = rng.randf_range(-0.25, 0.25)
		if pressing_bestiole:
			drift *= 0.25
		cursor_value = clampf(cursor_value + drift * delta, 0.0, 1.0)
		_update_cursor()
		if cursor_value >= target_min and cursor_value <= target_max:
			balance_score += delta
		if minigame_time > minigame_duration:
			_resolve_balance()

func _update_cursor() -> void:
	var area_width = maxf(1.0, mini_area.size.x)
	if area_width <= 1.0:
		area_width = maxf(1.0, mini_area.custom_minimum_size.x)
	mini_cursor.position.x = cursor_value * (area_width - mini_cursor.size.x)
	mini_bar.value = cursor_value * 100.0

func _resolve_pulse() -> void:
	if not minigame_active or minigame_type != "pulse":
		return
	if cursor_value >= target_min and cursor_value <= target_max:
		_reward_success("pulse")
	else:
		_reward_fail("pulse")
	_stop_minigame()

func _resolve_balance() -> void:
	if balance_score >= 1.4:
		_reward_success("balance")
	else:
		_reward_fail("balance")
	_stop_minigame()

func _memory_generate() -> void:
	memory_sequence.clear()
	memory_input.clear()
	var letters = ["A", "B", "C"]
	for i in range(3):
		memory_sequence.append(letters[rng.randi_range(0, 2)])
	mem_sequence_label.text = "Sequence: " + "-".join(memory_sequence)

func _memory_input(letter: String) -> void:
	if not minigame_active or minigame_type != "memory":
		return
	memory_input.append(letter)
	if memory_input.size() >= memory_sequence.size():
		if memory_input == memory_sequence:
			_reward_success("memory")
		else:
			_reward_fail("memory")
		_stop_minigame()

func _reward_success(kind: String) -> void:
	_change_mood(8)
	_change_bond(1)
	if talent_flags.get("oath", false):
		_change_mood(3)
	_play_bestiole_anim("happy")
	_log("Mini game success: " + kind)

func _reward_fail(kind: String) -> void:
	_change_mood(-4)
	_play_bestiole_anim("sad")
	_log("Mini game fail: " + kind)

func _upgrade_stat(stat_key: String) -> void:
	if skill_points <= 0:
		_log("No skill points")
		return
	if resources["essence"] <= 0 or resources["materiel"] <= 0:
		_log("Need essence + materiel")
		return
	combat_stats[stat_key] = min(10, combat_stats[stat_key] + 1)
	skill_points -= 1
	resources["essence"] -= 1
	resources["materiel"] -= 1
	_update_ui()
	_log("Upgraded " + stat_key)

func _upgrade_skill() -> void:
	var idx = skills_list.get_selected_items()
	if idx.is_empty():
		return
	if skill_points <= 0:
		_log("No skill points")
		return
	var item = skills[idx[0]]
	item.level += 1
	skills[idx[0]] = item
	skill_points -= 1
	_refresh_lists()
	_update_ui()
	_log("Skill upgraded: " + item.name)

func _use_item() -> void:
	var idx = inventory_list.get_selected_items()
	if idx.is_empty():
		return
	var item = inventory[idx[0]]
	if item.count <= 0:
		return
	_apply_item_effect(item.id)
	item.count -= 1
	if item.count <= 0:
		inventory.remove_at(idx[0])
	else:
		inventory[idx[0]] = item
	_refresh_lists()
	_update_ui()
	_play_bestiole_anim("item")
	_log("Used item: " + item.name)

func _equip_rune(slot_index: int) -> void:
	var idx = runes_list.get_selected_items()
	if idx.is_empty():
		return
	rune_slots[slot_index] = runes[idx[0]]
	if talent_flags.get("rune", false):
		combat_stats["focus"] = min(10, combat_stats["focus"] + 1)
	_update_ui()
	_log("Rune equipped: " + rune_slots[slot_index])

func _apply_item_effect(item_id: String) -> void:
	if not ITEM_EFFECTS.has(item_id):
		return
	var eff = ITEM_EFFECTS[item_id]
	if eff.has("mood"):
		_change_mood(eff["mood"])
	if eff.has("clean"):
		_change_clean(eff["clean"])
	if eff.has("energy"):
		_change_energy(eff["energy"])
	if eff.has("bond"):
		_change_bond(eff["bond"])
	if eff.has("vitality"):
		combat_stats["vitality"] = min(10, combat_stats["vitality"] + eff["vitality"])
	if eff.has("spirit"):
		combat_stats["spirit"] = min(10, combat_stats["spirit"] + eff["spirit"])

func _add_resources() -> void:
	resources["nourriture"] += 2
	resources["essence"] += 1
	resources["materiel"] += 1
	resources["faveur"] += 1
	skill_points += 1
	talent_points += 1
	_update_ui()
	_log("Resources added")

func _toggle_spawn() -> void:
	bestiole_active = not bestiole_active
	bestiole_sprite.visible = bestiole_active
	var spawn_btn = _find_button("BtnSpawn")
	if spawn_btn:
		spawn_btn.text = "Despawn Bestiole" if bestiole_active else "Spawn Bestiole"
	if not bestiole_active and minigame_active:
		_stop_minigame()
	_log("Bestiole " + ("active" if bestiole_active else "hidden"))

func _simulate_day() -> void:
	days_since_care += 1
	var hunger_delta = -5
	var energy_delta = -4
	if talent_flags.get("prowl", false):
		hunger_delta = -3
		energy_delta = -2
	_change_needs(hunger_delta, energy_delta, -6, -5, 0)
	if days_since_care >= 3:
		_change_bond(-1)
	_log("Simulated day")

func _toggle_night() -> void:
	is_night = not is_night
	_update_ui()
	_log("Time: " + ("Night" if is_night else "Day"))

func _reset_state(log_it: bool) -> void:
	bestiole_active = true
	hunger = 70
	energy = 60
	mood = 65
	cleanliness = 70
	bond = 2
	form_index = 0
	is_night = false
	days_since_care = 0
	press_time = 0.0
	press_strength = 0.0
	pressing_bestiole = false
	skill_points = 3
	talent_points = 2
	talent_flags = {"oath": false, "rune": false, "prowl": false}
	resources = {"nourriture": 5, "essence": 3, "materiel": 4, "faveur": 2}
	combat_stats = {"vitality": 2, "focus": 2, "spirit": 2, "agility": 2}
	rune_slots = ["", "", ""]
	talents = _clone_talents()
	if log_it:
		_log("Reset")
	_update_ui()
	_refresh_lists()
	_refresh_talents()

func _refresh_lists() -> void:
	skills_list.clear()
	for skill in skills:
		skills_list.add_item(skill.name + " Lv" + str(skill.level))
	inventory_list.clear()
	for item in inventory:
		inventory_list.add_item(item.name + " x" + str(item.count))
	runes_list.clear()
	for rune in runes:
		runes_list.add_item(rune)

func _clone_talents() -> Dictionary:
	var data := {}
	for key in TALENT_DEFS.keys():
		data[key] = TALENT_DEFS[key].duplicate(true)
	return data

func _refresh_talents() -> void:
	if talent_points_label:
		talent_points_label.text = "Talent Points: " + str(talent_points)
	for key in talent_buttons.keys():
		var btn: Button = talent_buttons[key]
		var info = talents.get(key, null)
		if not info:
			continue
		var unlocked: bool = bool(info.get("unlocked", false))
		var can_unlock: bool = (not unlocked) and _talent_requirements_met(key) and talent_points > 0
		btn.text = info["short"] + (" *" if unlocked else "")
		if unlocked:
			btn.modulate = Color(0.95, 0.9, 0.7, 1)
		elif can_unlock:
			btn.modulate = Color(0.7, 0.85, 1, 1)
		else:
			btn.modulate = Color(0.45, 0.45, 0.5, 1)

func _on_talent_pressed(talent_id: String) -> void:
	if not talents.has(talent_id):
		return
	var info = talents[talent_id]
	_show_talent_info(talent_id)
	if info["unlocked"]:
		return
	if talent_points <= 0:
		_log("No talent points")
		return
	if not _talent_requirements_met(talent_id):
		_log("Talent locked")
		return
	info["unlocked"] = true
	talents[talent_id] = info
	talent_points -= 1
	_apply_talent_effect(talent_id)
	_refresh_talents()
	_update_ui()
	_log("Unlocked talent: " + info["name"])

func _talent_requirements_met(talent_id: String) -> bool:
	if not talents.has(talent_id):
		return false
	var reqs: Array = talents[talent_id]["req"]
	for req in reqs:
		if not talents.has(req) or not talents[req]["unlocked"]:
			return false
	return true

func _apply_talent_effect(talent_id: String) -> void:
	match talent_id:
		"bond":
			_change_bond(1)
			_change_mood(4)
		"essence":
			combat_stats["spirit"] = min(10, combat_stats["spirit"] + 1)
			resources["essence"] += 1
		"feral":
			combat_stats["agility"] = min(10, combat_stats["agility"] + 1)
			_change_energy(6)
		"oath":
			talent_flags["oath"] = true
		"rune":
			talent_flags["rune"] = true
		"prowl":
			talent_flags["prowl"] = true
		_:
			pass

func _show_talent_info(talent_id: String) -> void:
	if not talent_info or not talents.has(talent_id):
		return
	var info = talents[talent_id]
	var locked_text = "" if info["unlocked"] else " (locked)"
	talent_info.text = info["name"] + locked_text + "\n" + info["desc"]

func _update_ui() -> void:
	if mood_icon:
		mood_icon.text = _get_mood_icon()
	if mood_label:
		mood_label.text = "Mood: " + str(mood)
	if form_label:
		form_label.text = "Form: " + FORMS[form_index]
	if time_label:
		time_label.text = "Time: " + ("Night" if is_night else "Day")
	if hunger_bar:
		hunger_bar.value = float(hunger)
		_apply_bar_color(hunger_bar, hunger)
	if energy_bar:
		energy_bar.value = float(energy)
		_apply_bar_color(energy_bar, energy)
	if mood_bar:
		mood_bar.value = float(mood)
		_apply_bar_color(mood_bar, mood)
	if clean_bar:
		clean_bar.value = float(cleanliness)
		_apply_bar_color(clean_bar, cleanliness)
	if bond_bar:
		bond_bar.value = float(bond)
	if skill_points_label:
		skill_points_label.text = "Skill Points: " + str(skill_points)
	if talent_points_label:
		talent_points_label.text = "Talent Points: " + str(talent_points)
	if vitality_bar:
		vitality_bar.value = float(combat_stats["vitality"])
		_apply_stat_color(vitality_bar, combat_stats["vitality"])
	if focus_bar:
		focus_bar.value = float(combat_stats["focus"])
		_apply_stat_color(focus_bar, combat_stats["focus"])
	if spirit_bar:
		spirit_bar.value = float(combat_stats["spirit"])
		_apply_stat_color(spirit_bar, combat_stats["spirit"])
	if agility_bar:
		agility_bar.value = float(combat_stats["agility"])
		_apply_stat_color(agility_bar, combat_stats["agility"])
	if rune_slot_1:
		rune_slot_1.text = "Slot 1: " + (_slot_text(0))
	if rune_slot_2:
		rune_slot_2.text = "Slot 2: " + (_slot_text(1))
	if rune_slot_3:
		rune_slot_3.text = "Slot 3: " + (_slot_text(2))
	_update_resources_text()
	_update_combat_text()
	_refresh_talents()

func _apply_bar_color(bar: ProgressBar, value: int) -> void:
	var t = clampf(float(value) / float(NEED_MAX), 0.0, 1.0)
	var low = Color(0.75, 0.25, 0.25)
	var high = Color(0.25, 0.75, 0.45)
	bar.modulate = low.lerp(high, t)

func _apply_stat_color(bar: ProgressBar, value: int) -> void:
	var t = clampf(float(value) / 10.0, 0.0, 1.0)
	var low = Color(0.35, 0.45, 0.8)
	var high = Color(0.9, 0.8, 0.35)
	bar.modulate = low.lerp(high, t)

func _slot_text(index: int) -> String:
	if rune_slots[index] == "":
		return "(empty)"
	return rune_slots[index]

func _update_resources_text() -> void:
	if not resources_text:
		return
	resources_text.text = "Nourriture: %d\nEssence: %d\nMateriel: %d\nFaveur: %d" % [
		resources["nourriture"],
		resources["essence"],
		resources["materiel"],
		resources["faveur"]
	]

func _update_combat_text() -> void:
	if not combat_text:
		return
	combat_text.text = "Vit: %d\nFocus: %d\nSpirit: %d\nAgi: %d" % [
		combat_stats["vitality"],
		combat_stats["focus"],
		combat_stats["spirit"],
		combat_stats["agility"]
	]

func _get_mood_icon() -> String:
	if mood >= 70:
		return ":)"
	if mood >= 40:
		return ":|"
	return ":("

func _change_needs(hunger_delta: int, energy_delta: int, mood_delta: int, clean_delta: int, bond_delta: int) -> void:
	_change_hunger(hunger_delta)
	_change_energy(energy_delta)
	_change_mood(mood_delta)
	_change_clean(clean_delta)
	_change_bond(bond_delta)
	_update_ui()

func _change_hunger(delta: int) -> void:
	hunger = clampi(hunger + delta, NEED_MIN, NEED_MAX)

func _change_energy(delta: int) -> void:
	energy = clampi(energy + delta, NEED_MIN, NEED_MAX)

func _change_mood(delta: int) -> void:
	mood = clampi(mood + delta, NEED_MIN, NEED_MAX)

func _change_clean(delta: int) -> void:
	cleanliness = clampi(cleanliness + delta, NEED_MIN, NEED_MAX)

func _change_bond(delta: int) -> void:
	bond = clampi(bond + delta, 0, MAX_BOND)

func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 10:
		log_lines = log_lines.slice(log_lines.size() - 10, log_lines.size())
	if log_text:
		log_text.text = "\n".join(log_lines)

func _play_bestiole_anim(kind: String) -> void:
	if not bestiole_sprite:
		return
	var tween = create_tween()
	match kind:
		"happy":
			tween.tween_property(bestiole_sprite, "scale", Vector2(1.08, 1.08), 0.12)
			tween.tween_property(bestiole_sprite, "scale", Vector2.ONE, 0.18)
		"sad":
			tween.tween_property(bestiole_sprite, "scale", Vector2(0.94, 1.02), 0.12)
			tween.tween_property(bestiole_sprite, "scale", Vector2.ONE, 0.18)
		"item":
			tween.tween_property(bestiole_sprite, "scale", Vector2(1.05, 0.95), 0.10)
			tween.tween_property(bestiole_sprite, "scale", Vector2.ONE, 0.16)
		_:
			tween.tween_property(bestiole_sprite, "scale", Vector2(1.04, 1.04), 0.10)
			tween.tween_property(bestiole_sprite, "scale", Vector2.ONE, 0.12)

func _find_button(name: String) -> Button:
	var nodes = get_tree().get_nodes_in_group("bestiole_buttons")
	for node in nodes:
		if node is Button and node.name == name:
			return node
	return null

