## =============================================================================
## HubAntre -- L'Antre Vivant (Spatial Hub)
## =============================================================================
## Immersive spatial hub with procedural pixel art UI.
## 4 hotspots, reactive Bestiole, MerlinBubble greeting,
## PARTIR button -> BiomeRadial -> adventure launch.
## Zero permanent text. All animated.
## =============================================================================

extends Control

# =============================================================================
# SCENE NAVIGATION
# =============================================================================

const SCENE_TRANSITION := "res://scenes/TransitionBiome.tscn"
const SCENE_OPTIONS := "res://scenes/MenuOptions.tscn"
const SCENE_CALENDAR := "res://scenes/Calendar.tscn"
const SCENE_COLLECTION := "res://scenes/Collection.tscn"
const SCENE_ARBRE := "res://scenes/ArbreDeVie.tscn"
const SCENE_MENU := "res://scenes/MenuPrincipal.tscn"
const SCENE_MAPMONDE := "res://scenes/MapMonde.tscn"

# =============================================================================
# BIOME DATA -- 7 Sanctuaires de Bretagne
# =============================================================================

const BIOME_DATA := {
	"foret_broceliande": {
		"name": "Foret de Broceliande",
		"subtitle": "Mystere et magie ancestrale",
		"color": MerlinVisual.ASPECT_COLORS["Monde"],
		"ogham": "duir",
		"guardian": "Maelgwn",
		"season": "automne",
		"aspect_hint": "Corps +20%",
		"difficulty_label": "Normal",
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere",
		"subtitle": "Solitude et endurance",
		"color": MerlinVisual.ASPECT_COLORS["Ame"],
		"ogham": "onn",
		"guardian": "Talwen",
		"season": "hiver",
		"aspect_hint": "Ame +20%",
		"difficulty_label": "Difficile",
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages",
		"subtitle": "L'ocean murmurant",
		"color": MerlinVisual.GBC.water,
		"ogham": "nuin",
		"guardian": "Bran",
		"season": "ete",
		"aspect_hint": "Monde +20%",
		"difficulty_label": "Normal",
	},
	"villages_celtes": {
		"name": "Villages Celtes",
		"subtitle": "Flammes obstinees de l'humanite",
		"color": MerlinVisual.GBC.fire,
		"ogham": "gort",
		"guardian": "Azenor",
		"season": "printemps",
		"aspect_hint": "Monde +20%",
		"difficulty_label": "Facile",
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres",
		"subtitle": "Ou le temps hesite",
		"color": MerlinVisual.CRT_PALETTE.inactive,
		"ogham": "huath",
		"guardian": "Keridwen",
		"season": "samhain",
		"aspect_hint": "Ame +40%",
		"difficulty_label": "Difficile",
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans",
		"subtitle": "Deception et feux follets",
		"color": MerlinVisual.GBC.grass_dark,
		"ogham": "muin",
		"guardian": "Gwydion",
		"season": "lughnasadh",
		"aspect_hint": "Corps +20%",
		"difficulty_label": "Tres difficile",
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens",
		"subtitle": "Les os de la terre",
		"color": MerlinVisual.ASPECT_COLORS_LIGHT["Monde"],
		"ogham": "ioho",
		"guardian": "Elouan",
		"season": "yule",
		"aspect_hint": "Equilibre",
		"difficulty_label": "Normal",
	},
}

# =============================================================================
# BIOME MISSIONS -- Procedural mission pool per biome
# =============================================================================

