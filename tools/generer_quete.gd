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
# Une generation d'amorce de MerlinScenario dure une minute environ ; une generation de beat
# jusqu'a deux. Trois minutes couvrent les deux sans masquer un vrai blocage.
const VOIE_TIMEOUT_MS: int = 180000
const GEN_OPTS: Dictionary = {"creative": true, "max_tokens": 400, "label": "quete"}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mn: Node = null
var _erreurs: Array = []
var _compte_erreurs: Dictionary = {}
var _t0: int = 0


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

	_t0 = Time.get_ticks_msec()
	print("=== GÉNÉRATION — chapitre %d : %s (%s) · %d beats ===" % [
		n_ch, str(ch.get("titre", "")), str(ch.get("lieu", "")), n_beats])

	# FAIRE TAIRE LE SCENARIO — ET AVANT D'ATTENDRE LE MOTEUR, PAS APRES.
	#
	# q80 a genere six beats en cinquante-cinq minutes, dont huit d'attente par beat : le moteur est
	# mono-place par voie, et MerlinScenario amorce sa voix des que le modele est charge. Mettre le
	# scenario au repos reglait la suite, mais pas l'amorce elle-meme — q84 et q86 ont encore paye
	# 227 secondes AVANT le premier beat, soit 45 % du budget d'une generation.
	#
	# La raison est un ordre : `_attendre_moteur()` rend la main quand `is_ready()` est vrai, donc
	# APRES que `model_ready` soit tombe — et l'amorce, branchee dessus en one-shot, est deja partie.
	# Couper le signal ensuite ne sert a rien. On le coupe donc AVANT d'attendre : le modele met une
	# trentaine de secondes a charger, ce qui laisse tout le temps de defaire la connexion.
	#
	# Ce harnais n'utilise pas le scenario — MerlinQuete est statique — donc rien ne casse. L'amorce
	# n'est de toute facon qu'un prechauffage : « un prechauffage rate ne doit jamais devenir une
	# panne visible », dit son propre commentaire.
	var sc: Node = root.get_node_or_null("/root/MerlinScenario")
	if sc != null:
		sc.set_process(false)
		sc.set_physics_process(false)
		print("  MerlinScenario mis au repos (il se disputait la voie du moteur)")
		print("  amorce du scenario coupee : %d connexion(s) defaite(s)" % _couper_amorce(sc))

	_mn = await _attendre_moteur()
	if _mn == null:
		print("moteur indisponible")
		quit(1)
		return
	# Si l'amorce est partie malgre tout (moteur deja pret au demarrage du harnais), on la laisse
	# finir plutot que de se faire refuser a chaque appel.
	if _mn.has_method("est_occupe") and _mn.est_occupe("conteur"):
		print("  la voie est prise malgre la coupure — on attend qu'elle se libere")
		if not await _attendre_voie("conteur", VOIE_TIMEOUT_MS):
			print("  la voie conteur ne se libere pas — on tente quand meme")
	else:
		print("  voie libre d'entree")

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
	var issues: Array = []
	for i in range(n_beats):
		var forme: Dictionary = squelette[i]
		var b: Dictionary = await _beat(ch, lieu, figures, forme, main,
			" ".join(issues.slice(maxi(0, issues.size() - 2))), i + 1, n_beats)
		q["beats"].append(b)
		issues.append(str(b.get("issue", "")))
		if not b.has("special"):
			main.erase(str(b["rune"]))
			main.append(_repiocher(main))
		print("  beat %2d/%d  %4ds  %-11s %s" % [i + 1, n_beats,
			int((Time.get_ticks_msec() - _t0) / 1000), str(forme.get("t")),
			("SPÉCIAL " + str((b.get("special") as Dictionary).get("genre", ""))) if b.has("special")
			else "%s avec %s" % [str(b.get("action")), str(b.get("rune"))]])

	# L'ECRITURE DIT OU ELLE VA, ET SE RABAT SI ELLE NE PEUT PAS. q81 a genere sept beats sur huit
	# puis s'est arretee sans fichier : le message « ecriture impossible » existait deja, mais le
	# filtre de log du job ne le cherchait pas — j'ai filtre la reponse. Desormais le chemin est
	# annonce AVANT d'ecrire, et un echec se rabat sur user:// plutot que de tout perdre : sept
	# beats generes valent mieux qu'un fichier absent, meme ranges ailleurs que prevu.
	var sortie: String = OS.get_environment("MERLIN_QUETE_OUT")
	if sortie == "":
		sortie = "user://quete_generee.json"
	print("écriture vers : %s (absolu : %s)" % [sortie, ProjectSettings.globalize_path(sortie)])
	var f: FileAccess = FileAccess.open(sortie, FileAccess.WRITE)
	if f == null:
		var err: int = FileAccess.get_open_error()
		print("ÉCRITURE IMPOSSIBLE vers %s (erreur %d) — repli sur user://" % [sortie, err])
		sortie = "user://quete_generee.json"
		f = FileAccess.open(sortie, FileAccess.WRITE)
		if f == null:
			print("ÉCRITURE IMPOSSIBLE même sur user:// — la quête est perdue")
			quit(1)
			return
		print("replié sur : %s" % ProjectSettings.globalize_path(sortie))
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


