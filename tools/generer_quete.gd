extends SceneTree
## Génère une quête de référence à partir d'un chapitre de la quête principale.
##
##     MERLIN_ALLOW_HEADLESS_LLM=1 godot --headless --path . \
##         --script res://tools/generer_quete.gd
##
##     MERLIN_CHAPITRE=3   le chapitre à écrire (défaut : le chapitre courant du squelette)
##     MERLIN_BEATS_Q=8    combien de beats (défaut 8 ; le canon autorise 8 à 25)
##     MERLIN_QUETE_OUT    où écrire (défaut : user://quete_generee.json)
##
## LE PARTAGE DU TRAVAIL, ET C'EST LUI QUI DÉCIDE DE TOUT. Le modèle n'écrit QUE de la prose et
## ne choisit QUE deux mots — une tuile et une rune. Toute la mécanique est calculée ici : la
## longueur, les types de beats, lesquels sont spéciaux, les bascules, les dés, les atouts, la
## pioche. Le modèle ne peut donc pas produire une quête non conforme : il n'a pas la main sur ce
## qui pourrait l'être.
##
## Une génération qui laisserait le modèle écrire `"de": 14` ou une tuile hors socle produirait
## une quête refusée par le contrat, et il faudrait relancer. Ici la seule chose qui peut mal se
## passer est que la prose soit mauvaise — ce qu'aucun validateur ne sait juger, et qu'il faut
## lire.
##
## LA RUNE EST VÉRIFIÉE, PAS SUPPOSÉE. Le modèle choisit dans la main qu'on lui montre ; s'il en
## nomme une autre, on reprend la plus proche de la main réelle plutôt que d'écrire une quête que
## le solveur de deck refusera ensuite.

const TUILES: Array = ["OBSERVER", "AGIR", "COMBATTRE", "RÉVÉLER", "PARLER"]
const TUILES_SENS: Dictionary = {
	"OBSERVER": "lire une scène avant d'y toucher",
	"AGIR": "faire de ses mains, avec adresse",
	"COMBATTRE": "y mettre le corps et tenir",
	"RÉVÉLER": "faire venir au jour ce qui se cache",
	"PARLER": "s'adresser à quelqu'un",
}
const RUNES: Dictionary = {
	"La Patience": "laisser venir plutôt qu'aller chercher",
	"La Méfiance": "supposer le pire et se garder",
	"La Franchise": "dire ce qui est, sans arranger",
	"L'Élan": "partir avant d'être sûr",
	"La Pitié": "s'arrêter pour ce qui souffre",
	"L'Entêtement": "recommencer sans changer d'avis",
	"Le Silence": "ne rien dire et laisser le vide travailler",
	"La Ruse": "prendre par un autre bord",
	"L'Aplomb": "tenir sa place devant plus grand que soi",
	"Le Deuil": "accepter ce qui ne reviendra pas",
}
const MAIN_DEPART: Array = ["La Patience", "La Méfiance", "La Franchise", "L'Élan"]
const NODE_TIMEOUT_MS: int = 180000
const GEN_OPTS: Dictionary = {"creative": true, "max_tokens": 260, "label": "quete"}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mn: Node = null
var _erreurs: Array = []
var _compte_erreurs: Dictionary = {}


func _init() -> void:
	_rng.randomize()
	call_deferred("_go")