const BIOME_MISSIONS := {
	"foret_broceliande": [
		{"type": "discovery", "target": "Trouver la Source de Barenton", "total": 8},
		{"type": "alliance", "target": "Ecouter les murmures des arbres anciens", "total": 6},
	],
	"landes_bruyere": [
		{"type": "survival", "target": "Traverser les landes sans faillir", "total": 10},
		{"type": "recovery", "target": "Rallumer le feu de Talwen", "total": 7},
	],
	"cotes_sauvages": [
		{"type": "discovery", "target": "Dechiffrer les vagues de Bran", "total": 8},
		{"type": "alliance", "target": "Calmer les marees errantes", "total": 6},
	],
	"villages_celtes": [
		{"type": "alliance", "target": "Reunir les villages epars", "total": 9},
		{"type": "recovery", "target": "Soigner les fievres d'Azenor", "total": 7},
	],
	"cercles_pierres": [
		{"type": "discovery", "target": "Reveler le chant des menhirs", "total": 8},
		{"type": "survival", "target": "Resister au silence de Keridwen", "total": 10},
	],
	"marais_korrigans": [
		{"type": "survival", "target": "Echapper aux feux follets", "total": 12},
		{"type": "discovery", "target": "Percer les illusions de Gwydion", "total": 8},
	],
	"collines_dolmens": [
		{"type": "recovery", "target": "Apaiser les ancetres d'Elouan", "total": 9},
		{"type": "alliance", "target": "Restaurer les liens ancestraux", "total": 7},
	],
}

# =============================================================================
# MERLIN GREETINGS -- Contextual dialogue lines
# =============================================================================

const MERLIN_GREETINGS := {
	"first_hub": [
		"Bienvenue, %s. Le feu t'attendait.",
		"Entre, %s. Bestiole aussi.",
	],
	"return": [
		"Te revoila, %s !",
		"De retour, %s.",
		"Ah, %s. Toujours debout.",
	],
	"after_fall": [
		"Chaque chute enseigne, %s.",
		"Encore toi, %s ? Bien.",
		"On se releve, %s.",
	],
	"veteran": [
		"Tu connais le chemin, %s.",
		"%s. Qui guide qui ?",
		"Les pierres te reconnaissent, %s.",
	],
}

# =============================================================================
# HOTSPOT CONFIG (icon indices: 0=MOON, 1=TREE, 2=BOOK, 3=GEAR, 4=COMPASS)
# =============================================================================

const HOTSPOT_DEFS := [
	{"name": "calendar", "icon": 0, "label": "Calendrier", "palette_key": "amber_bright", "ratio": Vector2(0.08, 0.10)},
	{"name": "options", "icon": 3, "label": "Options", "palette_key": "phosphor_dim", "ratio": Vector2(0.86, 0.10)},
	{"name": "arbre", "icon": 1, "label": "Arbre", "palette_key": "phosphor_dim", "ratio": Vector2(0.06, 0.45)},
	{"name": "collection", "icon": 2, "label": "Collection", "palette_key": "amber_dim", "ratio": Vector2(0.88, 0.45)},
	# B.1 — Souffle Perk selection (bottom-left, before departure)
	{"name": "souffle", "icon": 4, "label": "Souffle", "palette_key": "phosphor", "ratio": Vector2(0.06, 0.80)},
]

# =============================================================================
# SCENE NODES (from .tscn)
# =============================================================================

@onready var parchment_bg: ColorRect = $ParchmentBg
@onready var mist_layer: ColorRect = $MistLayer

# =============================================================================
# DYNAMIC NODES
# =============================================================================

var _bestiole: Control = null
var _bubble: MerlinBubble = null
var _radial: BiomeRadial = null
var _partir_btn: Button = null
var _hotspots: Array = []
var _perk_overlay: Control = null  # B.1 — Souffle Perk selection overlay

# =============================================================================
# STATE
# =============================================================================

var store: MerlinStore = null
var selected_biome: String = ""
var chronicle_name: String = "Voyageur"
var player_class: String = "eclaireur"
var _current_mission: Dictionary = {}
var _is_first_hub: bool = true
var _passive_llm_pending: bool = false
var _mist_tween: Tween

