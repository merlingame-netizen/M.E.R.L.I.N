extends SceneTree
## Test isolé de MerlinProse.strip_scene_echo (GDScript réel, headless, sans LLM).
## (A4 : helper extrait de merlin_scenario._strip_scene_echo → statique pur, plus besoin d'instancier.)
##   godot --headless --path . --script res://tools/test_strip.gd

func _init() -> void:
	var situ: String = "Au milieu de ce passage, le Voyageur rencontra un vieil être, vêtu de peaux d'animaux, qui lui raconta que ce sentier était gardé par les esprits des anciens druides. Le vieil être montra alors une marque gravée sur son bras, qui indiquait la voie. Que fit le Voyageur ?"
	var prose: String = "L'être montra alors une marque gravée sur son bras, qui indiquait la voie. Le Voyageur choisit de poser sa main sur la marque et de laisser ses paroles couler doucement. L'être se tourna vers le Voyageur et s'inclina profondément."
	var out: String = MerlinProse.strip_scene_echo(prose, situ)
	print("=== INPUT ===")
	print(prose)
	print("=== OUTPUT ===")
	print(out)
	print("=== DROPPED FIRST SENTENCE? ===")
	print("YES" if not out.begins_with("L'être montra") else "NO -- BUG")
	quit()