func _go() -> void:
	var n_ch: int = int(OS.get_environment("MERLIN_CHAPITRE")) if OS.has_environment("MERLIN_CHAPITRE") else 0
	if n_ch <= 0:
		n_ch = MerlinQuete.chapitre_courant()
		if n_ch <= 0:
			n_ch = 1
	var ch: Dictionary = MerlinQuete.chapitre(n_ch)
	if ch.is_empty():
		print("chapitre %d inconnu" % n_ch)
		quit(1)
		return
	var n_beats: int = int(OS.get_environment("MERLIN_BEATS_Q")) if OS.has_environment("MERLIN_BEATS_Q") else 8
	n_beats = clampi(n_beats, 8, 25)

	print("=== GÉNÉRATION — chapitre %d : %s (%s) · %d beats ===" % [
		n_ch, str(ch.get("titre", "")), str(ch.get("lieu", "")), n_beats])

	_mn = await _attendre_moteur()
	if _mn == null:
		print("moteur indisponible")
		quit(1)
		return

	var lieu: Dictionary = _lire_json("res://data/biomes/%s.json" % str(ch.get("lieu", "")))
	var figures: Array = _figures_du_lieu(str(ch.get("lieu", "")))
	var squelette: Array = _squelette(n_beats)
	var q: Dictionary = {
		"id": "gen_ch%d" % n_ch, "titre": str(ch.get("titre", "")),
		"monde": "penn_ar_bed", "genere": true, "chapitre": n_ch,
		"runes": RUNES, "gestes": TUILES_SENS, "main_depart": MAIN_DEPART,
		"bourse_depart": 20, "integrite": {}, "corruption": {}, "beats": [],
	}

	q["preambule"] = await _preambule(ch, lieu)
	print("  préambule : %d phrase(s)" % (q["preambule"] as Array).size())

	var main: Array = MAIN_DEPART.duplicate()
	var precedent: String = ""
	for i in range(n_beats):
		var forme: Dictionary = squelette[i]
		var b: Dictionary = await _beat(ch, lieu, figures, forme, main, precedent, i + 1, n_beats)
		q["beats"].append(b)
		precedent = str(b.get("issue", ""))
		if not b.has("special"):
			main.erase(str(b["rune"]))
			main.append(_repiocher(main))
		print("  beat %2d/%d  %-11s %s" % [i + 1, n_beats, str(forme.get("t")),
			("SPÉCIAL " + str((b.get("special") as Dictionary).get("genre", ""))) if b.has("special")
			else "%s avec %s" % [str(b.get("action")), str(b.get("rune"))]])

	var sortie: String = OS.get_environment("MERLIN_QUETE_OUT")
	if sortie == "":
		sortie = "user://quete_generee.json"
	var f: FileAccess = FileAccess.open(sortie, FileAccess.WRITE)
	if f == null:
		print("écriture impossible : %s" % sortie)
		quit(1)
		return
	q["_erreurs_moteur"] = _compte_erreurs
	f.store_string(JSON.stringify(q, " "))
	f.close()
	print("\nécrit : %s (%d beats)" % [sortie, (q["beats"] as Array).size()])
	if not _compte_erreurs.is_empty():
		print("ERREURS DU MOTEUR — la prose est vide a cause de ceci :")
		for k in _compte_erreurs.keys():
			print("  %4d × %s" % [int(_compte_erreurs[k]), str(k)])
	quit(0)


# ── LA STRUCTURE, décidée ici et pas par le modèle ─────────────────────────────────────────────

## La forme de la quête : types, beats spéciaux, bascules, dés, atouts. Tout ce que le contrat
## vérifie est produit ici, donc tout ce que le contrat vérifie est juste par construction.
func _squelette(n: int) -> Array:
	var out: Array = []
	var i_choix: int = maxi(2, int(n * 0.4))          # la première décision, après que le sol ait bougé
	var i_choix2: int = mini(n - 2, int(n * 0.75))    # la seconde, quand on a de quoi décider
	for i in range(n):
		var k: int = i + 1
		var t: String = "Exploration"
		if k == n:
			t = "Climax"
		elif k == i_choix or k == i_choix2:
			t = "Dilemme"
		elif k % 3 == 2:
			t = "Rencontre"
		elif k % 3 == 0:
			t = "Épreuve"
		var forme: Dictionary = {"t": t}
		if t == "Dilemme":
			forme["special"] = "choix de dialogue" if k == i_choix2 else "choix de route"
		else:
			forme["dc"] = 12 if k == n else 9
			forme["at"] = [0, 3, 6, 6, 6][_rng.randi_range(0, 4)]
			forme["de"] = _rng.randi_range(1, 6) + _rng.randi_range(1, 6)
		if k == 2 or k == i_choix or k == i_choix2 or k == n:
			forme["bascule"] = ["choisie" if t == "Dilemme" else "subie", ""]
		out.append(forme)
	# Le socle doit être complet : on impose les cinq tuiles sur les cinq premiers beats ordinaires.
	var ordinaires: Array = []
	for i in range(out.size()):
		if not (out[i] as Dictionary).has("special"):
			ordinaires.append(i)
	for j in range(mini(5, ordinaires.size())):
		(out[ordinaires[j]] as Dictionary)["tuile_imposee"] = TUILES[j]
	return out