# Audio
var audio_player: AudioStreamPlayer = null
var voicebox: Node = null
var voice_ready: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_connect_store()
	_load_player_data()
	_configure_background()
	_create_bestiole()
	_create_hotspots()
	_create_partir_button()
	_create_bubble()
	_create_radial()
	_setup_audio()
	_setup_voicebox()
	_apply_aspect_aura()
	_sync_from_state()

	var screen_fx := get_node_or_null("/root/ScreenEffects")
	if screen_fx and screen_fx.has_method("set_merlin_mood"):
		screen_fx.set_merlin_mood("warm")

	resized.connect(_layout_all)
	_start_mist_animation()
	_play_entry_animation.call_deferred()

	await get_tree().create_timer(1.2).timeout
	_show_greeting()


# =============================================================================
# SETUP
# =============================================================================

func _connect_store() -> void:
	store = get_node_or_null("/root/MerlinStore")


func _load_player_data() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var run_data = gm.get("run")
		if run_data is Dictionary:
			var profile: Dictionary = run_data.get("traveler_profile", {})
			player_class = profile.get("class", "eclaireur")
			chronicle_name = run_data.get("chronicle_name", "Voyageur")

	selected_biome = ""

	if store:
		_is_first_hub = not store.state.get("flags", {}).get("hub_visited", false)


func _configure_background() -> void:
	parchment_bg.material = null
	parchment_bg.color = MerlinVisual.CRT_PALETTE.bg_dark
	mist_layer.color = MerlinVisual.CRT_PALETTE.mist


func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Master"
	add_child(audio_player)


func _setup_voicebox() -> void:
	var vb_path := "res://addons/acvoicebox/acvoicebox.tscn"
	if not ResourceLoader.exists(vb_path):
		return
	var vb_scene: PackedScene = load(vb_path)
	if vb_scene == null:
		return
	voicebox = vb_scene.instantiate()
	voicebox.set("pitch", 2.5)
	voicebox.set("pitch_variation", 0.12)
	voicebox.set("speed_scale", 0.65)
	add_child(voicebox)
	voice_ready = true


func _sync_from_state() -> void:
	if store == null:
		return
	if not store.state.has("flags"):
		store.state["flags"] = {}
	store.state["flags"]["hub_visited"] = true


func _apply_aspect_aura() -> void:
	if _bestiole == null or store == null:
		return
	var aspects: Dictionary = store.state.get("aspects", {})
	var corps: int = aspects.get("Corps", 50)
	var ame: int = aspects.get("Ame", 50)
	var monde: int = aspects.get("Monde", 50)

	var dominant: String = "Corps"
	var max_val: int = corps
	if ame > max_val:
		dominant = "Ame"
		max_val = ame
	if monde > max_val:
		dominant = "Monde"

	var tint: Color = MerlinVisual.ASPECT_COLORS[dominant]
	tint = tint.lightened(0.6)
	tint.a = 1.0
	_bestiole.call("set_aura_tint", tint)


# =============================================================================
# CREATE COMPONENTS
# =============================================================================

func _create_bestiole() -> void:
	var BestioleClass = load("res://scripts/ui/bestiole_creature.gd")
	if BestioleClass == null:
		return
	_bestiole = Control.new()
	_bestiole.set_script(BestioleClass)
	_bestiole.call("setup", 200.0)
	add_child(_bestiole)
	move_child(_bestiole, mist_layer.get_index() + 1)
	_bestiole.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bestiole.call_deferred("assemble")


func _create_hotspots() -> void:
	var vp := get_viewport_rect().size
	for def in HOTSPOT_DEFS:
		var hs := HubHotspot.new()
		var icon_type: int = def["icon"]
		hs.setup(icon_type, def["name"], def["label"], MerlinVisual.CRT_PALETTE[def["palette_key"]])
		hs.tooltip_text = def["label"]
		hs.position = vp * Vector2(def["ratio"])
		add_child(hs)
		hs.hotspot_hovered.connect(_on_hotspot_hovered)
		hs.hotspot_pressed.connect(_on_hotspot_pressed)
		_hotspots.append(hs)


