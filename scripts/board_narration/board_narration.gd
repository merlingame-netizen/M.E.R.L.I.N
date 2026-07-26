## ═══════════════════════════════════════════════════════════════════════════════
## BoardNarration — Post-run cinematic replay (REFONTE v2, 2026-05-13)
## ═══════════════════════════════════════════════════════════════════════════════
## User feedback on v1: "fond noir, rien de visible, cadre de tableau parasite,
## flou typo, déroulé plat". This rewrite fixes:
##   - Lights pumped (DirectionalLight strong + key Spotlight + fill rim)
##   - Brighter plateau wood material + proper exposure
##   - Tokens are now procedural FIGURINES (see sigle_token.gd v2)
##   - Biome BACKDROP procédural built behind plateau (see biome_backdrop.gd)
##   - Camera animated: wide intro → close-up per figurine → wide outro
##   - Auto-paced (no click-to-advance) — Inscryption-like theatrical 12s/item
##   - UI strip: zero theme/panel/border, large readable font (SystemFont)
##   - Skip button bottom-right only (text-only, transparent)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D
class_name BoardNarration

signal narration_done

const FIGURINE_LINE_X_HALF := 1.6     # row of figurines, x from -1.6 to +1.6
const FIGURINE_LINE_Z := -0.3
const FIGURINE_Y := 0.16              # sits on top of plateau
const TOKEN_STAGGER_DELAY := 0.4
const PER_TOKEN_DURATION := 11.0      # total seconds spent on each figurine
const INTRO_DURATION := 4.0
const OUTRO_DURATION := 4.0
const TYPEWRITER_CPS := 24.0
const LLM_PER_CALL_TIMEOUT := 12.0
const CAMERA_WIDE_POS := Vector3(0.0, 2.6, 4.6)
const CAMERA_WIDE_TARGET := Vector3(0.0, 0.4, 0.0)
const CAMERA_CLOSE_OFFSET := Vector3(0.0, 0.6, 1.4)   # offset from figurine
const CAMERA_DOLLY_TIME := 1.5

const FALLBACK_BY_CATEGORY := {
	"reveal":     "Le voile s'écarte. Tu vois ce qui se cachait.",
	"protection": "L'ombre passe sans t'effleurer. Tu tiens debout.",
	"boost":      "Une braise gonfle ton souffle. Tu repars plus fort.",
	"narrative":  "Le récit bifurque. Une autre voie s'ouvre.",
	"":           "Le moment a passé. Tu portes sa marque.",
}

const FALLBACK_NO_OGHAM := [
	"Tu as marché sans présage. La rune dormait.",
	"Pas de signe — juste ton pas, et ce qu'il dit de toi.",
	"Le silence des Oghams. Tu as choisi sans filet.",
]

## Fallback hand-written card pool when LLM is unavailable / times out.
## Loaded once on demand from data/ai/fastroute_cards.json (biome="foret_broceliande").
const FALLBACK_CARDS_PATH := "res://data/ai/fastroute_cards.json"
var _fallback_pool: Array = []
var _fallback_index: int = 0


# Animal totem cameo — map faction → GLB filename.
# When a token highlights, the matching totem appears briefly next to it.
const ANIMAL_CAMEO_BY_FACTION := {
	"druides":   "res://assets/blender/animal_deer.glb",
	"anciens":   "res://assets/blender/animal_raven.glb",
	"korrigans": "res://assets/blender/creature_korrigan.glb",
	"niamh":     "res://assets/blender/animal_salmon.glb",
	"ankou":     "res://assets/blender/animal_wolf.glb",
}
const CAMEO_OFFSET := Vector3(0.55, 0.0, 0.20)  # right and slightly forward
const CAMEO_FADE_TIME := 0.6

var _run_data: Dictionary = {}
var _biome_id: String = ""
var _outcome: String = ""
var _save_system: Object = null
var _merlin_ai: Node = null
var _flow_controller: Node = null
var _tokens: Array = []                     # Array of SigleToken
var _narrations: Array = []
var _current_index: int = -1
var _llm_unavailable: bool = false
var _narration_done_emitted: bool = false
var _skip_requested: bool = false

# Built nodes
var _camera: Camera3D = null
var _world_env: WorldEnvironment = null
var _key_light: DirectionalLight3D = null
var _fill_light: OmniLight3D = null
var _spot_light: SpotLight3D = null
var _plateau: MeshInstance3D = null
var _backdrop_root: Node3D = null
var _token_container: Node3D = null
var _ui_layer: CanvasLayer = null
var _biome_label: Label = null
var _narration_label: Label = null
var _skip_button: Button = null
var _current_cameo: Node3D = null      # totem animal next to highlighted figurine

# ─── Live-game mode (new in this session) ─────────────────────────────────
# When no replay story_log exists and MerlinStore is available, BoardNarration
# becomes the active card-play stage : we START_RUN, GET_CARD via LLM, show
# the card+3 options as overlay UI, and on click → RESOLVE_CHOICE + spawn a
# new SigleToken on the plateau.
var _live_card_mode: bool = false
var _live_run_active: bool = false
var _store: Node = null
var _card_overlay: Control = null
var _card_text_label: RichTextLabel = null
var _card_option_buttons: Array = []   # Array of Button
var _live_cards_played: int = 0
var _live_pending_choice: int = -1
var _live_current_card: Dictionary = {}

# Global overlay autoloads to hide during the cinematic (they belong to the
# main card-game 2D UI and draw on TOP of our 3D scene as fullscreen CanvasLayers).
# Restored on _finish().
#
# CRITICAL: In Godot, CanvasLayers render AFTER the 3D pass regardless of `layer`.
# A `CanvasLayer` autoload with a fullscreen `ColorRect` will completely occlude
# 3D rendering. MerlinBackdrop (layer -100) does exactly that with bg_deep.
const HIDDEN_OVERLAY_AUTOLOADS := [
	"MerlinBackdrop",   # CanvasLayer with fullscreen black ColorRect bg (must hide)
	"ScreenFrame",      # CanvasLayer with green Celtic border (must hide)
	"PixelTransition",  # Transition overlay (must hide)
	# NOTE: ScreenDither is intentionally NOT hidden — we re-configure it to PSX
	# mode for retro post-process. See _configure_psx_filter().
]
const SCREEN_DITHER_AUTOLOAD := "ScreenDither"
var _overlay_prev_visible: Dictionary = {}
var _screen_dither_prev: Dictionary = {}


func _ready() -> void:
	_disable_global_overlays()
	# v7.7.5a (item #10) — defensive: force-complete any pending PixelTransition so
	# we don't render under a black fade. Mirrors the menu_test.gd v7.7.2.2 pattern.
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt and pt.has_method("_force_complete"):
		pt._force_complete()
	# Le scenario scripte doit etre connu avant la construction de la scene :
	# c'est lui qui fixe la longueur du run, donc la hauteur du deck 3D.
	_load_scripted_scenario()
	_build_scene_tree()
	await _await_store_ready()
	_resolve_dependencies()
	_load_run_data()
	# Boot to NEUTRAL state. The biome theme (lighting, backdrop, figurines,
	# card mode) is only applied AFTER the user picks a biome via the selector.
	# Per design intent : "le plateau doit être neutre de base, on doit
	# sélectionner le biome" (2026-05-14).
	_apply_neutral_lighting()
	_configure_psx_filter()  # PSX active right from boot (filter-only, no CRT residuals)
	_build_biome_selector()


# ─── Neutral boot state ─────────────────────────────────────────────────────

## Apply a soft, biome-agnostic lighting setup : single warm overhead spot
## on the plateau, no biome tint. Used at boot before any biome is chosen.
func _apply_neutral_lighting() -> void:
	# v7.7.2 — dark room ambiance (per user directive 2026-05-15) :
	#   "boardnarration qui est vide, juste un plateau vide dans une piece
	#    éclairée et sombre (lampe vers le plateau et la bouche de merlin au fond)"
	# KeyLight stronger (acts as the lamp), ambient near-black, fog enabled to
	# render the light cone, Label3D silhouette in the back as Merlin's mouth.
	if _key_light:
		_key_light.light_color = Color(1.0, 0.86, 0.55)  # warm tungsten lamp
		_key_light.light_energy = 2.4
		_key_light.position = Vector3(0.5, 4.5, 1.5)
		_key_light.look_at_from_position(_key_light.position, Vector3.ZERO, Vector3.UP)
	if _fill_light:
		_fill_light.light_energy = 0.0  # turned off — only the lamp illuminates
	if _spot_light:
		_spot_light.light_energy = 0.0
	if _world_env and _world_env.environment:
		var env: Environment = _world_env.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.012, 0.012, 0.020)  # near-black
		env.ambient_light_color = Color(0.06, 0.05, 0.07)
		env.ambient_light_energy = 0.18  # very dark
		# Volumetric fog renders the lamp cone — key visual cue for "lampe vers plateau".
		env.fog_enabled = true
		env.fog_light_color = Color(0.20, 0.13, 0.06)
		env.fog_density = 0.035
		# v7.7.3a — density cut 0.02→0.008 (still visible lamp cone, ~60% cheaper).
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.008
		env.volumetric_fog_emission = Color(0.10, 0.07, 0.03)
	_build_merlin_sound_bar()


## v7.7.15 — Merlin is now a digital sound bar at the back of the plateau
## (user request : « merlin sous forme de barre de son digitale qui s'anima
## quand il parle »). Replaces the static MerlinMouthSilhouette Label3D.
## Typed as Node3D + preload to avoid class_name registry timing issues
## with first-pass headless smoke. The methods pulse/start/stop_speaking are
## called via has_method guards (defensive).
const MERLIN_SOUND_BAR_SCRIPT := preload("res://scripts/board_narration/merlin_sound_bar.gd")
var _merlin_sound_bar: Node3D = null

func _build_merlin_sound_bar() -> void:
	if _merlin_sound_bar != null and is_instance_valid(_merlin_sound_bar):
		return
	_merlin_sound_bar = Node3D.new()
	_merlin_sound_bar.set_script(MERLIN_SOUND_BAR_SCRIPT)
	_merlin_sound_bar.name = "MerlinSoundBar"
	_merlin_sound_bar.position = Vector3(0.0, 1.6, -3.4)
	_merlin_sound_bar.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
	add_child(_merlin_sound_bar)


# ─── Biome selector overlay ─────────────────────────────────────────────────
# 8 biome slots, only foret_broceliande unlocked. 2D Control overlay for now;
# Wave 1 architect spec calls for 3D stone disc halo around the plateau, but
# Blender assets for that are deferred to a follow-up session.

const BIOME_ORDER := [
	"foret_broceliande",
	"landes_bruyere",
	"cotes_sauvages",
	"villages_celtes",
	"cercles_pierres",
	"marais_korrigans",
	"collines_dolmens",
	"iles_mystiques",
]

const BIOME_TITLES := {
	"foret_broceliande": "Le Bois qui Murmure",
	"landes_bruyere":    "Les Landes Mauves",
	"cotes_sauvages":    "Le Rivage des Naufrages",
	"villages_celtes":   "Les Feux du Clan",
	"cercles_pierres":   "L'Assemblée Debout",
	"marais_korrigans":  "La Vase qui Rit",
	"collines_dolmens":  "Les Tables des Anciens",
	"iles_mystiques":    "L'Archipel des Voiles",
}

const BIOME_LOCK_MESSAGES := {
	"landes_bruyere":    "Apprends encore. La bruyère ne se montre qu'à ceux qui ont déjà su écouter Brocéliande.",
	"cotes_sauvages":    "Apprends encore. Le sel n'accepte que les langues qui ont goûté la sève.",
	"villages_celtes":   "Apprends encore. Les feux humains s'ouvrent à qui sait déjà ce qu'est un bois.",
	"cercles_pierres":   "Apprends encore. Les pierres ne tournent que pour qui les a longtemps frôlées.",
	"marais_korrigans":  "Apprends encore. Les korrigans ne rient qu'aux apprentis qu'ils reconnaissent.",
	"collines_dolmens":  "Apprends encore. Les Anciens ne lèvent pas leurs dalles pour un nom trop neuf.",
	"iles_mystiques":    "Apprends encore. L'Archipel se révèle au dernier pas, jamais au premier.",
}

# v7.7.21 — Poétique-mystique 2-line description per biome (user locked decision).
# Each entry evokes the biome's atmosphere without spoiling content. Druidic
# imagery : nature speaks, ancients watch, korrigans laugh. Used by the
# DigitalPickerCard body text in the biome picker grid.
const BIOME_DESCRIPTIONS := {
	"foret_broceliande": "Les arbres murmurent\nles secrets des druides.",
	"landes_bruyere":    "Brumes pourpres sur cairns.\nLe vent porte des noms.",
	"cotes_sauvages":    "Falaises noires battues\npar l'écume des korrigans.",
	"villages_celtes":   "Feux du clan dans la nuit.\nLes Anciens veillent.",
	"cercles_pierres":   "Mégalithes alignés.\nL'équinoxe approche.",
	"marais_korrigans":  "Vase qui rit, feux follets.\nLes rusés guettent.",
	"collines_dolmens":  "Tables des Anciens posées\nsur des collines vertes.",
	"iles_mystiques":    "Archipel des voiles azur.\nNiamh attend.",
}

# v7.7.21 — Unified DigitalPickerCard preload (same component as ScenarioLoading).
const DIGITAL_PICKER_CARD_SCRIPT := preload("res://scripts/ui/digital_picker_card.gd")

const BROCELIANDE_INCANTATION := "Tu poses le pied sur la mousse, et la mousse te reconnaît. Brocéliande n'est pas une forêt : c'est une bouche. Elle parle en chênes, en racines, en pluies fines. Écoute, jeune Merlin. Ce que tu prendras pour le vent sera la forêt qui te nomme."

var _biome_selector: Control = null


func _build_biome_selector() -> void:
	# Autoplay : env var MERLIN_AUTOPLAY=1 → skip selector, auto-pick a biome.
	# MERLIN_BIOME_OVERRIDE=<biome_id> (optional) picks any of the 8 biomes for
	# automated palette/capture tests. Default = foret_broceliande when AUTOPLAY=1.
	# Used by smoke tests + tools/capture_biomes_compare.py (v7.4).
	if OS.get_environment("MERLIN_AUTOPLAY") == "1":
		var override: String = OS.get_environment("MERLIN_BIOME_OVERRIDE")
		var pick: String = override if override != "" else "foret_broceliande"
		push_warning("[BoardNarration] AUTOPLAY ON — auto-picking %s" % pick)
		call_deferred("_on_biome_picked", pick)
		return

	_biome_selector = Control.new()
	_biome_selector.name = "BiomeSelector"
	_biome_selector.anchor_right = 1.0
	_biome_selector.anchor_bottom = 1.0
	_biome_selector.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.add_child(_biome_selector)

	# Dim backdrop (subtle, lets the plateau show through)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_biome_selector.add_child(dim)

	# Title : prompt the user
	var title := Label.new()
	title.name = "Title"
	title.text = "Choisis ton biome, druide…"
	title.position = Vector2(0, 60)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.96, 0.92, 0.74))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	_biome_selector.add_child(title)

	# v7.7.21 — Grid of 8 DigitalPickerCard (4×2). Each card is 320×400 ; with
	# 24px separation and 4 cols we need ~1352 wide. With 2 rows + 24px sep we
	# need ~824 tall. Anchored center so it scales with viewport up to 1920×1080.
	var grid := GridContainer.new()
	grid.name = "BiomeGrid"
	grid.columns = 4
	grid.anchor_left = 0.5
	grid.anchor_right = 0.5
	grid.anchor_top = 0.5
	grid.anchor_bottom = 0.5
	grid.offset_left = -676
	grid.offset_right = 676
	grid.offset_top = -412
	grid.offset_bottom = 412
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	_biome_selector.add_child(grid)

	# v7.7.15 — User decision : DISABLE force_only_broceliande for the rework.
	# All 8 biomes unlocked + each styled per its destination accent. Maturity
	# gate code preserved for future re-lock (set dev_unlock_all_biomes = false).
	var dev_unlock_all_biomes := true
	var player_maturity: int = 0
	if _store and _store.has_method("calculate_maturity_score"):
		player_maturity = int(_store.calculate_maturity_score())

	# v7.7.15 — Per-biome Ogham glyph (bible §3 Rune-Circuits mapping :
	# Beith / Luis / Fearn / Sail / Nion / Huath / Duir / Tinne).
	var biome_glyphs := {
		"foret_broceliande":  "ᚁ",
		"landes_bruyere":     "ᚂ",
		"cotes_sauvages":     "ᚃ",
		"villages_celtes":    "ᚄ",
		"cercles_pierres":    "ᚅ",
		"marais_korrigans":   "ᚆ",
		"collines_dolmens":   "ᚇ",
		"iles_mystiques":     "ᚈ",
	}

	# v7.7.21 — Build 8 DigitalPickerCard (replaces 8 Button widgets). Each card
	# self-handles hover/click/animations. Per-biome accent color comes from
	# BiomePalettes ; charter geometry (border 4→6, radius 0, bg dark) intraitable.
	var card_idx: int = 0
	for biome_id in BIOME_ORDER:
		var threshold: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS.get(biome_id, 999))
		var unlocked: bool = true if dev_unlock_all_biomes else (threshold <= player_maturity)
		var palette: Dictionary = BiomePalettes.get_palette(biome_id)
		var accent_color: Color = palette.get("accent", MerlinVisual.UI_GOLD)
		# Force alpha=1.0 so the border is fully opaque (palettes sometimes leak alpha).
		accent_color.a = 1.0
		var title_text: String = str(BIOME_TITLES.get(biome_id, biome_id))
		var body_text: String = str(BIOME_DESCRIPTIONS.get(biome_id, ""))
		var glyph_text: String = String(biome_glyphs.get(biome_id, "ᛚ"))
		var lock_msg: String = str(BIOME_LOCK_MESSAGES.get(biome_id, "Apprends encore."))

		# Instantiate via preload + set_script (avoids class_name first-pass race).
		var card := PanelContainer.new()
		card.set_script(DIGITAL_PICKER_CARD_SCRIPT)
		card.name = "BiomeCard_" + biome_id
		grid.add_child(card)
		if card.has_method("setup"):
			card.call("setup", biome_id, title_text, body_text, glyph_text, accent_color, not unlocked, lock_msg)
		# Connect selected → existing _on_biome_picked handler (preserves run flow).
		if card.has_signal("selected") and unlocked:
			card.connect("selected", _on_biome_picked)
		# Stagger reveal cascade : 80ms between cards (8 × 80ms = 640ms total intro).
		if card.has_method("animate_in"):
			card.call("animate_in", float(card_idx) * 0.08)
		card_idx += 1


func _on_biome_picked(biome_id: String) -> void:
	# Hide the selector. Apply biome theme. Run reveal animation. Open card mode.
	if _biome_selector:
		_biome_selector.queue_free()
		_biome_selector = null
	_biome_id = biome_id
	_run_data["current_biome"] = biome_id
	_run_data["biome"] = biome_id
	# v7.7 Phase 2.1.8 — route to ScenarioLoading FIRST (3 titles → skeleton → return).
	# Skip the loading screen when :
	#   (a) capture/smoke mode is active (MERLIN_CAPTURE_DIR set) — preserves the
	#       proven smoke-test path used through v7.5/v7.6/v7.7 validation
	#   (b) a scenario skeleton is already present in _run_data (we returned from
	#       ScenarioLoading and shouldn't re-enter it — would create a scene loop)
	var skeleton_loaded: bool = _run_data.has("scenario_skeleton")
	var capture_mode: bool = OS.get_environment("MERLIN_CAPTURE_DIR") != ""
	if not skeleton_loaded and not capture_mode:
		# v7.7 Phase 2.1.8 — proper dispatch (preserves Redux semantics + state_changed
		# signal + transition log). SET_BIOME is lightweight, distinct from START_RUN.
		if _store and _store.has_method("dispatch"):
			_store.dispatch({"type": "SET_BIOME", "biome": biome_id})
		# v7.7.2 — embed ScenarioLoading as a sub-scene (no change_scene_to_file).
		# The whole game session now stays in one BoardNarration instance per user
		# directive "tout dans la même scène". We listen for skeleton_dispatched
		# signal to know when to clean up the sub-scene and continue the run.
		var scenario_pack: PackedScene = load("res://scenes/ScenarioLoading.tscn")
		if scenario_pack == null:
			push_warning("[BoardNarration] ScenarioLoading.tscn missing — fallback to scene change")
			# v7.7.19 — Use PixelTransition for fade if available (user request « aucune transition »).
			var pt: Node = get_node_or_null("/root/PixelTransition")
			if pt != null and pt.has_method("transition_to"):
				pt.call("transition_to", "res://scenes/ScenarioLoading.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/ScenarioLoading.tscn")
			return
		var scenario_inst: Node = scenario_pack.instantiate()
		if scenario_inst.has_signal("skeleton_dispatched"):
			scenario_inst.skeleton_dispatched.connect(_on_scenario_done.bind(scenario_inst))
		add_child(scenario_inst)
		return
	_reveal_biome_sequence()


## v7.7.2 — Called when the embedded ScenarioLoading sub-scene completes (skeleton
## dispatched to Store). Cleanup + re-hydrate + resume the run flow.
func _on_scenario_done(scenario_inst: Node) -> void:
	if is_instance_valid(scenario_inst):
		scenario_inst.queue_free()
	# Re-read Store state so _run_data picks up the freshly dispatched skeleton.
	_load_run_data()
	# Continue the run flow now that the skeleton is loaded.
	_reveal_biome_sequence()