func _repiocher(main: Array) -> String:
	var libres: Array = []
	for r in RUNES.keys():
		if not main.has(r):
			libres.append(r)
	if libres.is_empty():
		return str(RUNES.keys()[0])
	return str(libres[_rng.randi_range(0, libres.size() - 1)])


# ── LA PROSE, écrite par le modèle ─────────────────────────────────────────────────────────────

const REGLES: String = """REGLES D'ECRITURE, sans exception :
- Langue simple. Aucune metaphore, aucune comparaison, aucune phrase retournee. On dit ce qui se passe, dans l'ordre.
- Chaque figure a un NOM et veut quelque chose. Jamais « une femme au visage fatigue ».
- Le mystere est dans l'ambiance, jamais dans le sens. Une phrase qui sonne profonde et ne veut rien dire est interdite.
- L'issue ne redit pas la scene : elle la deplace. Si la derniere phrase pouvait etre la premiere, recommence.
- Ce qui apparait revient. Pas d'objet ni d'animal qui traverse une scene et disparait.
- Aucun numero d'etape dans le texte. N'ecris jamais « 1. » ni « 2. » au debut d'une phrase."""


func _preambule(ch: Dictionary, lieu: Dictionary) -> Array:
	var sys: String = "Tu es MERLIN et tu paries au Voyageur. Francais simple, present, deuxieme personne."
	var usr: String = ("%s\n\nLIEU : %s. %s\nCE QUI S'Y JOUE : %s\n\n"
		+ "Ecris le PREAMBULE de cette quete en QUATRE phrases courtes, une par ligne. "
		+ "Il installe la scene du premier beat : ou l'on est, ce qu'on voit, ce qu'on entend. "
		+ "Il n'annonce NI le but, NI ce qu'il faudra faire. La quatrieme phrase rappelle que dans "
		+ "ces bois tout recommence, sauf le Voyageur.\nQuatre lignes, rien d'autre.") % [
			REGLES, str(lieu.get("nom", "")), str(lieu.get("resume", "")), str(ch.get("sujet", ""))]
	var txt: String = await _generer(sys, usr)
	var out: Array = []
	for l in txt.split("\n"):
		var s: String = str(l).strip_edges()
		if s != "" and not s.begins_with("#"):
			out.append(_nettoyer(s))
	return out.slice(0, 4) if out.size() > 4 else out


