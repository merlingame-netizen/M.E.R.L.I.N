class_name MerlinSentier
extends RefCounted
## LE CHARGEUR DES SENTIERS ÉCRITS — une quête de `data/scenarios/` devient une traversée jouable.
##
## POURQUOI. Les quêtes écrites à la main n'avaient jamais été jouables : seul `generer_quete.gd`
## les lisait, comme exemples pour le modèle. Le jeu construisait toujours ses propres beats
## (`MerlinScenario.build_quest_beats`), et la prose écrite à la main ne servait qu'à l'entraînement.
## Décision de Maxime (2026-09-07) : elles deviennent du CONTENU. Douze quêtes écrites font douze
## traversées jouables, et la nuit peut en mesurer une sur deux.
##
## CE QUE ÇA CHANGE POUR LE JOUEUR. Sur un sentier écrit, la prose est déjà là : aucune attente,
## aucun beat au banc, une qualité constante. La MÉCANIQUE, elle, se joue pour de vrai — les tags
## requis sont tirés du pool comme partout, le dé roule, la couverture compte, l'intégrité descend.
## Le joueur pose le geste qu'il veut ; l'issue affichée reste celle qui est écrite. La quête
## raconte son histoire, et le joueur la traverse plus ou moins bien.
##
## LE PIÈGE DE L'ACCENT, corrigé ici. Le corpus écrit « Épreuve » et le moteur connaît « Epreuve » :
## `NATURE_BASE_TIER_BY_TYPE` et la liste blanche du geste sûr (v55) ne reconnaissent que la forme
## sans accent. Un type non normalisé aurait rendu les Épreuves écrites moins chères que les
## Épreuves générées, et le dé s'y serait dispensé. On normalise au chargement, une fois.

const TYPES: Dictionary = {
	"exploration": "Exploration", "rencontre": "Rencontre", "epreuve": "Epreuve",
	"épreuve": "Epreuve", "dilemme": "Dilemme", "climax": "Climax",
}
## Le DC écrit dit la difficulté : c'est la table du moteur, lue à l'envers.
const DIFF_PAR_DC: Dictionary = {6: 1, 9: 2, 12: 3}
const DOSSIER: String = "res://data/scenarios"


## Les identifiants disponibles, triés. Vide si le dossier manque (harnais hors dépôt du jeu).
static func liste() -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open(DOSSIER)
	if d == null:
		return out
	d.list_dir_begin()
	var nom: String = d.get_next()
	while nom != "":
		if nom.ends_with(".json"):
			out.append(nom.trim_suffix(".json"))
		nom = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


## Les identifiants d'un biome donné — ce que le menu et le harnais de nuit veulent proposer.
static func liste_du_biome(biome: String) -> Array:
	var out: Array = []
	for cle in liste():
		var q: Dictionary = lire(cle)
		if not q.is_empty() and str(q.get("biome", "")) == biome:
			out.append(cle)
	return out


## La quête brute, telle qu'elle est écrite. Dictionnaire vide si elle est illisible — on ne devine
## pas : un sentier à moitié lu produirait une traversée qui ment sur ce qu'elle raconte.
static func lire(cle: String) -> Dictionary:
	if cle == "" or cle.contains("/") or cle.contains(".."):
		return {}
	var f: FileAccess = FileAccess.open("%s/%s.json" % [DOSSIER, cle], FileAccess.READ)
	if f == null:
		return {}
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_DICTIONARY:
		return {}
	var q: Dictionary = brut
	return q if (q.get("beats") is Array) and not (q["beats"] as Array).is_empty() else {}