## LA MARCHE DE CE BEAT. q82 avait une mecanique parfaite et une histoire ou rien n'arrivait :
## huit beats interchangeables, chacun juste apres le precedent et avant rien. Le modele n'a pas
## d'arc en tete — il n'ecrit qu'un beat a la fois et ne voit que la derniere issue. L'arc est donc
## calcule ici, comme la longueur et les des, et chaque appel recoit SA MARCHE : ce que ce beat-la
## doit avoir accompli quand il se termine. Meme decision que pour la mecanique — ce que le modele
## ne sait pas tenir, le harnais le tient a sa place.
func _marche(k: int, n: int) -> String:
	if k == 1:
		return ("ON ARRIVE. Poser le lieu, puis montrer UNE chose qui ne va pas. A la fin du beat "
			+ "a la fin du beat, l'anomalie a ete vue sans etre comprise.")
	if k == n:
		return ("ON TRANCHE. Ce qui a ete pose au premier beat se regle — bien ou mal, mais ne reste "
			+ "pas ouvert. Dire ce qui est emporte en partant.")
	var p: float = float(k - 1) / float(n - 1)
	if p <= 0.3:
		return "ON S'APPROCHE. Apprendre A QUI ou A QUOI on a affaire, et le NOMMER."
	if p <= 0.5:
		return "ON COMPREND. Dire ce qui est en jeu, et qui va perdre quoi si personne ne bouge."
	if p <= 0.7:
		return "CA SE COMPLIQUE. Un fait nouveau rend impossible la solution qui semblait evidente."
	if p <= 0.85:
		return "ON PAIE. Quelque chose est perdu, ou lache pour en garder une autre."
	return "DERNIER OBSTACLE. Un empechement concret, juste avant la fin."


## CE QUI EST EN JEU, DIT AUTREMENT SELON L'ENDROIT DE LA QUETE. q86 a donne le Rameau Fendu au
## beat 1 et l'Eclat au beat 2 : chaque prompt lui annoncait ce que la quete devait rapporter, il
## a lu une liste de courses et l'a faite immediatement. Il ne restait rien a jouer sur six beats.
## Le but est donc un ENJEU tant qu'on n'est pas au bout, et une ACQUISITION seulement au dernier
## beat — ou il est enfin question de repartir avec quelque chose.
func _enjeu(ch: Dictionary, k: int, n: int) -> String:
	var quoi: String = str(ch.get("ramene", ""))
	if quoi == "":
		return ""
	if k == n:
		return "CE QU'ON REPART AVEC, ET C'EST MAINTENANT QUE CA SE JOUE : " + quoi
	return ("CE QUI EST EN JEU, ET QUI N'EST PAS ENCORE OBTENU : %s. "
		+ "Ne l'accorde pas dans ce beat, et ne le fais pas tenir en main.") % quoi