func _reveal_biome_sequence() -> void:
	# v5 (2026-05-14) : the biome reveal is now a PLATEAU-ALIVE CHOREOGRAPHY
	# — plateau wakes (scale pulse), spotlight ramps, volumetric fog drifts in,
	# camera dollies forward, assets DROP from sky with bounce-settle.
	# Per docs/BOARD_NARRATION_PLATEAU_ALIVE.md §1.
	_apply_biome_lighting()
	_build_biome_backdrop()
	# Reconfigure PSX with biome tint now that _biome_id is set.
	_configure_psx_filter()
	# Enable plateau-alive systems : breathing lights + volumetric fog + ambient motion.
	_enable_volumetric_fog()
	_build_plateau_breathing_lights()
	_animate_plateau_breath()
	# Run the drop choreography (5.5s skippable sequence).
	await _run_biome_drop_choreography(_biome_id)
	# Populate UI header with biome name.
	_populate_ui_header()
	# v6.4 — Legacy live-mode opening block REMOVED. The drop choreography
	# now calls _open_live_card_mode() internally at the end (line ~548),
	# which builds the overlay, runs the incantation, queue-frees it, and
	# starts the live loop. The old block here caused DOUBLE execution
	# (parchemin built TWICE, overlay never disappeared).
	# Cinematic fallback path stays unchanged but is now handled inside
	# _open_live_card_mode's else branch.


func biome_id_eq_broceliande() -> bool:
	return _biome_id == "foret_broceliande"


# ════════════════════════════════════════════════════════════════════════
# PLATEAU ALIVE (v5) — breathing lights + volumetric fog + drop choreography
# ════════════════════════════════════════════════════════════════════════
# Per docs/BOARD_NARRATION_PLATEAU_ALIVE.md.

const PLATEAU_BREATH_LIGHTS := [
	{"pos": Vector3(-1.2, 0.55, -0.5), "color": Color(1.00, 0.78, 0.45), "period": 1.6, "min_e": 0.6, "max_e": 1.3},
	{"pos": Vector3( 1.1, 0.50,  0.4), "color": Color(0.95, 0.72, 0.50), "period": 2.0, "min_e": 0.5, "max_e": 1.1},
	{"pos": Vector3( 0.0, 0.40,  1.0), "color": Color(0.98, 0.86, 0.62), "period": 2.4, "min_e": 0.4, "max_e": 1.0},
]
var _breath_lights: Array = []  # Array of OmniLight3D
var _dice_node: DicePhysics3D = null  # Physical dice tray next to plateau
var _card_deck: CardDeck3D = null  # v5.2 : visible 3D card stack on plateau
var _discard_pile: CardDeck3D = null  # v7.0 : pile de défausse (right-back), grows per RESOLVE_CHOICE
var _live_card_3d: LiveCard3D = null  # v6 : Hand of Fate-style 3D card (replaces parchemin overlay)
var _floating_option_buttons: Array = []  # v6 : 3 Button2D anchored to 3D card options

const DROP_TOTAL_DURATION := 5.5


## Enable volumetric fog on the WorldEnvironment with druidic forest tone.
## Density tweens from 0 to target over the drop choreography for a "summon" feel.
func _enable_volumetric_fog() -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var env: Environment = _world_env.environment
	# v7.5 — Volumetric fog boosted per user feedback 2026-05-15 part 19 :
	# "prends des effets volumétriques importants". Density × 2, emission × 2,
	# length extended for deeper atmospheric depth.
	env.fog_enabled = true
	env.fog_density = 0.014  # was 0.008
	env.fog_light_color = Color(0.55, 0.72, 0.55)
	env.fog_light_energy = 1.4  # was 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0  # ramped by choreography to 0.045 below (was 0.022)
	env.volumetric_fog_albedo = Color(0.78, 0.88, 0.80)
	env.volumetric_fog_emission = Color(0.40, 0.62, 0.42)
	env.volumetric_fog_emission_energy = 0.55  # was 0.25
	env.volumetric_fog_anisotropy = 0.5
	# v7.7.3a — length 36→18 cuts ray-march steps in half. Visual depth still OK.
	env.volumetric_fog_length = 18.0  # was 36.0 (v7.5 over-extension)


