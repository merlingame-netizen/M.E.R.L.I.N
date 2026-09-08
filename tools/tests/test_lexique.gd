extends SceneTree
## Épreuve du lexique de Merlin : les clés existent, le ton est tenu, les douze biomes sont cadrés.
##
##     godot --headless --path . --script res://tools/tests/test_lexique.gd
##
## POURQUOI. Un lexique écrit à la main peut se déformer en silence : une clé renommée, un tiret
## cadratin glissé (interdit dans la voix de Merlin depuis la consigne du scénario), un biome oublié
## quand on en ajoute un. Cette épreuve le dit avant que le joueur ne lise une case vide.

var _rates: int = 0

const CLES: Array = ["attente.reve", "attente.trace", "attente.tisse", "verdict.eclatante",
	"verdict.reussite", "verdict.partiel", "verdict.echec", "choix.avant", "choix.apres",
	"sentier.ouverture", "fin.mort", "fin.corruption", "fin.victoire", "fin.retour"]


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func _init() -> void:
	print("=== ÉPREUVE DU LEXIQUE DE MERLIN ===\n")
	for c in CLES:
		var l: Array = MerlinLexique.lignes(str(c))
		_verifier("%s a au moins deux lignes" % c, l.size() >= 2, "%d" % l.size())
		for ligne in l:
			var s: String = str(ligne)
			_verifier("%s : « %s » tient sur une ligne courte" % [c, s.substr(0, 24)], s.length() <= 90 and s.length() >= 8,
				"%d caractères" % s.length())
			_verifier("%s : pas de tiret cadratin" % c, not s.contains("—"), s)
	# LE TIRAGE NE BÉGAIE PAS : deux tirages de suite ne rendent jamais la même ligne quand il y en a d'autres.
	var doublons: int = 0
	var prev: String = MerlinLexique.tirer("verdict.echec")
	for i in 40:
		var cur: String = MerlinLexique.tirer("verdict.echec")
		if cur == prev:
			doublons += 1
		prev = cur
	_verifier("deux tirages de suite ne donnent jamais la même ligne", doublons == 0, "%d doublon(s)" % doublons)
	_verifier("une clé inconnue rend le repli", MerlinLexique.tirer("nexiste.pas", "repli") == "repli")
	_verifier("verdict() sert un degré", MerlinLexique.verdict("partiel") != "")
	# LES DOUZE BIOMES, ceux de data/biomes/, tous cadrés.
	var attendus: Array = []
	var d: DirAccess = DirAccess.open("res://data/biomes")
	if d != null:
		d.list_dir_begin()
		var n: String = d.get_next()
		while n != "":
			if n.ends_with(".json"):
				attendus.append(n.trim_suffix(".json"))
			n = d.get_next()
		d.list_dir_end()
	var manquants: Array = []
	for b in attendus:
		if MerlinLexique.biome(str(b)) == "" or not MerlinLexique.biomes_cadres().has(b):
			manquants.append(b)
	_verifier("les %d biomes du jeu sont cadrés" % attendus.size(), attendus.size() >= 12 and manquants.is_empty(), str(manquants))
	for b in MerlinLexique.biomes_cadres():
		var t: String = MerlinLexique.biome(str(b))
		_verifier("cadrage %s : deux souffles, « Avance : », sans tiret cadratin" % b,
			t.contains("Voyageur") and t.contains("Avance :") and not t.contains("—") and t.length() <= 260,
			"%d caractères" % t.length())
	_verifier("le scénario et le lexique disent la même chose pour la forêt",
		str((load("res://scripts/llm/merlin_scenario.gd") as GDScript).get_script_constant_map()["WORLD_SETUP_SHORT"]["foret"]) == MerlinLexique.biome("foret"))
	print("\n%s (%d échec%s)" % ["ÉPREUVE PASSÉE" if _rates == 0 else "ÉPREUVE ÉCHOUÉE", _rates, "s" if _rates > 1 else ""])
	quit(1 if _rates > 0 else 0)
