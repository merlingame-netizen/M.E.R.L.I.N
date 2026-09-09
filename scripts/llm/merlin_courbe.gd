class_name MerlinCourbe
extends RefCounted
## LA COURBE DE LA QUÊTE — cinq mouvements, un Tour, une matière par beat (09/09).
##
## POURQUOI. Sur p104 (24 beats entièrement générés), le modèle recevait quatre rôles en boucle :
## « une progression », « une rencontre », « un obstacle », « un choix ». Vingt-quatre scènes plates,
## vingt-et-une réussites, aucun retournement, et des images qui reviennent (la brume monte, le sol
## humide). Maxime a tranché le 09/09 : la quête suit CINQ MOUVEMENTS, elle porte un TOUR au milieu,
## aucun rôle ne se répète deux fois de suite, et chaque scène s'ancre dans une MATIÈRE imposée.
##
## PUR. Aucune lecture d'autoload, aucun état : (position, longueur, titre, graine) → un plan.
## Déterministe : deux appels avec les mêmes entrées rendent le même plan, donc la sonde et la
## partie voient la même chose, et l'épreuve headless peut tout vérifier.
##
## LES CINQ MOUVEMENTS, en proportion de la longueur :
##   ARRIVEE        1 beat    on entre, on découvre l'enjeu
##   PISTE          ~35 %     on apprend, on s'enfonce, la piste se précise
##   TOUR           1 beat    ce qu'on croyait se retourne (le but n'était pas le but,
##                            ou un être croisé change de camp)
##   MONTEE         ~35 %     le prix monte, l'étau se serre, plus de retour en arrière
##   CONFRONTATION  1-2 beats le choix qui engage la fin, puis la résolution

const ARRIVEE: String = "arrivee"
const PISTE: String = "piste"
const TOUR: String = "tour"
const MONTEE: String = "montee"
const CONFRONTATION: String = "confrontation"

## Les deux formes du Tour retenues par Maxime (09/09). La seconde n'est proposée que si une figure
## a déjà été croisée : un être ne se retourne que si on l'a rencontré.
const TOUR_BUT: String = "but"
const TOUR_ETRE: String = "etre"

# Les rôles de la PISTE et de la MONTÉE, tirés sans jamais répéter le précédent. Chacun dit une
# CHOSE À FAIRE, pas une ambiance : le modèle écrit mieux un ordre qu'une humeur.
const ROLES_PISTE: Array = [
	"une trace a lire : quelque chose ici dit ou est passe ce que vous cherchez",
	"un etre qui sait et qui ne dit pas tout : il faut le faire parler",
	"un passage qui resiste : le lieu ne vous laisse pas avancer sans payer d'effort",
	"un temoin de ce qui s'est passe ici avant vous : un reste, une marque, un objet abandonne",
	"une fausse piste qui coute du temps : elle ressemble a la bonne et n'en est pas une",
]
const ROLES_MONTEE: Array = [
	"ce que vous avez derange se met en travers : quelque chose vous suit ou vous attend",
	"un prix a payer tout de suite pour continuer",
	"le lieu se referme derriere vous : reculer n'est plus une option",
	"un etre vous met en garde une derniere fois, et il a de bonnes raisons",
	"une porte, un seuil, une garde : le dernier obstacle avant le but",
]


## Le mouvement du beat `pos` (0-indexé) dans une quête de `total` beats.
static func mouvement(pos: int, total: int) -> String:
	if total <= 2:
		return ARRIVEE if pos == 0 else CONFRONTATION
	if pos <= 0:
		return ARRIVEE
	if pos >= total - 1:
		return CONFRONTATION
	if total <= 4:
		return PISTE if pos == 1 else MONTEE
	var tours: Array = beats_du_tour(total)
	if tours.has(pos):
		return TOUR
	if pos >= total - 2:
		return CONFRONTATION
	return PISTE if pos < int(tours[0]) else MONTEE


## À quel beat le Tour tombe : au milieu, jamais avant le 3e beat ni après l'avant-avant-dernier.
## Rend le PREMIER tour ; sur une quête longue il y en a deux (voir beats_du_tour).
static func beat_du_tour(total: int) -> int:
	var t: Array = beats_du_tour(total)
	return int(t[0]) if not t.is_empty() else -1


## LES TOURS de la quête. Maxime a demandé « du dynamisme et des rebondissements » : un seul
## retournement au milieu de vingt-quatre beats laisse onze beats de piste plate. Donc UN tour au
## milieu jusqu'à treize beats, DEUX au tiers et aux deux tiers au-delà — jamais voisins, jamais
## dans les deux premiers ni les deux derniers beats.
const LONGUE: int = 14


static func beats_du_tour(total: int) -> Array:
	if total < 5:
		return []
	if total < LONGUE:
		return [clampi(int(total / 2), 2, total - 3)]
	var t1: int = clampi(int(total / 3), 2, total - 6)
	var t2: int = clampi(int(2 * total / 3), t1 + 3, total - 3)
	return [t1, t2]