func _beat(ch: Dictionary, lieu: Dictionary, figures: Array, forme: Dictionary, main: Array,
		precedent: String, k: int, n: int) -> Dictionary:
	var b: Dictionary = {"n": k, "t": str(forme["t"]), "lieu": str(lieu.get("nom", ""))}
	if forme.has("bascule"):
		b["bascule"] = forme["bascule"]

	if forme.has("special"):
		b["special"] = await _beat_choix(ch, forme, precedent, k)
		b["scene"] = str(b["special"]["_scene"])
		b["special"].erase("_scene")
		b["issue"] = await _issue_choix(b["special"], precedent)
		b["note"] = ("Beat special : ni tuile, ni rune, ni de. On selectionne parmi %d propositions, "
			+ "et aucune n'est neutre.") % (b["special"]["options"] as Array).size()
		if b.has("bascule"):
			b["bascule"] = ["choisie", str((b["special"]["options"] as Array)[0][0]).to_lower()]
		return b

	var tuile: String = str(forme.get("tuile_imposee", ""))
	var couple: Dictionary = await _choisir_geste(ch, lieu, figures, main, precedent, k, n, tuile)
	b["action"] = str(couple["tuile"])
	b["rune"] = str(couple["rune"])
	b["dc"] = int(forme["dc"])
	b["at"] = int(forme["at"])
	b["de"] = int(forme["de"])
	var marge: int = b["de"] + b["at"] - b["dc"]
	b["scene"] = str(couple["scene"])
	b["issue"] = await _issue(b, precedent, marge)
	b["note"] = ("%s avec %s. Marge %+d — %s. La tuile dit ce qu'on fait, la rune dit avec quoi ; "
		+ "c'est le modele qui a lu la paire.") % [b["action"], b["rune"], marge, _degre(marge)]
	if b.has("bascule"):
		b["bascule"] = ["subie", "ce que le lieu impose"]
	return b


func _choisir_geste(ch: Dictionary, lieu: Dictionary, figures: Array, main: Array,
		precedent: String, k: int, n: int, tuile_imposee: String) -> Dictionary:
	var noms: String = ""
	for f in figures:
		noms += "%s (%s) ; " % [str((f as Dictionary).get("nom", "")), str((f as Dictionary).get("resume", ""))]
	var sys: String = "Tu ecris un jeu narratif celtique. Francais simple, present, deuxieme personne (« Vous »)."
	var usr: String = ("%s\n\nLIEU : %s. %s\nFIGURES QU'ON PEUT RENCONTRER ICI : %s\n"
		+ "CE QUI S'Y JOUE : %s\n%s\n\n"
		+ "Ecris la SCENE du beat %d sur %d (type : %s), en TROIS phrases courtes. "
		+ "Elle decoule de ce qui precede. Elle finit sur un instant suspendu, sans poser de question.\n"
		+ "Puis, sur une derniere ligne, ecris exactement : GESTE: <TUILE> | <RUNE>\n"
		+ "TUILE %s\nRUNE, une seule de cette main : %s\n"
		+ "Choisis la paire qui rend la scene la plus juste.") % [
			REGLES, str(lieu.get("nom", "")), str(lieu.get("resume", "")), noms,
			str(ch.get("sujet", "")),
			("CE QUI PRECEDE : " + precedent) if precedent != "" else "C'est le premier beat.",
			k, n, str(_type_court(str(ch.get("lieu", "")))),
			("imposee : " + tuile_imposee) if tuile_imposee != "" else ("au choix : " + ", ".join(TUILES)),
			", ".join(main)]
	var txt: String = await _generer(sys, usr)
	var scene: String = ""
	var tuile: String = tuile_imposee
	var rune: String = ""
	for l in txt.split("\n"):
		var s: String = str(l).strip_edges()
		if s == "":
			continue
		if s.to_upper().begins_with("GESTE"):
			var apres: String = s.substr(s.find(":") + 1)
			var bouts: PackedStringArray = apres.split("|")
			if bouts.size() >= 2:
				if tuile_imposee == "":
					tuile = _plus_proche(str(bouts[0]).strip_edges(), TUILES)
				rune = _plus_proche(str(bouts[1]).strip_edges(), main)
		else:
			scene += ("" if scene == "" else " ") + _nettoyer(s)
	if tuile == "":
		tuile = TUILES[_rng.randi_range(0, TUILES.size() - 1)]
	if rune == "":
		rune = str(main[_rng.randi_range(0, main.size() - 1)])
	return {"scene": scene, "tuile": tuile, "rune": rune}


