class_name MerlinJournal
extends RefCounted
## MerlinJournal — LA CHRONIQUE DE CHAQUE TRAVERSÉE, gardée pour être relue.
##
## POURQUOI IL EXISTE. `MerlinChronicle` compte les traversées, il n'en garde aucune : ses champs
## sont des `last_*` que la traversée suivante écrase, et son carnet est plafonné à trois pages —
## volontairement, parce qu'il sert au RÉCIT (« le récit doit pouvoir s'y référer, pas réciter une
## biographie »). Ce plafond est bon pour ce qu'il fait, et c'est pourquoi on ne le touche pas :
## lire l'historique demande un autre objet, pas un carnet plus gros.
##
## CE QU'IL GARDE, et pourquoi tout est là. Une chronique doit permettre de répondre à « est-ce que
## le jeu s'améliore ? ». Les chiffres seuls disent l'équilibrage et pas l'écriture ; la prose
## seule se lit bien mais ne se relie à rien. Donc les deux, beat par beat : la scène telle qu'elle
## a été affichée, l'issue telle qu'elle a été écrite, le geste posé, le dé, le degré, les jauges
## avant et après.
##
## UN FICHIER PAR TRAVERSÉE, ET UN INDEX. Maxime a demandé de tout garder, sans limite. Les mettre
## dans `options.cfg` ferait grossir sans plafond le fichier que le jeu relit à CHAQUE démarrage :
## on tiendrait la promesse en payant un ralentissement qui empire à chaque partie. Ici l'index
## seul est lu pour afficher la liste (une ligne par traversée), et le détail n'est ouvert que
## lorsqu'on ouvre une chronique. Mille traversées ne coûtent rien au démarrage.
##
## ÉCRIT AU FIL DE L'EAU, pas à la fin. Une partie interrompue — fermeture, plantage, coupure —
## laisse quand même sa chronique lisible jusqu'au dernier beat joué. C'est le comportement de la
## sonde des parties témoins, éprouvé, et la seule façon qu'un incident reste consultable.
##
## MAIS RIEN NE S'ÉCRIT AVANT LE PREMIER BEAT JOUÉ. Décidé par Maxime le 03/09, sur preuve : après
## un jour, quatre des cinq chroniques de la VM étaient des lancements sans partie — 0 beat, 191
## octets — dont un à 03:00 par un agent de nuit. Un lancement sans partie n'est pas une traversée.
## « Joué » et non « posé » : lancé sans personne, le jeu PRÉSENTE le beat 1 de lui-même — un smoke
## de cent secondes l'a montré en écrivant une chronique à un beat et zéro geste. Ce qui fait une
## traversée, c'est qu'un joueur ou un bot ait posé un geste. La règle vit ICI et non dans une
## variable d'environnement de harnais : un smoke lancé à la main n'en porte aucune, et c'est lui
## qui avait écrit celle de 03:00. Les parties témoins, elles, jouent — elles restent.

const DOSSIER: String = "user://chroniques"
const INDEX: String = "user://chroniques/index.json"
const VERSION: int = 1

# La traversée en cours. Statique : elle doit survivre aux changements de scène, et il n'y a
# jamais qu'une traversée à la fois.
static var _courante: Dictionary = {}
static var _id: String = ""


## Ouvre une chronique EN ATTENTE : rien n'est écrit tant qu'aucun beat n'est joué. Toute
## chronique restée ouverte est abandonnée ici — une traversée commencée en remplace une autre,
## et la précédente, si elle a joué, a déjà son fichier sur le disque.
static func ouvrir(titre: String, biome: String, chapitre: String = "") -> void:
	_id = _nouvel_id()
	_courante = {
		"version": VERSION, "id": _id,
		"debut_iso": Time.get_datetime_string_from_system(),
		"titre": titre, "biome": biome, "chapitre": chapitre,
		"beats": [], "fin": {},
	}


