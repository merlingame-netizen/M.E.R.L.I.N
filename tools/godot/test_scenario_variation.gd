## ═══════════════════════════════════════════════════════════════════════════
## test_scenario_variation.gd — non-regression de la variation de scenario
## ═══════════════════════════════════════════════════════════════════════════
## Exigence de design : les scenarios sont generes a 100 % par le LLM et aucun
## ne doit ressembler a un autre. Deux mecanismes le garantissent — la graine de
## variation (tirage impose sur 5 axes, 25 920 combinaisons) et la porte de
## nouveaute (rejet de ce qui est trop proche des scenarios recents).
##
## Ce test verifie que les deux fonctionnent : 12 tirages consecutifs doivent
## donner 12 graines distinctes, et la porte doit rejeter un texte proche tout
## en acceptant un texte eloigne.
##
## Usage : godot --headless --path . --script res://tools/godot/test_scenario_variation.gd
## ═══════════════════════════════════════════════════════════════════════════
extends SceneTree
func _init() -> void:
	var v := ScenarioVariation.new(12345)
	var seen: Dictionary = {}
	var fails: int = 0
	for i in range(12):
		var s: Dictionary = v.draw_seed()
		if s.is_empty():
			print("[FAIL] graine vide au tirage %d" % i); fails += 1; break
		var key: String = JSON.stringify(s)
		if seen.has(key):
			print("[FAIL] graine repetee : %s" % key); fails += 1
		seen[key] = true
		v.commit_seed(s)
		if i == 0:
			print("--- exemple de bloc de prompt ---")
			print(v.format_seed_for_prompt(s))
			print("---")
	print("[OK] %d graines distinctes sur 12" % seen.size())
	# porte de nouveaute
	var prev := {"a": "Le rite des neuf souffles dort sous la mousse de Broceliande depuis des siecles"}
	var proche := v.novelty_gate("Le rite des neuf souffles dort sous la mousse de Broceliande depuis longtemps", prev)
	var loin := v.novelty_gate("Un korrigan vend des clous tordus au bord d'une carriere noyee", prev)
	print("[porte] texte proche  -> accepte=%s sim=%.2f" % [proche["accepte"], proche["similarite_max"]])
	print("[porte] texte eloigne -> accepte=%s sim=%.2f" % [loin["accepte"], loin["similarite_max"]])
	if not proche["accepte"] and loin["accepte"]:
		print("[OK] porte de nouveaute discriminante")
	else:
		print("[FAIL] porte non discriminante"); fails += 1
	quit(1 if fails > 0 else 0)