func _issue(b: Dictionary, precedent: String, marge: int) -> String:
	var sys: String = "Tu ecris un jeu narratif celtique. Francais simple, present, deuxieme personne."
	var usr: String = ("%s\n\nLA SCENE : %s\nLE GESTE POSE : %s (%s) avec %s (%s)\n"
		+ "LE RESULTAT : %s\n\nEcris l'ISSUE en TROIS phrases courtes : ce que le Voyageur fait, "
		+ "et ce que ca change. Elle ne redit pas la scene, elle la deplace. "
		+ "Le geste pose doit se LIRE dans ce qui est ecrit.\nTrois phrases, rien d'autre.") % [
			REGLES, str(b["scene"]), str(b["action"]), str(TUILES_SENS.get(b["action"], "")),
			str(b["rune"]), str(RUNES.get(b["rune"], "")), _resultat_en_clair(marge)]
	return _nettoyer(await _generer(sys, usr))


func _beat_choix(ch: Dictionary, forme: Dictionary, precedent: String, k: int) -> Dictionary:
	var sys: String = "Tu ecris un jeu narratif celtique. Francais simple, present, deuxieme personne."
	var usr: String = ("%s\n\nCE QUI PRECEDE : %s\nCE QUI S'Y JOUE : %s\n\n"
		+ "Ecris un beat de DECISION (%s), ainsi :\n"
		+ "SCENE: deux phrases qui posent le choix, sans le resoudre.\n"
		+ "OPTION: <ce qu'on fait> || <ce que ca entraine>\n"
		+ "OPTION: <ce qu'on fait> || <ce que ca entraine>\n"
		+ "OPTION: <ce qu'on fait> || <ce que ca entraine>\n"
		+ "TROIS options, et AUCUNE ne doit etre gratuite : chacune coute quelque chose de "
		+ "nommable. Si l'une est manifestement la bonne, recommence.") % [
			REGLES, precedent if precedent != "" else "rien", str(ch.get("sujet", "")),
			str(forme["special"])]
	var txt: String = await _generer(sys, usr)
	var scene: String = ""
	var options: Array = []
	for l in txt.split("\n"):
		var s: String = str(l).strip_edges()
		if s.to_upper().begins_with("SCENE"):
			scene = _nettoyer(s.substr(s.find(":") + 1))
		elif s.to_upper().begins_with("OPTION"):
			var corps: String = s.substr(s.find(":") + 1)
			var bouts: PackedStringArray = corps.split("||")
			if bouts.size() >= 2:
				options.append([_nettoyer(str(bouts[0])), _nettoyer(str(bouts[1]))])
	while options.size() < 2:
		options.append(["Ne rien faire", "le temps passe, et rien ne change en votre faveur."])
	return {"genre": str(forme["special"]), "pris": 0,
			"options": options.slice(0, 4), "_scene": scene if scene != "" else "Il faut trancher."}


func _issue_choix(sp: Dictionary, precedent: String) -> String:
	var pris: Array = (sp["options"] as Array)[int(sp["pris"])]
	var sys: String = "Tu ecris un jeu narratif celtique. Francais simple, present, deuxieme personne."
	var usr: String = ("%s\n\nLE VOYAGEUR CHOISIT : %s\nCE QUE CA ENTRAINE : %s\n\n"
		+ "Ecris en TROIS phrases courtes ce qui se passe une fois ce choix fait. "
		+ "Pas de commentaire, pas de morale. Trois phrases, rien d'autre.") % [
			REGLES, str(pris[0]), str(pris[1])]
	return _nettoyer(await _generer(sys, usr))


# ── outillage ──────────────────────────────────────────────────────────────────────────────────