## Le scénario prêt pour `MerlinRun.new_run`. Dictionnaire vide si la quête est illisible.
static func charger(cle: String) -> Dictionary:
	var q: Dictionary = lire(cle)
	if q.is_empty():
		return {}
	var titre: String = str(q.get("titre", cle))
	var beats_ecrits: Array = q["beats"]
	var beats: Array = []
	var n: int = 0
	for b_v in beats_ecrits:
		if not (b_v is Dictionary):
			continue
		var b: Dictionary = b_v
		n += 1
		var beat: Dictionary = {
			"n": n, "qn": n, "qtotal": beats_ecrits.size(), "quest": 0,
			"quest_title": titre, "quest_pitch": _pitch(q),
			"type": type_normalise(str(b.get("t", "Exploration"))),
			"difficulte": _difficulte(b),
			# LE SENTIER SE RECONNAÎT À CE DRAPEAU. Les mesures en ont besoin : une nuit écrite et
			# une nuit générée ne disent pas la même chose et ne se comparent pas.
			"sentier": true,
			"lieu": str(b.get("lieu", "")),
			"scene_ecrite": str(b.get("scene", "")),
			# 09/09 : la réplique écrite (`dial`) ne se fond plus dans l'issue — elle ouvre un PORTRAIT
			# au moment de la scène, avec la figure qui la dit ; l'issue reste l'issue.
			"dial_ecrit": str(b.get("dial", "")).strip_edges(),
			"issue_ecrite": str(b.get("issue", "")).strip_edges(),
		}
		if b.get("special") is Dictionary:
			beat["special"] = (b["special"] as Dictionary).duplicate(true)
		if b.get("bascule") is Array:
			beat["bascule"] = (b["bascule"] as Array).duplicate()
		beats.append(beat)
	if beats.is_empty():
		return {}
	return {
		"title": titre, "titre": titre,
		"pitch": _pitch(q),
		"biome": str(q.get("biome", "foret")),
		"beats": beats, "total": beats.size(), "quests": 1,
		"sentier": cle,
		"bourse_depart": int(q.get("bourse_depart", 0)),
		"preambule": (q.get("preambule", []) as Array).duplicate(),
	}


## « Épreuve » du corpus et « Epreuve » du moteur sont le MÊME type. Un type inconnu devient une
## Exploration plutôt que de traverser tel quel : le moteur le classerait au tier 1 en silence.
static func type_normalise(t: String) -> String:
	return str(TYPES.get(t.strip_edges().to_lower(), "Exploration"))


## Le beat porte-t-il un choix jouable ? Deux à quatre propositions, pas une de plus.
static func est_un_choix(beat: Dictionary) -> bool:
	var sp: Variant = beat.get("special")
	if not (sp is Dictionary):
		return false
	var d: Dictionary = sp
	if not str(d.get("genre", "")).contains("choix"):
		return false
	var opts: Array = d.get("options", []) as Array
	return opts.size() >= 2 and opts.size() <= 4


## Les propositions d'un beat de choix, en forme normale : {texte, entraine, cout}.
##
## DEUX ÉCRITURES ACCEPTÉES. Les quêtes d'avant écrivent une paire [libellé, conséquence] et ne
## coûtent rien mécaniquement ; les nouvelles écrivent un dictionnaire avec son `cout`. Refuser les
## premières aurait rendu injouables les quêtes qui ont servi à écrire la règle.
static func propositions(beat: Dictionary) -> Array:
	if not est_un_choix(beat):
		return []
	var out: Array = []
	for o in ((beat["special"] as Dictionary).get("options", []) as Array):
		if o is Array:
			var paire: Array = o
			out.append({
				"texte": str(paire[0]) if paire.size() > 0 else "",
				"entraine": str(paire[1]) if paire.size() > 1 else "",
				"cout": {},
			})
		elif o is Dictionary:
			var d: Dictionary = o
			out.append({
				"texte": str(d.get("texte", "")),
				"entraine": str(d.get("entraine", "")),
				"cout": cout_borne(d.get("cout", {})),
			})
	return out


