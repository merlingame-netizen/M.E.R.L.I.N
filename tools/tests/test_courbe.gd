extends SceneTree
## Épreuve de LA COURBE DE LA QUÊTE et du REGISTRE (09/09, décisions de Maxime : « la continuité,
## varier les situations, du dynamisme et des rebondissements »).
##
##     godot --headless --path . --script res://tools/tests/test_courbe.gd
##
## CE QU'ELLE VÉRIFIE, et pourquoi chacun compte :
##   LES CINQ MOUVEMENTS    p104 tournait sur quatre rôles en boucle : la quête doit MONTER.
##   LE TOUR TOMBE UNE FOIS un rebondissement qui se répète n'en est plus un.
##   AUCUNE RÉPÉTITION      deux beats voisins ne peuvent pas demander la même chose.
##   LA MATIÈRE CHANGE      « la brume monte » trois fois de suite, c'est ce qu'on corrige.
##   LES QUÊTES COURTES     2, 3, 4 beats : la courbe ne doit pas plier.
##   LE REGISTRE            cinq faits, pas de doublon, pas de vide, le plus ancien sort.
##   L'ACQUIS S'EXTRAIT     la ligne « ACQUIS : … » sort du texte, même après une parole.

var _rates: int = 0


func _verifier(nom: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ok    %s" % nom)
	else:
		_rates += 1
		print("  RATE  %s%s" % [nom, ("  — " + detail) if detail != "" else ""])


func graine_test() -> int:
	return MerlinCourbe.graine_de("Le Chant du Chene Creux")


func _init() -> void:
	print("=== ÉPREUVE DE LA COURBE ET DU REGISTRE ===\n")

	# ── LES CINQ MOUVEMENTS sur une quête longue (la longueur de p104)
	var total: int = 24
	var mvs: Array = []
	for i in total:
		mvs.append(MerlinCourbe.mouvement(i, total))
	_verifier("le premier beat est l'arrivée", str(mvs[0]) == MerlinCourbe.ARRIVEE, str(mvs[0]))
	_verifier("le dernier beat est la confrontation", str(mvs[total - 1]) == MerlinCourbe.CONFRONTATION, str(mvs[total - 1]))
	_verifier("l'avant-dernier aussi (le choix qui engage la fin)", str(mvs[total - 2]) == MerlinCourbe.CONFRONTATION, str(mvs[total - 2]))
	var n_tour: int = 0
	for m in mvs:
		if str(m) == MerlinCourbe.TOUR:
			n_tour += 1
	# Une quête longue porte DEUX tours (Maxime : « des rebondissements ») ; une courte, un seul.
	_verifier("une quête de 24 beats porte deux tours", n_tour == 2, "%d tour(s)" % n_tour)
	_verifier("une quête de 10 beats n'en porte qu'un", MerlinCourbe.beats_du_tour(10).size() == 1,
		str(MerlinCourbe.beats_du_tour(10)))
	var tours: Array = MerlinCourbe.beats_du_tour(total)
	_verifier("les deux tours ne sont jamais voisins", int(tours[1]) - int(tours[0]) >= 3, str(tours))
	_verifier("le second tour prend l'autre forme que le premier",
		MerlinCourbe.forme_du_tour(total, graine_test(), "Kado le Cordier", int(tours[0]))
			!= MerlinCourbe.forme_du_tour(total, graine_test(), "Kado le Cordier", int(tours[1])),
		"%s / %s" % [MerlinCourbe.forme_du_tour(total, graine_test(), "Kado", int(tours[0])),
			MerlinCourbe.forme_du_tour(total, graine_test(), "Kado", int(tours[1]))])
	var t: int = MerlinCourbe.beat_du_tour(total)
	_verifier("le premier Tour tombe avant le milieu, jamais au début", t >= 2 and t <= total - 3, "beat %d sur %d" % [t + 1, total])
	_verifier("la piste précède le Tour", str(mvs[t - 1]) == MerlinCourbe.PISTE, str(mvs[t - 1]))
	_verifier("la montée suit le Tour", str(mvs[t + 1]) == MerlinCourbe.MONTEE, str(mvs[t + 1]))
	# Les cinq mouvements existent tous, dans l'ordre.
	var vus: Array = []
	for m in mvs:
		if not vus.has(str(m)):
			vus.append(str(m))
	_verifier("les cinq mouvements se suivent dans l'ordre",
		vus == [MerlinCourbe.ARRIVEE, MerlinCourbe.PISTE, MerlinCourbe.TOUR, MerlinCourbe.MONTEE, MerlinCourbe.CONFRONTATION],
		str(vus))

	# ── AUCUN RÔLE DEUX FOIS DE SUITE
	var graine: int = MerlinCourbe.graine_de("Le Chant du Chene Creux")
	var repets: int = 0
	var precedent: String = ""
	for i in total:
		var r: String = MerlinCourbe.role(i, total, "Le Chant du Chene Creux", graine)
		if r == precedent:
			repets += 1
		precedent = r
	_verifier("aucun rôle ne se répète deux beats de suite", repets == 0, "%d répétition(s)" % repets)

	# ── LA MATIÈRE CHANGE À CHAQUE BEAT
	var matieres: String = "mousse gorgee d'eau, chenes tordus, houx, gui, souches creuses, sentiers qui se referment"
	var m_prec: String = ""
	var m_repets: int = 0
	var m_vues: Dictionary = {}
	for i in total:
		var m: String = MerlinCourbe.matiere(matieres, i, graine)
		if m == m_prec:
			m_repets += 1
		m_prec = m
		m_vues[m] = true
	_verifier("la matière change à chaque beat", m_repets == 0, "%d répétition(s)" % m_repets)
	_verifier("les six matières du lieu servent toutes", m_vues.size() == 6, "%d matière(s)" % m_vues.size())

	# ── LA FORME DU TOUR : l'être ne se retourne que s'il a été croisé
	var sans_figure: String = MerlinCourbe.forme_du_tour(total, graine, "")
	_verifier("sans figure croisée, le Tour est « le but n'était pas le but »",
		sans_figure == MerlinCourbe.TOUR_BUT, sans_figure)
	var avec: int = 0
	for g in 20:
		if MerlinCourbe.forme_du_tour(total, g, "Kado le Cordier") == MerlinCourbe.TOUR_ETRE:
			avec += 1
	_verifier("avec une figure croisée, les deux formes existent", avec > 0 and avec < 20, "%d/20 « l'être se retourne »" % avec)
	var role_tour: String = MerlinCourbe.role(t, total, "Le Chant du Chene Creux", graine, "Kado le Cordier")
	_verifier("le rôle du Tour nomme le retournement",
		role_tour.contains("TOUR"), role_tour.substr(0, 60))

	# ── LES QUÊTES COURTES NE PLIENT PAS
	for court in [2, 3, 4, 5]:
		var ok: bool = true
		for i in court:
			var mv: String = MerlinCourbe.mouvement(i, court)
			if mv == "":
				ok = false
			if MerlinCourbe.role(i, court, "Court", 3).strip_edges() == "":
				ok = false
		_verifier("une quête de %d beats a une courbe complète" % court, ok)
	_verifier("le premier beat d'une quête de 2 est l'arrivée", MerlinCourbe.mouvement(0, 2) == MerlinCourbe.ARRIVEE)
	_verifier("le second est la confrontation", MerlinCourbe.mouvement(1, 2) == MerlinCourbe.CONFRONTATION)
	_verifier("une quête de 4 n'a pas de Tour (trop courte pour un retournement)",
		MerlinCourbe.beat_du_tour(4) == -1, str(MerlinCourbe.beat_du_tour(4)))
	# Aucune longueur ne doit produire un plan bancal : tours dans les bornes, ordonnés, non voisins.
	var bancal: int = 0
	for n in range(2, 41):
		var ts: Array = MerlinCourbe.beats_du_tour(n)
		for k in ts.size():
			var v: int = int(ts[k])
			if v < 2 or v > n - 3:
				bancal += 1
			if k > 0 and v - int(ts[k - 1]) < 3:
				bancal += 1
		if MerlinCourbe.mouvement(0, n) != MerlinCourbe.ARRIVEE:
			bancal += 1
		if MerlinCourbe.mouvement(n - 1, n) != MerlinCourbe.CONFRONTATION:
			bancal += 1
	_verifier("de 2 à 40 beats, aucun plan bancal", bancal == 0, "%d anomalie(s)" % bancal)

	# ── L'ÉTAT SE LIT
	var etat: String = MerlinCourbe.etat(3, total)
	_verifier("l'état dit où l'on en est", etat.contains("piste") and etat.contains("beat 4"), etat)

	# ── LE REGISTRE DES FAITS ACQUIS
	var RunScript: GDScript = load("res://scripts/game/merlin_run.gd")
	var run: Node = RunScript.new()
	_verifier("le registre est vide au départ", str(run.registre()) == "")
	_verifier("un fait vide est refusé", not bool(run.noter_acquis("  ")))
	_verifier("un fait trop court est refusé", not bool(run.noter_acquis("ok")))
	_verifier("un fait entre", bool(run.noter_acquis("le Chevalier cherche la meme chose que vous")))
	_verifier("le même fait ne rentre pas deux fois", not bool(run.noter_acquis("Le Chevalier cherche la meme chose que vous")))
	_verifier("le registre le rend", str(run.registre()).begins_with("le Chevalier cherche"), str(run.registre()))
	for i in 6:
		run.noter_acquis("fait numero %d de la traversee" % i)
	_verifier("le registre garde cinq faits au plus", (run.faits_acquis as Array).size() == 5,
		"%d faits" % (run.faits_acquis as Array).size())
	_verifier("le plus ancien est sorti", not str(run.registre()).contains("Chevalier"), str(run.registre()))
	_verifier("un fait trop long est coupé à dix mots",
		str(run.noter_acquis("un deux trois quatre cinq six sept huit neuf dix onze douze")) == "true"
			and (str((run.faits_acquis as Array)[-1]).split(" ", false) as PackedStringArray).size() == 10,
		str((run.faits_acquis as Array)[-1]))
	run.free()

	# ── L'ACQUIS S'EXTRAIT DU TEXTE, MÊME APRÈS UNE PAROLE
	var issue: String = "[i]Vous poussez la dalle.[/i] Le passage s'ouvre. Kado recule d'un pas.\nKado le Cordier — las : « Je ne monterai pas. »\nACQUIS : Kado refuse de monter la corde"
	var a: Dictionary = MerlinProse.extraire_acquis(issue)
	_verifier("le fait acquis est reconnu", str(a["fait"]) == "Kado refuse de monter la corde", str(a["fait"]))
	_verifier("il est retiré du texte affiché", not str(a["reste"]).contains("ACQUIS"), str(a["reste"]).substr(0, 60))
	var parole: Dictionary = MerlinProse.extraire_parole(str(a["reste"]))
	_verifier("la parole reste lisible sous l'acquis retiré", str(parole["dit"]) == "Je ne monterai pas.", str(parole["dit"]))
	_verifier("un texte sans acquis n'est pas touché",
		str(MerlinProse.extraire_acquis("Le passage s'ouvre.")["fait"]) == "")

	print("\n%s" % ("ÉPREUVE PASSÉE (0 échec)" if _rates == 0 else "ÉPREUVE RATÉE (%d échec(s))" % _rates))
	quit(0 if _rates == 0 else 1)