## CE QUE LE MODELE SAIT DES FIGURES. Le harnais leur demandait « nom (resume) » — or ces fiches
## n'ont PAS de champ `resume`, et le modele recevait « Dame Aveline aux Corbeaux () ». Il avait
## donc des noms et rien d'autre. q86 en a nomme seize et pas un n'a voulu quoi que ce soit :
## Aveline regarde, fixe, incline la tete. Lui interdire de se contenter de regarder ne sert a rien
## tant qu'il ignore ce qu'elle veut — la regle sans la donnee est une demi-correction.
##
## Le canon, lui, sait tout ca : `role`, `veut`, `replique_etalon` (un echantillon de voix), et
## parfois `regle_ecriture` (« Trois mots maximum par replique », pour Ordalc'h). On le lui donne.
## MEME DEFAUT POUR LE LIEU, et meme cause. Le harnais demandait `resume` a la fiche du biome, qui
## n'a pas ce champ : le modele recevait « Ar C'hoad Kozh. » et rien de plus. Il ne savait donc pas
## qu'il ecrivait dans une foret — d'ou la « petite hutte en pierre » de q86, batie au milieu d'un
## cercle de menhirs. La fiche sait pourtant dire ce que c'est : `sous_titre`, `archetype`, `tags`.
func _lieu_en_clair(lieu: Dictionary) -> String:
	var bouts: Array = []
	if str(lieu.get("sous_titre", "")) != "":
		bouts.append(str(lieu.get("sous_titre", "")))
	if str(lieu.get("archetype", "")) != "":
		bouts.append("c'est %s, en plein air" % str(lieu.get("archetype", "")))
	var tg: Variant = lieu.get("tags", [])
	if typeof(tg) == TYPE_ARRAY and not (tg as Array).is_empty():
		bouts.append("on y trouve : " + ", ".join(tg as Array))
	return ". ".join(bouts)


func _figures_en_clair(figures: Array) -> String:
	var out: String = ""
	for f in figures:
		var d: Dictionary = f as Dictionary
		var bout: String = "\n- %s" % str(d.get("nom", ""))
		if str(d.get("role", "")) != "":
			bout += ", %s" % str(d.get("role", ""))
		if str(d.get("veut", "")) != "":
			bout += ". VEUT : %s" % str(d.get("veut", ""))
		if str(d.get("replique_etalon", "")) != "":
			bout += " PARLE AINSI : « %s »" % str(d.get("replique_etalon", ""))
		if str(d.get("regle_ecriture", "")) != "":
			bout += " (%s)" % str(d.get("regle_ecriture", "")).substr(0, 90)
		out += bout
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
- VOUVOIEMENT toujours : « Vous voyez », jamais « Tu vois ». Seule une figure qui parle peut tutoyer, et seulement entre guillemets.
- Le joueur est « Vous ». N'ecris JAMAIS « le Voyageur », ni « il » pour le designer. Chaque phrase qui parle de lui commence par « Vous ».
- Tu ne peux nommer QUE les figures de la liste donnee. N'en invente aucune autre, sous aucun nom.
- N'invente aucun objet. N'emploie que ceux qui sont nommes dans la consigne ou deja apparus.
- Langue simple. Aucune metaphore, aucune comparaison, aucune phrase retournee. Jamais « comme si », « tel un », « on dirait ». On dit ce qui se passe, dans l'ordre.
- Chaque figure a un NOM et veut quelque chose. Jamais « une femme au visage fatigue ».
- On reste dans le lieu nomme. N'invente AUCUN batiment : ni hutte, ni maison, ni toit, ni piece, ni porte, ni feu. Si le lieu est un bois, on reste sous les arbres.
- Un objet est a UN SEUL endroit. S'il change de main, dis-le au moment ou ca arrive ; sinon il reste ou il etait.
- Une figure presente AGIT et VEUT quelque chose. Elle ne se contente jamais de regarder, de fixer ou d'incliner la tete.
- Aucune question posee au lecteur.
- Le mystere est dans l'ambiance, jamais dans le sens. Une phrase qui sonne profonde et ne veut rien dire est interdite.
- L'issue ne redit pas la scene : elle la deplace. Si la derniere phrase pouvait etre la premiere, recommence.
- Ce qui apparait revient. Pas d'objet ni d'animal qui traverse une scene et disparait.
- Aucun numero d'etape dans le texte. N'ecris jamais « 1. » ni « 2. » au debut d'une phrase."""