## Build 3 breathing OmniLight3D point lights around the plateau, each with
## a looped scale+energy tween on a slightly different period — gives the
## plateau a "pulsing" alive feel.
func _build_plateau_breathing_lights() -> void:
	if not _breath_lights.is_empty():
		return  # already built
	for spec in PLATEAU_BREATH_LIGHTS:
		var light := OmniLight3D.new()
		light.name = "BreathLight_%d" % _breath_lights.size()
		light.light_color = spec["color"]
		light.light_energy = float(spec["min_e"])
		light.omni_range = 4.5
		light.omni_attenuation = 1.5
		light.position = spec["pos"]
		add_child(light)
		_breath_lights.append(light)
		# Loop the energy tween (modulate.a wouldn't work on Light3D).
		var period: float = float(spec["period"])
		var min_e: float = float(spec["min_e"])
		var max_e: float = float(spec["max_e"])
		var tw := create_tween().set_loops()
		tw.tween_property(light, "light_energy", max_e, period * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(light, "light_energy", min_e, period * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## v7.7.7 — Enrich the plateau with 4 procedural layers per design intent
## "plateau de base plus travaillé". All layers child of _plateau so they
## inherit position/transform. All apply CelShadingManager outline noir per
## bible §20.1 mandatory rule.
##
## Layers spawned :
##   L2 — Bronze raised border ring (TorusMesh, outer rim, accent gold)
##   L3 — Carved rune circle (5 inverted segment markers around inner ring,
##         one per faction : Druides/Anciens/Korrigans/Niamh/Ankou)
##   L4 — 4 cardinal stat markers (Logic N, Empathie E, Volonté S, Instinct W)
##   L5 — Center pedestal (small cylinder, LiveCard3D fly-to target marker)
func _build_plateau_enrichment() -> void:
	if _plateau == null:
		return
	# Read biome palette + accent gold (bible §22).
	var palette: Dictionary = BiomePalettes.get_palette(_biome_id)
	var accent_gold: Color = palette.get("accent", Color("#d4a868"))
	var outline_black: Color = palette.get("outline", Color("#0a0500"))

	# L2 — Bronze raised border ring (TorusMesh on plateau rim, slight raise)
	var border := MeshInstance3D.new()
	border.name = "PlateauBorder"
	var border_mesh := TorusMesh.new()
	border_mesh.inner_radius = 2.42
	border_mesh.outer_radius = 2.62
	border_mesh.rings = 36
	border_mesh.ring_segments = 6
	border.mesh = border_mesh
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = accent_gold * 0.85
	border_mat.metallic = 0.65
	border_mat.roughness = 0.42
	border_mat.emission_enabled = true
	border_mat.emission = accent_gold * 0.45
	border_mat.emission_energy_multiplier = 0.35
	border.material_override = border_mat
	border.position = Vector3(0.0, 0.10, 0.0)
	_plateau.add_child(border)
	CelShadingManager.apply(border, {"outline_thickness": 0.010, "outline_color": outline_black})

	# L3 — Carved rune circle : 5 small inverted segment markers (one per faction)
	# Positioned at 72° intervals around inner ring (radius 1.4)
	const FACTION_STAT_COLORS := [
		Color("#7c9e6e"),  # Druides (vert sage)
		Color("#9c8a6e"),  # Anciens (ocre)
		Color("#8e7ca0"),  # Korrigans (violet)
		Color("#c0a878"),  # Niamh (gold pale)
		Color("#5a4e64"),  # Ankou (gris-pourpre)
	]
	for i in range(5):
		var angle: float = float(i) * (TAU / 5.0)
		var segment := MeshInstance3D.new()
		segment.name = "RuneSegment_%d" % i
		var seg_mesh := BoxMesh.new()
		seg_mesh.size = Vector3(0.18, 0.02, 0.10)
		segment.mesh = seg_mesh
		var seg_mat := StandardMaterial3D.new()
		seg_mat.albedo_color = FACTION_STAT_COLORS[i]
		seg_mat.roughness = 0.78
		seg_mat.emission_enabled = true
		seg_mat.emission = FACTION_STAT_COLORS[i] * 0.65
		seg_mat.emission_energy_multiplier = 0.32
		segment.material_override = seg_mat
		segment.position = Vector3(cos(angle) * 1.35, 0.095, sin(angle) * 1.35)
		segment.rotation.y = -angle  # face center
		_plateau.add_child(segment)
		CelShadingManager.apply(segment, {"outline_thickness": 0.008, "outline_color": outline_black})

	# L4 — 4 cardinal stat markers at N/E/S/W (raised small stones)
	# Maps to bible §25.1 : Logic N (druides) / Empathie E (niamh) / Volonté S (anciens) / Instinct W (korrigans)
	const CARDINAL_STAT_COLORS := [
		Color("#7c9e6e"),  # N = Logic (druides)
		Color("#c0a878"),  # E = Empathie (niamh)
		Color("#9c8a6e"),  # S = Volonté (anciens)
		Color("#8e7ca0"),  # W = Instinct (korrigans)
	]
	const CARDINAL_DIRECTIONS := [
		Vector3( 0.0, 0.0,  2.05),  # N — Logic
		Vector3( 2.05, 0.0, 0.0),   # E — Empathie
		Vector3( 0.0, 0.0, -2.05),  # S — Volonté
		Vector3(-2.05, 0.0, 0.0),   # W — Instinct
	]
	for i in range(4):
		var marker := MeshInstance3D.new()
		marker.name = "CardinalMarker_%d" % i
		var marker_mesh := BoxMesh.new()
		marker_mesh.size = Vector3(0.16, 0.18, 0.16)
		marker.mesh = marker_mesh
		var marker_mat := StandardMaterial3D.new()
		marker_mat.albedo_color = CARDINAL_STAT_COLORS[i]
		marker_mat.roughness = 0.85
		marker_mat.metallic = 0.05
		marker_mat.emission_enabled = true
		marker_mat.emission = CARDINAL_STAT_COLORS[i] * 0.45
		marker_mat.emission_energy_multiplier = 0.28
		marker.material_override = marker_mat
		marker.position = CARDINAL_DIRECTIONS[i] + Vector3(0.0, 0.18, 0.0)
		_plateau.add_child(marker)
		CelShadingManager.apply(marker, {"outline_thickness": 0.012, "outline_color": outline_black})

	# L5 — Center pedestal (LiveCard3D fly-to-marker target)
	var pedestal := MeshInstance3D.new()
	pedestal.name = "CenterPedestal"
	var ped_mesh := CylinderMesh.new()
	ped_mesh.top_radius = 0.42
	ped_mesh.bottom_radius = 0.48
	ped_mesh.height = 0.06
	ped_mesh.radial_segments = 24
	pedestal.mesh = ped_mesh
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = accent_gold * 0.70
	ped_mat.metallic = 0.40
	ped_mat.roughness = 0.55
	ped_mat.emission_enabled = true
	ped_mat.emission = accent_gold * 0.50
	ped_mat.emission_energy_multiplier = 0.40
	pedestal.material_override = ped_mat
	pedestal.position = Vector3(0.0, 0.12, 0.0)
	_plateau.add_child(pedestal)
	CelShadingManager.apply(pedestal, {"outline_thickness": 0.010, "outline_color": outline_black})


## v7.7.8 — KayKit canonical asset pipeline (bible §20.6)
## Reusable GLB guardian spawner. Parameterised per code-review MEDIUM-2 so
## adding biome-specific guardians becomes a one-liner.
##
## Default = KayKit Adventurers Mage (druide-aligned).
const KAYKIT_GUARDIAN_PATH := "res://Assets/blender/kaykit_mage.glb"
const KAYKIT_GUARDIAN_POSITION := Vector3(3.4, 0.0, 0.6)
const KAYKIT_GUARDIAN_SCALE := 0.55
const KAYKIT_GUARDIAN_ROTATION_Y := -0.95   # face plateau center

var _kaykit_spawned: bool = false

## Spawns the default Mage druide guardian. One-shot via _kaykit_spawned flag.
func _spawn_kaykit_guardian() -> void:
	if _kaykit_spawned:
		return
	if _spawn_glb_guardian(
		KAYKIT_GUARDIAN_PATH,
		KAYKIT_GUARDIAN_POSITION,
		KAYKIT_GUARDIAN_SCALE,
		KAYKIT_GUARDIAN_ROTATION_Y,
		"KayKitGuardian"
	) != null:
		_kaykit_spawned = true


## Generic helper : load a `.glb` PackedScene, wrap in a Node3D, position/scale/rotate,
## apply outline noir per bible §20.6. Returns the wrapper Node3D or null on failure.
## Wrapper is added as child of `self` ; caller can keep the reference for later tweens.
func _spawn_glb_guardian(path: String, pos: Vector3, scale_f: float, rot_y: float, node_name: String = "GLBGuardian") -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("[BoardNarration] GLB guardian not found at %s — skipping" % path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("[BoardNarration] GLB guardian failed to load as PackedScene: %s" % path)
		return null
	var inst: Node = packed.instantiate()
	if inst == null:
		push_warning("[BoardNarration] GLB guardian instantiate() returned null: %s" % path)
		return null
	var wrapper := Node3D.new()
	wrapper.name = node_name
	wrapper.position = pos
	wrapper.scale = Vector3.ONE * scale_f
	wrapper.rotation.y = rot_y
	add_child(wrapper)
	wrapper.add_child(inst)
	# Outline noir signature mandatory per bible §20.6
	CelShadingManager.apply_recursive(wrapper, {"outline_thickness": 0.008})
	return wrapper


## Looped subtle scale-breath on the plateau mesh — barely perceptible (1.0 → 1.002).
## Pumps up the "alive" feel without distorting the geometry.
func _animate_plateau_breath() -> void:
	if _plateau == null:
		return
	var tw := create_tween().set_loops()
	tw.tween_property(_plateau, "scale", Vector3.ONE * 1.002, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_plateau, "scale", Vector3.ONE, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Main drop choreography — 5.5s sequence.
## Phase 0  : plateau wake-pulse (0..0.4s) + LLM pre-warm fire-and-forget
## Phase 1  : spotlight ramp + fog density ramp + camera dolly (parallel)
## Phase 2  : figurines drop from Y=+10 with stagger 3..3.8s
## Phase 3  : open live card mode at the end
func _run_biome_drop_choreography(biome_id: String) -> void:
	# v5.7 — Refonte SÉQUENTIELLE : chaque élément apparaît un par un avec
	# effet "materialize_reveal" (flash blanc émissif + scale-in TRANS_BACK).
	# Per user feedback (2026-05-14 part 13) : "donne un délai d'apparition
	# des éléments, un par un, effet généré par ordinateur".
	# LLM pre-warm fire-and-forget at start.
	_prewarm_llm()
	# Step 1 (T=0.0..0.4s) : plateau wake-pulse — le plateau s'éveille en premier.
	if _plateau:
		var wake := create_tween()
		wake.tween_property(_plateau, "scale", Vector3.ONE * 1.04, 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		wake.tween_property(_plateau, "scale", Vector3.ONE, 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.5).timeout
	if _skip_requested:
		return
	# Step 2 (T=0.5..1.5s) : spotlight ramp solo (avant tout autre élément).
	if _spot_light:
		create_tween().tween_property(_spot_light, "light_energy", 1.5, 1.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.0).timeout
	if _skip_requested:
		return
	# Step 3 (T=1.5..3.0s) : fog volumétrique s'infiltre (lent, ambiance).
	if _world_env and _world_env.environment:
		var env: Environment = _world_env.environment
		# v7.7.3a — ramp target back to 0.022 (v7.5 pre-boost). 0.045 was 2× too
		# expensive — combined with the 36→18 length cut this section now costs
		# ~3-4ms/frame instead of 6-8ms. Atmospheric depth still reads.
		create_tween().tween_property(env, "volumetric_fog_density", 0.022, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.6).timeout
	if _skip_requested:
		return
	# Step 4 (T=2.1..3.0s) : dice tray apparaît avec materialize_reveal (flash blanc).
	if _dice_node == null:
		_dice_node = DicePhysics3D.new()
		_dice_node.name = "DiceTray"
		add_child(_dice_node)
		# v7.0 — Per GAME_DESIGN_BIBLE §19.1 : dés + ustensiles en HAUT/BACK du plateau
		# (Z négatif = derrière, loin de la caméra). Was (2.4, 0.5, 0.7) = à droite.
		# Aligned to bible canonical Z=-1.4 (was -1.8, code-review v7.0 HIGH finding).
		_dice_node.global_position = Vector3(0.0, 0.5, -1.4)
		_dice_node.setup(2)
		JuiceHelpers.materialize_reveal(self, _dice_node, 0.0)
	await get_tree().create_timer(0.8).timeout
	if _skip_requested:
		return
	# Step 5 (T=3.0..3.8s) : card deck apparaît avec materialize_reveal.
	if _card_deck == null:
		_card_deck = CardDeck3D.new()
		_card_deck.name = "CardDeck"
		add_child(_card_deck)
		# v7.0 — Per GAME_DESIGN_BIBLE §19.1 : deck pioche en LEFT-BACK du plateau.
		_card_deck.global_position = Vector3(-2.4, 0.5, -1.4)
		_card_deck.setup(_act_sequence().size())
		JuiceHelpers.materialize_reveal(self, _card_deck, 0.0)
	# v7.0 — NEW : Discard pile en RIGHT-BACK du plateau (mirroir pioche).
	# Hauteur du stack grandit à chaque RESOLVE_CHOICE (cartes jouées s'empilent).
	if _discard_pile == null:
		_discard_pile = CardDeck3D.new()
		_discard_pile.name = "DiscardPile"
		add_child(_discard_pile)
		_discard_pile.global_position = Vector3(2.4, 0.5, -1.4)
		_discard_pile.setup(0)  # vide au départ, grossit à chaque card joué
		JuiceHelpers.materialize_reveal(self, _discard_pile, 0.0)
	await get_tree().create_timer(0.8).timeout
	if _skip_requested:
		return
	# Step 6 (T=3.8..4.5s) : camera dolly forward pour montrer le plateau prêt.
	if _camera:
		var dolly_pos := CAMERA_WIDE_POS + Vector3(0.0, 0.0, -0.5)
		var t_cam := create_tween()
		t_cam.tween_property(_camera, "position", dolly_pos, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t_cam.tween_property(_camera, "position", CAMERA_WIDE_POS, 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.5).timeout
	if _skip_requested:
		return
	# Phase 2 : drop figurines (the 5 sigles) from Y=+10 with stagger.
	# Use existing _spawn_figurines but intercept the position-setting so
	# each token starts at its drop start position.
	if _store and _store.has_method("dispatch"):
		# Live mode : we don't pre-spawn figurines; they spawn after each card resolve.
		# Instead, in live mode the drop sequence shows only the plateau "wake" then
		# opens the card overlay. The figurines fall later via _spawn_live_token's
		# new drop animation (see _spawn_live_token below).
		pass
	else:
		_spawn_figurines()
		for i in range(_tokens.size()):
			var fig: Node3D = _tokens[i]
			var target := Vector3(_token_x_for_index(i, _tokens.size()), FIGURINE_Y, FIGURINE_LINE_Z)
			_drop_asset(fig, 10.0, target, 0.4 + i * 0.2, true)
		await get_tree().create_timer(1.8).timeout
		if _skip_requested:
			return
	# Wait for the rest of the choreography window.
	await get_tree().create_timer(2.0).timeout
	if _skip_requested:
		return
	# Phase 3 : open live card mode (was the tail of _reveal_biome_sequence).
	_open_live_card_mode()


## Drop a single Node3D from Y=start_y onto target_pos with overshoot + bounce-settle.
## `delay` : initial wait before the fall starts.
## `spin`  : if true, randomize starting y rotation and tween it to 0.
func _drop_asset(node: Node3D, start_y: float, target_pos: Vector3,
				 delay: float, spin: bool) -> void:
	if node == null:
		return
	node.position = Vector3(target_pos.x, start_y, target_pos.z)
	if spin:
		node.rotation_degrees = Vector3(0.0, randf_range(-180.0, 180.0), 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if _skip_requested:
		node.position = target_pos
		node.rotation = Vector3.ZERO
		return
	# Fall with overshoot (TRANS_BACK/EASE_IN → satisfying drop)
	var fall_time := 0.85
	var t := create_tween().set_parallel(true)
	t.tween_property(node, "position", target_pos, fall_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if spin:
		t.tween_property(node, "rotation:y", 0.0, fall_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished
	# Micro-bounce on landing.
	var b := create_tween()
	b.tween_property(node, "position:y", target_pos.y + 0.06, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.tween_property(node, "position:y", target_pos.y, 0.18) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## v5.1 — Mutate the card panel anchors + style based on act_type + faction.
## v5.4 — Now accepts the full card dict (instead of just act_type) so the
## border can also tint based on the card's dominant faction
## (per user : "cartes doivent avoir leur propre contour et particularités").
##
## Tint hierarchy : act_type provides BASE color, faction blends in at 40%
## if a clear dominant faction is detected. Result : a Brocéliande shop card
## with druid-heavy options shows korrigan-amber x druid-green hybrid border.
func _apply_act_styling(panel: Control, card: Dictionary) -> void:
	if panel == null:
		return
	var act_type: String = str(card.get("act_type", "standard"))
	var border_col := Color(0.30, 0.20, 0.12, 1.0)  # default bronze
	var dim_alpha := 0.18
	var anchor_top := 0.60
	match act_type:
		"shop":
			border_col = Color(0.90, 0.68, 0.30, 1.0)  # korrigan amber
			dim_alpha = 0.25
			anchor_top = 0.55
		"event":
			border_col = Color(0.45, 0.78, 0.95, 1.0)  # niamh cyan
			dim_alpha = 0.22
			anchor_top = 0.60
		"boss":
			border_col = Color(0.85, 0.30, 0.30, 1.0)  # ankou red
			dim_alpha = 0.55
			anchor_top = 0.30
		_:
			pass
	# v5.4 — blend in the dominant faction's color at 40% if found in card options.
	var dominant_faction: String = _compute_card_dominant_faction(card)
	if not dominant_faction.is_empty():
		var fac_col: Color = FACTION_HUD_COLORS.get(dominant_faction, Color.WHITE)
		border_col = border_col.lerp(fac_col, 0.40)
	# Mutate the panel's stylebox to apply new border color.
	var sb: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.border_color = border_col
	# Mutate the dim backdrop alpha.
	var dim_node := _card_overlay.get_node_or_null("DimBackdrop") as ColorRect
	if dim_node:
		var tw := create_tween()
		tw.tween_property(dim_node, "color:a", dim_alpha, 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# v5.3 — Boss visuals : HUD pulse rouge + camera dolly+tilt for drama.
	if act_type == "boss":
		_strengthen_boss_presence()
	panel.anchor_top = anchor_top


## v5.4 — Compute the dominant faction of a card from its options' ADD_REPUTATION
## effects. The faction with the highest summed positive amount wins. Empty string
## if no faction is affected positively. Used to tint card borders.
func _compute_card_dominant_faction(card: Dictionary) -> String:
	var sums := {"druides": 0, "anciens": 0, "korrigans": 0, "niamh": 0, "ankou": 0}
	for opt in card.get("options", []):
		if not (opt is Dictionary):
			continue
		for fx in opt.get("effects", []):
			if not (fx is Dictionary):
				continue
			if str(fx.get("type", "")) != "ADD_REPUTATION":
				continue
			var f: String = str(fx.get("faction", ""))
			var amt: int = int(fx.get("amount", 0))
			if amt > 0 and sums.has(f):
				sums[f] = int(sums[f]) + amt
	var best := ""
	var best_amt := 0
	for f in sums.keys():
		var v: int = int(sums[f])
		if v > best_amt:
			best_amt = v
			best = str(f)
	return best


## v5.3 — Boss presence enhancer. Started when boss act fires.
## - HUD life bar pulses rouge faible (modulate alpha 1.0↔0.85) period 1.6s loop
## - Camera dollies forward +0.4 on local-Z + tilt rotation +3° on X over 1.4s
## Per user feedback (2026-05-14 part 10) : "HUD pulse rouge 1.6s + camera dolly+tilt"
var _boss_pulse_tween: Tween = null

func _strengthen_boss_presence() -> void:
	# HUD pulse — looped breathing on the life bar (subtle red threat).
	if _hud_life_bar:
		if _boss_pulse_tween and is_instance_valid(_boss_pulse_tween):
			_boss_pulse_tween.kill()
		_boss_pulse_tween = create_tween().bind_node(_hud_life_bar).set_loops()
		_boss_pulse_tween.tween_property(_hud_life_bar, "modulate", Color(1.2, 0.7, 0.7, 1.0), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_boss_pulse_tween.tween_property(_hud_life_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Camera dolly + tilt for dramatic boss framing.
	if _camera:
		var origin: Vector3 = _camera.position
		var origin_rot: Vector3 = _camera.rotation
		var dolly_target := origin + Vector3(0.0, -0.15, -0.4)  # forward+slightly down
		var tilt_target := origin_rot + Vector3(deg_to_rad(3.0), 0.0, 0.0)
		var cam_tw := create_tween().bind_node(_camera).set_parallel(true)
		cam_tw.tween_property(_camera, "position", dolly_target, 1.4) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		cam_tw.tween_property(_camera, "rotation", tilt_target, 1.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# v7.7.10 — Boss sting : screen flash + camera punch + SFX.
	_play_boss_sting()


## v7.7.10 — Boss arrival sting. Quick red flash + camera punch + audio cue.
## Total budget : 0.4s. Fires once when boss card enters.
func _play_boss_sting() -> void:
	# Screen flash : full-bleed red ColorRect, fade-in 0.08s + fade-out 0.32s.
	if _ui_layer != null:
		var flash := ColorRect.new()
		flash.name = "BossStingFlash"
		flash.color = Color(0.85, 0.12, 0.10, 0.0)
		flash.anchor_left = 0.0
		flash.anchor_right = 1.0
		flash.anchor_top = 0.0
		flash.anchor_bottom = 1.0
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui_layer.add_child(flash)
		var flash_tw := create_tween().bind_node(flash)
		flash_tw.tween_property(flash, "color:a", 0.55, 0.08).set_trans(Tween.TRANS_SINE)
		flash_tw.tween_property(flash, "color:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
		flash_tw.tween_callback(func() -> void:
			if is_instance_valid(flash):
				flash.queue_free()
		)
	# Camera punch : rapid forward bump (8 cm) over 0.10s, recover over 0.30s.
	# v7.7.10 code-review fix: the boss dolly tween runs concurrently in
	# _strengthen_boss_presence(), so we cannot capture origin upfront and
	# recover to it (would undo dolly progress). Instead we apply the punch
	# delta async and have the recovery read the camera's then-current position
	# so the dolly's contribution is preserved. TRANS_QUAD on recovery avoids
	# the TRANS_BACK overshoot (would push camera behind dolly position).
	if _camera != null:
		var cam_ref := _camera   # captured for the async closure
		var punch_delta := Vector3(0.0, 0.0, -0.08)
		var punch_to := cam_ref.position + punch_delta
		var punch_tw := create_tween().bind_node(cam_ref)
		punch_tw.tween_property(cam_ref, "position", punch_to, 0.10) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		punch_tw.tween_callback(func() -> void:
			if not is_instance_valid(cam_ref):
				return
			# Recover RELATIVE to the dolly-progressed position, not the stale snapshot.
			var dolly_now: Vector3 = cam_ref.position - punch_delta
			var recover_tw := create_tween().bind_node(cam_ref)
			recover_tw.tween_property(cam_ref, "position", dolly_now, 0.30) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		)
	# SFX — defensive (autoload may be absent in smoke).
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx != null and sfx.has_method("play"):
		sfx.call("play", "boss_sting")


## v7.7.10 — Death anim. Dramatic punch-out before route to EndRunScreen.
## Total budget : 1.4s prelude before existing 4s narration wait.
## - Red vignette over entire UI layer fade-in 0.30s, hold 0.80s, hold-to-finish
## - Camera dolly back + tilt down for "collapse" feel
## - Audio sting via SFXManager (defensive)
func _play_death_anim() -> void:
	if _ui_layer != null:
		var vignette := ColorRect.new()
		vignette.name = "DeathVignette"
		vignette.color = Color(0.45, 0.05, 0.08, 0.0)
		vignette.anchor_left = 0.0
		vignette.anchor_right = 1.0
		vignette.anchor_top = 0.0
		vignette.anchor_bottom = 1.0
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui_layer.add_child(vignette)
		var v_tw := create_tween().bind_node(vignette)
		v_tw.tween_property(vignette, "color:a", 0.65, 0.50) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		# Vignette holds — only cleaned up on _finish via the parent tree teardown.
	if _camera != null:
		var origin: Vector3 = _camera.position
		var origin_rot: Vector3 = _camera.rotation
		var pull_back := origin + Vector3(0.0, 0.5, 1.2)
		var tilt_down := origin_rot + Vector3(deg_to_rad(-12.0), 0.0, 0.0)
		var death_cam := create_tween().bind_node(_camera).set_parallel(true)
		death_cam.tween_property(_camera, "position", pull_back, 1.3) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		death_cam.tween_property(_camera, "rotation", tilt_down, 1.3) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx != null and sfx.has_method("play"):
		sfx.call("play", "death_sting")


## v5.1 — Roll the "dé du destin" after each non-boss card resolves.
## If any die rolls a 6 → +1 random faction (small bonus reward).
## If any die rolls a 1 → -1 random faction (small malus).
## Otherwise neutral. Visual flair : floating label announces the result.
## This makes the physics dice meaningful on every act, not just the boss.
func _roll_fate_dice() -> void:
	if _dice_node == null or not is_instance_valid(_dice_node):
		return
	var values: Array = await _dice_node.roll()
	if values.is_empty():
		return
	var has_six := false
	var has_one := false
	for v in values:
		var iv: int = int(v)
		if iv == 6:
			has_six = true
		elif iv == 1:
			has_one = true
	# Cancel if both 6 and 1 — fortune balanced.
	if has_six and has_one:
		_spawn_fate_dice_label("ÉQUILIBRE", Color(0.96, 0.92, 0.74))
		return
	if not has_six and not has_one:
		return  # neutral roll — no flair, dice already settled visually
	# v5.2 — Pick a random faction in BACKEND, but DON'T name it to the player.
	# Réputations cachées : la narration reste ambiguë ("Le destin penche" /
	# "Le destin se détourne") — le joueur ressent l'effet sans voir le nom.
	var factions := ["druides", "anciens", "korrigans", "niamh", "ankou"]
	var faction: String = factions[randi() % factions.size()]
	var delta: int = 1 if has_six else -1
	# Apply to state.meta.faction_rep (backend mutation, invisible to player).
	if _store and _store.get("state") is Dictionary:
		var meta: Dictionary = _store.state.get("meta", {})
		var rep: Dictionary = meta.get("faction_rep", {})
		rep[faction] = int(rep.get(faction, 0)) + delta
		meta["faction_rep"] = rep
		_store.state["meta"] = meta
	# Ambiguous floating label — narration mode.
	var label_text: String = "Le destin penche…" if delta > 0 else "Le destin se détourne…"
	var col: Color = Color(0.85, 0.78, 0.45) if delta > 0 else Color(0.78, 0.55, 0.45)
	_spawn_fate_dice_label(label_text, col)


## v6.4 — Fate dice labels SUPPRESSED per user feedback (2026-05-14 part 16) :
## "certaines phrases qui apparaissent me gênent — Le destin penche, etc."
## Backend faction_rep mutation still happens (silent).
func _spawn_fate_dice_label(_text: String, _color: Color) -> void:
	return  # suppressed in v6.4 — no visible label, backend effect preserved


## Compute the X position for figurine i out of count on the line row.
static func _token_x_for_index(i: int, count: int) -> float:
	if count <= 1:
		return 0.0
	var t: float = float(i) / float(count - 1)
	return lerp(-FIGURINE_LINE_X_HALF, FIGURINE_LINE_X_HALF, t)


## Open the live card mode (parchment overlay + HUD + run loop). Extracted from
## the old _reveal_biome_sequence so the drop choreography can call it after the
## plateau has "settled".
func _open_live_card_mode() -> void:
	# v5.3 — start the ambient biome soundtrack (forest wind + birds for Brocéliande).
	# Per user feedback (2026-05-14 part 10) : "Ambient forêt loop pendant tout le run".
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play_biome_ambient") and biome_id_eq_broceliande():
		sfx.play_biome_ambient("broceliande")
	if _store and _store.has_method("dispatch"):
		_live_card_mode = true
		# v7.1 — Skip _build_card_overlay entirely. The parchemin 2D Panel was a
		# "big rectangle in the middle of the plateau" with no remaining purpose
		# (LiveCard3D carries all card content). Per user feedback 2026-05-14
		# part 15 : "le gros rectangle... il doit dégager".
		# Incantation is now typed into _narration_label (bottom Label, no panel).
		_build_hud()
		if biome_id_eq_broceliande() and _narration_label:
			await _typewriter_narration(BROCELIANDE_INCANTATION)
			await get_tree().create_timer(1.5).timeout
			_narration_label.text = ""
		# Card text labels never built — make sure stale refs are null.
		_card_text_label = null
		_card_badge_label = null
		# v7.2 — QA HIGH 8.3 : Hide redundant HUD labels during LIVE CARD to
		# stay under the 7-affordance Miller cap (bible §21.1). LifeBar + AnamLabel
		# + ActIndicator + CardCount + 3 floating buttons + LiveCard3D + Skip = 8.
		# Hiding BiomeLabel + NarrationLabel + LifeValueLabel brings it to 7.
		if _biome_label:
			_biome_label.visible = false
		if _narration_label:
			_narration_label.visible = false
		if _hud_life_value_label:
			_hud_life_value_label.visible = false
		_card_option_buttons.clear()
		_run_live_loop()
	else:
		_spawn_figurines()
		_run_cinematic()


# ════════════════════════════════════════════════════════════════════════
# HUD — life essence bar + faction rep counters
# ════════════════════════════════════════════════════════════════════════

const FACTION_HUD_COLORS := {
	"druides":   Color(0.55, 0.95, 0.50),
	"anciens":   Color(1.00, 0.85, 0.45),
	"korrigans": Color(0.98, 0.66, 0.30),
	"niamh":     Color(0.65, 0.85, 1.00),
	"ankou":     Color(0.72, 0.55, 0.85),
}
const FACTION_HUD_LABELS := {
	"druides":   "Druides",
	"anciens":   "Anciens",
	"korrigans": "Korrigans",
	"niamh":     "Niamh",
	"ankou":     "Ankou",
}


## Build a thin RPG HUD strip across the top of the screen :
## [ Vie ████░░ 78/100 ]  Druides 12 · Anciens 5 · Korrigans 0 · Niamh 8 · Ankou 3
## Updated after each choice via _refresh_hud().
func _build_hud() -> void:
	# Life essence bar (left side)
	var life_box := HBoxContainer.new()
	life_box.name = "HudLifeBox"
	life_box.position = Vector2(32, 86)
	life_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	life_box.add_theme_constant_override("separation", 8)
	_ui_layer.add_child(life_box)

	var life_lbl := Label.new()
	life_lbl.text = "Vie"
	life_lbl.add_theme_font_size_override("font_size", 16)
	life_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.74))
	life_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	life_lbl.add_theme_constant_override("outline_size", 4)
	life_box.add_child(life_lbl)

	_hud_life_bar = ProgressBar.new()
	_hud_life_bar.name = "LifeBar"
	_hud_life_bar.min_value = 0
	_hud_life_bar.max_value = 100
	_hud_life_bar.value = 100
	_hud_life_bar.show_percentage = false
	_hud_life_bar.custom_minimum_size = Vector2(200, 18)
	var bar_style_bg := StyleBoxFlat.new()
	bar_style_bg.bg_color = Color(0.05, 0.08, 0.10, 0.85)
	bar_style_bg.border_color = Color(0.62, 0.46, 0.24, 1.0)
	bar_style_bg.set_border_width_all(1)
	bar_style_bg.set_corner_radius_all(2)
	_hud_life_bar.add_theme_stylebox_override("background", bar_style_bg)
	var bar_style_fill := StyleBoxFlat.new()
	bar_style_fill.bg_color = Color(0.75, 0.30, 0.20, 0.95)
	bar_style_fill.set_corner_radius_all(2)
	_hud_life_bar.add_theme_stylebox_override("fill", bar_style_fill)
	life_box.add_child(_hud_life_bar)

	# v5.2 — Anam compteur (cross-run currency). Sit next to life bar.
	_hud_anam_label = Label.new()
	_hud_anam_label.name = "AnamLabel"
	_hud_anam_label.text = "Anam 0"
	_hud_anam_label.add_theme_font_size_override("font_size", 14)
	_hud_anam_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.25))  # gold
	_hud_anam_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_anam_label.add_theme_constant_override("outline_size", 3)
	life_box.add_child(_hud_anam_label)

	# v5.2 — Réputations sont META (cachées au joueur). Les 5 labels faction
	# sont supprimés du HUD per user feedback (2026-05-14 part 9) :
	# "enleve les réputations elles ne doivent pas etres visibles, c'est de l'ordre
	#  du meta et doit influencer dans les tirages de carte x narration x qualité
	#  des evenements". Le dict _hud_faction_labels reste vide pour éviter de
	#  casser les autres références (HUD ticker, faction_flip).
	_hud_faction_labels.clear()
	# Card count "Carte X / 5" (top-right) — informe le joueur de sa progression.
	_hud_card_count_label = Label.new()
	_hud_card_count_label.name = "HudCardCount"
	_hud_card_count_label.text = "Carte 1 / 5"
	_hud_card_count_label.add_theme_font_size_override("font_size", 16)
	_hud_card_count_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.74))
	_hud_card_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_card_count_label.add_theme_constant_override("outline_size", 4)
	_hud_card_count_label.anchor_left = 1.0
	_hud_card_count_label.anchor_right = 1.0
	_hud_card_count_label.offset_left = -130
	_hud_card_count_label.offset_right = -16
	_hud_card_count_label.offset_top = 86
	_hud_card_count_label.offset_bottom = 108
	_hud_card_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ui_layer.add_child(_hud_card_count_label)

	# v7.7.9 — Disco-style 4-stat HUD strip (bible v3.6 §25-§26).
	# Stacked vertically under Carte X/Y, top-right anchor. Each label shows
	# icon glyph + stat name + level + pass% (e.g. "◆ Logic L3 80%").
	_build_disco_stats_hud()

	# Floating FX layer (for "+5 Druides" labels appearing on choice)
	_floating_fx_layer = Control.new()
	_floating_fx_layer.name = "FloatingFx"
	_floating_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_fx_layer.anchor_right = 1.0
	_floating_fx_layer.anchor_bottom = 1.0
	_ui_layer.add_child(_floating_fx_layer)

	# Numeric value label next to the life bar (for ticker animation).
	_hud_life_value_label = Label.new()
	_hud_life_value_label.name = "LifeValueLabel"
	_hud_life_value_label.text = "100/100"
	_hud_life_value_label.add_theme_font_size_override("font_size", 14)
	_hud_life_value_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.74))
	_hud_life_value_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_life_value_label.add_theme_constant_override("outline_size", 3)
	life_box.add_child(_hud_life_value_label)

	# Act indicator (top-center, anchored across the screen).
	_hud_act_label = Label.new()
	_hud_act_label.name = "ActIndicator"
	_hud_act_label.text = ""
	_hud_act_label.add_theme_font_size_override("font_size", 20)
	_hud_act_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_act_label.add_theme_constant_override("outline_size", 5)
	_hud_act_label.anchor_left = 0.0
	_hud_act_label.anchor_right = 1.0
	_hud_act_label.offset_top = 56
	_hud_act_label.offset_bottom = 80
	_hud_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(_hud_act_label)

	# Stat readout strip (above the parchment card panel).
	_hud_stat_strip = HBoxContainer.new()
	_hud_stat_strip.name = "StatStrip"
	_hud_stat_strip.anchor_left = 0.0
	_hud_stat_strip.anchor_right = 1.0
	_hud_stat_strip.offset_top = 130
	_hud_stat_strip.offset_bottom = 178
	_hud_stat_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_stat_strip.add_theme_constant_override("separation", 16)
	_hud_stat_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_stat_strip.visible = false
	_ui_layer.add_child(_hud_stat_strip)

	_refresh_hud()


## v7.7.9 — Build the 4-stat HUD strip (top-right under Carte X/Y).
## Each stat = its own Label, stacked vertically. Icons via glyph chars
## (◆ Logic, ♥ Empathie, ⚔ Volonté, ☆ Instinct) per bible §25 archetypes.
## Wired to MerlinStats.stat_changed + level_up signals for live updates.
const DISCO_STAT_GLYPHS := {
	"logic":    "◆",
	"empathie": "♥",
	"volonte":  "⚔",
	"instinct": "☆",
}
const DISCO_STAT_COLORS := {
	"logic":    Color(0.55, 0.85, 0.95),   # cyan-blue (cold reason)
	"empathie": Color(0.95, 0.65, 0.75),   # rose (warmth)
	"volonte":  Color(0.95, 0.78, 0.30),   # gold (resolve)
	"instinct": Color(0.78, 0.62, 0.95),   # violet (gut)
}
const DISCO_STAT_ORDER: Array[String] = ["logic", "empathie", "volonte", "instinct"]
const DISCO_HUD_RIGHT_OFFSET: float = 16.0
const DISCO_HUD_TOP_START: float = 112.0    # below "Carte X/Y" label
const DISCO_HUD_LINE_HEIGHT: float = 22.0

func _build_disco_stats_hud() -> void:
	# Skip cleanly if MerlinStats autoload not present (defensive — should be).
	var stats_node: Node = Engine.get_main_loop().root.get_node_or_null("MerlinStats")
	if stats_node == null:
		push_warning("[BoardNarration] MerlinStats autoload missing — skipping stats HUD")
		return
	for i in range(DISCO_STAT_ORDER.size()):
		var stat: String = DISCO_STAT_ORDER[i]
		var lbl := Label.new()
		lbl.name = "DiscoStat_" + stat
		lbl.text = _format_disco_stat_text(stat, stats_node)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", DISCO_STAT_COLORS[stat])
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.anchor_left = 1.0
		lbl.anchor_right = 1.0
		lbl.offset_left = -180.0
		lbl.offset_right = -DISCO_HUD_RIGHT_OFFSET
		lbl.offset_top = DISCO_HUD_TOP_START + float(i) * DISCO_HUD_LINE_HEIGHT
		lbl.offset_bottom = lbl.offset_top + DISCO_HUD_LINE_HEIGHT
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_ui_layer.add_child(lbl)
		_hud_stat_labels[stat] = lbl
	# Wire signals — refresh + toast on level up.
	if stats_node.has_signal("stat_changed"):
		stats_node.stat_changed.connect(_on_disco_stat_changed)
	if stats_node.has_signal("level_up"):
		stats_node.level_up.connect(_on_disco_level_up)


## Format one stat label : "◆ Logic L3 80%"
func _format_disco_stat_text(stat: String, stats_node: Node) -> String:
	var glyph: String = String(DISCO_STAT_GLYPHS.get(stat, "•"))
	var label: String = stat.capitalize()
	var level: int = int(stats_node.call("get_stat_level", stat))
	var chance: float = float(stats_node.call("get_pass_chance", stat))
	return "%s %s L%d %d%%" % [glyph, label, level, int(round(chance * 100.0))]


func _on_disco_stat_changed(stat_name: String, _xp: int, _level: int) -> void:
	if not _hud_stat_labels.has(stat_name):
		return
	var stats_node: Node = Engine.get_main_loop().root.get_node_or_null("MerlinStats")
	if stats_node == null:
		return
	var lbl: Label = _hud_stat_labels[stat_name]
	lbl.text = _format_disco_stat_text(stat_name, stats_node)
	# Subtle pulse to draw eye on XP gain. bind_node ensures the tween auto-stops
	# if `lbl` is freed mid-animation (code-review MEDIUM fix).
	var tw := create_tween().bind_node(lbl)
	tw.tween_property(lbl, "scale", Vector2(1.18, 1.18), 0.10).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)


## Spawn a transient toast "Lv ↑ Logic L3" center-screen for 1.5s on level up.
func _on_disco_level_up(stat_name: String, new_level: int) -> void:
	if _ui_layer == null:
		return
	if _hud_level_toast != null and is_instance_valid(_hud_level_toast):
		_hud_level_toast.queue_free()
	var toast := Label.new()
	toast.name = "DiscoLevelUpToast"
	var glyph: String = String(DISCO_STAT_GLYPHS.get(stat_name, "•"))
	var color: Color = DISCO_STAT_COLORS.get(stat_name, Color.WHITE)
	toast.text = "Lv ↑  %s  %s  L%d" % [glyph, stat_name.capitalize(), new_level]
	toast.add_theme_font_size_override("font_size", 28)
	toast.add_theme_color_override("font_color", color)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	toast.add_theme_constant_override("outline_size", 8)
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.anchor_top = 0.5
	toast.anchor_bottom = 0.5
	toast.offset_left = -160
	toast.offset_right = 160
	toast.offset_top = -120
	toast.offset_bottom = -60
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	_ui_layer.add_child(toast)
	_hud_level_toast = toast
	# bind_node auto-stops the tween if `toast` is freed mid-animation (rapid
	# level-up sequences would otherwise dangle the tween — code-review HIGH-2).
	var tw := create_tween().bind_node(toast)
	tw.tween_property(toast, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(toast, "offset_top", -150.0, 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(toast, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
		_hud_level_toast = null
	)


## Read current life + faction rep from Store, update HUD widgets.
## Uses JuiceHelpers ticker on the life bar (counts from old→new over 0.6s
## with chevron wave) + faction flip animation when a faction's value changes.
## Caches previous values so the animation only fires on real deltas.
func _refresh_hud() -> void:
	if _store == null or not (_store.get("state") is Dictionary):
		return
	var state: Dictionary = _store.state
	var run: Dictionary = state.get("run", {})
	var life: int = int(run.get("life_essence", 100))
	if _hud_life_bar and life != _hud_prev_life:
		JuiceHelpers.hud_life_ticker(self, _hud_life_bar, _hud_life_value_label, _hud_prev_life, life)
		_hud_prev_life = life
	elif _hud_life_bar:
		_hud_life_bar.value = float(life)
		if _hud_life_value_label:
			_hud_life_value_label.text = "%d/100" % life
	var meta: Dictionary = state.get("meta", {})
	# v5.2 — Réputations sont META. Le loop sur _hud_faction_labels est obsolète
	# (dict reste vide). On lit toujours faction_rep en backend pour les calculs
	# de cartes / narration / event quality, mais aucun affichage HUD.
	# Anam : affichage de la currency cross-run.
	if _hud_anam_label:
		var anam_val: int = int(meta.get("anam", 0)) + _run_anam_earned
		_hud_anam_label.text = "Anam %d" % anam_val
	# Card count : "Carte X / 5"
	if _hud_card_count_label:
		var total_acts: int = _act_sequence().size()
		var shown_idx: int = clampi(_live_acts_played + 1, 1, total_acts)
		_hud_card_count_label.text = "Carte %d / %d" % [shown_idx, total_acts]
	# v5.5 — Dominant faction shift ambient music variant.
	# Réput reste cachée au joueur en chiffres, mais le ressenti audio change.
	_update_ambient_for_dominant_faction(meta)


## v5.5 — Detect dominant faction (rep ≥ 5) and swap to its ambient variant.
## De-bounced via _last_ambient_variant : we only swap when the variant key changes.
## Per user feedback (2026-05-14 part 11) : "Ambient music shift selon faction dominante".
func _update_ambient_for_dominant_faction(meta: Dictionary) -> void:
	if not biome_id_eq_broceliande():
		return  # only Brocéliande has variants implemented
	var rep: Dictionary = meta.get("faction_rep", {})
	var best := ""
	var best_v := 4  # threshold = 5 (need at least 5 to be dominant)
	for fac in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		var v: int = int(rep.get(fac, 0))
		if v > best_v:
			best_v = v
			best = fac
	var target: String = "amb_broc_" + best if not best.is_empty() else "amb_broceliande"
	if target == _last_ambient_variant:
		return
	_last_ambient_variant = target
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play(target, 1.0)
	# v5.6 — Cameo animal totem on faction threshold crossed.
	_check_faction_cameo_threshold(meta)


## v5.6 — Trigger an animal totem cameo when a faction first crosses rep ≥ 15.
## One-shot per faction per run (de-duped via _shown_cameo_factions).
## Per user feedback (round 11 Q1 multiselect) : "Cameo : l'animal totem de la
## faction haute apparaît près du plateau".
func _check_faction_cameo_threshold(meta: Dictionary) -> void:
	var rep: Dictionary = meta.get("faction_rep", {})
	for fac in ["druides", "anciens", "korrigans", "niamh", "ankou"]:
		var v: int = int(rep.get(fac, 0))
		if v >= 10 and not _shown_cameo_factions.get(fac, false):  # v7.2 QA MEDIUM 6.10 : threshold 15→10 (15 unreachable in most runs)
			_shown_cameo_factions[fac] = true
			_spawn_faction_totem_cameo(fac)


## Spawn the totem animal GLB next to the plateau, fade in → 5s idle → fade out.
## Reuses the existing ANIMAL_CAMEO_BY_FACTION dict + CAMEO_FADE_TIME constants.
## Doesn't disturb the _current_cameo system (that one is tied to SigleToken
## which is no longer spawned in live mode — kept for cinematic replay path).
func _spawn_faction_totem_cameo(faction: String) -> void:
	var glb_path: String = str(ANIMAL_CAMEO_BY_FACTION.get(faction, ""))
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		return
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		return
	var cameo: Node3D = packed.instantiate() as Node3D
	if cameo == null:
		return
	cameo.name = "FactionTotem_" + faction
	# World position : left edge of plateau, in view of camera (mirror of dice tray right).
	cameo.position = Vector3(-2.5, 0.5, 1.2)
	cameo.scale = Vector3.ZERO
	cameo.rotation = Vector3(0, deg_to_rad(25.0), 0)  # face toward plateau center
	add_child(cameo)
	# Fade in → 5s hold → fade out + free
	var t := create_tween()
	t.tween_property(cameo, "scale", Vector3.ONE * 0.6, CAMEO_FADE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(5.0)
	t.tween_property(cameo, "scale", Vector3.ZERO, CAMEO_FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(cameo.queue_free)
	# v6.4 — "Un présage se montre…" label SUPPRESSED per user feedback.
	# Le cameo visuel (GLB animal) suffit, plus de label superflu.


## Render the per-card stat readout strip (Difficulty / Risk / FactionPressure / Reward / Ogham).
## Strip lives in _hud_stat_strip (HBoxContainer) above the parchment card panel.
## Computes the stats from the card's own options[].effects[] via JuiceHelpers.compute_stat_readout.
func _render_stat_readout(card: Dictionary) -> void:
	if _hud_stat_strip == null:
		return
	# Clear previous widgets
	for child in _hud_stat_strip.get_children():
		(child as Node).queue_free()
	# Skip stat strip for shop / boss / event variants (they have their own UI badges).
	var act_type: String = str(card.get("act_type", "standard"))
	if act_type == "shop" or act_type == "boss":
		_hud_stat_strip.visible = false
		return
	var stats: Dictionary = JuiceHelpers.compute_stat_readout(card)
	_hud_stat_strip.visible = true
	# Block 1 : Difficulty (stars)
	var diff_lbl := Label.new()
	diff_lbl.add_theme_font_size_override("font_size", 18)
	var diff: int = int(stats.get("difficulty", 1))
	var diff_color := Color(0.96, 0.78, 0.25)  # gold default
	if diff >= 4:
		diff_color = Color(0.81, 0.25, 0.19)  # red
	elif diff == 3:
		diff_color = Color(0.94, 0.55, 0.19)  # amber
	diff_lbl.add_theme_color_override("font_color", diff_color)
	diff_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	diff_lbl.add_theme_constant_override("outline_size", 4)
	var stars := ""
	for i in range(5):
		stars += "★" if i < diff else "☆"
	diff_lbl.text = stars
	_hud_stat_strip.add_child(diff_lbl)
	# Block 2 : Risk %
	var risk_lbl := Label.new()
	risk_lbl.add_theme_font_size_override("font_size", 14)
	var risk: int = int(stats.get("risk_pct", 0))
	var risk_col := Color(0.37, 0.69, 0.31)  # green
	if risk >= 31:
		risk_col = Color(0.81, 0.25, 0.19)  # red
	elif risk >= 16:
		risk_col = Color(0.94, 0.55, 0.19)  # amber
	risk_lbl.add_theme_color_override("font_color", risk_col)
	risk_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	risk_lbl.add_theme_constant_override("outline_size", 4)
	risk_lbl.text = "RISQUE %d%%" % risk
	_hud_stat_strip.add_child(risk_lbl)
	# v5.2 — Block 3 (faction pressure dots) SUPPRIMÉ.
	# Per user feedback : "réputations cachées, c'est de l'ordre du meta".
	# Les faction_pressure dots révélaient les effets prévus par faction —
	# information meta qui doit rester en backend pour influencer narration /
	# qualité d'event sans être affichée au joueur.
	# Block 4 : Reward hint — v5.2 enleve la mention faction (meta cachée).
	# On garde uniquement le gain de vie potentiel (info utile au joueur).
	# Le gain de faction reste backend (influence narration / qualité).
	var reward: Dictionary = stats.get("reward_hint", {})
	var max_life: int = int(reward.get("max_life", 0))
	if max_life > 0:
		var reward_lbl := Label.new()
		reward_lbl.add_theme_font_size_override("font_size", 14)
		reward_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55))
		reward_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		reward_lbl.add_theme_constant_override("outline_size", 4)
		reward_lbl.text = "+%d vie" % max_life
		_hud_stat_strip.add_child(reward_lbl)
	# Block 5 : Ogham echo
	var ogham_id: String = str(card.get("ogham_used", ""))
	if not ogham_id.is_empty():
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		var glyph: String = str(spec.get("unicode", ""))
		if not glyph.is_empty():
			var ogham_lbl := Label.new()
			ogham_lbl.text = glyph
			ogham_lbl.add_theme_font_size_override("font_size", 28)
			ogham_lbl.add_theme_color_override("font_color", Color(0.96, 0.78, 0.25))
			ogham_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			ogham_lbl.add_theme_constant_override("outline_size", 5)
			_hud_stat_strip.add_child(ogham_lbl)


## Spawn floating labels showing each effect's delta near the appropriate
## HUD widget. "+5 Druides" floats up + fades; "-3 vie" floats above the bar.
func _animate_effect_feedback(effects: Array) -> void:
	if _floating_fx_layer == null:
		return
	var stagger := 0.0
	for raw in effects:
		var eff: Dictionary = raw if raw is Dictionary else {}
		var etype: String = str(eff.get("type", ""))
		var amount: int = int(eff.get("amount", 0))
		var faction: String = str(eff.get("faction", ""))
		var text := ""
		var color := Color(1, 1, 1)
		var anchor_pos: Vector2 = Vector2(120, 100)
		match etype:
			"ADD_REPUTATION":
				# v5.2 — réputations cachées : pas de label visible pour les
				# deltas de faction. Le backend mutate l'état, l'UI ne révèle
				# pas. On skip silencieusement le spawn de label.
				continue
			"HEAL_LIFE", "DAMAGE_LIFE":
				# v6.4 — "+/-N vie" floating labels SUPPRESSED per user feedback.
				# Le HUD life bar ticker (count-up animation) parle pour l'effet.
				continue
			_:
				continue
		# v6.4 — All spawn calls in this match are `continue` ; this line is unreachable
		# kept for future re-enable. The HUD refresh below still fires for ticker anim.
	# Refresh HUD values after a beat so the bar/numbers catch up to the store.
	var refresh := create_tween()
	refresh.tween_interval(0.5)
	refresh.tween_callback(Callable(self, "_refresh_hud"))


func _spawn_floating_label(text: String, color: Color, pos: Vector2, delay: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.modulate = Color(1, 1, 1, 0)
	_floating_fx_layer.add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_interval(delay)
	tw.chain().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_property(lbl, "position:y", pos.y - 60.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(lbl.queue_free)


## Fetch a card with bounded wait. Try LLM via Store first; if it returns
## empty within 15s, use the hand-written FastRoute fallback pool.
## 15s gives the LLM real generation time (vs 6s which always timed out).
## Ensures the scenario always advances even when LLM is offline / slow.
func _fetch_card_with_fallback() -> Dictionary:
	var llm_ready := _store != null and _store.has_method("dispatch")
	if llm_ready:
		var got_holder := {"done": false, "card": {}}
		var get_action: Dictionary = {"type": "GET_CARD"}
		var llm_task := func() -> void:
			var r = await _store.dispatch(get_action)
			if got_holder.get("done", false):
				return
			got_holder["done"] = true
			if r is Dictionary and bool(r.get("ok", false)) and r.has("card"):
				got_holder["card"] = r["card"]
		llm_task.call()
		var elapsed := 0.0
		while not bool(got_holder["done"]) and elapsed < 15.0:
			await get_tree().create_timer(0.1).timeout
			elapsed += 0.1
		got_holder["done"] = true
		var card_v: Dictionary = got_holder.get("card", {})
		if not card_v.is_empty() and card_v.has("options"):
			return card_v
	return _pick_fallback_card()


## Fetch a card biased to a specific act_type ("standard"/"shop"/"event"/"boss").
## Falls back to the unfiltered fetch when no LLM card matches and no act-specific
## fallback exists in the pool.
func _fetch_card_for_act(act_type: String) -> Dictionary:
	# Scenario scripte : la carte est imposee par la sequence, pas piochee.
	# `_live_acts_played` est l'index de la carte courante, deja pose par la boucle.
	if not _scripted_cards.is_empty():
		var i: int = clampi(_live_acts_played, 0, _scripted_cards.size() - 1)
		return _scripted_card_to_engine(_scripted_cards[i] as Dictionary, act_type)
	# Filter fallback pool by act_type. "standard" matches both explicit and missing field.
	if _fallback_pool.is_empty():
		_load_fallback_pool()
	var matching: Array = []
	for c in _fallback_pool:
		if not (c is Dictionary):
			continue
		var ct: String = str(c.get("act_type", "standard"))
		if ct == act_type or (act_type == "standard" and ct == "standard"):
			matching.append(c)
	# Boss/shop/event must use the act-specific fallback (LLM doesn't know these schemas yet).
	if act_type != "standard" and not matching.is_empty():
		var idx: int = _fallback_index % matching.size()
		_fallback_index += 1
		var raw: Dictionary = matching[idx]
		return _normalize_act_card(raw, act_type)
	# Standard : try LLM first, fall back to standard pool.
	if act_type == "standard":
		return await _fetch_card_with_fallback()
	# No matching act card found — emergency fall back to any card.
	return _pick_fallback_card()


## Normalize an act-typed card (shop/event/boss) into the {text, options, ...} shape
## expected by _show_live_card. Preserves all act-specific metadata.
func _normalize_act_card(raw: Dictionary, act_type: String) -> Dictionary:
	var normalized: Dictionary = {
		"id": str(raw.get("id", "act_card")),
		"text": str(raw.get("text", "")),
		"prompt": str(raw.get("text", "")),
		"options": raw.get("options", []),
		"act_type": act_type,
		"act_subtype": str(raw.get("act_subtype", "")),
		"ogham_used": str(raw.get("ogham_used", "")),
		"dialogue": str(raw.get("dialogue", "")),
		"difficulty": int(raw.get("difficulty", 1)),
	}
	# For boss cards, prepend the dialogue to the body text so the player sees it.
	if act_type == "boss" and not normalized["dialogue"].is_empty():
		normalized["text"] = "%s\n\n«%s»" % [normalized["text"], normalized["dialogue"]]
		normalized["prompt"] = normalized["text"]
	return normalized


## Capture the shop modifier from the chosen ware so Acts 3-4 can mutate effects.
## Modifier code is the first APPLY_MODIFIER effect on the chosen option.
func _capture_shop_modifier(card: Dictionary, option_index: int) -> void:
	var options: Array = card.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return
	var opt: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	for fx in opt.get("effects", []):
		if fx is Dictionary and str(fx.get("type", "")) == "APPLY_MODIFIER":
			_active_modifier = str(fx.get("modifier", ""))
			push_warning("[BoardNarration] Shop modifier captured: %s" % _active_modifier)
			# v6.4 — "Modifier : XXX" banner SUPPRESSED per user feedback.
			# Effet appliqué en backend, le joueur ressent l'effet sur Acts 3-4.
			return


## Resolve boss DICE_TEST + ANAM_REWARD inline (effect engine doesn't know these).
## 1d20 + (faction_score / 10) vs DC. v5 : actually rolls _dice_node (2 physics dice).
## 2d6 sum (range 2..12) is mapped onto the 1..20 d20 range for narrative flair —
## the player SEES physical dice tumble next to the plateau then settle.
func _resolve_boss_anam(card: Dictionary, option_index: int) -> void:
	var options: Array = card.get("options", [])
	if option_index < 0 or option_index >= options.size():
		return
	var opt: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	for fx in opt.get("effects", []):
		if not (fx is Dictionary):
			continue
		if str(fx.get("type", "")) != "DICE_TEST":
			continue
		var dc: int = int(fx.get("dc", 12))
		var stat: String = str(fx.get("stat", "druides"))
		# Read current faction rep from Store (defaults to 0 if missing).
		var rep: int = 0
		if _store and _store.get("state") is Dictionary:
			rep = int(_store.state.get("meta", {}).get("faction_rep", {}).get(stat, 0))
		# Roll the physical dice (2d6) if available, else fall back to randi.
		var roll: int
		if _dice_node and is_instance_valid(_dice_node):
			var dice_values: Array = await _dice_node.roll()
			var sum_dice := 0
			for v in dice_values:
				sum_dice += int(v)
			# Map 2..12 → 1..20 for d20 equivalence (linear scale).
			roll = clampi(int(round((sum_dice - 2) / 10.0 * 19.0)) + 1, 1, 20)
		else:
			roll = randi() % 20 + 1
		var total: int = roll + int(rep / 10.0)
		var success: bool = total >= dc
		var anam_amount: int = 0
		var branch: Array = fx.get("on_success" if success else "on_failure", [])
		for sub_fx in branch:
			if sub_fx is Dictionary and str(sub_fx.get("type", "")) == "ANAM_REWARD":
				anam_amount = int(sub_fx.get("amount", 0))
				break
		_run_anam_earned += anam_amount
		push_warning("[BoardNarration] Boss dice test : 1d20=%d + %d/10=%d vs DC %d = %s, Anam +%d" % [
			roll, rep, total, dc, "SUCCESS" if success else "FAILURE", anam_amount
		])
		# Spawn a big floating label showing the roll.
		if _floating_fx_layer:
			var roll_col: Color = Color(0.96, 0.92, 0.74) if success else Color(0.85, 0.30, 0.30)
			JuiceHelpers.spawn_floating_label_arc(
				self, _floating_fx_layer,
				"%d vs DC %d = %s" % [total, dc, "RÉUSSITE" if success else "ÉCHEC"],
				roll_col, Vector2(540, 240), 0.0
			)
			JuiceHelpers.spawn_floating_label_arc(
				self, _floating_fx_layer,
				"+%d Anam" % anam_amount,
				Color(0.96, 0.78, 0.25),
				Vector2(540, 280), 0.4
			)
		# Persist Anam to state.meta.anam if Store is available.
		if _store and _store.get("state") is Dictionary:
			var meta: Dictionary = _store.state.get("meta", {})
			meta["anam"] = int(meta.get("anam", 0)) + anam_amount
			_store.state["meta"] = meta
			# v5.4 — save profile immediately so Anam survives crash/quit.
			# Per user feedback (2026-05-14 part 11) : "Save à chaque incrément Anam".
			_save_anam_to_profile()
		return


## v5.4 — Trigger MerlinStore SAVE_PROFILE dispatch to persist meta state
## (notably state.meta.anam) to user://merlin_profile.save. Called after every
## Anam mutation so cross-run currency survives mid-run crash/quit.
func _save_anam_to_profile() -> void:
	if _store == null or not _store.has_method("dispatch"):
		return
	# Fire-and-forget : we don't await — save is fast (small JSON).
	_store.dispatch({"type": "SAVE_PROFILE"})


## v5.4 — Pre-warm the LLM (Qwen 3.5) by firing an early GET_CARD whose result
## we discard. The model loads ~15-25s cold; our drop choreography is 5.5s.
## After this warm-up, the Act 1 GET_CARD response time drops to ~3-5s instead
## of 15-25s — masking the latency behind the visible drop animation.
## Fire-and-forget : we don't await ; the dispatch runs in parallel with the rest
## of the scene logic.
func _prewarm_llm() -> void:
	if _store == null or not _store.has_method("dispatch"):
		return
	if not _scripted_cards.is_empty():
		return  # scenario scripte : aucune carte ne vient du LLM
	# Lambda captures _store ; runs async ; result discarded.
	var warmup_task := func() -> void:
		var _r = await _store.dispatch({"type": "GET_CARD"})
		# Result intentionally discarded — only the model warm-up matters.
	warmup_task.call()


## Load FastRoute pool on first call, then cycle through Brocéliande cards.
## Etapes d'arc deja servies dans ce run : nom d'arc -> etape la plus haute vue.
var _arc_stage_served: Dictionary = {}

## Texte de la derniere carte servie — sert au garde-fou de repetition.
var _last_card_text: String = ""

## Au-dela de cette proximite lexicale, deux cartes racontent la meme chose.
const CARD_ECHO_THRESHOLD := 0.40


## Mots de plus de 4 lettres d'un texte, en minuscules — base de comparaison.
static func _content_words(text: String) -> Dictionary:
	var out: Dictionary = {}
	var cleaned: String = text.to_lower()
	for ch in [",", ".", ";", ":", "!", "?", "'", "«", "»", "\"", "(", ")", "—"]:
		cleaned = cleaned.replace(ch, " ")
	for w in cleaned.split(" ", false):
		if w.length() > 4:
			out[w] = true
	return out


## Proximite lexicale de deux textes (indice de Jaccard).
static func _text_similarity(a: String, b: String) -> float:
	var wa: Dictionary = _content_words(a)
	var wb: Dictionary = _content_words(b)
	if wa.is_empty() or wb.is_empty():
		return 0.0
	var inter: int = 0
	for w in wa.keys():
		if wb.has(w):
			inter += 1
	var union: int = wa.size() + wb.size() - inter
	return float(inter) / float(union) if union > 0 else 0.0


## Une carte d'arc n'est jouable que si l'etape precedente a ete jouee.
## v7.7.28 — sans ce garde-fou, le melange du pool servait l'arc a l'envers :
## Gwenn demandait au climax d'examiner le Chene alors qu'a la premiere carte
## elle avait deja trouve la racine corrompue. Le sens d'une sequence est dans
## son ordre ; la varier revient a la detruire.
func _arc_card_is_playable(card: Dictionary) -> bool:
	var arc_name: String = str(card.get("arc", ""))
	if arc_name == "":
		return true
	var stage: int = int(card.get("arc_stage", 1))
	return stage == int(_arc_stage_served.get(arc_name, 0)) + 1


func _note_arc_stage(card: Dictionary) -> void:
	var arc_name: String = str(card.get("arc", ""))
	if arc_name == "":
		return
	var stage: int = int(card.get("arc_stage", 1))
	if stage > int(_arc_stage_served.get(arc_name, 0)):
		_arc_stage_served[arc_name] = stage


func _pick_fallback_card() -> Dictionary:
	if _fallback_pool.is_empty():
		_load_fallback_pool()
	if _fallback_pool.is_empty():
		return {}
	# Cherche la prochaine carte jouable : on saute les etapes d'arc hors
	# sequence, et — v7.7.28 — les cartes trop proches de celle qu'on vient de
	# servir. Le pool contient des quasi-jumelles (deux cercles de champignons
	# luminescents au pied de deux arbres differents) : les enchainer donne au
	# joueur l'impression de rejouer la meme scene.
	var idx: int = _fallback_index % _fallback_pool.size()
	var found: bool = false
	for pass_idx in range(2):
		# 1re passe : sequence d'arc ET anti-repetition. 2e passe : sequence
		# seule, pour ne jamais rester sans carte a servir.
		var probes: int = 0
		while probes < _fallback_pool.size():
			var probe: int = (_fallback_index + probes) % _fallback_pool.size()
			var cand: Dictionary = _fallback_pool[probe]
			if _arc_card_is_playable(cand):
				var echo: float = 0.0
				if pass_idx == 0 and _last_card_text != "":
					echo = _text_similarity(str(cand.get("text", "")), _last_card_text)
				if echo <= CARD_ECHO_THRESHOLD:
					idx = probe
					found = true
					break
			probes += 1
		if found:
			break
	_fallback_index = idx + 1
	# Normalize the pool format so it matches what _show_live_card expects.
	var raw: Dictionary = _fallback_pool[idx]
	_note_arc_stage(raw)
	_last_card_text = str(raw.get("text", ""))
	var normalized: Dictionary = {
		"id": str(raw.get("id", "fallback_%d" % idx)),
		"text": str(raw.get("text", "")),
		"prompt": str(raw.get("text", "")),
		"options": raw.get("options", []),
	}
	return normalized


func _load_fallback_pool() -> void:
	var f := FileAccess.open(FALLBACK_CARDS_PATH, FileAccess.READ)
	if f == null:
		push_warning("[BoardNarration] fallback pool not found at %s" % FALLBACK_CARDS_PATH)
		return
	var content: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(content)
	if not (parsed is Dictionary):
		push_warning("[BoardNarration] fallback pool JSON parse failed")
		return
	var d: Dictionary = parsed
	var narratives: Array = d.get("narrative", [])
	# Filter to current biome only.
	for card in narratives:
		if card is Dictionary and str(card.get("biome", "")) == _biome_id:
			_fallback_pool.append(card)

	# v7.7.27 — le pool etait consomme dans son ordre de fichier, et
	# `_fallback_index` repart de 0 a chaque scene : six runs d'affilee tiraient
	# exactement les cartes 1 a 5, dans le meme ordre. Mesure sur serie reelle :
	# 1 parcours distinct sur 6 runs, 42 % du pool jamais vu. On melange le pool
	# a chaque chargement — meme sans LLM, deux runs ne se ressemblent plus.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(_fallback_pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap = _fallback_pool[i]
		_fallback_pool[i] = _fallback_pool[j]
		_fallback_pool[j] = swap

	push_warning("[BoardNarration] fallback pool loaded: %d %s cards (melange)" % [_fallback_pool.size(), _biome_id])


func _disable_global_overlays() -> void:
	for overlay_name in HIDDEN_OVERLAY_AUTOLOADS:
		var node: Node = get_node_or_null("/root/" + overlay_name)
		if node == null:
			continue
		if node is CanvasItem:
			_overlay_prev_visible[overlay_name] = (node as CanvasItem).visible
			(node as CanvasItem).visible = false
		elif node.has_method("set_visible"):
			_overlay_prev_visible[overlay_name] = true
			node.set_visible(false)


func _restore_global_overlays() -> void:
	for overlay_name in _overlay_prev_visible.keys():
		var node: Node = get_node_or_null("/root/" + overlay_name)
		if node == null:
			continue
		var prev: bool = bool(_overlay_prev_visible[overlay_name])
		if node is CanvasItem:
			(node as CanvasItem).visible = prev
		elif node.has_method("set_visible"):
			node.set_visible(prev)


# ─── Scene construction ──────────────────────────────────────────────────────

func _build_scene_tree() -> void:
	# Camera (add to tree BEFORE look_at)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	add_child(_camera)
	_camera.position = CAMERA_WIDE_POS
	_camera.look_at(CAMERA_WIDE_TARGET, Vector3.UP)
	_camera.fov = 50.0
	_camera.current = true

	# WorldEnvironment — sky gradient, mild glow + tonemap for richer colors
	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var procedural := ProceduralSkyMaterial.new()
	procedural.sky_top_color = Color(0.04, 0.06, 0.10)
	procedural.sky_horizon_color = Color(0.15, 0.13, 0.18)
	procedural.ground_bottom_color = Color(0.02, 0.03, 0.04)
	procedural.ground_horizon_color = Color(0.15, 0.13, 0.18)
	procedural.sun_angle_max = 30.0
	procedural.sun_curve = 0.15
	sky.sky_material = procedural
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.18
	env.glow_strength = 1.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.10
	# Distance fog softens spotlight cone + adds depth to backdrop.
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.50, 0.45)
	env.fog_light_energy = 0.5
	env.fog_density = 0.018
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.2
	# VolumetricFog — real god-ray-capable volumetrics (Godot 4 Forward+).
	# Density low so it adds atmosphere without washing the scene out.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.72, 0.65, 0.55)
	env.volumetric_fog_emission = Color(0.04, 0.03, 0.02)
	env.volumetric_fog_emission_energy = 0.3
	env.volumetric_fog_anisotropy = 0.20
	env.volumetric_fog_length = 24.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.0
	_world_env.environment = env
	add_child(_world_env)

	# Key light (sun / moon — biome tinted, strong)
	_key_light = DirectionalLight3D.new()
	_key_light.name = "KeyLight"
	_key_light.position = Vector3(3.0, 5.0, 2.0)
	# v7.7.3a — _key_light acts as fill in the plateau scene; _spot_light below is
	# the primary shadow caster. Two shadow-casting lights = 2-3ms/frame, cut to
	# one (spot only). Fill light shadow on a druidic plateau is imperceptible.
	_key_light.shadow_enabled = false
	_key_light.light_energy = 2.0
	_key_light.light_indirect_energy = 1.2
	add_child(_key_light)

	# Fill light (soft warm, opposite side)
	_fill_light = OmniLight3D.new()
	_fill_light.name = "FillLight"
	_fill_light.position = Vector3(-3.0, 1.5, 2.5)
	_fill_light.light_color = Color(0.9, 0.7, 0.5)
	_fill_light.light_energy = 1.2
	_fill_light.omni_range = 8.0
	_fill_light.omni_attenuation = 1.5
	add_child(_fill_light)

	# Theatrical spotlight (will follow the current figurine) — add BEFORE look_at
	_spot_light = SpotLight3D.new()
	_spot_light.name = "Spotlight"
	_spot_light.light_color = Color(1.0, 0.95, 0.85)
	_spot_light.light_energy = 0.0
	_spot_light.spot_range = 5.0
	_spot_light.spot_angle = 18.0
	_spot_light.spot_attenuation = 1.6   # higher = sharper edge, less visible cone
	_spot_light.shadow_enabled = true
	add_child(_spot_light)
	_spot_light.position = Vector3(0.0, 3.0, 0.5)
	_spot_light.look_at(Vector3(0.0, FIGURINE_Y, FIGURINE_LINE_Z), Vector3.UP)

	# Plateau loading priority (v7.4) :
	#   1. Biome-specific bundle via BiomeLoader (NEW — bible §22 + workflow §5).
	#   2. Legacy plateau_carved.glb if a biome bundle is absent.
	#   3. Procedural cylinder fallback.
	# BiomeLoader auto-applies CelShadingManager (low-poly flat + outline noir).
	if BiomeLoader.has_bundle(_biome_id):
		var biome_root: Node3D = BiomeLoader.instantiate_bundle(_biome_id)
		if biome_root != null:
			add_child(biome_root)
			biome_root.set_meta("from_biome_bundle", true)
			_plateau = _find_first_mesh(biome_root)
			if _plateau == null:
				push_warning("[BoardNarration] Bundle '%s' loaded but no Plateau mesh found." % _biome_id)
				biome_root.queue_free()
	# v7.5 — DISABLED legacy plateau_carved.glb path. The GLB ships with an
	# extra cuboid mesh that appears as a persistent brown rectangle on the
	# plateau center in every biome (user 3x flagged, 2026-05-15 part 19).
	# Procedural cylinder fallback (now BiomePalettes-driven §22) is the only
	# remaining path until a clean v7.4-spec biome bundle replaces it.
	var plateau_glb_path := ""  # was "res://assets/blender/plateau_carved.glb"
	if _plateau == null and plateau_glb_path != "" and ResourceLoader.exists(plateau_glb_path):
		var packed: PackedScene = load(plateau_glb_path) as PackedScene
		if packed:
			var inst: Node = packed.instantiate()
			inst.name = "Plateau"
			inst.set_meta("from_glb", true)
			add_child(inst)
			# Deep search for first MeshInstance3D (Blender GLBs may nest meshes
			# under an Empty/armature root; shallow get_children() misses them
			# and would leave the GLB orphaned in the tree behind a fallback
			# procedural cylinder — see code-review 2026-05-14).
			_plateau = _find_first_mesh(inst)
			if _plateau == null:
				# GLB had no usable MeshInstance3D — drop it before fallback.
				inst.queue_free()
			else:
				# v7.1 — Cel-shading + outline noir per bible §20. Apply
				# recursively so nested GLB sub-meshes get the silhouette too.
				CelShadingManager.apply_recursive(inst, {"outline_thickness": 0.008})
	if _plateau == null:
		_plateau = MeshInstance3D.new()
		_plateau.name = "Plateau"
		var plate := CylinderMesh.new()
		plate.top_radius = 2.6
		plate.bottom_radius = 2.4
		plate.height = 0.18
		plate.radial_segments = 56
		_plateau.mesh = plate
		_plateau.position = Vector3(0.0, 0.0, 0.0)
		# v7.4 — Procedural plateau picks color from BiomePalettes (bible §22 v3.4).
		# Uses the FIRST narrative slot of the palette (most structural / ground tone).
		var p_palette: Dictionary = BiomePalettes.get_palette(_biome_id)
		var plateau_color: Color = Color(0.30, 0.22, 0.14)  # safe fallback
		if not p_palette.is_empty():
			for k in p_palette.keys():
				if k != "accent" and k != "outline":
					plateau_color = p_palette[k]
					break
		var plat_mat := StandardMaterial3D.new()
		plat_mat.albedo_color = plateau_color
		plat_mat.roughness = 0.82
		plat_mat.metallic = 0.0
		plat_mat.emission_enabled = true
		plat_mat.emission = plateau_color * 0.30
		plat_mat.emission_energy_multiplier = 0.25
		_plateau.material_override = plat_mat
		add_child(_plateau)
		# v7.1 — Cel-shading + outline noir per bible §20 (marque de fabrique).
		CelShadingManager.apply(_plateau, {"outline_thickness": 0.008})

	# v7.7.8 — Plateau enrichment fires regardless of plateau source (biome
	# bundle, legacy glb, or procedural cylinder).
	# v7.7.16 — KayKit Mage guardian REMOVED per user request « enleve le mage
	# des scenes ». The _spawn_kaykit_guardian() + _spawn_glb_guardian() helper
	# functions stay in the file (dead code) for easy revert / future biome
	# guardian use, but the call is dropped.
	if _plateau != null:
		_build_plateau_enrichment()

	# Biome backdrop root
	_backdrop_root = Node3D.new()
	_backdrop_root.name = "Backdrop"
	add_child(_backdrop_root)

	# Token container (sits on top of plateau)
	_token_container = Node3D.new()
	_token_container.name = "Tokens"
	_token_container.position = Vector3(0.0, 0.10, 0.0)
	add_child(_token_container)

	# UI overlay — bare bones, ZERO theme, ZERO panel
	# CRITICAL: layer 110 puts the UI ABOVE the PSX/CRT post-process layer
	# (ScreenDither at layer 100). Otherwise the shader samples our text and
	# dithers it. Game text must stay crisp regardless of retro filters.
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 110
	add_child(_ui_layer)

	# Biome name top-left (large, no panel, white outlined)
	_biome_label = Label.new()
	_biome_label.name = "BiomeLabel"
	_biome_label.position = Vector2(40, 30)
	_biome_label.custom_minimum_size = Vector2(800, 60)
	_biome_label.add_theme_font_size_override("font_size", 38)
	_biome_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
	_biome_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_biome_label.add_theme_constant_override("outline_size", 6)
	_ui_layer.add_child(_biome_label)

	# Narration text — bottom center, large, no panel, sharp white outline
	_narration_label = Label.new()
	_narration_label.name = "NarrationLabel"
	_narration_label.anchor_left = 0.0
	_narration_label.anchor_right = 1.0
	_narration_label.anchor_top = 1.0
	_narration_label.anchor_bottom = 1.0
	_narration_label.offset_left = 80.0
	_narration_label.offset_right = -80.0
	_narration_label.offset_top = -180.0
	_narration_label.offset_bottom = -70.0
	_narration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_narration_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration_label.add_theme_font_size_override("font_size", 30)
	_narration_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.82))
	_narration_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_narration_label.add_theme_constant_override("outline_size", 8)
	_narration_label.text = ""
	_ui_layer.add_child(_narration_label)

	# Skip button — text only, bottom right
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.text = "passer ▶"
	_skip_button.flat = true
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.anchor_top = 1.0
	_skip_button.anchor_bottom = 1.0
	# v7.2 — QA HIGH 8.4 : SkipButton ≥44×44 px (bible §21.1 TACTILE).
	# Was 128×32 → now 144×56. Custom min size enforced as a fallback.
	_skip_button.offset_left = -176.0
	_skip_button.offset_right = -32.0
	_skip_button.offset_top = -76.0
	_skip_button.offset_bottom = -20.0
	_skip_button.custom_minimum_size = Vector2(120, 48)
	_skip_button.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78, 0.7))
	_skip_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78, 1.0))
	_skip_button.add_theme_font_size_override("font_size", 22)
	_skip_button.pressed.connect(_on_skip_pressed)
	_ui_layer.add_child(_skip_button)

	# v7.2 — QA HIGH 3.11 : Back/Retour button → MerlinCabinHub (bible §21.3).
	# Mirrors SkipButton on the LEFT side, always accessible during run.
	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "◀ retour"
	back_btn.flat = true
	back_btn.anchor_left = 0.0
	back_btn.anchor_right = 0.0
	back_btn.anchor_top = 1.0
	back_btn.anchor_bottom = 1.0
	back_btn.offset_left = 32.0
	back_btn.offset_right = 176.0
	back_btn.offset_top = -76.0
	back_btn.offset_bottom = -20.0
	back_btn.custom_minimum_size = Vector2(120, 48)
	back_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78, 0.7))
	back_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78, 1.0))
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back_pressed)
	_ui_layer.add_child(back_btn)


