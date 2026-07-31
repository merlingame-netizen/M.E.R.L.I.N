## ═══════════════════════════════════════════════════════════════════════════
## test_scenario_selection.gd — Non-regression : le catalogue est-il atteint ?
## ═══════════════════════════════════════════════════════════════════════════
## v7.7.26. `StoreRun.init_run` initialisait `current_biome` a "" puis le relisait
## pour choisir un scenario ; tous les scenarios du catalogue ayant une
## `biome_affinity` non vide, aucun ne passait le filtre — le catalogue entier
## etait du code mort.
##
## Ce test verifie les deux sens :
##   - biome renseigne  -> un scenario est selectionne
##   - biome vide       -> aucun scenario (comportement documente, pas un bug)
##
## Usage : godot --headless --path . --script res://tools/godot/test_scenario_selection.gd
## ═══════════════════════════════════════════════════════════════════════════
extends SceneTree

const ScenarioManager = preload("res://scripts/merlin/merlin_scenario_manager.gd")


func _init() -> void:
	var mgr = ScenarioManager.new()
	var failures: int = 0

	# Cas nominal : chaque biome connu doit pouvoir tirer un scenario.
	var biomes: Array = ["foret_broceliande", "marais_korrigans", "cercles_pierres"]
	for biome in biomes:
		var sc: Dictionary = mgr.select_scenario(str(biome), {})
		if sc.is_empty():
			print("[FAIL] biome '%s' : aucun scenario selectionne" % biome)
			failures += 1
		else:
			print("[OK]   biome '%s' -> '%s'" % [biome, str(sc.get("id", "?"))])

	# Cas degrade : biome vide -> aucun scenario. C'est exactement l'etat que
	# produisait le bug d'ordre, et ce que le fix doit rendre inatteignable.
	var empty_sc: Dictionary = mgr.select_scenario("", {})
	if empty_sc.is_empty():
		print("[OK]   biome vide -> aucun scenario (comportement attendu)")
	else:
		print("[FAIL] biome vide -> '%s' (le filtre biome_affinity ne joue pas)"
			% str(empty_sc.get("id", "?")))
		failures += 1

	if failures == 0:
		print("[test_scenario_selection] PASS")
		quit(0)
	else:
		print("[test_scenario_selection] FAIL — %d echec(s)" % failures)
		quit(1)