# LE PRIX D'UN CHOIX EST BORNÉ, et il l'est ICI. Décision de Maxime (07/09) : « petit mais net ».
# Un ou deux points d'intégrité ou de corruption, deux à six gwenneg, une rune au plus. Sur dix
# beats, deux choix coûtent autant qu'un partiel : le choix pèse sans décider de la traversée.
# La borne vit dans le code et non dans les données pour qu'une quête mal réglée ne puisse pas
# tuer le Voyageur sur une proposition.
const COUT_MAX_INTEGRITE: int = 2
const COUT_MAX_CORRUPTION: int = 2
const COUT_MAX_GWENNEG: int = 6


static func cout_borne(brut: Variant) -> Dictionary:
	if not (brut is Dictionary):
		return {}
	var d: Dictionary = brut
	var out: Dictionary = {}
	var integ: int = int(d.get("integrite", 0))
	if integ != 0:
		out["integrite"] = -mini(absi(integ), COUT_MAX_INTEGRITE)
	var corr: int = int(d.get("corruption", 0))
	if corr != 0:
		out["corruption"] = mini(absi(corr), COUT_MAX_CORRUPTION)
	var gw: int = int(d.get("gwenneg", 0))
	if gw != 0:
		out["gwenneg"] = -mini(absi(gw), COUT_MAX_GWENNEG)
	var rune: String = str(d.get("rune", ""))
	if rune != "":
		out["rune"] = rune
	return out


## Ce que coûte une proposition, en clair, pour l'afficher sous elle. Vide si elle ne coûte rien.
static func cout_en_clair(cout: Dictionary) -> String:
	var bouts: Array = []
	if int(cout.get("integrite", 0)) != 0:
		bouts.append("−%d intégrité" % absi(int(cout["integrite"])))
	if int(cout.get("corruption", 0)) != 0:
		bouts.append("+%d corruption" % absi(int(cout["corruption"])))
	if int(cout.get("gwenneg", 0)) != 0:
		bouts.append("−%d gwenneg" % absi(int(cout["gwenneg"])))
	if str(cout.get("rune", "")) != "":
		bouts.append("vous laissez %s" % str(cout["rune"]))
	return " · ".join(bouts)


## De quoi présenter un sentier sans le charger tout entier : titre, lieu, longueur, première ligne.
## C'est ce que le menu affiche — « assez pour choisir, rien qui déflore » (décision du 08/09).
static func resume(cle: String) -> Dictionary:
	var q: Dictionary = lire(cle)
	if q.is_empty():
		return {}
	var pre: Array = q.get("preambule", []) as Array
	return {
		"cle": cle,
		"titre": str(q.get("titre", cle)),
		"biome": str(q.get("biome", "")),
		"biome_nom": nom_du_biome(str(q.get("biome", ""))),
		"beats": (q.get("beats", []) as Array).size(),
		"ouverture": str(pre[0]) if not pre.is_empty() else "",
	}


## Le nom que le joueur connaît d'un biome (« Les Falaises du Bout-du-Monde »), lu dans ses données.
## L'identifiant brut en repli : mieux vaut « falaises » qu'une ligne vide.
static func nom_du_biome(id: String) -> String:
	if id == "":
		return ""
	var f: FileAccess = FileAccess.open("res://data/biomes/%s.json" % id, FileAccess.READ)
	if f == null:
		return id
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_DICTIONARY:
		return id
	var d: Dictionary = brut
	return str(d.get("sous_titre", d.get("nom", id)))


# ── interne ───────────────────────────────────────────────────────────────────────────────────

## Le pitch d'un sentier est son préambule : c'est ce que la quête promet, et le climax s'y ancre.
static func _pitch(q: Dictionary) -> String:
	var p: Array = q.get("preambule", []) as Array
	return str(p[0]) if not p.is_empty() else str(q.get("titre", ""))


## La difficulté vient du DC écrit ; à défaut, du type, comme `build_quest_beats`.
static func _difficulte(b: Dictionary) -> int:
	if b.has("dc"):
		return int(DIFF_PAR_DC.get(int(b["dc"]), 2))
	if type_normalise(str(b.get("t", ""))) == "Climax":
		return 3
	return 1 if int(b.get("n", 2)) == 1 else 2