func _on_back_pressed() -> void:
	# v7.7.1 C1 — Abandon mid-run via the proper lifecycle. Direct change_scene_to_file
	# bypassed GameFlowController._on_board_narration_done(), leaving the phase machine
	# stuck in BOARD_NARRATION and rejecting all subsequent _on_run_requested calls.
	# Now we set outcome + emit narration_done so the controller routes to EndRunScreen
	# (which shows the "ABANDON" bilan) then back to Hub via hub_requested.
	if _save_system and _save_system.has_method("save_run_state"):
		_save_system.save_run_state(_store.state if _store else {})
	_outcome = "abandon"
	_run_data["reason"] = "abandon"
	_emit_done_once()


# ─── Dependencies & data ─────────────────────────────────────────────────────

func _resolve_dependencies() -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.get("save_system") != null:
		_save_system = store.save_system
	_merlin_ai = get_node_or_null("/root/MerlinAI")
	# v7.7.3b — autoload registered name is `GameFlow` (project.godot:46), not
	# `GameFlowController`. The old lookup never resolved → _flow_controller was
	# always null → narration_done emitted into void in non-failsafe paths.
	_flow_controller = get_node_or_null("/root/GameFlow")
	if _flow_controller == null:
		_flow_controller = get_node_or_null("/root/GameFlowController")  # legacy fallback
	if _flow_controller and _flow_controller.has_method("wire_board_narration"):
		_flow_controller.wire_board_narration(self)
	else:
		# v7.7.1 C3 — GameFlowController autoload absent (smoke test, dev-menu launch,
		# or corrupted project.godot). Without it, narration_done emits into the void
		# and the player is stranded on a finished plateau. Route to Hub directly.
		# We pick Hub over EndRunScreen because EndRunScreen depends on GameFlow.get_last_run_data()
		# which is also unavailable in this branch — would show a black screen anyway.
		if not narration_done.is_connected(_failsafe_to_hub):
			narration_done.connect(_failsafe_to_hub)