## Le beat est présenté : on note ce que le joueur LIT, avant qu'il touche à quoi que ce soit.
static func beat_pose(n: int, type_beat: String, narration: String, provenance: String,
		difficulte: int, de: int, integrite: int, corruption: int) -> void:
	if _courante.is_empty():
		return
	(_courante["beats"] as Array).append({
		"n": n, "type": type_beat, "provenance": provenance,
		"scene": narration, "difficulte": difficulte, "de": de,
		"integrite_avant": integrite, "corruption_avant": corruption,
	})
	_ecrire()


## Le beat est résolu : on complète la MÊME entrée. Un beat résolu sans avoir été posé n'existe
## pas — on ne fabrique pas d'entrée ici, sinon un décalage d'un beat passerait inaperçu.
static func beat_resolu(degre: String, issue: String, integrite: int, corruption: int) -> void:
	if _courante.is_empty():
		return
	var b: Array = _courante["beats"]
	if b.is_empty():
		return
	var d: Dictionary = b[b.size() - 1]
	if d.has("degre"):
		return  # déjà résolu : une seconde résolution du même beat serait une anomalie, pas une mise à jour
	d["degre"] = degre
	d["issue"] = issue
	d["integrite_apres"] = integrite
	d["corruption_apres"] = corruption
	_ecrire()


## Le geste posé, noté au moment où il l'est. Séparé de la résolution parce que la sélection est
## vidée AVANT l'affichage de l'issue : la lire là-bas rendait deux chaînes vides, et une chaîne
## vide se lit comme une donnée, pas comme une erreur.
static func beat_geste(action: String, trait_: String) -> void:
	if _courante.is_empty():
		return
	var b: Array = _courante["beats"]
	if b.is_empty():
		return
	var d: Dictionary = b[b.size() - 1]
	if d.has("action"):
		return
	d["action"] = action
	d["trait"] = trait_
	_ecrire()


## Clôt la chronique : elle est déjà à l'index depuis son ouverture, la clôture y pose sa fin.
## Idempotent — clore deux fois ne fait rien la seconde fois, la traversée courante étant vidée.
static func clore(fin_type: String, integrite: int, corruption: int, resume: String = "",
		faits: Array = [], pnj: Array = []) -> void:
	if _courante.is_empty():
		return
	_courante["fin"] = {
		"type": fin_type, "integrite": integrite, "corruption": corruption,
		"resume": resume, "faits_marquants": faits, "pnj_rencontres": pnj,
		"iso": Time.get_datetime_string_from_system(),
	}
	# Une traversée close sans un seul beat joué n'a jamais existé : ni fichier, ni ligne d'index.
	if _a_joue():
		_ecrire()
		_indexer()
	_courante = {}
	_id = ""


## L'index, la plus récente d'abord. C'est tout ce que l'écran de liste a besoin de lire.
static func liste() -> Array:
	var f: FileAccess = FileAccess.open(INDEX, FileAccess.READ)
	if f == null:
		return []
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(brut) != TYPE_ARRAY:
		return []
	var out: Array = []
	for l in (brut as Array):
		if int((l as Dictionary).get("beats", 0)) > 0:
			out.append(l)
	out.reverse()
	return out


## Une chronique entière. Dictionnaire vide si l'identifiant est inconnu — on ne devine pas.
static func lire(id: String) -> Dictionary:
	if id == "" or id.contains("/") or id.contains(".."):
		return {}   # un identifiant vient de l'index, jamais d'une saisie : on le vérifie quand même
	var f: FileAccess = FileAccess.open("%s/%s.json" % [DOSSIER, id], FileAccess.READ)
	if f == null:
		return {}
	var brut: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return brut if typeof(brut) == TYPE_DICTIONARY else {}


## Combien de chroniques sont lisibles. Sert à l'écran, et à savoir si la liste vaut la peine.
static func combien() -> int:
	return liste().size()


# ── interne ───────────────────────────────────────────────────────────────────────────────────

