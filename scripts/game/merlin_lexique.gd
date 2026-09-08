class_name MerlinLexique
extends RefCounted
## LES FORMULES DE MERLIN, écrites à la main et tirées sans modèle.
##
## POURQUOI. Ce que Merlin dit en dur vivait éparpillé : deux voiles d'attente dans la sélection,
## un troisième dans la fusion, deux cadrages de biome sur douze dans le scénario. Le reste venait
## du modèle, mono-place et occupé par les beats : des silences, et des bancs. Décision de Maxime
## (08/09) : un lexique à la main comme socle, toujours là, jamais au banc, relu par lui ; le modèle
## garde le menu.
##
## LE TON est celui du corpus : court, le Voyageur tutoyé, jamais de tiret cadratin. Une clé est une
## situation ; `tirer` rend une ligne et ne redonne jamais la précédente de la même clé.

const CHEMIN: String = "res://data/merlin_lexique.json"

static var _donnees: Dictionary = {}
static var _derniere: Dictionary = {}   # clé → index de la dernière ligne tirée
static var _graine: int = 0


static func _charger() -> Dictionary:
	if not _donnees.is_empty():
		return _donnees
	var f: FileAccess = FileAccess.open(CHEMIN, FileAccess.READ)
	if f == null:
		return {}
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) == TYPE_DICTIONARY:
		_donnees = brut
	return _donnees


## Les lignes d'une clé « section.sous_clé » (« verdict.echec »). Vide si la clé manque.
static func lignes(cle: String) -> Array:
	var d: Dictionary = _charger()
	var parts: PackedStringArray = cle.split(".")
	var cur: Variant = d
	for p in parts:
		if cur is Dictionary and (cur as Dictionary).has(p):
			cur = (cur as Dictionary)[p]
		else:
			return []
	if cur is Array:
		return cur
	if cur is String:
		return [cur]
	return []


## Une ligne de la clé, jamais la même que la précédente tant qu'il y en a d'autres. `repli` si la
## clé manque : le jeu ne se tait jamais parce qu'un fichier manque.
static func tirer(cle: String, repli: String = "") -> String:
	var l: Array = lignes(cle)
	if l.is_empty():
		return repli
	if l.size() == 1:
		return str(l[0])
	var prev: int = int(_derniere.get(cle, -1))
	_graine = (_graine * 1103515245 + 12345 + Time.get_ticks_msec()) & 0x7fffffff
	var i: int = _graine % l.size()
	if i == prev:
		i = (i + 1) % l.size()
	_derniere[cle] = i
	return str(l[i])


## Le cadrage d'un biome, en deux souffles. Repli : la forêt, comme le scénario l'a toujours fait.
static func biome(id: String) -> String:
	var b: Dictionary = _charger().get("biomes", {}) as Dictionary
	return str(b.get(id, b.get("foret", "")))


## La formule du verdict pour un degré (« eclatante », « reussite », « partiel », « echec »).
static func verdict(degre: String) -> String:
	return tirer("verdict." + degre)


## Les identifiants de biomes cadrés : l'épreuve vérifie qu'ils sont douze.
static func biomes_cadres() -> Array:
	return (_charger().get("biomes", {}) as Dictionary).keys()