func _create_partir_button() -> void:
	_partir_btn = Button.new()
	_partir_btn.text = "PARTIR"
	_partir_btn.custom_minimum_size = Vector2(180, 52)

	var font: Font = MerlinVisual.get_font("title")
	if font:
		_partir_btn.add_theme_font_override("font", font)
	_partir_btn.add_theme_font_size_override("font_size", MerlinVisual.BUTTON_SIZE)
	_style_partir_button()

	add_child(_partir_btn)
	_partir_btn.pressed.connect(_on_partir_pressed)
	_partir_btn.mouse_entered.connect(func():
		SFXManager.play("hover")
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_partir_btn, "scale", Vector2(1.08, 1.08), 0.12)
	)
	_partir_btn.mouse_exited.connect(func():
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_partir_btn, "scale", Vector2(1.0, 1.0), 0.12)
	)

	_layout_partir()


func _style_partir_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = MerlinVisual.CRT_PALETTE["amber"]
	style.border_color = MerlinVisual.CRT_PALETTE["amber_bright"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = MerlinVisual.CRT_PALETTE["shadow"]
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	_partir_btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = MerlinVisual.CRT_PALETTE["amber_dim"]
	hover.shadow_size = 14
	_partir_btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate()
	pressed.bg_color = MerlinVisual.CRT_PALETTE["amber_bright"]
	pressed.shadow_size = 4
	_partir_btn.add_theme_stylebox_override("pressed", pressed)

	_partir_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["bg_panel"])
	_partir_btn.add_theme_color_override("font_hover_color", MerlinVisual.CRT_PALETTE["bg_panel"])
	_partir_btn.add_theme_color_override("font_pressed_color", MerlinVisual.CRT_PALETTE["phosphor"])

	_partir_btn.pivot_offset = Vector2(90, 26)


func _create_bubble() -> void:
	_bubble = MerlinBubble.new()
	add_child(_bubble)


func _create_radial() -> void:
	_radial = BiomeRadial.new()
	add_child(_radial)
	_radial.biome_selected.connect(_on_radial_biome_selected)
	_radial.radial_dismissed.connect(_on_radial_dismissed)


# =============================================================================
# LAYOUT
# =============================================================================

func _layout_all() -> void:
	var vp := get_viewport_rect().size
	for i in _hotspots.size():
		var def: Dictionary = HOTSPOT_DEFS[i]
		_hotspots[i].position = vp * Vector2(def["ratio"])
	_layout_partir()


func _layout_partir() -> void:
	if _partir_btn == null:
		return
	var vp := get_viewport_rect().size
	_partir_btn.position = Vector2(
		(vp.x - _partir_btn.custom_minimum_size.x) * 0.5,
		vp.y - 110
	)


# =============================================================================
# INTERACTIONS
# =============================================================================

func _on_hotspot_hovered(hotspot_name: String) -> void:
	SFXManager.play("hover")
	if _bestiole == null:
		return
	for hs in _hotspots:
		if hs.hotspot_name == hotspot_name:
			var target: Vector2 = hs.position + Vector2(32, 32)
			_bestiole.call("look_at_position", target)
			break


func _on_hotspot_pressed(hotspot_name: String) -> void:
	SFXManager.play("click")
	_store_return_scene()
	match hotspot_name:
		"calendar":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_CALENDAR)
		"options":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_OPTIONS)
		"arbre":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_ARBRE)
		"collection":
			SFXManager.play("whoosh")
			PixelTransition.transition_to(SCENE_COLLECTION)
		"souffle":
			SFXManager.play("whoosh")
			_show_perk_overlay()


func _on_partir_pressed() -> void:
	SFXManager.play("click")
	if _radial.is_open():
		return
	var center := _partir_btn.position + Vector2(_partir_btn.custom_minimum_size.x * 0.5, 0)
	_radial.open(center)


func _on_radial_biome_selected(biome_key: String) -> void:
	SFXManager.play("choice_select")
	var wms: Node = get_node_or_null("/root/WorldMapSystem")
	if wms and wms.has_method("is_biome_accessible"):
		if not wms.is_biome_accessible(biome_key):
			SFXManager.play("hover")
			return

	selected_biome = biome_key
	_generate_mission()

	var biome_name: String = BIOME_DATA.get(biome_key, {}).get("name", biome_key)
	_request_merlin_passive_comment("destination: %s" % biome_name)

	_launch_adventure()


