extends SceneTree

const FastRoute = preload("res://addons/merlin_ai/fast_route.gd")

func _init() -> void:
	print("=== Tests FastRoute ===\n")

	var test_cases := [
		["J'attaque le gobelin avec mon epee", "combat", 0.6],
		["Je frappe l'ennemi", "combat", 0.6],
		["Je me defends contre l'attaque", "combat", 0.6],
		["Je parle au marchand", "dialogue", 0.6],
		["Bonjour, comment allez-vous ?", "dialogue", 0.6],
		["Je demande des informations au garde", "dialogue", 0.6],
		["J'examine la piece", "exploration", 0.6],
		["Je fouille le coffre", "exploration", 0.6],
		["J'entre dans la grotte", "exploration", 0.6],
		["Je prends la potion", "inventaire", 0.6],
		["J'equipe l'epee magique", "inventaire", 0.6],
		["Je regarde mon inventaire", "inventaire", 0.6],
		["Je lance un sort de feu", "magie", 0.6],
		["J'utilise la rune d'ogham", "magie", 0.6],
		["J'invoque un esprit", "magie", 0.6],
		["J'accepte la quete", "quete", 0.6],
		["Quel est mon objectif ?", "quete", 0.3],
		["Comment fonctionne la magie ?", "dialogue", 0.0],
		["Explique-moi les regles de combat", "dialogue", 0.0],
		["Je fais quelque chose", "", 0.0],
		["Hmm interessant", "", 0.0]
	]

	var passed := 0
	var failed := 0

	for test in test_cases:
		var input: String = test[0]
		var expected_category: String = test[1]
		var min_confidence: float = test[2]

		var result := FastRoute.classify(input)

		var category_ok: bool = result.category == expected_category or (expected_category == "" and result.confidence < 0.3)
		var confidence_ok: bool = result.confidence >= min_confidence or expected_category == ""

		if category_ok and confidence_ok:
			print("[PASS] %s" % input.substr(0, 40))
			passed += 1
		else:
			print("[FAIL] %s" % input.substr(0, 40))
			print("  Attendu: %s (>= %.1f)" % [expected_category, min_confidence])
			print("  Obtenu: %s (%.2f) [%s]" % [result.category, result.confidence, result.method])
			failed += 1

	print("\n=== Resultats ===")
	print("Passes: %d / %d" % [passed, passed + failed])
	print("Echoues: %d" % failed)

	print("\n=== Debug exemple ===")
	var debug = FastRoute.debug_scores("Je lance un sort de feu sur le gobelin")
	for key in debug.keys():
		print("  %s: %s" % [key, debug[key]])

	quit()
