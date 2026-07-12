extends SceneTree
## probe_biome_check.gd — SONDE JETABLE (N5-C1 fix biome) : prouve que le biome choisi pilote le
## CONTENU (titres de sélection du secours + 1er scénario). Le secours biome-aware s'affiche >95 % du
## temps ET sert de pool à la chaîne de quêtes → c'est ce que le joueur voit. Force via env MERLIN_BIOME.
##   Godot --headless --path . --script res://tools/probe_biome_check.gd
## Sortie : [BIOME] OK|FAIL ... ; exit 0/1. Ne touche pas à la save (lecture seule).

func _init() -> void:
	_main()


func _main() -> void:
	await process_frame
	var run: Node = root.get_node_or_null("/root/MerlinRun")
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if run == null or sc == null:
		print("[BIOME] FAIL autoloads absents")
		quit(1)
		return
	var biome: String = str(run.biome)
	print("[BIOME] === biome=%s · lieu=%s ===" % [biome, str(sc._lieu_name())])
	var pool: Array = sc._sel_fallback_pool()
	var joined: String = ""
	for i in pool.size():
		var t: String = str((pool[i] as Dictionary).get("title", "?"))
		var p: String = str((pool[i] as Dictionary).get("pitch", ""))
		print("[BIOME] titre %d : %s | %s" % [i + 1, t, p])
		joined += " " + t + " " + p
	# 1er scénario : squelette depuis le 1er titre + situation du beat 0 (narration biome-aware).
	if pool.size() > 0:
		var skel: Dictionary = sc.build_skeleton(str((pool[0] as Dictionary).get("title", "")),
			str((pool[0] as Dictionary).get("pitch", "")))
		var beats: Array = skel.get("beats", [])
		if beats.size() > 0:
			var situ: Dictionary = sc.build_situation(beats[0])
			print("[BIOME] 1er scenario : %s" % str(situ.get("narration", "")).left(220))
	# Assertion : en falaises, JAMAIS Broceliande.
	var low: String = joined.to_lower()
	if biome == "falaises" and (low.find("broceliande") >= 0 or low.find("broc") >= 0):
		print("[BIOME] FAIL — falaises contient une reference foret/Broceliande")
		quit(1)
		return
	print("[BIOME] OK")
	quit(0)