func _on_radial_dismissed() -> void:
	pass


func _generate_mission() -> void:
	var missions: Array = BIOME_MISSIONS.get(selected_biome, [])
	if missions.size() > 0:
		_current_mission = missions[randi() % missions.size()].duplicate()
		_current_mission["progress"] = 0
	else:
		_current_mission = {"type": "exploration", "target": "Explorer ce sanctuaire", "total": 8, "progress": 0}


func _launch_adventure() -> void:
	SFXManager.play("whoosh")

	var wms: Node = get_node_or_null("/root/WorldMapSystem")
	if wms and wms.has_method("select_biome"):
		wms.select_biome(selected_biome)

	var gm := get_node_or_null("/root/GameManager")
	if gm:
		var biome_data: Dictionary = BIOME_DATA.get(selected_biome, {})
		var run_data = gm.get("run")
		if not run_data is Dictionary:
			run_data = {}
		run_data["biome"] = {
			"id": selected_biome,
			"name": biome_data.get("name", "Inconnu"),
			"color": biome_data.get("color", Color.WHITE),
			"ogham_dominant": biome_data.get("ogham", ""),
			"gardien": biome_data.get("guardian", ""),
			"season_forte": biome_data.get("season", ""),
		}
		run_data["current_biome"] = selected_biome
		if not _current_mission.is_empty():
			run_data["mission_template"] = _current_mission.duplicate()
		gm.set("run", run_data)

	if store:
		var run: Dictionary = store.state.get("run", {})
		var mission: Dictionary = run.get("mission", {})
		if not _current_mission.is_empty():
			mission["type"] = _current_mission.get("type", "")
			mission["target"] = _current_mission.get("target", "")
			mission["total"] = _current_mission.get("total", 8)
			mission["progress"] = 0
			mission["revealed"] = true
		run["mission"] = mission
		store.state["run"] = run

	_quick_save()
	PixelTransition.transition_to(SCENE_TRANSITION)


func _store_return_scene() -> void:
	var se := get_node_or_null("/root/ScreenEffects")
	if se:
		se.return_scene = get_tree().current_scene.scene_file_path


# =============================================================================
# MERLIN DIALOGUE
# =============================================================================

func _show_greeting() -> void:
	if _bubble == null:
		return
	var text := _get_greeting_text()
	_bubble.show_message(text, 5.0)


func _get_greeting_text() -> String:
	var pool: Array
	var total_runs: int = 0
	var last_ending: String = ""

	if store:
		var meta: Dictionary = store.state.get("meta", {})
		total_runs = meta.get("total_runs", 0)
		var endings: Array = meta.get("endings_seen", [])
		if endings.size() > 0:
			last_ending = str(endings[-1])

	if _is_first_hub:
		pool = MERLIN_GREETINGS.get("first_hub", ["Bienvenue, %s."])
	elif total_runs > 5:
		pool = MERLIN_GREETINGS.get("veteran", ["Te revoila, %s."])
	elif last_ending != "":
		pool = MERLIN_GREETINGS.get("after_fall", ["La boucle tourne, %s."])
	else:
		pool = MERLIN_GREETINGS.get("return", ["Te revoila, %s."])

	return pool[randi() % pool.size()] % chronicle_name


func _request_merlin_passive_comment(context: String) -> void:
	var merlin_node := get_node_or_null("/root/MerlinAI")
	if merlin_node == null or not merlin_node.get("is_ready"):
		return
	if _passive_llm_pending:
		return
	if not merlin_node.has_method("generate_voice"):
		return

	_passive_llm_pending = true
	var system := "Tu es Merlin le druide. Commente le choix du joueur en 1 phrase courte (10 mots max). Ton bienveillant ou espiegle. Francais."
	var user_input := "Le joueur prepare: %s" % context

	var result: Dictionary = await merlin_node.generate_voice(system, user_input, {"max_tokens": 30, "temperature": 0.8})
	_passive_llm_pending = false

	if result.has("error") or not is_inside_tree():
		return
	var text: String = str(result.get("text", "")).strip_edges()
	if text.length() < 5 or text.length() > 80:
		return

	if _bubble and is_instance_valid(_bubble):
		_bubble.show_message(text, 4.0)


