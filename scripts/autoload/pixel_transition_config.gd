## PixelTransitionConfig — Per-scene transition profiles
## Defines block_size, durations, cascade order, and skip flags for each scene.
## Used by PixelTransition autoload to customize the pixel formation effect.

class_name PixelTransitionConfig
extends RefCounted


enum CascadeOrder {
	ISOMETRIC,     ## Diagonal top-left to bottom-right (col + row sort)
	RANDOM,        ## Shuffled random batches
	COLUMN_LTR,    ## Left-to-right column sweep
	ROW_TOP_DOWN,  ## Top-down row-by-row reveal
	CENTER_OUT,    ## Radial from screen center
}


const DEFAULT := {
	"block_size": 10,
	"exit_duration": 0.6,
	"enter_duration": 0.8,
	"exit_scatter_y_min": -80.0,
	"exit_scatter_y_max": -200.0,
	"exit_scatter_x": 60.0,
	"enter_spawn_y_min": -60.0,
	"enter_spawn_y_max": -180.0,
	"enter_spawn_x": 40.0,
	"batch_size": 8,
	"batch_delay": 0.012,
	"cascade_order": CascadeOrder.ISOMETRIC,
	"cascade_mode": "rain",        ## "rain" (row-progressive curtain) | "element_batch" (legacy)
	"row_stagger": 0.005,          ## Delay per row of blocks (rain mode)
	"rain_jitter": 0.012,          ## Random per-pixel timing jitter (rain mode)
	"input_unlock_progress": 0.7,
	"skip_exit": false,
	"skip_enter": false,
	"sfx_scatter": "pixel_scatter",
	"sfx_assemble": "pixel_cascade",
	"bg_color": Color(0.02, 0.04, 0.02),  # MerlinVisual.CRT_PALETTE["bg_deep"]
}


const SCENE_PROFILES := {
	# --- Intro scenes (own animations, skip both) ---
	"res://scenes/IntroCeltOS.tscn": {
		"block_size": 8,
		"skip_exit": true,
		"skip_enter": true,
	},

	# --- Main flow (demo build 2026-04-25) ---
	"res://scenes/MenuPrincipal.tscn": {
		"block_size": 10,
		"enter_duration": 1.0,
	},
	"res://scenes/MerlinCabinHub.tscn": {
		"block_size": 10,
		"enter_duration": 0.9,
	},
	"res://scenes/BroceliandeForest3D.tscn": {
		"block_size": 12,
		"exit_duration": 0.5,
		"skip_enter": true,
	},
	"res://scenes/MerlinGame.tscn": {
		"block_size": 8,
		"exit_duration": 0.5,
		"enter_duration": 0.7,
	},
	"res://scenes/EndRunScreen.tscn": {
		"block_size": 10,
		"exit_duration": 0.6,
		"enter_duration": 0.8,
	},

	# --- Sub-menus (fast, larger blocks) ---
	"res://scenes/MenuOptions.tscn": {
		"block_size": 12,
		"exit_duration": 0.4,
		"enter_duration": 0.5,
		"cascade_order": CascadeOrder.RANDOM,
	},
	"res://scenes/SelectionSauvegarde.tscn": {
		"block_size": 12,
		"exit_duration": 0.4,
		"enter_duration": 0.5,
		"cascade_order": CascadeOrder.RANDOM,
	},
	"res://scenes/ParchmentPreRun.tscn": {
		"block_size": 10,
		"exit_duration": 0.5,
		"enter_duration": 0.7,
	},
}


static func get_profile(scene_path: String) -> Dictionary:
	var profile: Dictionary = DEFAULT.duplicate(true)
	if SCENE_PROFILES.has(scene_path):
		var overrides: Dictionary = SCENE_PROFILES[scene_path]
		for key: String in overrides:
			profile[key] = overrides[key]
	return profile