func _preambule(ch: Dictionary, lieu: Dictionary) -> Array:
	var sys: String = ("Tu es MERLIN et tu parles au Voyageur. Francais simple, present, VOUVOIEMENT "
		+ "(« Vous voyez », jamais « Tu vois »).")
	var usr: String = ("%s\n\nLIEU : %s. %s\nCE QUI S'Y JOUE : %s\n\n"
		+ "Ecris le PREAMBULE de cette quete en QUATRE phrases courtes, une par ligne. "
		+ "Il installe la scene du premier beat : ou l'on est, ce qu'on voit, ce qu'on entend. "
		+ "Il n'annonce NI le but, NI ce qu'il faudra faire. La quatrieme phrase rappelle que dans "
		+ "ces bois tout recommence, sauf vous.\nQuatre lignes, rien d'autre.") % [
			REGLES, str(lieu.get("nom", "")), _lieu_en_clair(lieu), str(ch.get("sujet", ""))]
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
		b["special"] = await _beat_choix(ch, forme, precedent, k, n)
		b["scene"] = str(b["special"]["_scene"])
		b["special"].erase("_scene")
		b["issue"] = await _issue_choix(b["special"], precedent)
		b["note"] = ("Beat special : ni tuile, ni rune, ni de. On selectionne parmi %d propositions, "
			+ "et aucune n'est neutre.") % (b["special"]["options"] as Array).size()
		if b.has("bascule"):
			b["bascule"] = ["choisie", str((b["special"]["options"] as Array)[0][0]).to_lower()]
		return b

	# UN SEUL APPEL POUR TOUT LE BEAT. Deux appels par beat doublaient l'attente de voie sans
	# rien apporter : le modele ecrit mieux l'issue quand il vient d'ecrire la scene, puisqu'il
	# l'a encore sous les yeux au lieu de la relire dans un prompt.
	var tuile: String = str(forme.get("tuile_imposee", ""))
	var marge: int = int(forme["de"]) + int(forme["at"]) - int(forme["dc"])
	var tout: Dictionary = await _beat_entier(ch, lieu, figures, main, precedent, k, n, tuile, marge)
	b["action"] = str(tout["tuile"])
	b["rune"] = str(tout["rune"])
	b["dc"] = int(forme["dc"])
	b["at"] = int(forme["at"])
	b["de"] = int(forme["de"])
	b["scene"] = str(tout["scene"])
	b["issue"] = str(tout["issue"])
	b["note"] = ("%s avec %s. Marge %+d — %s. La tuile dit ce qu'on fait, la rune dit avec quoi ; "
		+ "c'est le modele qui a lu la paire.") % [b["action"], b["rune"], marge, _degre(marge)]
	if b.has("bascule"):
		b["bascule"] = ["subie", "ce que le lieu impose"]
	return b


