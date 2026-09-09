extends SceneTree
## SONDE — ce que le modèle reçoit vraiment, beat par beat, avec la courbe du 09/09.
##
##     godot --headless --path . --script res://tools/probe_courbe_prompts.gd
##
## Elle n'appelle AUCUN modèle : elle imprime le plan d'une quête de 24 beats (la longueur de p104,
## celle qui tournait à plat) et le prompt COMPLET de trois beats témoins — l'arrivée, le Tour, la
## confrontation. C'est la preuve lisible que la quête monte, que le rôle change, et que la scène
## reçoit une matière et un registre.

func _init() -> void:
	var titre: String = "Le Chant du Chene Creux"
	var pitch: String = "Va voir si les racines du grand Chene Creux retiennent encore le secret d'un pacte ancien."
	var total: int = 24
	var graine: int = MerlinCourbe.graine_de(titre)
	var matieres: String = str((MerlinPromptBuilder.BIOMES["foret_broceliande"] as Dictionary)["matiere"])
	print("=== LA COURBE DE « %s » — %d beats (graine %d) ===\n" % [titre, total, graine])
	for i in total:
		var mv: String = MerlinCourbe.mouvement(i, total)
		var mat: String = MerlinCourbe.matiere(matieres, i, graine)
		var role: String = MerlinCourbe.role(i, total, titre, graine, "Kado le Cordier")
		print("  b%02d  %-14s %-26s %s" % [i + 1, mv, mat, role.substr(0, 84)])

	var temoins: Array = [0, MerlinCourbe.beat_du_tour(total), total - 1]
	var ctx: Dictionary = {
		"biome": "foret",
		"registre": "le Chevalier cherche la meme chose ; la corde est trop courte ; Kado a menti sur le compte",
		"figure_croisee": "Kado le Cordier",
	}
	for pos in temoins:
		var p: Dictionary = MerlinPromptBuilder.scene_jit(
			{"title": titre, "pitch": pitch}, "Rencontre", pos, total,
			["Instinct", "Nature"], "Vous avez tire la corde et elle a tenu.",
			"vous avez vu ce qui se cachait", "", "Broceliande",
			["Instinct", "Nature", "Ruse"], "Kado le Cordier : allie (votre aide, moment 4)", ctx)
		print("\n\n────────── PROMPT DU BEAT %d sur %d (%s) ──────────" % [
			pos + 1, total, MerlinCourbe.mouvement(pos, total)])
		print(str(p["user"]).substr(maxi(0, str(p["user"]).length() - 1400)))
	quit(0)