func _failsafe_to_hub() -> void:
	# v7.7.1 C3 failsafe target — see _resolve_dependencies.
	# v7.7.19 — Use PixelTransition fade for harmonized cross-scene transitions.
	if not is_inside_tree():
		return
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt != null and pt.has_method("transition_to"):
		pt.call("transition_to", "res://scenes/MerlinCabinHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MerlinCabinHub.tscn")


func _load_run_data() -> void:
	# Try both autoload names — project uses "GameFlow" but historical name was
	# "GameFlowController". get_node_or_null handles either.
	var flow: Node = get_node_or_null("/root/GameFlow")
	if flow == null:
		flow = get_node_or_null("/root/GameFlowController")
	if flow and flow.has_method("get_last_run_data"):
		var last: Dictionary = flow.get_last_run_data()
		if not last.is_empty():
			_run_data = last.duplicate(true)
			_outcome = str(last.get("reason", ""))
			return
	_store = get_node_or_null("/root/MerlinStore")
	if _store and _store.get("state") is Dictionary:
		var state: Dictionary = _store.state
		var run: Dictionary = state.get("run", {})
		var sl: Array = run.get("story_log", [])
		if run.has("story_log") and not sl.is_empty():
			_run_data = run.duplicate(true)
			_outcome = "ongoing"
			return
		# No story_log → enter LIVE CARD MODE if Store available and dispatchable.
		if _store.has_method("dispatch"):
			push_warning("[BoardNarration] live card mode active — fetching cards via LLM")
			_live_card_mode = true
			_run_data = {
				"current_biome": str(run.get("current_biome", "foret_broceliande")),
				"cards_played": 0,
				"life_essence": 100,
				"factions": run.get("factions", {}),
				"story_log": [],
			}
			# v7.7 Phase 2.1.9 — hydrate scenario_skeleton from Store if ScenarioLoading
			# wrote one before scene-changing back here. Makes the idempotency guard
			# in _on_biome_picked actually live (was dead code per code-review HIGH).
			if run.has("scenario_skeleton"):
				_run_data["scenario_skeleton"] = run.get("scenario_skeleton", {})
			if run.has("scenario_chosen_title"):
				_run_data["scenario_chosen_title"] = str(run.get("scenario_chosen_title", ""))
			_outcome = "live"
			return
	_run_data = BoardRunJournal.build_mock_run_data()
	_outcome = "smoke_mock"


# ─── Biome wiring ────────────────────────────────────────────────────────────

func _apply_biome_lighting() -> void:
	# Skip plateau material override when plateau comes from GLB — we want to
	# keep the carved-wood look. Only key light + env are biome-tinted.
	var plateau_for_ambience: MeshInstance3D = null  # null = skip plateau material
	BoardBiomeAmbience.apply_to_nodes(_biome_id, _key_light, _world_env.environment, plateau_for_ambience, null)
	if _key_light:
		_key_light.light_energy = maxf(_key_light.light_energy, 1.6)


func _build_biome_backdrop() -> void:
	BoardBiomeBackdrop.build_into(_backdrop_root, _biome_id)


func _populate_ui_header() -> void:
	var biome_name: String = _biome_id
	var spec: Dictionary = MerlinConstants.BIOMES.get(_biome_id, {})
	if not spec.is_empty():
		biome_name = str(spec.get("name", _biome_id))
	if _biome_label:
		_biome_label.text = biome_name


# ─── Figurines ───────────────────────────────────────────────────────────────

