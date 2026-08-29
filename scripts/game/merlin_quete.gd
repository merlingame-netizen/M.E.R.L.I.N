class_name MerlinQuete
extends RefCounted
## MerlinQuete — LE SQUELETTE DE LA QUÊTE PRINCIPALE : structure, paliers, avancement.
##
## CE QU'IL FAIT. Il lit `data/quete/` et `data/biomes/` — le canon §26 déployé le 2026-08-29 —
## et répond aux quatre questions dont tout le reste dépend :
##   quel palier le Voyageur a atteint · quels lieux lui sont ouverts · quel chapitre est le sien
##   maintenant · et si le verrou de ce chapitre est franchissable, sinon ce qui manque.
##
## POURQUOI IL EST SÉPARÉ DU RESTE. La chronique (`MerlinChronicle`) retient CE QUI EST ARRIVÉ ;
## le registre (`MerlinHautsFaits`) retient CE QUI A ÉTÉ FAIT ; ce fichier ne retient rien du
## tout. Il ne fait que lire les données et l'état, et calculer. Aucun état de quête n'est
## persisté ici — il n'y en a pas à persister, tout se recalcule depuis les éclats et le registre.
## C'est ce qui rend l'avancement impossible à désynchroniser.
##
## CE QU'IL NE FAIT PAS ENCORE, et il vaut mieux le lire ici qu'en jouant : rien n'APPELLE ce
## fichier aujourd'hui. Le squelette existe, l'écran de carte et le lanceur de traversée ne s'y
## branchent pas encore. Et trois verrous sur douze reposent sur des faits que rien ne sait noter
## (réputation, arbre méta) — `diagnostic()` les nomme un par un.

const CHAPITRES_PATH: String = "res://data/quete/chapitres.json"
const PALIERS_PATH: String = "res://data/quete/paliers.json"
const RELIQUES_PATH: String = "res://data/quete/reliques.json"
const TRAVERSEES_PATH: String = "res://data/quete/traversees.json"
const BIOMES_DIR: String = "res://data/biomes"

static var _cache: Dictionary = {}


static func _charger(chemin: String) -> Dictionary:
	if _cache.has(chemin):
		return _cache[chemin]
	var f: FileAccess = FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		push_error("[MerlinQuete] introuvable : %s" % chemin)
		return {}
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_DICTIONARY:
		push_error("[MerlinQuete] illisible : %s" % chemin)
		return {}
	_cache[chemin] = brut
	return brut


## Les douze chapitres, dans l'ordre.
static func chapitres() -> Array:
	return _charger(CHAPITRES_PATH).get("chapitres", []) as Array


## Le chapitre n, ou un dictionnaire vide.
static func chapitre(n: int) -> Dictionary:
	for c in chapitres():
		if int((c as Dictionary).get("n", 0)) == n:
			return c as Dictionary
	return {}


## Combien d'éclats le Voyageur a ramenés. Un seul endroit le sait : la chronique.
static func eclats() -> int:
	return int(MerlinChronicle.read().get("graal_fragments", 0))


## Le palier atteint : le dernier dont le seuil d'éclats est franchi. Toujours au moins 1 — le
## Seuil est ouvert d'entrée, sinon le jeu ne commencerait nulle part.
static func palier() -> Dictionary:
	var courant: Dictionary = {}
	var n: int = eclats()
	for p in (_charger(PALIERS_PATH).get("paliers", []) as Array):
		if n >= int((p as Dictionary).get("eclats_requis", 0)):
			courant = p as Dictionary
	return courant


## Les lieux ouverts : ceux de tous les paliers franchis, plus ceux qu'une relique a ouverts.
## Un lieu fermé n'est pas caché, il est verrouillé — la carte doit pouvoir le montrer et dire
## pourquoi on n'y va pas.
static func lieux_ouverts() -> Array:
	var out: Array = []
	var n: int = eclats()
	for p in (_charger(PALIERS_PATH).get("paliers", []) as Array):
		if n < int((p as Dictionary).get("eclats_requis", 0)):
			continue
		for l in ((p as Dictionary).get("ouvre", []) as Array):
			if not out.has(str(l)):
				out.append(str(l))
	for r in (_charger(RELIQUES_PATH).get("reliques", []) as Array):
		var relique: Dictionary = r as Dictionary
		var ouvre: String = str(relique.get("ouvre", ""))
		if ouvre != "" and not out.has(ouvre) and _relique_trouvee(relique):
			out.append(ouvre)
	return out


## Le chapitre courant : le premier qui n'est pas encore acquis. Rend 0 quand les douze sont
## faits — c'est le seul cas où la quête principale est finie.
static func chapitre_courant() -> int:
	var acquis: Array = MerlinChronicle.read().get("chapitres_acquis", []) as Array
	for c in chapitres():
		var n: int = int((c as Dictionary).get("n", 0))
		if not acquis.has(str(n)) and not acquis.has(n):
			return n
	return 0