func _beat_entier(ch: Dictionary, lieu: Dictionary, figures: Array, main: Array,
		precedent: String, k: int, n: int, tuile_imposee: String, marge: int) -> Dictionary:
	var noms: String = _figures_en_clair(figures)
	var sys: String = ("Tu ecris un jeu narratif celtique. Francais simple, present, VOUVOIEMENT "
		+ "(« Vous voyez », jamais « Tu vois »).")
	var usr: String = ("%s\n\nTOUTE LA SCENE SE PASSE ICI, ET NULLE PART AILLEURS : %s. %s\n"
		+ "QUI VIT ICI, ET CE QUE CHACUN VEUT : %s\n\nCE QUI S'Y JOUE : %s\n%s\n%s\n\n"
		+ "CE QUE CE BEAT DOIT ACCOMPLIR — %s\n\n"
		+ "Ecris le beat %d sur %d, EXACTEMENT dans cette forme et rien d'autre :\n"
		+ "SCENE: trois phrases courtes. Elle decoule de ce qui precede et finit sur un instant "
		+ "suspendu, sans poser de question.\n"
		+ "GESTE: <TUILE> | <RUNE>\n"
		+ "ISSUE: trois phrases courtes — ce qui est fait, et ce que ca change. "
		+ "L'issue ne redit pas la scene, elle la deplace. Le geste doit s'y LIRE : on doit retrouver "
		+ "la tuile et la rune en lisant, sans qu'elles soient nommees.\n"
		+ "A la fin du beat, une chose est SUE ou OBTENUE qu'on n'avait pas en y entrant, "
		+ "et cette chose est NOMMEE dans l'issue.\n\n"
		+ "TUILE %s\nRUNE, une seule de cette main : %s\n"
		+ "CE QUE DONNE LE GESTE : %s") % [
			REGLES, str(lieu.get("nom", "")), _lieu_en_clair(lieu), noms,
			str(ch.get("sujet", "")), _enjeu(ch, k, n),
			("CE QUI PRECEDE : " + precedent) if precedent != "" else "C'est le premier beat.",
			_marche(k, n), k, n,
			("imposee : " + tuile_imposee) if tuile_imposee != "" else ("au choix : " + ", ".join(TUILES)),
			", ".join(main), _resultat_en_clair(marge)]
	var txt: String = await _generer(sys, usr)
	var scene: String = ""
	var issue: String = ""
	var tuile: String = tuile_imposee
	var rune: String = ""
	var ou: int = 0   # 0 = rien, 1 = scene, 2 = issue
	for l in txt.split("\n"):
		var s: String = str(l).strip_edges()
		if s == "":
			continue
		var haut: String = s.to_upper()
		if haut.begins_with("SCENE"):
			ou = 1
			scene = _nettoyer(s.substr(s.find(":") + 1))
		elif haut.begins_with("ISSUE"):
			ou = 2
			issue = _nettoyer(s.substr(s.find(":") + 1))
		elif haut.begins_with("GESTE"):
			ou = 0
			var bouts: PackedStringArray = s.substr(s.find(":") + 1).split("|")
			if bouts.size() >= 2:
				if tuile_imposee == "":
					tuile = _plus_proche(str(bouts[0]).strip_edges(), TUILES)
				rune = _plus_proche(str(bouts[1]).strip_edges(), main)
		elif ou == 1:
			scene += " " + _nettoyer(s)
		elif ou == 2:
			issue += " " + _nettoyer(s)
	if tuile == "":
		tuile = TUILES[_rng.randi_range(0, TUILES.size() - 1)]
	if rune == "":
		rune = str(main[_rng.randi_range(0, main.size() - 1)])
	return {"scene": scene.strip_edges(), "issue": issue.strip_edges(),
			"tuile": tuile, "rune": rune}


func _beat_choix(ch: Dictionary, forme: Dictionary, precedent: String, k: int, n: int) -> Dictionary:
	var sys: String = ("Tu ecris un jeu narratif celtique. Francais simple, present, VOUVOIEMENT "
		+ "(« Vous voyez », jamais « Tu vois »).")
	var usr: String = ("%s\n\nCE QUI PRECEDE : %s\nCE QUI S'Y JOUE : %s\n"
		+ "%s\nCE QUE CE BEAT DOIT ACCOMPLIR — %s\n\n"
		+ "Ecris un beat de DECISION (%s), ainsi :\n"
		+ "SCENE: deux phrases qui posent le choix, sans le resoudre.\n"
		+ "OPTION: <ce qu'on fait> || <ce que ca entraine>\n"
		+ "OPTION: <ce qu'on fait> || <ce que ca entraine>\n"
		+ "OPTION: <ce qu'on fait> || <ce que ca entraine>\n"
		+ "TROIS options, et AUCUNE ne doit etre gratuite : chacune coute quelque chose de "
		+ "nommable. Si l'une est manifestement la bonne, recommence.") % [
			REGLES, precedent if precedent != "" else "rien", str(ch.get("sujet", "")),
			_enjeu(ch, k, n), _marche(k, n), str(forme["special"])]
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
	var sys: String = ("Tu ecris un jeu narratif celtique. Francais simple, present, VOUVOIEMENT "
		+ "(« Vous voyez », jamais « Tu vois »).")
	var usr: String = ("%s\n\nCE QUI EST CHOISI : %s\nCE QUE CA ENTRAINE : %s\n\n"
		+ "Ecris en TROIS phrases courtes ce qui se passe une fois ce choix fait. "
		+ "Pas de commentaire, pas de morale. Trois phrases, rien d'autre.") % [
			REGLES, str(pris[0]), str(pris[1])]
	return _nettoyer(await _generer(sys, usr))