func _spawn_figurines() -> void:
	var story_log: Array = _run_data.get("story_log", [])
	if story_log.is_empty():
		return
	var count: int = story_log.size()
	for i in range(count):
		var raw = story_log[i]
		if not (raw is Dictionary):
			continue
		var entry: Dictionary = raw
		var ogham: String = str(entry.get("ogham_used", entry.get("ogham", "")))
		var card_id: String = str(entry.get("card_id", ""))
		var faction: String = _resolve_dominant_faction(entry.get("faction_deltas", {}))

		var token: SigleToken = SigleToken.new()
		token.name = "Figurine_%d" % i
		_token_container.add_child(token)
		var pos: Vector3 = _line_position(i, count)
		token.position = pos
		token.remember_base_y()
		token.setup(ogham, card_id, faction, _biome_id)
		token.animate_in(TOKEN_STAGGER_DELAY * float(i))
		token.rotation = Vector3(0, randf_range(-0.2, 0.2), 0)
		_tokens.append(token)


func _line_position(index: int, total: int) -> Vector3:
	if total <= 1:
		return Vector3(0, FIGURINE_Y, FIGURINE_LINE_Z)
	var t: float = float(index) / float(total - 1)
	var x: float = lerp(-FIGURINE_LINE_X_HALF, FIGURINE_LINE_X_HALF, t)
	return Vector3(x, FIGURINE_Y, FIGURINE_LINE_Z)


func _resolve_dominant_faction(deltas: Variant) -> String:
	if not (deltas is Dictionary):
		return ""
	var dict: Dictionary = deltas
	var best_key := ""
	var best_abs := 0.0
	for k in dict.keys():
		var val: float = abs(float(dict[k]))
		if val > best_abs:
			best_abs = val
			best_key = str(k)
	return best_key


# ─── Cinematic loop ──────────────────────────────────────────────────────────

func _run_cinematic() -> void:
	# Intro: slow camera tilt + lights ramp
	await _phase_intro()
	if _skip_requested:
		_phase_outro_then_done()
		return
	# Per-figurine narration
	for i in range(_tokens.size()):
		if _skip_requested:
			break
		_current_index = i
		await _phase_token(i)
	# Outro
	await _phase_outro()
	_finish()


func _phase_intro() -> void:
	# v7.7.15 — Dark room arrival per user request : « on arrive dans une salle
	# sombre, une lumière projetée arrive avec de nombreuses particules d'effets ».
	# Kill all lights at start so the player begins in actual darkness, then
	# ramp the spotlight up dramatically (the "projected light arrives") while
	# the camera dollies in. Particle burst from light cone happens here too.
	_camera.position = CAMERA_WIDE_POS + Vector3(0.0, 0.6, 2.6)
	if _spot_light != null:
		_spot_light.light_energy = 0.0
	if _key_light != null:
		_key_light.light_energy = 0.0
	if _fill_light != null:
		_fill_light.light_energy = 0.0
	# Brief moment of pure darkness before the spotlight ignites.
	await get_tree().create_timer(0.35).timeout
	# Spawn the particle burst when the light arrives.
	_spawn_arrival_particles()
	# Spotlight ramps first (the "projected light") — fast.
	var t := create_tween().set_parallel(true)
	t.tween_property(_spot_light, "light_energy", 1.4, 0.55) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Key + fill ramp slower (ambient fills in gradually after the spotlight punch).
	t.tween_property(_key_light, "light_energy", 2.0, INTRO_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.30)
	t.tween_property(_fill_light, "light_energy", 1.2, INTRO_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_delay(0.30)
	# Camera dolly in (same timing as before, just from further back).
	t.tween_property(_camera, "position", CAMERA_WIDE_POS, INTRO_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Subtle initial narration: biome title
	_narration_label.text = "…" + str(_biome_label.text) + "…"
	await get_tree().create_timer(INTRO_DURATION).timeout
	_narration_label.text = ""


## v7.7.15 — Spawn ~60 gold particle motes spiraling down from the spotlight
## position to the plateau center. Burst is one-shot, dies after 1.5s.
func _spawn_arrival_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ArrivalParticles"
	particles.amount = 60
	particles.lifetime = 1.4
	particles.one_shot = true
	particles.explosiveness = 0.65
	particles.position = Vector3(0.0, 3.4, 0.0)   # high above plateau (spotlight source)
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0.0, -1.2, 0.0)
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.2
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.spread = 45.0
	pm.scale_min = 0.04
	pm.scale_max = 0.10
	pm.color = Color(0.95, 0.82, 0.35)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	particles.process_material = pm
	# Use a simple BoxMesh as the particle's draw mesh (lightweight, cel-friendly).
	var draw_mesh := BoxMesh.new()
	draw_mesh.size = Vector3(0.06, 0.06, 0.06)
	particles.draw_pass_1 = draw_mesh
	add_child(particles)
	# Auto-cleanup after lifetime + small buffer.
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _phase_token(index: int) -> void:
	if index < 0 or index >= _tokens.size():
		return
	var token: SigleToken = _tokens[index] as SigleToken
	if token == null:
		return

	# Move camera close to the figurine
	var target: Vector3 = token.position
	var cam_target_pos: Vector3 = target + CAMERA_CLOSE_OFFSET
	var dolly := create_tween().set_parallel(true)
	dolly.tween_property(_camera, "position", cam_target_pos, CAMERA_DOLLY_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Spotlight moves to figurine
	dolly.tween_property(_spot_light, "position", target + Vector3(0, 2.8, 0.3), CAMERA_DOLLY_TIME).set_trans(Tween.TRANS_SINE)
	# Look_at after dolly settles — do via incremental tween_method on rotation
	dolly.tween_method(_camera_look_at, _camera.global_transform.basis.get_euler(), _euler_to_target(cam_target_pos, target + Vector3(0, 0.15, 0)), CAMERA_DOLLY_TIME)

	# Dim previous, highlight current
	if index > 0:
		var prev: SigleToken = _tokens[index - 1] as SigleToken
		if prev:
			prev.dim_to_idle()
	token.highlight()
	# Spawn / cross-fade the totem animal cameo next to this figurine.
	_spawn_cameo(token)

	await get_tree().create_timer(CAMERA_DOLLY_TIME).timeout
	if _skip_requested:
		return

	# Spotlight punch
	var punch := create_tween()
	punch.tween_property(_spot_light, "light_energy", 4.0, 0.5).set_trans(Tween.TRANS_QUAD)

	# Begin narration in parallel with camera settle
	var story_log: Array = _run_data.get("story_log", [])
	var entry: Dictionary = story_log[index] if index < story_log.size() and story_log[index] is Dictionary else {}
	var ogham: String = str(entry.get("ogham_used", entry.get("ogham", "")))
	var comment: String = await _request_llm_comment(entry, index, _tokens.size())
	var source := "llm"
	if comment.is_empty():
		comment = _fallback_comment(ogham)
		source = "fallback"
	_narrations.append({"card_id": str(entry.get("card_id", "")), "comment": comment, "source": source})

	# Typewriter reveal (skippable via _skip_requested)
	await _typewriter(comment)
	if _skip_requested:
		return

	# Hold beat
	var remaining: float = PER_TOKEN_DURATION - CAMERA_DOLLY_TIME - 0.5 - (float(comment.length()) / TYPEWRITER_CPS)
	if remaining > 0.0:
		await get_tree().create_timer(maxf(remaining, 0.5)).timeout


func _spawn_cameo(token: SigleToken) -> void:
	# Fade out + free previous cameo.
	if _current_cameo and is_instance_valid(_current_cameo):
		var prev := _current_cameo
		_current_cameo = null
		var fade_out := create_tween()
		fade_out.tween_property(prev, "scale", Vector3.ZERO, CAMEO_FADE_TIME).set_trans(Tween.TRANS_SINE)
		fade_out.tween_callback(prev.queue_free)
	# Load the animal GLB for this token's faction.
	var glb_path: String = str(ANIMAL_CAMEO_BY_FACTION.get(token.faction, ""))
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		return
	var packed: PackedScene = load(glb_path) as PackedScene
	if packed == null:
		return
	var cameo: Node3D = packed.instantiate() as Node3D
	if cameo == null:
		return
	cameo.name = "Cameo_" + token.faction
	# Position to the right of the token, on the plateau surface.
	cameo.position = token.position + CAMEO_OFFSET
	cameo.scale = Vector3.ZERO
	# Orient slightly toward the camera (rotate Y a bit).
	cameo.rotation = Vector3(0, deg_to_rad(-25.0), 0)
	add_child(cameo)
	_current_cameo = cameo
	# Animate scale-in.
	var fade_in := create_tween()
	fade_in.tween_property(cameo, "scale", Vector3.ONE * 0.5, CAMEO_FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _phase_outro() -> void:
	# Camera pulls back wide, lights restore, spotlight cool
	if _tokens.size() > 0:
		var last: SigleToken = _tokens[_tokens.size() - 1] as SigleToken
		if last:
			last.dim_to_idle()
	# Fade out the cameo if still present.
	if _current_cameo and is_instance_valid(_current_cameo):
		var c := _current_cameo
		_current_cameo = null
		var fade_t := create_tween()
		fade_t.tween_property(c, "scale", Vector3.ZERO, CAMEO_FADE_TIME)
		fade_t.tween_callback(c.queue_free)
	var t := create_tween().set_parallel(true)
	t.tween_property(_camera, "position", CAMERA_WIDE_POS, OUTRO_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(_camera_look_at, _camera.global_transform.basis.get_euler(), _euler_to_target(CAMERA_WIDE_POS, CAMERA_WIDE_TARGET), OUTRO_DURATION)
	t.tween_property(_spot_light, "light_energy", 0.3, OUTRO_DURATION).set_trans(Tween.TRANS_SINE)
	_narration_label.text = "…"
	await get_tree().create_timer(OUTRO_DURATION).timeout


func _phase_outro_then_done() -> void:
	# Called when skip pressed mid-flow.
	_narration_label.text = "…"
	await get_tree().create_timer(0.6).timeout
	_finish()


func _finish() -> void:
	_skip_button.disabled = true
	_skip_button.visible = false
	_tr_record({"evenement": "fin_run", "issue": _outcome,
		"anam_gagne": _run_anam_earned, "hud": _tr_hud_snapshot()})
	_tr_flush()
	var entry: Dictionary = BoardRunJournal.build_entry(_run_data, _narrations, _outcome)
	if _save_system:
		BoardRunJournal.save_to_profile(_save_system, entry)
	push_warning("[BoardNarration] done — %d figurines, %d narrations, outcome=%s" % [_tokens.size(), _narrations.size(), _outcome])
	# IMPORTANT: do NOT restore overlays here. _finish() runs while the scene is
	# still alive — restoring MerlinBackdrop would put a fullscreen black ColorRect
	# back on top of the 3D rendering. Overlays are restored in _exit_tree() when
	# the scene actually leaves the tree (via change_scene_to_file from the flow
	# controller, OR when the user closes the standalone demo window).
	_emit_done_once()


func _exit_tree() -> void:
	# Final restore — fires when the scene leaves the tree for good.
	_restore_psx_filter()
	_restore_global_overlays()
	# v7.7.9 — Disconnect MerlinStats autoload signals so we don't leak handler
	# refs across scene reloads (code-review HIGH-1 fix).
	var stats_node: Node = Engine.get_main_loop().root.get_node_or_null("MerlinStats")
	if stats_node != null:
		if stats_node.has_signal("stat_changed") and stats_node.stat_changed.is_connected(_on_disco_stat_changed):
			stats_node.stat_changed.disconnect(_on_disco_stat_changed)
		if stats_node.has_signal("level_up") and stats_node.level_up.is_connected(_on_disco_level_up):
			stats_node.level_up.disconnect(_on_disco_level_up)


# ════════════════════════════════════════════════════════════════════════
# LIVE GAME MODE — Card UI + game loop driven by MerlinStore + LLM
# ════════════════════════════════════════════════════════════════════════

## Build the card overlay UI : centred card panel with LLM-generated card
## text + up to 3 option buttons. Sits on top of the PSX post-process
## (layer 110 like the rest of the UI).
func _build_card_overlay() -> void:
	_card_overlay = Control.new()
	_card_overlay.name = "CardOverlay"
	_card_overlay.anchor_left = 0.0
	_card_overlay.anchor_right = 1.0
	_card_overlay.anchor_top = 0.0
	_card_overlay.anchor_bottom = 1.0
	_card_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_ui_layer.add_child(_card_overlay)

	# Backdrop dim panel — v5.1 : much lighter so the 3D plateau (with breathing
	# lights + volumetric fog + figurines + dice) stays visible behind the parchemin.
	# Per user feedback (2026-05-14 part 8) : "le plateau qu'on a animé est masqué".
	# Only the BOTTOM 40% gets a slight dim to seat the parchemin visually.
	var dim := ColorRect.new()
	dim.name = "DimBackdrop"
	dim.color = Color(0.0, 0.0, 0.0, 0.18)  # was 0.45 — let the plateau breathe
	dim.anchor_right = 1.0
	dim.anchor_top = 0.55
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_overlay.add_child(dim)

	# Card panel — v5.1 : anchored to BOTTOM 40% of screen (was centered 50/50).
	# Plateau visible top 60%. Boss grow logic (_apply_act_styling) extends this
	# to top 30% on boss acts for the climactic 70% take-over.
	var card_panel := Panel.new()
	card_panel.name = "CardPanel"
	card_panel.anchor_left = 0.04
	card_panel.anchor_right = 0.96
	card_panel.anchor_top = 0.60
	card_panel.anchor_bottom = 0.98
	card_panel.offset_left = 0
	card_panel.offset_right = 0
	card_panel.offset_top = 0
	card_panel.offset_bottom = 0
	# Parchment style : aged cream paper + sepia ink + wood-frame borders.
	# Per worldbuilding agent : "Le parchemin est une voix, pas une UI."
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.92, 0.86, 0.68, 0.97)  # aged cream
	panel_style.border_color = Color(0.30, 0.20, 0.12, 1.0)  # dark wood
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(24)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 8
	card_panel.add_theme_stylebox_override("panel", panel_style)
	_card_overlay.add_child(card_panel)

	# Card header badge — title (small caps) + Ogham glyph on the right.
	_card_badge_label = RichTextLabel.new()
	_card_badge_label.name = "CardBadge"
	_card_badge_label.bbcode_enabled = true
	_card_badge_label.fit_content = false
	_card_badge_label.scroll_active = false
	_card_badge_label.anchor_left = 0.0
	_card_badge_label.anchor_right = 1.0
	_card_badge_label.anchor_top = 0.0
	_card_badge_label.anchor_bottom = 0.0
	_card_badge_label.offset_left = 24
	_card_badge_label.offset_right = -24
	_card_badge_label.offset_top = 8
	_card_badge_label.offset_bottom = 44
	_card_badge_label.add_theme_font_size_override("normal_font_size", 18)
	_card_badge_label.add_theme_color_override("default_color", Color(0.30, 0.20, 0.12))
	_card_badge_label.text = "[b][color=#3a2410]…[/color][/b]"
	card_panel.add_child(_card_badge_label)

	# Card text label (LLM-generated narrative — sepia ink on parchment)
	_card_text_label = RichTextLabel.new()
	_card_text_label.name = "CardText"
	_card_text_label.bbcode_enabled = true
	_card_text_label.fit_content = false
	_card_text_label.scroll_active = false
	_card_text_label.anchor_left = 0.0
	_card_text_label.anchor_right = 1.0
	_card_text_label.anchor_top = 0.0
	_card_text_label.anchor_bottom = 0.5
	_card_text_label.offset_left = 24
	_card_text_label.offset_right = -24
	_card_text_label.offset_top = 56
	_card_text_label.offset_bottom = 0
	_card_text_label.add_theme_font_size_override("normal_font_size", 22)
	_card_text_label.add_theme_color_override("default_color", Color(0.28, 0.18, 0.10))  # sepia ink
	_card_text_label.text = "[i]La rune s'éveille…[/i]"
	card_panel.add_child(_card_text_label)

	# 3 option buttons in vertical stack (bottom half of panel)
	var buttons_box := VBoxContainer.new()
	buttons_box.name = "Options"
	buttons_box.anchor_left = 0.0
	buttons_box.anchor_right = 1.0
	buttons_box.anchor_top = 0.5
	buttons_box.anchor_bottom = 1.0
	buttons_box.offset_left = 24
	buttons_box.offset_right = -24
	buttons_box.offset_top = 8
	buttons_box.offset_bottom = -16
	buttons_box.add_theme_constant_override("separation", 8)
	card_panel.add_child(buttons_box)

	_card_option_buttons.clear()
	for i in range(3):
		var btn := Button.new()
		btn.name = "Option_%d" % i
		btn.text = ""
		btn.flat = false
		btn.disabled = true
		btn.visible = false
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 18)
		# Parchment ink option style : transparent bg with sepia underline on hover.
		var opt_sb := StyleBoxFlat.new()
		opt_sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		opt_sb.border_color = Color(0.30, 0.20, 0.12, 0.6)
		opt_sb.border_width_bottom = 1
		opt_sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", opt_sb)
		var opt_hover: StyleBoxFlat = opt_sb.duplicate()
		opt_hover.bg_color = Color(0.30, 0.20, 0.12, 0.10)
		opt_hover.border_width_bottom = 2
		opt_hover.border_color = Color(0.30, 0.20, 0.12, 1.0)
		btn.add_theme_stylebox_override("hover", opt_hover)
		btn.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10))
		btn.add_theme_color_override("font_hover_color", Color(0.10, 0.05, 0.02))
		var idx := i  # capture for lambda
		btn.pressed.connect(func() -> void: _on_card_option_pressed(idx))
		buttons_box.add_child(btn)
		_card_option_buttons.append(btn)