# =============================================================================
# SAVE
# =============================================================================

func _quick_save() -> void:
	if store == null:
		return
	var save_data := store.state.duplicate(true)
	save_data["timestamp"] = int(Time.get_unix_time_from_system())
	save_data["phase"] = "hub"
	save_data["selected_biome"] = selected_biome
	store.save_system.save_slot(1, save_data)


# =============================================================================
# ANIMATIONS
# =============================================================================

func _start_mist_animation() -> void:
	if mist_layer == null or not is_instance_valid(mist_layer):
		return
	if _mist_tween:
		_mist_tween.kill()
	_mist_tween = create_tween().set_loops()
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.25, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mist_tween.tween_property(mist_layer, "modulate:a", 0.05, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_entry_animation() -> void:
	SFXManager.play("scene_transition")

	# Start everything invisible
	for hs in _hotspots:
		hs.modulate.a = 0.0
	if _partir_btn:
		_partir_btn.modulate.a = 0.0
		_partir_btn.scale = Vector2(0.5, 0.5)

	await get_tree().process_frame

	var pca: Node = get_node_or_null("/root/PixelContentAnimator")

	# Stagger hotspots reveal
	for i in _hotspots.size():
		var hs: Control = _hotspots[i]
		await get_tree().create_timer(0.12).timeout
		if pca:
			pca.reveal(hs, {"duration": 0.35, "block_size": 6})
		else:
			var tw := create_tween()
			tw.tween_property(hs, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# PARTIR button entrance
	await get_tree().create_timer(0.2).timeout
	if _partir_btn:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_partir_btn, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_partir_btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =============================================================================
# B.1 — SOUFFLE PERK OVERLAY
# =============================================================================

func _show_perk_overlay() -> void:
	## Show Souffle Perk selection overlay (modal, 4 perk cards).
	if _perk_overlay != null and is_instance_valid(_perk_overlay):
		_perk_overlay.visible = true
		return

	var current_perk: String = ""
	if store:
		current_perk = str(store.state.get("run", {}).get("perks", {}).get("selected_perk", ""))

	# Backdrop
	_perk_overlay = Control.new()
	_perk_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	_perk_overlay.add_child(bg)

	# Panel
	var vp: Vector2 = get_viewport_rect().size
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 380)
	panel.position = (vp - Vector2(540, 380)) * 0.5
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MerlinVisual.CRT_PALETTE.bg_panel
	panel_style.border_color = MerlinVisual.CRT_PALETTE.amber
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	_perk_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Choisir ton Souffle d'Ogham"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright)
	var title_font: Font = MerlinVisual.get_font("title")
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	# 4 perk cards in 2×2 grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	var perk_keys: Array = MerlinConstants.SOUFFLE_PERK_TYPES.keys()
	var _selected_in_overlay: String = current_perk
	var perk_buttons: Array = []

	for pk in perk_keys:
		var pdata: Dictionary = MerlinConstants.SOUFFLE_PERK_TYPES.get(pk, {})
		var card_btn := Button.new()
		card_btn.custom_minimum_size = Vector2(230, 90)
		card_btn.text = "[%s]\n%s" % [str(pdata.get("name", pk)), str(pdata.get("description", ""))]
		card_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var is_selected: bool = pk == current_perk

		var style_normal := StyleBoxFlat.new()
		style_normal.set_corner_radius_all(6)
		style_normal.set_border_width_all(2 if is_selected else 1)
		style_normal.bg_color = MerlinVisual.CRT_PALETTE.bg_panel if not is_selected else MerlinVisual.CRT_PALETTE.bg_dark
		style_normal.border_color = MerlinVisual.CRT_PALETTE.amber if is_selected else MerlinVisual.CRT_PALETTE.phosphor_dim
		card_btn.add_theme_stylebox_override("normal", style_normal)
		card_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor if not is_selected else MerlinVisual.CRT_PALETTE.amber_bright)
		card_btn.add_theme_font_size_override("font_size", 11)

		# Capture pk for the lambda
		var captured_pk: String = pk
		card_btn.pressed.connect(func(): _on_perk_card_selected(captured_pk))
		card_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
		grid.add_child(card_btn)
		perk_buttons.append({"key": pk, "btn": card_btn})

	# Confirm + Cancel row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirmer"
	confirm_btn.custom_minimum_size = Vector2(140, 44)
	var cs := StyleBoxFlat.new()
	cs.bg_color = MerlinVisual.CRT_PALETTE.amber
	cs.set_border_width_all(2)
	cs.border_color = MerlinVisual.CRT_PALETTE.amber_bright
	cs.set_corner_radius_all(6)
	confirm_btn.add_theme_stylebox_override("normal", cs)
	confirm_btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.bg_panel)
	confirm_btn.pressed.connect(_on_perk_confirmed)
	confirm_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.custom_minimum_size = Vector2(110, 44)
	cancel_btn.pressed.connect(_on_perk_cancelled)
	cancel_btn.mouse_entered.connect(func(): SFXManager.play("hover"))
	btn_row.add_child(cancel_btn)

	add_child(_perk_overlay)
	SFXManager.play("card_draw")