## LA QUETE PORTE SES PROPRES ERREURS. Au premier essai reel, les huit beats sont revenus vides :
## chaque appel avait echoue, et le fichier produit ne disait pas pourquoi — il fallait aller
## chercher un log sur la VM pour apprendre laquelle des six erreurs du moteur s'etait produite.
## Une sortie qui ne sait pas dire ce qui lui est arrive coute un aller-retour a chaque diagnostic.
func _generer(sys: String, usr: String) -> String:
	if _mn == null or not _mn.is_ready():
		_noter_erreur("moteur non pret au moment de l'appel")
		return ""
	var r: Dictionary = await _mn.generate(sys, usr, GEN_OPTS)
	if r.has("error"):
		_noter_erreur(str(r["error"]))
		push_warning("[generer_quete] %s" % str(r["error"]))
		return ""
	var txt: String = str(r.get("text", "")).strip_edges()
	if txt == "":
		_noter_erreur("le moteur a rendu un texte vide sans erreur")
	return txt


func _noter_erreur(quoi: String) -> void:
	_erreurs.append(quoi)
	var n: int = int(_compte_erreurs.get(quoi, 0))
	_compte_erreurs[quoi] = n + 1


## Retire ce qui n'a rien a faire dans la prose : numeros d'etape (defaut mesure sur p74),
## puces, guillemets de code, et les marqueurs que le modele ajoute parfois de lui-meme.
func _nettoyer(s: String) -> String:
	var t: String = str(s).strip_edges()
	var re: RegEx = RegEx.new()
	re.compile("^\\s*(?:[0-9]+[.)]|[-*•])\\s+")
	t = re.sub(t, "", true)
	re.compile("\\s(?:[0-9]+[.)])\\s")
	t = re.sub(t, " ", true)
	t = t.replace("```", "").replace("**", "").strip_edges()
	return t


func _plus_proche(brut: String, parmi: Array) -> String:
	var b: String = brut.to_lower().strip_edges()
	for x in parmi:
		if str(x).to_lower() == b:
			return str(x)
	for x in parmi:
		if b.contains(str(x).to_lower()) or str(x).to_lower().contains(b):
			return str(x)
	return ""


func _degre(m: int) -> String:
	if m >= 8:
		return "eclatante"
	if m >= 0:
		return "reussite"
	if m >= -5:
		return "partiel"
	return "echec"


func _resultat_en_clair(m: int) -> String:
	match _degre(m):
		"eclatante":
			return "une reussite ECLATANTE — mieux que prevu, et ca se voit"
		"reussite":
			return "une REUSSITE, sans plus : ca marche, ca ne triomphe pas"
		"partiel":
			return "un PARTIEL — le Voyageur obtient ce qu'il voulait mais le paie"
		_:
			return "un ECHEC — le geste rate, et la suite en sera plus chere"


func _type_court(lieu: String) -> String:
	return lieu


func _lire_json(chemin: String) -> Dictionary:
	var f: FileAccess = FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return {}
	var b: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return b if typeof(b) == TYPE_DICTIONARY else {}


func _figures_du_lieu(lieu: String) -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open("res://data/figures")
	if d == null:
		return out
	d.list_dir_begin()
	var nom: String = d.get_next()
	while nom != "":
		if nom.ends_with(".json") or nom.ends_with(".json.remap"):
			var cle: String = nom.get_basename()
			if cle.ends_with(".json"):
				cle = cle.get_basename()
			var fig: Dictionary = _lire_json("res://data/figures/%s.json" % cle)
			var lx: Variant = fig.get("lieux", fig.get("lieu", ""))
			var ici: bool = false
			if typeof(lx) == TYPE_ARRAY:
				ici = (lx as Array).has(lieu)
			else:
				ici = str(lx) == lieu
			if ici or str(fig.get("faction", "")) == "transversal":
				out.append(fig)
		nom = d.get_next()
	d.list_dir_end()
	return out.slice(0, 4) if out.size() > 4 else out


func _attendre_moteur() -> Node:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < NODE_TIMEOUT_MS:
		var n: Node = root.get_node_or_null("/root/MerlinNative")
		if n != null and n.has_method("is_ready") and n.is_ready():
			return n
		await create_timer(1.0).timeout
	return null