## Main live game loop — 5-act rogue-like sequence.
## ACT_SEQUENCE = [standard, shop, standard, event, boss] (see top of file).
## Each act fetches a card filtered by `act_type` from the fallback pool (LLM-first).
func _run_live_loop() -> void:
	# v6.2 — Parchemin overlay is queue_freed in _open_live_card_mode, so
	# _card_text_label is null in live mode. Skip the legacy text write.
	if _card_text_label and is_instance_valid(_card_text_label):
		_card_text_label.text = "[i]La forêt respire…[/i]"
	await get_tree().create_timer(2.0).timeout
	# Start a fresh run.
	if _store == null or not _store.has_method("dispatch"):
		# v7.7.1 C2 — Don't strand the player on a frozen plateau. Emit narration_done
		# with outcome=error so the controller (or failsafe in C3) routes elsewhere.
		push_warning("[BoardNarration] live mode aborted — Store dispatch unavailable")
		_outcome = "error"
		_run_data["reason"] = "error"
		_finish()
		return
	var start_action: Dictionary = {"type": "START_RUN", "biome": _biome_id}
	var start_res = await _store.dispatch(start_action)
	if start_res is Dictionary and not bool(start_res.get("ok", false)):
		push_warning("[BoardNarration] START_RUN rejected: %s" % str(start_res))
	_live_run_active = true
	_run_anam_earned = 0
	_active_modifier = ""

	# Transcript opt-in (MERLIN_TRANSCRIPT=<chemin.json>) — QA / revue de design.
	_transcript_path = OS.get_environment("MERLIN_TRANSCRIPT")
	_transcript.clear()
	_tr_record({"evenement": "debut_run", "biome": _biome_id, "hud": _tr_hud_snapshot()})

	var act_seq: Array = _act_sequence()
	var total_acts: int = act_seq.size()
	for act_idx in range(total_acts):
		if _skip_requested:
			break
		var act_type: String = str(act_seq[act_idx])
		# v5.2 — track current act for the "Carte X / 5" HUD label.
		_live_acts_played = act_idx
		_refresh_hud()
		# Animate the act indicator (top-center, color-coded by type).
		JuiceHelpers.update_act_indicator(self, _hud_act_label, act_idx, total_acts, act_type)
		_live_pending_choice = -1
		# v6.1 — Hide the legacy parchemin overlay 2D throughout the live loop.
		# All card text/options now display on the LiveCard3D (Hand of Fate style).
		# The parchemin overlay is only kept for cinematic fallback path.
		if _card_overlay:
			_card_overlay.visible = false
		for b in _card_option_buttons:
			(b as Button).visible = false
			(b as Button).disabled = true

		# Fetch a card filtered to this act type (LLM first, fallback pool filtered).
		var card: Dictionary = await _fetch_card_for_act(act_type)
		push_warning("[BoardNarration] carte %d/%d (%s) : %s" % [
			act_idx + 1, total_acts, act_type, str(card.get("id", "?"))])
		if card.is_empty() or not card.has("options"):
			if _card_text_label and is_instance_valid(_card_text_label):
				_card_text_label.text = "[i]Le silence répond à l'appel. Aucune carte ne vient.[/i]"
			await get_tree().create_timer(3.0).timeout
			break
		_live_current_card = card

		# Transcript : ce que le joueur a sous les yeux avant de choisir.
		if not _transcript_path.is_empty():
			var opts_vues: Array = []
			for o in (card.get("options", []) as Array):
				var od: Dictionary = o as Dictionary
				opts_vues.append({
					"label": str(od.get("label", "")),
					"verbe": str(od.get("verb", "")),
					"gradient": str(od.get("gradient", "")),
					"faction": str(od.get("primary_faction", "")),
					"epreuve_telegraphiee": (od.get("check", {}) as Dictionary).duplicate(true),
					"effets_caches": (od.get("effects", []) as Array).duplicate(true),
				})
			_tr_record({
				"evenement": "carte_affichee",
				"acte_index": act_idx + 1,
				"acte_type_demande": act_type,
				"acte_type_servi": str(card.get("act_type", "standard")),
				"carte_id": str(card.get("id", "")),
				"texte": str(card.get("text", card.get("prompt", ""))),
				"dialogue_merlin": str(card.get("dialogue", "")),
				"options_visibles": opts_vues,
				"hud": _tr_hud_snapshot(),
			})

		# v5.2 — Visual "pioche" : the top card of the 3D deck lifts, rotates,
		# flies toward the camera, fades — THEN the parchemin overlay appears.
		# Per user feedback : "il manque toujours la présence du tirage de carte".
		if _card_deck and is_instance_valid(_card_deck):
			# v5.3 — draw sound (low pitch UI cue).
			var sfx: Node = get_node_or_null("/root/SFXManager")
			if sfx and sfx.has_method("play"):
				sfx.play("button_appear", 0.65)
			await _card_deck.draw_top_card()

		# v6 — Hand of Fate : la carte 3D devient le porteur du scénario + options.
		# Plus de parchemin overlay 2D — tout est sur la carte 3D.
		# Per user feedback (2026-05-14 part 14).
		await _show_live_card_3d(card)

		# Wait for user click on a 3D card option (autoplay : auto-pick 0 after 4s).
		var autoplay := OS.get_environment("MERLIN_AUTOPLAY") == "1"
		var click_deadline_ms := 4_000 if autoplay else 60_000
		var click_deadline := Time.get_ticks_msec() + click_deadline_ms
		while _live_pending_choice < 0 and not _skip_requested and Time.get_ticks_msec() < click_deadline:
			await get_tree().create_timer(0.1).timeout
			_sync_floating_buttons_to_card_3d()
		if _skip_requested:
			break
		if _live_pending_choice < 0:
			# Timeout — choix automatique (suite imposee, sinon option 0).
			_on_card_option_pressed(_autoplay_pick(act_idx))
			await get_tree().create_timer(0.6).timeout
		# Fly the 3D card to the marker where the new pion will spawn,
		# then queue_free it. The pion's drop animation starts after.
		if _live_card_3d and is_instance_valid(_live_card_3d):
			var marker_preview: Vector3 = _get_next_marker_position_preview()
			await _live_card_3d.fly_to_marker(marker_preview)
			_live_card_3d = null
		_clear_floating_option_buttons()

		# Apply Anam reward if boss card. Now AWAITS — physical dice roll
		# takes ~3s to settle (v5). The player sees the dice tumble before
		# the boss reveals success/failure.
		if act_type == "boss":
			await _resolve_boss_anam(card, _live_pending_choice)

		# ── L'EPREUVE ──────────────────────────────────────────────────────
		# Sur un scenario scripte, l'option porte un `check` : on le resout AVANT
		# d'appliquer les effets. Reussite -> les effets declares. Echec -> aucun
		# gain, et les degats d'echec. C'est ce qui donne son sens au gradient
		# prudente/equilibree/audacieuse (bible §26).
		var chosen_pre: Dictionary = {}
		var opts_pre: Array = card.get("options", [])
		if _live_pending_choice >= 0 and _live_pending_choice < opts_pre.size():
			chosen_pre = opts_pre[_live_pending_choice] as Dictionary
		var epreuve: Dictionary = {}
		if not _scripted_cards.is_empty() and not chosen_pre.is_empty():
			epreuve = _resolve_scripted_check(chosen_pre)

		# Resolve the chosen option through the Store. Un echec d'epreuve annule
		# les gains : on n'envoie que les degats.
		var resolve_action: Dictionary = {
			"type": "RESOLVE_CHOICE",
			"card": card,
			"option": _live_pending_choice,
			"modulated_effects": [],
		}
		if not epreuve.is_empty() and not bool(epreuve.get("succes", true)):
			resolve_action["modulated_effects"] = [
				{"type": "DAMAGE_LIFE", "amount": int(epreuve.get("degats", 0))},
			]
		var res = await _store.dispatch(resolve_action)
		_live_cards_played += 1

		var hud_apres_choix: Dictionary = _tr_hud_snapshot()

		# ── LA RESOLUTION ──────────────────────────────────────────────────
		# v7.7.28 — le beat qui manquait. Le joueur choisissait, et il ne se
		# passait rien : la carte suivante arrivait sans rapport, comme si son
		# geste n'avait pas eu lieu. On raconte desormais ce qui se produit et
		# ce que cela apporte, avant de passer a la suite. Les chiffres restent
		# hors du texte : l'effet doit se lire dans la scene.
		var chosen_opt: Dictionary = {}
		var opts_for_outcome: Array = card.get("options", [])
		if _live_pending_choice >= 0 and _live_pending_choice < opts_for_outcome.size():
			chosen_opt = opts_for_outcome[_live_pending_choice] as Dictionary
		var outcome_text: String = str(chosen_opt.get("outcome", ""))
		var outcome_source: String = "pool"
		if not epreuve.is_empty():
			var res_txt: Dictionary = _scripted_outcome_text(
				chosen_opt, bool(epreuve.get("succes", true)))
			outcome_text = str(res_txt.get("texte", outcome_text))
			outcome_source = str(res_txt.get("source", ""))
		if outcome_text != "" and not _skip_requested:
			if _narration_label:
				_narration_label.visible = true
			await _typewriter_narration(outcome_text)
			await get_tree().create_timer(1.4).timeout

		# Capture shop modifier for the next 2 acts.
		if act_type == "shop":
			_capture_shop_modifier(card, _live_pending_choice)

		# v5.1 — Dé du destin : roll the physical dice after each non-boss card.
		# If any die rolls a 6 → +1 random faction; if any rolls a 1 → -1.
		# Makes the dice meaningful on every act, not just the boss climax.
		# Per user feedback (2026-05-14 part 8) : "Dé du destin à chaque carte".
		if act_type != "boss":
			await _roll_fate_dice()

		# Transcript : le choix retenu et ce que le moteur en a fait.
		if not _transcript_path.is_empty():
			var opt_idx: int = _live_pending_choice
			var opts_arr: Array = card.get("options", [])
			var chosen: Dictionary = {}
			if opt_idx >= 0 and opt_idx < opts_arr.size():
				chosen = opts_arr[opt_idx] as Dictionary
			_tr_record({
				"evenement": "resolution",
				"acte_index": act_idx + 1,
				"option_choisie": opt_idx,
				"label_choisi": str(chosen.get("label", "")),
				"gradient": str(chosen.get("gradient", "")),
				"faction_option": str(chosen.get("primary_faction", "")),
				"epreuve": epreuve,
				"texte_resolution": outcome_text,
				"source_resolution": outcome_source,
				"effets_declares": (chosen.get("effects", []) as Array).duplicate(true),
				"effets_appliques": (resolve_action.get("modulated_effects", []) as Array
					if not (resolve_action.get("modulated_effects", []) as Array).is_empty()
					else (chosen.get("effects", []) as Array)),
				"reponse_store": (res if res is Dictionary else {}),
				"hud_apres_choix": hud_apres_choix,
				"hud_apres_des_du_destin": _tr_hud_snapshot(),
				"modificateur_marchand_actif": _active_modifier,
			})

		# Spawn a SigleToken on the plateau for the resolved card.
		_spawn_live_token(card, _live_pending_choice, act_idx)

		# v7.0 — Grow discard pile : hauteur ∝ cartes jouées (GAME_DESIGN_BIBLE §19.3).
		if _discard_pile and is_instance_valid(_discard_pile):
			_discard_pile.add_card()

		# Brief hold before next card.
		await get_tree().create_timer(1.5).timeout

		# v5.3 — Death check : if life ≤ 0, interrupt the run with an epilogue.
		# Anam earned is halved (consolation prize). Boss reward is 0 if death
		# happened before Act 5. Per user feedback (2026-05-14 part 10) :
		# "Death = stop run + epilogue + Anam réduit".
		var current_life: int = 100
		if _store and _store.get("state") is Dictionary:
			current_life = int(_store.state.get("run", {}).get("life_essence", 100))
		if current_life <= 0:
			# v7.2 QA MEDIUM 6.12 : removed 0.5 halving (was double-penalty stacked
			# with store_run.gd:399 min(cards/30, 1.0) ratio per bible §16.1).
			# v7.7.10 — Death anim (red vignette + camera pull-back + SFX) BEFORE
			# the narration timer so the player sees the punctuation, not just text.
			_play_death_anim()
			if _card_text_label and is_instance_valid(_card_text_label):
				_card_text_label.text = "[i]Tu t'effondres sur la mousse. Brocéliande se referme sur ton souffle. Tu emportes %d Anam.[/i]" % _run_anam_earned
			elif _floating_fx_layer:
				JuiceHelpers.spawn_floating_label_arc(
					self, _floating_fx_layer,
					"Tu t'effondres. +%d Anam" % _run_anam_earned,
					Color(0.96, 0.78, 0.25),
					Vector2(540, 360), 0.0
				)
			for b in _card_option_buttons:
				(b as Button).visible = false
			await get_tree().create_timer(4.0).timeout
			if _card_overlay:
				_card_overlay.visible = false
			_finish()
			return  # exit the run loop — death is final

		# If run ended via store flag, stop.
		if res is Dictionary and bool(res.get("run_ended", false)):
			break

	# v6.2 — End of live run outro. The parchemin is gone in live mode (queue_freed
	# after incantation), so route narration to a floating label instead.
	var outro_text: String = (
		"La forêt se referme. Tu emportes %d Anam." % _run_anam_earned
		if _run_anam_earned > 0
		else "La forêt se referme. Ta trace reste sur le plateau."
	)
	if _card_text_label and is_instance_valid(_card_text_label):
		_card_text_label.text = "[i]%s[/i]" % outro_text
	elif _floating_fx_layer:
		JuiceHelpers.spawn_floating_label_arc(
			self, _floating_fx_layer,
			outro_text,
			Color(0.96, 0.92, 0.74),
			Vector2(640, 320), 0.0
		)
	for b in _card_option_buttons:
		if is_instance_valid(b):
			(b as Button).visible = false
	await get_tree().create_timer(3.0).timeout
	# Hide overlay so the plateau shows in full.
	if _card_overlay:
		_card_overlay.visible = false
	_finish()


const LIVE_TYPEWRITER_CPS := 22.0
## Rogue-like 5-act sequence — deterministic positions so the player learns the rhythm.
## Standard cards stay backward-compatible (act_type defaults to "standard").
## v7.7.29 — n'est plus qu'un DEFAUT : un scenario scripte impose sa propre
## longueur (11/15/17/21/25, bible §31.1) via `_scripted_act_seq`.
const ACT_SEQUENCE := ["standard", "shop", "standard", "event", "boss"]

# ── Scenario scripte (opt-in) ────────────────────────────────────────────────
# MERLIN_SCENARIO=<res://...json> fait jouer un scenario LINEAIRE ecrit d'avance
# au lieu de piocher dans le pool. C'est le mode qui rend un scenario type
# jouable de bout en bout : longueur variable, epreuves de stats resolues,
# resolutions narrees, variantes conditionnees par l'etat accumule (bible §32).
## CardType d'un scenario -> act_type du moteur.
const SCENARIO_TYPE_TO_ACT := {
	"NARRATIVE": "standard", "PROMISE": "standard", "RUNE_UNLOCK": "standard",
	"SHOP": "shop", "EVENT": "event", "MERLIN_DIRECT": "boss",
}
var _scripted_scenario: Dictionary = {}
var _scripted_cards: Array = []
var _scripted_act_seq: Array = []
var _scripted_rng := RandomNumberGenerator.new()
var _card_badge_label: RichTextLabel = null
var _hud_life_bar: ProgressBar = null
var _hud_life_value_label: Label = null
var _hud_faction_labels: Dictionary = {}  # faction_key → Label (kept empty in v5.2)
var _hud_act_label: Label = null
var _hud_stat_strip: HBoxContainer = null
var _hud_anam_label: Label = null            # v5.2 : Anam cumulé top-left
var _hud_card_count_label: Label = null      # v5.2 : "Carte X / 5" top-right
## v7.7.9 — Disco-style 4-stat HUD (bible v3.6 §25-§26).
## 4 stacked labels top-right under Carte X/Y, format "[ICON] Logic L3 80%".
## Updated via MerlinStats.stat_changed signal ; level_up triggers toast.
var _hud_stat_labels: Dictionary = {}        # stat_name → Label
var _hud_level_toast: Label = null            # transient level_up notification
var _live_acts_played: int = 0                # for card count display
var _floating_fx_layer: Control = null
var _last_ambient_variant: String = ""        # v5.5 : last faction ambient played (de-bounce)
var _shown_cameo_factions: Dictionary = {}    # v5.6 : faction → bool (one cameo per run per faction)
# Previous-value caches for HUD ticker animation (fire only on real delta).
var _hud_prev_life: int = 100
var _hud_prev_rep: Dictionary = {}
# Active shop modifier carried Acts 3-4.
var _active_modifier: String = ""
# Anam earned this run (boss reward).
var _run_anam_earned: int = 0

# ── Transcript de run (opt-in, QA / revue de design) ─────────────────────────
# Active par la variable d'environnement MERLIN_TRANSCRIPT=<chemin.json>.
# Enregistre, carte par carte, TOUT ce que le joueur voit et ce que le moteur
# resout derriere : etat du HUD, texte et options de la carte, choix retenu,
# effets appliques, des du destin, modificateur de marchand, recompenses.
# Zero cout quand la variable n'est pas definie.
var _transcript_path: String = ""
var _transcript: Array = []


## Instantane de tout ce que le joueur peut lire a l'ecran a l'instant t.
func _tr_hud_snapshot() -> Dictionary:
	if _store == null or not (_store.get("state") is Dictionary):
		return {}
	var state: Dictionary = _store.state
	var run: Dictionary = state.get("run", {})
	var meta: Dictionary = state.get("meta", {})
	var total_acts: int = _act_sequence().size()
	return {
		"vie": int(run.get("life_essence", 100)),
		"anam_affiche": int(meta.get("anam", 0)) + _run_anam_earned,
		"compteur_cartes": "Carte %d / %d" % [
			clampi(_live_acts_played + 1, 1, total_acts), total_acts],
		"factions_backend": (meta.get("faction_rep", {}) as Dictionary).duplicate(true),
		"tags_actifs": (run.get("active_tags", []) as Array).duplicate(),
		"promesses_actives": (run.get("active_promises", []) as Array).size(),
		"scenario_actif": str(run.get("active_scenario", "")),
		"modificateur_marchand": _active_modifier,
	}


# ── Scenario scripte : chargement, conversion, epreuves ──────────────────────

## Sequence d'actes effective : celle du scenario scripte, sinon le defaut a 5.
func _act_sequence() -> Array:
	return _scripted_act_seq if not _scripted_act_seq.is_empty() else ACT_SEQUENCE