func _on_perk_card_selected(perk_id: String) -> void:
	## Called when a perk card button is pressed — store tentative selection.
	SFXManager.play("click")
	if _perk_overlay == null or not is_instance_valid(_perk_overlay):
		return
	# Find the panel → vbox → grid and update button styles
	var panel: Node = _perk_overlay.get_child(1)  # index 1 = PanelContainer
	if panel == null:
		return
	var vbox: Node = panel.get_child(0) if panel.get_child_count() > 0 else null
	if vbox == null:
		return
	var grid: Node = vbox.get_child(1) if vbox.get_child_count() > 1 else null
	if grid == null:
		return
	var perk_keys: Array = MerlinConstants.SOUFFLE_PERK_TYPES.keys()
	for i in perk_keys.size():
		if i >= grid.get_child_count():
			break
		var btn: Button = grid.get_child(i) as Button
		if btn == null:
			continue
		var is_sel: bool = perk_keys[i] == perk_id
		var style_upd := StyleBoxFlat.new()
		style_upd.set_corner_radius_all(6)
		style_upd.set_border_width_all(2 if is_sel else 1)
		style_upd.bg_color = MerlinVisual.CRT_PALETTE.bg_dark if is_sel else MerlinVisual.CRT_PALETTE.bg_panel
		style_upd.border_color = MerlinVisual.CRT_PALETTE.amber if is_sel else MerlinVisual.CRT_PALETTE.phosphor_dim
		btn.add_theme_stylebox_override("normal", style_upd)
		btn.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber_bright if is_sel else MerlinVisual.CRT_PALETTE.phosphor)
	# Store tentative selection on the overlay node as metadata
	_perk_overlay.set_meta("pending_perk", perk_id)


func _on_perk_confirmed() -> void:
	## Dispatch SELECT_PERK with the pending selection and close overlay.
	SFXManager.play("click")
	if _perk_overlay == null or not is_instance_valid(_perk_overlay):
		return
	var perk_id: String = str(_perk_overlay.get_meta("pending_perk", ""))
	if store and not perk_id.is_empty():
		store.dispatch({"type": "SELECT_PERK", "perk_id": perk_id})
		print("[HubAntre] Souffle Perk selected: %s" % perk_id)
	_perk_overlay.visible = false


func _on_perk_cancelled() -> void:
	## Close overlay without saving.
	SFXManager.play("click")
	if _perk_overlay and is_instance_valid(_perk_overlay):
		_perk_overlay.visible = false