# ── outillage ──────────────────────────────────────────────────────────────────────────────────

## LA QUETE PORTE SES PROPRES ERREURS. Au premier essai reel, les huit beats sont revenus vides :
## chaque appel avait echoue, et le fichier produit ne disait pas pourquoi — il fallait aller
## chercher un log sur la VM pour apprendre laquelle des six erreurs du moteur s'etait produite.
## Une sortie qui ne sait pas dire ce qui lui est arrive coute un aller-retour a chaque diagnostic.
## ATTENDRE LA VOIE, PAS SEULEMENT LE MODELE. q79 a rendu dix-sept fois « generation deja en
## cours » : le moteur etait pret, mais MerlinScenario._ready() branche model_ready sur _amorcer,
## qui lance une generation de selection DES QUE le modele est charge. Mon premier appel tombait
## donc systematiquement sur une voie occupee, et tous les suivants aussi — la quete sortait avec
## une mecanique parfaite et huit proses vides.
## Le moteur est mono-place par voie : on attend qu'elle se libere au lieu de se faire refuser.
## Defait les connexions que MerlinScenario a posees sur les signaux du moteur. On passe par la
## liste reelle des connexions plutot que par un Callable reconstruit : le nom de la methode peut
## changer, l'objet connecte non — et une deconnexion qui echoue en silence redonnerait les 227
## secondes sans que rien ne le dise.
func _couper_amorce(sc: Node) -> int:
	var n: int = 0
	var mn0: Node = root.get_node_or_null("/root/MerlinNative")
	if mn0 == null:
		return 0
	for sig in ["model_ready", "vif_ready"]:
		if not mn0.has_signal(sig):
			continue
		for c in mn0.get_signal_connection_list(sig):
			var cb: Callable = (c as Dictionary).get("callable") as Callable
			if cb.get_object() == sc:
				mn0.disconnect(sig, cb)
				n += 1
	return n


func _attendre_voie(cerveau: String, budget_ms: int) -> bool:
	if _mn == null or not _mn.has_method("est_occupe"):
		return true
	var t0: int = Time.get_ticks_msec()
	while _mn.est_occupe(cerveau):
		if Time.get_ticks_msec() - t0 > budget_ms:
			return false
		await create_timer(1.0).timeout
	return true


func _generer(sys: String, usr: String) -> String:
	if _mn == null or not _mn.is_ready():
		_noter_erreur("moteur non pret au moment de l'appel")
		return ""
	if not await _attendre_voie("conteur", VOIE_TIMEOUT_MS):
		_noter_erreur("la voie conteur est restee occupee %d s" % int(VOIE_TIMEOUT_MS / 1000))
		return ""
	# LA TAILLE DU PROMPT SE DIT. Le moteur tourne a n_ctx=2048 : prompt + reponse doivent y tenir.
	# Les consignes ont grossi (regles d'ecriture, marche du beat, but, DEUX issues de contexte) et
	# je n'ai aucun moyen de savoir si je viens de depasser la fenetre — sauf en le comptant ici.
	# Le rapport signe/jeton est d'environ 3,5 en francais ; l'estimation suffit a voir un depassement.
	var _n: int = sys.length() + usr.length()
	print("    prompt=%d car. ~%d jetons (+%d de reponse, fenetre 2048)" % [
		_n, int(_n / 3.5), int(GEN_OPTS.get("max_tokens", 0))])
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
			return "un PARTIEL — on obtient ce qu'on voulait mais on le paie"
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