static func _nouvel_id() -> String:
	# Horodaté à la seconde, donc trié par ordre alphabétique = ordre chronologique. Deux
	# traversées dans la même seconde sont impossibles à la main ; un suffixe aléatoire couvre
	# les harnais, qui eux en enchaînent.
	var t: String = Time.get_datetime_string_from_system().replace(":", "-")
	return "%s-%04d" % [t, randi() % 10000]


static func _dossier_pret() -> bool:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DOSSIER)):
		return true
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DOSSIER)) == OK


## Une traversée existe à partir du premier geste posé — pas du premier beat affiché, que le jeu
## présente de lui-même, ni de l'ouverture, qui n'est qu'une intention.
static func _a_joue() -> bool:
	if _courante.is_empty():
		return false
	for b in (_courante["beats"] as Array):
		if (b as Dictionary).has("action") or (b as Dictionary).has("degre"):
			return true
	return false


static func _ecrire() -> void:
	if not _a_joue() or not _dossier_pret():
		return
	var f: FileAccess = FileAccess.open("%s/%s.json" % [DOSSIER, _id], FileAccess.WRITE)
	if f == null:
		push_warning("[MerlinJournal] chronique non écrite : %s" % _id)
		return
	f.store_string(JSON.stringify(_courante, " "))
	f.close()
	# L'INDEX SUIT LE FICHIER, TOUJOURS. Ne l'écrire qu'à la clôture rendait une traversée
	# interrompue invisible dans la liste alors que son fichier existait : « tout garder » aurait
	# voulu dire « tout garder sauf ce qu'on ne peut plus rejouer », c'est-à-dire justement les
	# parties qu'on voudrait comprendre. Deux petites écritures par beat, et les deux fichiers ne
	# peuvent pas raconter des choses différentes.
	_indexer()


## L'index se relit puis se réécrit en entier : quelques centaines de lignes, une fois par
## traversée. Le faire en ajout brut économiserait une lecture et coûterait un fichier corrompu
## le jour où une écriture est coupée en deux.
static func _indexer() -> void:
	if not _dossier_pret():
		return
	var lignes: Array = []
	var f: FileAccess = FileAccess.open(INDEX, FileAccess.READ)
	if f != null:
		var brut: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(brut) == TYPE_ARRAY:
			lignes = brut
	var fin: Dictionary = _courante.get("fin", {}) as Dictionary
	var ligne: Dictionary = {
		"id": _id,
		"iso": str(_courante.get("debut_iso", "")),
		"titre": str(_courante.get("titre", "")),
		"biome": str(_courante.get("biome", "")),
		"fin": str(fin.get("type", "")),
		"beats": (_courante.get("beats", []) as Array).size(),
		"integrite": int(fin.get("integrite", 0)),
		"corruption": int(fin.get("corruption", 0)),
		"signes": _signes(),
	}
	# Mise à jour en place si la traversée est déjà connue — sinon un beat de plus ajouterait une
	# ligne de plus, et la liste compterait des traversées qui n'ont jamais eu lieu.
	var trouve: bool = false
	for i in range(lignes.size()):
		if str((lignes[i] as Dictionary).get("id", "")) == _id:
			lignes[i] = ligne
			trouve = true
			break
	if not trouve:
		lignes.append(ligne)
	var g: FileAccess = FileAccess.open(INDEX, FileAccess.WRITE)
	if g == null:
		push_warning("[MerlinJournal] index non écrit")
		return
	g.store_string(JSON.stringify(lignes, " "))
	g.close()


## Le poids de prose de la traversée. C'est la mesure la plus simple de « le jeu écrit-il plus,
## ou moins ? » — elle s'affiche dans la liste et ne coûte rien à calculer.
static func _signes() -> int:
	var n: int = 0
	for b in (_courante.get("beats", []) as Array):
		n += str((b as Dictionary).get("scene", "")).length()
		n += str((b as Dictionary).get("issue", "")).length()
	return n