## Ce chapitre est-il jouable MAINTENANT ? Trois conditions, et elles doivent toutes tenir :
## son lieu est ouvert, son verrou de haut fait est franchi, et il n'est pas déjà acquis.
static func jouable(n: int) -> bool:
	var c: Dictionary = chapitre(n)
	if c.is_empty():
		return false
	var acquis: Array = MerlinChronicle.read().get("chapitres_acquis", []) as Array
	if acquis.has(str(n)) or acquis.has(n):
		return false
	if not lieux_ouverts().has(str(c.get("lieu", ""))):
		return false
	return MerlinHautsFaits.manquants(n).is_empty()


## Pourquoi ce chapitre n'est PAS jouable, en clair. Rend un tableau vide s'il l'est.
## Sert l'écran de carte : un verrou qu'on ne comprend pas est un bug pour le joueur.
static func pourquoi_bloque(n: int) -> Array:
	var c: Dictionary = chapitre(n)
	if c.is_empty():
		return ["chapitre inconnu"]
	var raisons: Array = []
	var acquis: Array = MerlinChronicle.read().get("chapitres_acquis", []) as Array
	if acquis.has(str(n)) or acquis.has(n):
		raisons.append("déjà accompli")
	var lieu: String = str(c.get("lieu", ""))
	if not lieux_ouverts().has(lieu):
		raisons.append("le lieu « %s » n'est pas encore ouvert" % lieu)
	for m in MerlinHautsFaits.manquants(n):
		var f: Dictionary = MerlinHautsFaits.fiche_de(str(m))
		raisons.append("haut fait manquant : %s" % str(f.get("libelle", m)))
	return raisons


## L'avancement, d'un bloc — ce que l'écran de carte et Merlin ont besoin de savoir.
static func avancement() -> Dictionary:
	var total: int = int(_charger(CHAPITRES_PATH).get("total", 12))
	var acquis: Array = MerlinChronicle.read().get("chapitres_acquis", []) as Array
	var p: Dictionary = palier()
	var courant: int = chapitre_courant()
	return {
		"eclats": eclats(),
		"eclats_total": int(_charger(CHAPITRES_PATH).get("graal_total", 12)),
		"chapitres_acquis": acquis.size(),
		"chapitres_total": total,
		"palier_n": int(p.get("n", 1)),
		"palier_nom": str(p.get("nom", "")),
		"lieux_ouverts": lieux_ouverts(),
		"chapitre_courant": courant,
		"chapitre_courant_titre": str(chapitre(courant).get("titre", "")),
		"chapitre_courant_jouable": jouable(courant),
		"fin_atteignable": eclats() >= int((_charger(PALIERS_PATH).get("run_final", {}) as Dictionary).get("a_eclats", 12)),
	}


## DIAGNOSTIC — ce que le squelette peut réellement porter aujourd'hui, et ce qu'il ne peut pas.
## Sans cette fonction, un chapitre bloqué parce que rien ne sait noter son haut fait ressemble
## à un chapitre difficile, et personne ne va chercher le chantier manquant.
static func diagnostic() -> Dictionary:
	var sans_code: Dictionary = {}
	for c in chapitres():
		var n: int = int((c as Dictionary).get("n", 0))
		var bloques: Array = MerlinHautsFaits.bloques_faute_de_code(n)
		if not bloques.is_empty():
			sans_code[n] = bloques
	var lieux_connus: Array = _lieux_du_dossier()
	var lieux_manquants: Array = []
	for c in chapitres():
		var l: String = str((c as Dictionary).get("lieu", ""))
		if l != "" and not lieux_connus.has(l) and not lieux_manquants.has(l):
			lieux_manquants.append(l)
	return {
		"chapitres": chapitres().size(),
		"lieux": lieux_connus.size(),
		"chapitres_bloques_faute_de_code": sans_code,
		"lieux_cites_mais_absents": lieux_manquants,
		"traversees_dorsale": (_charger(TRAVERSEES_PATH).get("dorsale", []) as Array).size(),
	}


# ── interne ───────────────────────────────────────────────────────────────────────────────────

static func _lieux_du_dossier() -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open(BIOMES_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var nom: String = d.get_next()
	while nom != "":
		if nom.ends_with(".json"):
			out.append(nom.get_basename())
		elif nom.ends_with(".json.remap"):
			out.append(nom.get_basename().get_basename())
		nom = d.get_next()
	d.list_dir_end()
	return out


## Une relique est trouvée quand le chapitre de son lieu de découverte est acquis. Rien d'autre
## ne les enregistre aujourd'hui, et inventer un second registre les ferait diverger.
static func _relique_trouvee(relique: Dictionary) -> bool:
	var lieu: String = str(relique.get("trouvee_a", ""))
	if lieu == "":
		return false
	var acquis: Array = MerlinChronicle.read().get("chapitres_acquis", []) as Array
	for c in chapitres():
		var ch: Dictionary = c as Dictionary
		if str(ch.get("lieu", "")) != lieu:
			continue
		var n: int = int(ch.get("n", 0))
		if acquis.has(str(n)) or acquis.has(n):
			return true
	return false