## Le rôle EXACT du beat : ce que la scène doit faire arriver. `deja_croisee` dit si une figure a
## déjà été rencontrée (sinon le Tour ne peut pas être « l'être se retourne »).
static func role(pos: int, total: int, titre: String, graine: int = 0, deja_croisee: String = "") -> String:
	var mv: String = mouvement(pos, total)
	match mv:
		ARRIVEE:
			return "l'ARRIVEE : vous entrez dans le lieu et vous DECOUVREZ ce qui s'y joue, sans encore savoir a qui vous avez affaire"
		TOUR:
			if forme_du_tour(total, graine, deja_croisee, pos) == TOUR_ETRE:
				return ("LE TOUR de la quete : %s, deja croise, revient et CHANGE DE CAMP. "
					+ "Ce qu'il faisait pour vous, il le fait contre vous, ou l'inverse. Dis-le par un FAIT, pas par une explication") % deja_croisee
			return ("LE TOUR de la quete : ce que vous cherchiez EXISTE, mais PAS comme on vous l'a dit. "
				+ "La chose est deja prise, ou le coupable n'est pas celui qu'on accuse, ou le secret protegeait quelqu'un. "
				+ "Le but ne disparait pas : il se CORRIGE, et la suite vise la version vraie")
		CONFRONTATION:
			if pos >= total - 1:
				return "la CONFRONTATION FINALE qui RESOUT « %s » : vous atteignez, obtenez ou affrontez ce que la quete promet, et cela se termine ici" % titre
			return "le DERNIER CHOIX avant la fin : deux voies s'ouvrent et celle que vous prenez decide de la fin"
		MONTEE:
			return _tire(ROLES_MONTEE, pos, graine)
		_:
			return _tire(ROLES_PISTE, pos, graine)


## La forme du Tour. « L'être se retourne » demande une figure déjà croisée. Quand une quête porte
## DEUX tours, le second prend l'autre forme que le premier : deux fois la même surprise n'en fait
## qu'une. `pos` dit lequel des deux tours on écrit.
static func forme_du_tour(total: int, graine: int, deja_croisee: String, pos: int = -1) -> String:
	if deja_croisee.strip_edges() == "":
		return TOUR_BUT
	var premier: bool = (absi(graine + total) % 2) == 1
	var tours: Array = beats_du_tour(total)
	if pos >= 0 and tours.size() > 1 and pos == int(tours[1]):
		premier = not premier
	return TOUR_ETRE if premier else TOUR_BUT


## Où l'on en est, dit au modèle en clair : « 3e des 7 beats de la piste ».
static func etat(pos: int, total: int) -> String:
	var mv: String = mouvement(pos, total)
	var debut: int = pos
	while debut > 0 and mouvement(debut - 1, total) == mv:
		debut -= 1
	var fin: int = pos
	while fin < total - 1 and mouvement(fin + 1, total) == mv:
		fin += 1
	var n: int = fin - debut + 1
	var rang: int = pos - debut + 1
	var noms: Dictionary = {
		ARRIVEE: "l'arrivee", PISTE: "la piste", TOUR: "le tour",
		MONTEE: "la montee", CONFRONTATION: "la confrontation",
	}
	if n <= 1:
		return "%s (beat %d sur %d de la quete)" % [str(noms.get(mv, mv)), pos + 1, total]
	return "%s, %de beat sur %d (beat %d sur %d de la quete)" % [str(noms.get(mv, mv)), rang, n, pos + 1, total]


## LA MATIÈRE DU BEAT : une chose du lieu, différente à chaque scène, que la scène doit toucher.
## Tirée de la liste que la bible des biomes tient déjà (MerlinPromptBuilder.BIOMES[…]["matiere"]),
## parcourue dans un ordre décalé par la graine : aucune table nouvelle à maintenir.
static func matiere(matieres_du_lieu: String, pos: int, graine: int = 0) -> String:
	var bouts: PackedStringArray = PackedStringArray()
	for m in matieres_du_lieu.split(","):
		var t: String = m.strip_edges()
		if t != "":
			bouts.append(t)
	if bouts.is_empty():
		return ""
	return bouts[absi(graine + pos) % bouts.size()]


## Une graine stable pour une quête : son titre. Deux parties du même sentier tirent le même plan.
static func graine_de(titre: String) -> int:
	return absi(hash(titre)) % 1000


# Tire dans `liste` sans jamais rendre deux fois de suite le même élément : l'index avance d'au
# moins un cran à chaque beat (pos + décalage), donc deux beats voisins ne peuvent pas coïncider.
static func _tire(liste: Array, pos: int, graine: int) -> String:
	return str(liste[absi(graine + pos) % liste.size()])
