class_name MerlinHautsFaits
extends RefCounted
## MerlinHautsFaits — LE REGISTRE DES HAUTS FAITS, cross-run.
##
## POURQUOI IL EXISTE. Les douze chapitres de la quête principale posent leurs verrous en prose
## (« Avoir survécu à une traversée à Corruption 5 ou plus »). Rien ne peut vérifier une phrase :
## sans registre, AUCUNE condition de chapitre n'est vérifiable, et toute l'architecture des
## verrous reste décorative. Le canon nomme ce manque en §26.6 ; c'est celui-ci qu'on comble.
##
## CE QU'IL N'EST PAS. Ce n'est pas un compteur de succès à afficher. C'est la mémoire des faits
## qu'un chapitre peut EXIGER, et rien d'autre entre ici : un fait sans verrou qui le réclame n'a
## pas sa place (`data/quete/hauts_faits.json` est la liste close).
##
## DEUX ESPÈCES DE FAITS, et la distinction compte :
##   DÉRIVÉ   — recalculé à la volée depuis la chronique (« avoir rapporté le premier éclat » =
##              graal_fragments >= 1). Rien n'est stocké, donc rien ne peut diverger du réel.
##   REGISTRE — un événement qui arrive PENDANT une traversée et qu'il faut noter au moment où il
##              arrive, parce qu'après il est perdu.
##
## Persisté comme la chronique : ConfigFile `user://options.cfg`, section [chronique], clé
## `hauts_faits`. Additif — un fichier de préférences antérieur lit le défaut et ne migre pas.

const CATALOGUE_PATH: String = "res://data/quete/hauts_faits.json"
const PALIERS_PATH: String = "res://data/quete/paliers.json"
const CLE: String = "hauts_faits"

# Cache du catalogue : il ne change pas en cours de session, et le relire à chaque appel
# ferait un accès disque par verrou testé.
static var _catalogue: Dictionary = {}


## Le catalogue, chargé une fois. Vide si le fichier manque — auquel cas AUCUN verrou n'est
## franchissable, et c'est le bon comportement : mieux vaut une quête bloquée qu'une quête qui
## s'ouvre parce qu'on n'a pas su lire ses conditions.
static func catalogue() -> Dictionary:
	if not _catalogue.is_empty():
		return _catalogue
	var f: FileAccess = FileAccess.open(CATALOGUE_PATH, FileAccess.READ)
	if f == null:
		push_error("[MerlinHautsFaits] catalogue introuvable : %s" % CATALOGUE_PATH)
		return {}
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_DICTIONARY:
		push_error("[MerlinHautsFaits] catalogue illisible : %s" % CATALOGUE_PATH)
		return {}
	_catalogue = brut
	return _catalogue


## Les faits NOTÉS (espèce « registre »). Les dérivés n'y sont pas : ils se recalculent.
static func notes() -> Array:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(MerlinChronicle.PREFS_PATH)
	var v: Variant = cfg.get_value(MerlinChronicle.SECTION, CLE, [])
	return v if typeof(v) == TYPE_ARRAY else []


## Note un fait. Idempotent : le noter deux fois ne change rien, ce qui permet d'appeler sans
## vérifier d'abord. Refuse une clé absente du catalogue — une faute de frappe deviendrait sinon
## un verrou qu'aucun chapitre ne réclame et que personne ne verrait jamais.
static func noter(cle: String) -> void:
	if cle == "":
		return
	if not _cles_connues().has(cle):
		push_warning("[MerlinHautsFaits] clé inconnue, ignorée : %s" % cle)
		return
	var deja: Array = notes()
	if deja.has(cle):
		return
	deja.append(cle)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(MerlinChronicle.PREFS_PATH)
	cfg.set_value(MerlinChronicle.SECTION, CLE, deja)
	cfg.save(MerlinChronicle.PREFS_PATH)


## Le Voyageur a-t-il ce fait ? Un dérivé est recalculé, un fait de registre est lu.
static func a(cle: String) -> bool:
	var fiche: Dictionary = fiche_de(cle)
	if fiche.is_empty():
		return false
	if str(fiche.get("source", "")) == "derive":
		return _derive(cle)
	return notes().has(cle)


## La fiche d'un fait, ou un dictionnaire vide si la clé est inconnue.
static func fiche_de(cle: String) -> Dictionary:
	for f in (catalogue().get("hauts_faits", []) as Array):
		if str((f as Dictionary).get("cle", "")) == cle:
			return f as Dictionary
	return {}


## Les faits qu'un chapitre exige. Un chapitre sans verrou rend un tableau vide.
static func verrous_de(chapitre: int) -> Array:
	var m: Dictionary = catalogue().get("verrous_par_chapitre", {}) as Dictionary
	var v: Variant = m.get(str(chapitre), [])
	return v if typeof(v) == TYPE_ARRAY else []


## Ce qui manque au Voyageur pour franchir ce chapitre. Vide = franchissable.
static func manquants(chapitre: int) -> Array:
	var out: Array = []
	for c in verrous_de(chapitre):
		if not a(str(c)):
			out.append(str(c))
	return out


## Un verrou peut être infranchissable NON parce que le Voyageur n'a pas joué, mais parce que
## RIEN dans le code ne sait encore noter ce fait. La différence est cruciale : le premier cas
## est du jeu, le second est un chantier ouvert. Sans cette distinction, un chapitre bloqué pour
## cause de code manquant ressemble à un chapitre difficile.
static func bloques_faute_de_code(chapitre: int) -> Array:
	var out: Array = []
	for c in verrous_de(chapitre):
		var f: Dictionary = fiche_de(str(c))
		if not bool(f.get("implemente", false)):
			out.append(str(c))
	return out


## Efface le registre. Réservé aux Options (« recommencer la Chronique ») et aux tests.
static func effacer() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(MerlinChronicle.PREFS_PATH)
	cfg.set_value(MerlinChronicle.SECTION, CLE, [])
	cfg.save(MerlinChronicle.PREFS_PATH)


# ── interne ───────────────────────────────────────────────────────────────────────────────────

static func _cles_connues() -> Array:
	var out: Array = []
	for f in (catalogue().get("hauts_faits", []) as Array):
		out.append(str((f as Dictionary).get("cle", "")))
	return out


## Les faits dérivés, recalculés depuis la chronique. Chacun est nommé ici explicitement : un
## dérivé qu'on ne saurait pas calculer doit rendre false et le dire, jamais deviner.
static func _derive(cle: String) -> bool:
	var chron: Dictionary = MerlinChronicle.read()
	var eclats: int = int(chron.get("graal_fragments", 0))
	match cle:
		"premier_eclat":
			return eclats >= 1
		"deux_souvenirs":
			return _souvenirs_debloques(eclats) >= 2
		_:
			push_warning("[MerlinHautsFaits] dérivé sans calcul : %s" % cle)
			return false


## Combien de Souvenirs de Merlin sont ouverts. Les seuils vivent dans paliers.json — les
## recopier ici les ferait diverger le jour ou le canon les bouge.
static func _souvenirs_debloques(eclats: int) -> int:
	var f: FileAccess = FileAccess.open(PALIERS_PATH, FileAccess.READ)
	if f == null:
		return 0
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_DICTIONARY:
		return 0
	var n: int = 0
	for seuil in ((brut as Dictionary).get("souvenirs_merlin", []) as Array):
		if eclats >= int(seuil):
			n += 1
	return n