## Charge le scenario designe par MERLIN_SCENARIO. Sans effet si la variable
## n'est pas definie ou si le fichier est illisible : on retombe sur le pool.
func _load_scripted_scenario() -> void:
	var path: String = OS.get_environment("MERLIN_SCENARIO")
	if path.is_empty():
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("[BoardNarration] scenario scripte introuvable : %s" % path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	var scen: Dictionary = {}
	if parsed is Array and (parsed as Array).size() > 0:
		scen = (parsed as Array)[0] as Dictionary
	elif parsed is Dictionary:
		scen = parsed as Dictionary
	if scen.is_empty() or not scen.has("cards"):
		push_warning("[BoardNarration] scenario scripte illisible : %s" % path)
		return
	_scripted_scenario = scen
	_scripted_cards = (scen.get("cards", []) as Array).duplicate(true)
	_scripted_act_seq.clear()
	for c in _scripted_cards:
		var ct: String = str((c as Dictionary).get("type", "NARRATIVE"))
		_scripted_act_seq.append(str(SCENARIO_TYPE_TO_ACT.get(ct, "standard")))
	var seed_env: String = OS.get_environment("MERLIN_SEED")
	if seed_env.is_valid_int():
		_scripted_rng.seed = int(seed_env)
		push_warning("[BoardNarration] epreuves graine %s (run reproductible)" % seed_env)
	else:
		_scripted_rng.randomize()
	push_warning("[BoardNarration] scenario scripte charge : « %s » — %d cartes" % [
		str(scen.get("title", "?")), _scripted_cards.size()])


## Niveau d'une stat (1 au premier run). MerlinStats est optionnel.
func _stat_level(stat_name: String) -> int:
	var stats: Node = get_node_or_null("/root/MerlinStats")
	if stats and stats.has_method("get_level"):
		return maxi(1, int(stats.call("get_level", stat_name)))
	return 1


## Resout l'epreuve d'une option : pass_chance = 50% + 10% x stat (bible §26.1).
## Retourne {succes, stat, niveau, chance, jet, degats}.
func _resolve_scripted_check(opt: Dictionary) -> Dictionary:
	var ck: Dictionary = opt.get("check", {}) as Dictionary
	if ck.is_empty():
		return {"succes": true, "stat": "", "niveau": 0, "chance": 1.0, "jet": 0.0, "degats": 0}
	var stat_name: String = str(ck.get("stat", "volonte"))
	var level: int = _stat_level(stat_name)
	var chance: float = clampf(0.50 + 0.10 * float(level), 0.0, 1.0)
	var roll: float = _scripted_rng.randf()
	var success: bool = roll < chance
	return {
		"succes": success, "stat": stat_name, "niveau": level,
		"chance": chance, "jet": roll,
		"type": str(ck.get("type", "white")),
		"degats": 0 if success else int(ck.get("fail_damage", 0)),
	}


## La resolution a raconter. En cas d'echec on lit `outcome_fail` ; en cas de
## reussite, la variante d'etat si sa condition est remplie, sinon `outcome`.
## C'est ici que vit le branchement narratif (bible §31.3) : meme carte, meme
## option, texte different selon ce que le joueur traine derriere lui.
func _scripted_outcome_text(opt: Dictionary, success: bool) -> Dictionary:
	if not success:
		var fail_text: String = str(opt.get("outcome_fail", ""))
		if fail_text != "":
			return {"texte": fail_text, "source": "echec"}
		return {"texte": str(opt.get("outcome", "")), "source": "echec_sans_texte"}
	var state: Dictionary = _store.state if _store and (_store.get("state") is Dictionary) else {}
	var run: Dictionary = state.get("run", {})
	var tags: Array = run.get("active_tags", []) as Array
	# Une promesse rompue reste dans `active_promises` avec status = "broken"
	# (store_run.check_promise_deadlines) — c'est la qu'on la lit.
	var broken: Array = []
	for p in (run.get("active_promises", []) as Array):
		var pd: Dictionary = p as Dictionary
		if str(pd.get("status", "")) == "broken":
			broken.append(str(pd.get("id", "")))
	for v in (opt.get("outcome_variants", []) as Array):
		var vd: Dictionary = v as Dictionary
		var marker: String = str(vd.get("si_marqueur", ""))
		if marker != "" and tags.has(marker):
			return {"texte": str(vd.get("texte", "")), "source": "variante_marqueur:" + marker}
		var promise: String = str(vd.get("si_promesse_rompue", ""))
		if promise != "" and broken.has(promise):
			return {"texte": str(vd.get("texte", "")), "source": "variante_promesse:" + promise}
	return {"texte": str(opt.get("outcome", "")), "source": "reussite"}


## Option choisie par l'autoplay pour la carte `idx`. MERLIN_AUTOPLAY_PICKS
## permet d'imposer une suite ("1,2,0,...") : sans elle l'autoplay prend toujours
## la premiere option, n'exerce jamais le gradient et ne peut declencher aucune
## variante d'etat.
func _autoplay_pick(idx: int) -> int:
	var spec: String = OS.get_environment("MERLIN_AUTOPLAY_PICKS")
	if spec.is_empty():
		return 0
	var parts: PackedStringArray = spec.split(",", false)
	if parts.is_empty():
		return 0
	var raw: String = parts[idx % parts.size()].strip_edges()
	return clampi(int(raw) if raw.is_valid_int() else 0, 0, 2)


## Prefixe lisible de l'epreuve portee par l'option `i` de la carte courante.
## Vide hors scenario scripte : le pool ne porte pas de `check`.
func _telegraph_suffix(i: int) -> String:
	if _live_current_card.is_empty():
		return ""
	var opts: Array = _live_current_card.get("options", [])
	if i < 0 or i >= opts.size():
		return ""
	var ck: Dictionary = (opts[i] as Dictionary).get("check", {}) as Dictionary
	if ck.is_empty():
		return ""
	var stat_fr: String = str(ck.get("stat", "")).capitalize()
	var pct: int = int(round(clampf(0.50 + 0.10 * float(_stat_level(str(ck.get("stat", "")))), 0.0, 1.0) * 100.0))
	match str(ck.get("type", "white")):
		"red":
			return "[ROUGE %s %d%%] " % [stat_fr, pct]
		"fatal":
			return "[FATAL %s %d%%] " % [stat_fr, pct]
		"contextuel":
			return "[%s %d%%] " % [stat_fr, pct]
		_:
			return "[%s %d%%] " % [stat_fr, pct]


## Convertit une carte de scenario dans la forme {text, options, ...} attendue
## par l'affichage. Les champs mecaniques (check, gradient, faction) sont
## conserves sur chaque option pour la resolution.
func _scripted_card_to_engine(card: Dictionary, act_type: String) -> Dictionary:
	var opts: Array = []
	for o in (card.get("options", []) as Array):
		var od: Dictionary = o as Dictionary
		opts.append({
			"label": str(od.get("label", "")),
			"text": str(od.get("label", "")),
			"verb": str(od.get("verb", "")),
			"effects": (od.get("effects", []) as Array).duplicate(true),
			"outcome": str(od.get("outcome", "")),
			"outcome_fail": str(od.get("outcome_fail", "")),
			"outcome_variants": (od.get("outcome_variants", []) as Array).duplicate(true),
			"check": (od.get("check", {}) as Dictionary).duplicate(true),
			"gradient": str(od.get("gradient", "")),
			"primary_faction": str(od.get("primary_faction", "")),
		})
	return {
		"id": str(card.get("card_id", "c?")),
		"text": str(card.get("text", card.get("summary", ""))),
		"prompt": str(card.get("text", card.get("summary", ""))),
		"act_type": act_type,
		"rarity": str(card.get("rarity", "COMMUNE")),
		"emotion": str(card.get("emotion", "")),
		"scenario_act": int(card.get("act", 1)),
		"options": opts,
	}


func _tr_record(entry: Dictionary) -> void:
	if _transcript_path.is_empty():
		return
	_transcript.append(entry)


func _tr_flush() -> void:
	if _transcript_path.is_empty():
		return
	var f := FileAccess.open(_transcript_path, FileAccess.WRITE)
	if f == null:
		push_warning("[BoardNarration] transcript : ecriture impossible dans %s" % _transcript_path)
		return
	f.store_string(JSON.stringify({
		"biome": _biome_id,
		"sequence_actes": _act_sequence(),
		"scenario": {
			"titre": str(_scripted_scenario.get("title", "")),
			"archetype": str(_scripted_scenario.get("archetype_id", "")),
			"longueur": int(_scripted_scenario.get("length", 0)),
			"intro": str(_scripted_scenario.get("intro", "")),
			"essence": str(_scripted_scenario.get("essence", "")),
			"graine": (_scripted_scenario.get("graine_de_variation", {}) as Dictionary).duplicate(),
		},
		"issue": _outcome,
		"anam_gagne": _run_anam_earned,
		"cartes_jouees": _live_cards_played,
		"entrees": _transcript,
	}, "  "))
	f.close()
	push_warning("[BoardNarration] transcript ecrit : %s (%d entrees)" % [
		_transcript_path, _transcript.size()])


## Display a fetched card in the overlay : text typewriter-revealed + 3 option
## labels (hidden until text fully written). Per user feedback : text should
## "s'écrire petit à petit" rather than appear instantly.
func _show_live_card(card: Dictionary) -> void:
	var prompt: String = str(card.get("text", card.get("prompt", card.get("title", "Une rune se pose."))))
	var options: Array = card.get("options", [])
	# Persona-style deal-in : slam parchment onto table with rotation + scale
	# overshoot + 3-tick shake. Replaces silent pop.
	var card_panel: Control = null
	if _card_overlay:
		card_panel = _card_overlay.get_node_or_null("CardPanel") as Control
	# v5.1 : adjust panel size + tint per act_type BEFORE the deal-in so the
	# slam lands at the correct anchor (boss = 70% take-over, event = cyan tint).
	# v5.4 : pass the full card so styling can also tint by dominant faction
	# (per user feedback : "cartes doivent avoir leur propre contour et particularités").
	_apply_act_styling(card_panel, card)
	if card_panel:
		JuiceHelpers.deal_in_card(self, card_panel)
	# Update badge (ogham + faction) BEFORE text reveal so it primes the eye.
	_update_card_badges(card)
	# Render the per-card stat readout strip (Difficulty / Risk / FactionPressure / Reward / Ogham).
	_render_stat_readout(card)
	# Hide buttons during text reveal.
	for b in _card_option_buttons:
		(b as Button).visible = false
		(b as Button).disabled = true
	# Typewriter the body text.
	await _typewriter_live(prompt)
	# Now reveal option buttons one by one with stagger.
	for i in range(_card_option_buttons.size()):
		var btn: Button = _card_option_buttons[i] as Button
		if i < options.size():
			var opt: Dictionary = options[i] if options[i] is Dictionary else {}
			var label: String = str(opt.get("text", opt.get("label", "Option %d" % (i + 1))))
			btn.text = "▸ " + label
			btn.disabled = false
			btn.visible = true
			btn.modulate = Color(1, 1, 1, 0)
			var fade := create_tween()
			fade.tween_interval(i * 0.18)
			fade.tween_property(btn, "modulate:a", 1.0, 0.35)
		else:
			btn.visible = false
			btn.disabled = true


## Update the card header badges (Ogham glyph + card title).
func _update_card_badges(card: Dictionary) -> void:
	if _card_badge_label == null:
		return
	var ogham_id: String = str(card.get("ogham_used", card.get("ogham", "")))
	var glyph := ""
	if not ogham_id.is_empty():
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
		glyph = str(spec.get("unicode", ""))
	var card_id: String = str(card.get("id", ""))
	var header := card_id.to_upper()
	if header.begins_with("FR_"):
		header = header.substr(3)
	var title: String = str(card.get("title", header))
	_card_badge_label.text = "[b][color=#3a2410]" + title + "[/color][/b]   [color=#7a3a18]" + glyph + "[/color]"


## Typewriter for live mode — slower than cinematic, with skip on click.
func _typewriter_live(text: String) -> void:
	if _card_text_label == null:
		return
	_card_text_label.text = ""
	var delay: float = 1.0 / LIVE_TYPEWRITER_CPS
	var i := 0
	while i < text.length() and not _skip_requested:
		if _live_pending_choice >= 0:
			break
		_card_text_label.text = "[color=#1c1208]" + text.substr(0, i + 1) + "[/color]"
		await get_tree().create_timer(delay).timeout
		i += 1
	_card_text_label.text = "[color=#1c1208]" + text + "[/color]"


## v7.1 — Typewriter targeting the bottom-of-screen Narration Label (no panel).
## Replaces the parchemin-based incantation reveal. Per user feedback (2026-05-14
## part 15) : "le gros rectangle ... il doit dégager".
func _typewriter_narration(text: String) -> void:
	if _narration_label == null:
		return
	_narration_label.text = ""
	# v7.7.15 — Merlin sound bar activates during speech, pulses per typed char.
	if _merlin_sound_bar != null and is_instance_valid(_merlin_sound_bar):
		_merlin_sound_bar.start_speaking()
	var delay: float = 1.0 / LIVE_TYPEWRITER_CPS
	var i := 0
	while i < text.length() and not _skip_requested:
		_narration_label.text = text.substr(0, i + 1)
		# Pulse a few random bars per char (skip whitespace for variety).
		if _merlin_sound_bar != null and is_instance_valid(_merlin_sound_bar):
			var ch: String = text.substr(i, 1)
			if ch.strip_edges() != "":
				_merlin_sound_bar.pulse(randf_range(0.4, 0.95))
		await get_tree().create_timer(delay).timeout
		i += 1
	_narration_label.text = text
	if _merlin_sound_bar != null and is_instance_valid(_merlin_sound_bar):
		_merlin_sound_bar.stop_speaking()


func _on_card_option_pressed(option_index: int) -> void:
	if _live_pending_choice >= 0:
		return  # already chosen
	_live_pending_choice = option_index
	# v5.3 — Click sound feedback (low-pitch parchment thunk).
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("click", 0.7)
	# Disable buttons immediately so the user can't double-click.
	for b in _card_option_buttons:
		(b as Button).disabled = true
	# Yakuza-style hit-stop : 80ms time freeze + camera kick + faction screen flash
	# + radial ink-line burst from the clicked button + button swell-settle.
	var options: Array = _live_current_card.get("options", [])
	var dominant := "druides"
	var clicked_btn: Control = null
	if option_index < _card_option_buttons.size():
		clicked_btn = _card_option_buttons[option_index]
	if option_index < options.size() and options[option_index] is Dictionary:
		var opt: Dictionary = options[option_index]
		var fac_deltas: Dictionary = opt.get("faction_deltas", {})
		if not fac_deltas.is_empty():
			dominant = _resolve_dominant_faction(fac_deltas)
		else:
			# Derive from effects if faction_deltas missing.
			for fx in opt.get("effects", []):
				if fx is Dictionary and str(fx.get("type", "")) == "ADD_REPUTATION":
					dominant = str(fx.get("faction", dominant))
					break
		JuiceHelpers.choice_impact(self, _ui_layer, _camera, _floating_fx_layer, clicked_btn, dominant)
		# Animate effect feedback : show floating "+5 druides" / "-3 vie" labels.
		var effects: Array = opt.get("effects", [])
		_animate_effect_feedback(effects)


## Add a SigleToken to the plateau for the just-resolved card. Faction is
## derived from the card's faction_deltas (dominant).
func _spawn_live_token(card: Dictionary, _option_index: int, total_index: int) -> void:
	# v5.5 Round B — Replace SigleToken (faction figurine in a row) with
	# NarrativePion3D (card-typed pion at a free Marker3D anchor with physics).
	# Per user feedback : "pas de pion pour les factions, les pions doivent avoir
	# de la physique et sont positionnés sur le plateau en fonction de ce qui se passe".
	var pion_type: int = NarrativePion3D.derive_type_from_card(card)
	var pos: Vector3 = _get_next_marker_position()
	var pion: NarrativePion3D = NarrativePion3D.new()
	pion.name = "Pion_%d" % total_index
	_token_container.add_child(pion)
	pion.global_position = pos
	pion.setup(pion_type, str(card.get("id", "")))
	pion.drop_in_from_above(pos, 0.0)
	_tokens.append(pion)
	pion.highlight()


## v5.5 Round B — Compute the next free Marker3D position on the plateau.
## 8 anchors at radius 1.4m, height 0.18m, angles 0°/45°/90°/... around plateau center.
## Markers are consumed in order ; if all 8 used, wrap back to 0 (recycling).
## Per user feedback : "Marker3D pre-définis sur le plateau (8 anchors, le pion va sur le plus proche libre)".
var _pion_markers_used: int = 0

func _get_next_marker_position() -> Vector3:
	const MARKER_COUNT := 8
	const MARKER_RADIUS := 1.4
	const MARKER_HEIGHT := 0.20
	var idx: int = _pion_markers_used % MARKER_COUNT
	_pion_markers_used += 1
	var angle: float = float(idx) * TAU / float(MARKER_COUNT)
	return Vector3(cos(angle) * MARKER_RADIUS, MARKER_HEIGHT, sin(angle) * MARKER_RADIUS)


## v6 — Peek the NEXT marker position WITHOUT consuming it. Used by LiveCard3D
## to know where to fly to before the pion is actually spawned.
func _get_next_marker_position_preview() -> Vector3:
	const MARKER_COUNT := 8
	const MARKER_RADIUS := 1.4
	const MARKER_HEIGHT := 0.20
	var idx: int = _pion_markers_used % MARKER_COUNT
	var angle: float = float(idx) * TAU / float(MARKER_COUNT)
	return Vector3(cos(angle) * MARKER_RADIUS, MARKER_HEIGHT, sin(angle) * MARKER_RADIUS)


## v6 — Hand of Fate-style 3D card. Replaces _show_live_card (parchemin overlay).
## Instantiates LiveCard3D in front of camera, populates with card content,
## spawns 3 floating Button2D buttons anchored to the card's option positions.
func _show_live_card_3d(card: Dictionary) -> void:
	# Hide the legacy 2D parchemin overlay (kept for cinematic fallback).
	if _card_overlay:
		_card_overlay.visible = false
	# Cleanup any previous live card.
	if _live_card_3d and is_instance_valid(_live_card_3d):
		_live_card_3d.queue_free()
	_clear_floating_option_buttons()
	# Spawn the new LiveCard3D in front of camera (world position synced to
	# CardDeck3D's HELD_POSITION_LOCAL so the card transition feels seamless).
	_live_card_3d = LiveCard3D.new()
	_live_card_3d.name = "LiveCard3D"
	add_child(_live_card_3d)
	# v6.1 — Position : center-stage in front of camera. Camera at (0, 2.6, 4.6).
	# Card at (0, 1.6, 2.8) — closer to camera, lower so it sits between camera
	# and plateau, well within frustum. Tilt -20° X to face camera (camera looks
	# down ~25° toward plateau center).
	_live_card_3d.global_position = Vector3(0.0, 1.6, 2.8)
	_live_card_3d.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
	_live_card_3d.setup(card)
	# v7.0 — Diagnostic prints removed (root cause identified + fixed in v6.6).
	# Build 3 floating Button2D anchored on each option's world position.
	_build_floating_option_buttons()


## v7.7.2.1 — Build 3 readable Button2D with full option text INSIDE, positioned
## at fixed screen anchors below the card (no more sync-to-Label3D-world-pos which
## caused buttons to land ON the card and overlap body text). Per user feedback :
## « les choix sont sur le côté et illisible et sur la carte elle même aussi ».
func _build_floating_option_buttons() -> void:
	if _ui_layer == null or _live_card_3d == null:
		return
	# Pull option text directly from the LiveCard3D so buttons display readable
	# labels (cards only show ▸ markers now — text lives on the buttons).
	var texts: Array = []
	if _live_card_3d.has_method("get_option_texts"):
		texts = _live_card_3d.get_option_texts()
	for i in range(3):
		# v7.7.20 — Intraitable UI : MerlinVisual.digital_button enforces uniform
		# gold border + white text + black outline + dark bg per user mandate.
		# 16 lines inline styling replaced with single factory call.
		var btn_text: String = str(texts[i]) if i < texts.size() else ("Option %d" % (i + 1))
		# Telegraphie de l'epreuve (bible §26.2 / check_schema.telegraphed_required_for).
		# Une epreuve rouge ou fatale doit se voir AVANT le choix, sinon le joueur
		# subit un piege au lieu de prendre un risque.
		btn_text = _telegraph_suffix(i) + btn_text
		var btn: Button = MerlinVisual.digital_button(btn_text, "primary")
		btn.name = "FloatOption_%d" % i
		btn.flat = false
		btn.custom_minimum_size = Vector2(560, 56)
		btn.clip_text = true   # cut overlong option text rather than overflow
		btn.add_theme_font_size_override("font_size", 18)
		# v7.7.2.1 — FIXED screen position : vertical stack centered, bottom 30% of screen.
		# This stops them from following the card and overlapping body text.
		btn.anchor_left = 0.5
		btn.anchor_right = 0.5
		btn.anchor_top = 0.65
		btn.anchor_bottom = 0.65
		btn.offset_left = -280  # half of 560
		btn.offset_right = 280
		btn.offset_top = float(i) * 64  # 64 = button height + small gap
		btn.offset_bottom = float(i) * 64 + 56
		btn.visible = true
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_floating_button_pressed(idx))
		btn.mouse_entered.connect(func() -> void:
			var s: Node = get_node_or_null("/root/SFXManager")
			if s and s.has_method("play"):
				s.play("hover", 1.0))
		_ui_layer.add_child(btn)
		_floating_option_buttons.append(btn)


## v7.7.2.1 — DEPRECATED. Buttons now use fixed screen anchors (bottom 30%)
## set once in _build_floating_option_buttons, so no per-frame sync is needed.
## Kept as no-op to preserve call sites that still invoke it.
func _sync_floating_buttons_to_card_3d() -> void:
	# Intentional no-op : buttons are now anchored via anchor_top/offset_top
	# rather than projected from 3D Label positions. Removing the call sites
	# is a follow-up cleanup (search for _sync_floating_buttons_to_card_3d).
	pass


## v6 — Click handler for the floating option buttons. Routes through the same
## _on_card_option_pressed entrypoint so all the v4/v5 juice (hit-stop, effect
## animation, etc.) still fires.
func _on_floating_button_pressed(idx: int) -> void:
	if _live_card_3d and is_instance_valid(_live_card_3d):
		_live_card_3d.resolve_choice(idx)
	_on_card_option_pressed(idx)


## v6 — Cleanup the 3 floating option buttons (called between cards).
func _clear_floating_option_buttons() -> void:
	for b in _floating_option_buttons:
		if is_instance_valid(b):
			(b as Node).queue_free()
	_floating_option_buttons.clear()


## Polls for /root/MerlinStore up to ~30 frames (≈0.5s @ 60fps). Returns
## when it appears, or after the timeout. Required because the Store is
## created via `call_deferred("add_child", store)` from GameManager autoload.
func _await_store_ready() -> void:
	for _i in range(30):
		if get_node_or_null("/root/MerlinStore") != null:
			return
		await get_tree().process_frame


## Depth-first search for the first MeshInstance3D under `node`.
## Used to bind `_plateau` to a usable mesh inside the GLB tree regardless
## of how Blender exported the scene (root Empty, intermediate groups, etc).
static func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_first_mesh(child)
		if found != null:
			return found
	return null


## Switch the ScreenDither autoload to PSX render mode with biome-specific tint.
## The retro_psx_post.gdshader is a post-process applied to the screen; it does
## NOT occlude the 3D scene (unlike MerlinBackdrop's opaque ColorRect).
func _configure_psx_filter() -> void:
	var sd: Node = get_node_or_null("/root/" + SCREEN_DITHER_AUTOLOAD)
	if sd == null:
		return
	# Save previous state for restore
	if sd is CanvasItem:
		_screen_dither_prev["visible"] = (sd as CanvasItem).visible
	if sd is CanvasItem:
		(sd as CanvasItem).visible = true
	# Switch to PSX mode (RenderMode.PSX = 1)
	if sd.has_method("set_render_mode"):
		sd.set_render_mode(1)
	# User feedback v5 (2026-05-14) : "le filtre PSX doit être très léger".
	# Subtle preset = smaller pixel blocks + higher color depth + minimal dither.
	# All CRT-vibe residuals zeroed (scanlines + curvature + vignette).
	if sd.has_method("set_psx_preset"):
		sd.set_psx_preset("subtle")
	if sd.has_method("set_shader_parameter"):
		sd.set_shader_parameter("scanline_opacity", 0.0)
		sd.set_shader_parameter("curvature", 0.0)
		sd.set_shader_parameter("vignette_intensity", 0.0)
		# Fine-tune intensity for a barely-perceptible texture vs heavy block dither.
		sd.set_shader_parameter("pixel_size", 1.5)
		sd.set_shader_parameter("color_depth", 64.0)
		sd.set_shader_parameter("dither_strength", 0.18)
		sd.set_shader_parameter("global_intensity", 0.45)
	# Biome-specific PSX tint (only applied AFTER biome is picked).
	if sd.has_method("set_biome") and _biome_id != "":
		var sd_biome_key := _map_biome_to_psx_key(_biome_id)
		sd.set_biome(sd_biome_key, false)


func _restore_psx_filter() -> void:
	var sd: Node = get_node_or_null("/root/" + SCREEN_DITHER_AUTOLOAD)
	if sd == null:
		return
	# Revert to CRT mode (default for the card game)
	if sd.has_method("set_render_mode"):
		sd.set_render_mode(0)
	if sd.has_method("set_crt_preset"):
		sd.set_crt_preset("subtle")
	if sd is CanvasItem and _screen_dither_prev.has("visible"):
		(sd as CanvasItem).visible = bool(_screen_dither_prev["visible"])


static func _map_biome_to_psx_key(biome_id: String) -> String:
	# ScreenDither's PSX_BIOME_PROFILES uses short keys; map the canonical biome_id.
	match biome_id:
		"foret_broceliande": return "broceliande"
		"landes_bruyere": return "landes"
		"cotes_sauvages": return "cotes"
		"villages_celtes": return "villages"
		"cercles_pierres": return "cercles"
		"marais_korrigans": return "marais"
		"collines_dolmens": return "dolmens"
		"iles_mystiques": return "iles"
		_:
			return "broceliande"


func _emit_done_once() -> void:
	if _narration_done_emitted:
		return
	_narration_done_emitted = true
	narration_done.emit()


# ─── Camera helpers ──────────────────────────────────────────────────────────

func _camera_look_at(eul: Vector3) -> void:
	_camera.rotation = eul


func _euler_to_target(pos: Vector3, target: Vector3) -> Vector3:
	# Compute the rotation a Camera3D would have after look_at(target, UP) from pos.
	var look := Transform3D().looking_at(target - pos, Vector3.UP)
	return look.basis.get_euler()


# ─── Narration ───────────────────────────────────────────────────────────────

func _request_llm_comment(entry: Dictionary, index: int, total: int) -> String:
	if _llm_unavailable:
		return ""
	if _merlin_ai == null or not _merlin_ai.has_method("generate_narrative"):
		_llm_unavailable = true
		return ""
	if _merlin_ai.has_method("is_llm_ready") and not bool(_merlin_ai.is_llm_ready()):
		_llm_unavailable = true
		return ""
	var ogham: String = str(entry.get("ogham_used", entry.get("ogham", "")))
	var ogham_name: String = ogham
	if not ogham.is_empty():
		var ogham_spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham, {})
		if not ogham_spec.is_empty():
			ogham_name = str(ogham_spec.get("name", ogham))
	var biome_name: String = str(MerlinConstants.BIOMES.get(_biome_id, {}).get("name", _biome_id))

	var system_prompt := "Tu es Merlin. Tu relis a voix posee une etape d'une run terminee. " \
		+ "Une phrase courte (12-22 mots), ton druidique sobre, pas de meta. " \
		+ "Pas de questions, pas de markdown."
	var user_input := "Biome : %s. Carte %d/%d (%s). Ogham : %s. Option : %d. Ambiance : %s." % [
		biome_name, index + 1, total,
		str(entry.get("card_id", "?")),
		ogham_name if not ogham.is_empty() else "aucun",
		int(entry.get("option_index", entry.get("option", 0))),
		BoardBiomeAmbience.get_mood_label(_biome_id),
	]
	var params := {"temperature": 0.7, "max_tokens": 90}

	var holder := {"done": false, "text": ""}
	var llm_task := func() -> void:
		var r_v = await _merlin_ai.generate_narrative(system_prompt, user_input, params)
		if holder.get("done", false):
			return
		holder["done"] = true
		if r_v is Dictionary and bool(r_v.get("ok", false)):
			holder["text"] = str(r_v.get("text", ""))
	llm_task.call()
	var elapsed := 0.0
	while not bool(holder["done"]) and elapsed < LLM_PER_CALL_TIMEOUT and not _skip_requested:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	if not bool(holder["done"]):
		holder["done"] = true
		_llm_unavailable = true
		return ""
	var text: String = str(holder.get("text", "")).strip_edges()
	if text.is_empty():
		return ""
	var first_line: String = text.split("\n")[0].strip_edges()
	if first_line.length() > 200:
		first_line = first_line.substr(0, 200) + "…"
	return first_line


func _fallback_comment(ogham_id: String) -> String:
	if ogham_id.is_empty():
		var idx: int = _current_index % FALLBACK_NO_OGHAM.size()
		return FALLBACK_NO_OGHAM[idx]
	var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
	var category: String = str(spec.get("category", ""))
	return str(FALLBACK_BY_CATEGORY.get(category, FALLBACK_BY_CATEGORY[""]))


func _typewriter(text: String) -> void:
	if _narration_label == null:
		return
	_narration_label.text = ""
	var delay: float = 1.0 / TYPEWRITER_CPS
	var i := 0
	while i < text.length() and not _skip_requested:
		_narration_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(delay).timeout
		i += 1
	_narration_label.text = text


# ─── Input ───────────────────────────────────────────────────────────────────

func _on_skip_pressed() -> void:
	_skip_requested = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_skip_pressed()
