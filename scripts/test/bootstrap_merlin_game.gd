## BootstrapMerlinGame — Lance MerlinGame en autonome, sans GameManager.
## Instancie MerlinStore à /root puis charge MerlinGame.tscn.
## Usage : godot --path . scenes/BootstrapMerlinGame.tscn
## Dev only — jamais exporté (guard OS.is_debug_build).
##
## PATTERN: call_deferred("_setup") obligatoire car add_child(/root) échoue
## pendant _ready() ("Parent node is busy setting up children").

extends Node

const DEV_BIOME := "broceliande"
const MERLIN_GAME_SCENE := "res://scenes/MerlinGame.tscn"
const MERLIN_STORE_SCRIPT := "res://scripts/merlin/merlin_store.gd"


func _ready() -> void:
	if not OS.is_debug_build():
		push_error("[Bootstrap] Scène debug uniquement — non lancée en build exporté")
		return
	## Déférer _setup pour que l'arbre soit stable (root plus occupé)
	call_deferred("_setup")


func _setup() -> void:
	## Setup exécuté après la fin du cycle _ready() de tous les autoloads.
	## À ce stade, get_tree().root.add_child() fonctionne sans erreur.

	print("[Bootstrap] _setup() — biome: %s" % DEV_BIOME)

	# 1. Ajouter MerlinStore à /root (doit être AVANT le controller)
	var store_script: Script = load(MERLIN_STORE_SCRIPT)
	if not store_script:
		push_error("[Bootstrap] Impossible de charger %s" % MERLIN_STORE_SCRIPT)
		return
	var store_node: Node = store_script.new()
	store_node.name = "MerlinStore"
	get_tree().root.add_child(store_node)
	print("[Bootstrap] MerlinStore ajouté à /root/MerlinStore")

	# 2. Instancier MerlinGame.tscn et définir dev_biome_override
	var game_scene: PackedScene = load(MERLIN_GAME_SCENE)
	if not game_scene:
		push_error("[Bootstrap] Impossible de charger %s" % MERLIN_GAME_SCENE)
		return
	var game_node: Node = game_scene.instantiate()
	game_node.set("dev_biome_override", DEV_BIOME)
	print("[Bootstrap] dev_biome_override = '%s'" % DEV_BIOME)

	# 3. Ajouter MerlinGame (déclenche _ready controller → trouve MerlinStore)
	get_tree().root.add_child(game_node)
	print("[Bootstrap] MerlinGame lancé")

	# 4. Libérer le bootstrap
	queue_free()
