#!/usr/bin/env python3
"""Patch v48.1d — LE BOT NE CHOISIT PLUS SEULEMENT, IL CONSTRUIT.

POURQUOI CE PATCH EXISTE. v48.1a a donne au bot de la partie temoin une politique de choix
couvrante. Ce n'etait pas assez, et le rejeu de p68 le prouve chiffre en main : en rejouant les
CINQ beats avec les des et les mains REELLEMENT tires, la meilleure paire (action, trait)
possible donne 3 reussites sur 5, pas 5 sur 5. Les beats 3 et 5 etaient IMPRENABLES : ils
reclamaient « Ruse » et « Nature », et aucune combinaison offerte ne portait ces tags.

La cause est structurelle, pas malchanceuse. `REQ_GAP_BY_DIFF = {1:1, 2:2, 3:2}`
(merlin_scenario.gd:109) : des la difficulte 2, les DEUX tags requis sont tires HORS des tags de
base des actions. Il faut donc les trouver dans la main de quatre traits — et un seul trait du
deck de seize en porte deux a la fois. Choisir mieux ne peut pas reparer une main qui ne contient
pas la reponse.

Le chemin honnete vers la reussite complete ne passe donc pas par le choix, mais par la
CONSTRUCTION — exactement comme pour un joueur humain qui sait jouer :

1. LE DRAFT PILOTE. Le bot prenait la premiere carte venue. Il lit desormais le `kind` de chaque
   greffe offerte (`game._graft_by_id`) et choisit dans cet ordre : `talent` (maitrise du verbe,
   +1 skill_mod — a 2 le geste devient sur hors Climax), `tag` (il AJOUTE un tag a l'action, donc
   il fabrique la couverture qui manquait), `roll` (+N au jet), puis le reste. Et il pose tout sur
   LE MEME verbe : trois greffes eparpillees ne font basculer aucun seuil.

2. LE PACTE EVALUE. Le bot cliquait le premier bouton, toujours, sans regarder. Il paie donc de
   la corruption pour des conversions inutiles — et il en refuse implicitement l'usage quand
   elles seraient decisives. Desormais il RE-SCORE avec le tag propose (`game._convert_offer_tag`,
   passe en `bonus_tags` a la vraie fonction du jeu) et n'accepte que si le meilleur degre
   atteignable s'ameliore, ou si le geste devient sur. Sinon il garde sa carte.

3. LE VERBE DE PREDILECTION. La maitrise se gagne en rejouant le meme verbe. Le choix couvrant
   departage donc, A QUALITE EGALE SEULEMENT, en faveur du verbe qui porte les greffes. Jamais
   au prix d'un degre inferieur : la mecanique du jeu passe avant l'optimisation du bot.

CE QUE CE PATCH NE FAIT TOUJOURS PAS : truquer. Aucun de force, aucun degre impose, aucun DC
baisse, aucune regle du jeu modifiee. Le bot joue ce qu'un joueur avise jouerait, avec les memes
cartes et les memes des. Et au Climax le geste sur reste desactive par regle (v34/v46) : si la
construction n'a pas suffi, le journal le dira au lieu de le maquiller.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("tools/probe_partie_journal.gd")
t = p.read_text(encoding="utf-8")

# ============================================================================ 1. l'etat
t = exact(
    t,
    "var _meca: Dictionary = {}\n",
    """var _meca: Dictionary = {}
# v48.1d — LE VERBE DE PREDILECTION : celui sur lequel toutes les greffes s'empilent. Trois
# greffes eparpillees sur trois verbes ne font basculer aucun seuil ; trois sur le meme font
# passer la maitrise a 2 (geste sur hors Climax) et ajoutent les tags qui manquaient.
var _verbe_prefere: Variant = null
""",
    "l'etat du verbe prefere",
)

# ============================================================================ 2. le draft pilote
t = exact(
    t,
    """		if game._draft_active:
			await create_timer(0.4).timeout
			if is_instance_valid(game) and game._draft_active:
				var cv: Node = _trouver_carte(game._hand_box)
				if cv != null:
					game._on_draft_card(cv.card)
					if not (game._pending_graft as Dictionary).is_empty():
						await create_timer(0.3).timeout
						if is_instance_valid(game) and game._draft_active:
							for a in run.actions:
								if (a.get("grafts") as Array).size() < int(run.MAX_GRAFTS_PER_ACTION):
									game._on_action_tile(a)
									if game._draft_done_flag:
										_incident("greffe « %s » posée sur %s"
												% [str(cv.card.get("card_name")), str(a.get("card_name"))])
									break
				else:
					game._on_draft_skip()
					if game._draft_done_flag:
						_incident("draft passé")""",
    """		if game._draft_active:
			await create_timer(0.4).timeout
			if is_instance_valid(game) and game._draft_active:
				# v48.1d — on ne prend plus la premiere carte venue : on lit le kind de chaque
				# greffe offerte et on choisit celle qui construit vraiment (talent > tag >
				# roll > reste), puis on la pose sur LE MEME verbe que les precedentes.
				var cv: Node = _meilleure_greffe(game) if _couvrant else _trouver_carte(game._hand_box)
				if cv != null:
					game._on_draft_card(cv.card)
					if not (game._pending_graft as Dictionary).is_empty():
						await create_timer(0.3).timeout
						if is_instance_valid(game) and game._draft_active:
							var cible: Variant = _verbe_a_greffer(run)
							for a in ([cible] + run.actions if cible != null else run.actions):
								if a == null:
									continue
								if (a.get("grafts") as Array).size() < int(run.MAX_GRAFTS_PER_ACTION):
									game._on_action_tile(a)
									if game._draft_done_flag:
										if _verbe_prefere == null:
											_verbe_prefere = a
										_incident("greffe « %s » posée sur %s"
												% [str(cv.card.get("card_name")), str(a.get("card_name"))])
									break
				else:
					game._on_draft_skip()
					if game._draft_done_flag:
						_incident("draft passé")""",
    "le draft pilote",
)

# ============================================================================ 3. le pacte evalue
t = exact(
    t,
    """		if game._pact_row != null and is_instance_valid(game._pact_row):
			await create_timer(0.3).timeout
			if is_instance_valid(game) and game._pact_row != null and is_instance_valid(game._pact_row):
				var pb: Array = []
				for b in game._pact_row.get_children():
					if b is Button:
						pb.append(b)
				if not pb.is_empty():
					(pb[0] as Button).pressed.emit()
					_incident("pacte : « %s »" % str((pb[0] as Button).text))""",
    """		if game._pact_row != null and is_instance_valid(game._pact_row):
			await create_timer(0.3).timeout
			if is_instance_valid(game) and game._pact_row != null and is_instance_valid(game._pact_row):
				var pb: Array = []
				for b in game._pact_row.get_children():
					if b is Button:
						pb.append(b)
				if not pb.is_empty():
					# v48.1d — le bot cliquait « accepter » a l'aveugle, payant de la
					# corruption pour des conversions inutiles. Il re-score maintenant avec
					# le tag propose et n'accepte que si cela change vraiment le degre.
					var utile: bool = true
					var motif: String = ""
					if _couvrant:
						var j: Dictionary = _pacte_utile(game, run)
						utile = bool(j.get("utile", true))
						motif = str(j.get("motif", ""))
					var idx: int = 0 if utile else mini(1, pb.size() - 1)
					(pb[idx] as Button).pressed.emit()
					_incident("pacte %s : « %s »%s"
							% ["ACCEPTE" if utile else "refusé",
								str((pb[idx] as Button).text), motif])""",
    "le pacte evalue",
)

# ============================================================================ 4. les trois fonctions
t = exact(
    t,
    "# Consigne POURQUOI le bot a joue cette paire",
    '''# v48.1d — LA MEILLEURE GREFFE DU DRAFT. On lit le `kind` dans game._graft_by_id (l'id de la
# carte de presentation est celui de la greffe : merlin_game.gd:1607) et on classe par ce qui
# fait REELLEMENT basculer un seuil :
#   talent (+1 skill_mod : a 2, MARGE_MAITRISE rend le geste sur hors Climax)
#   tag    (AJOUTE un tag a l'action — c'est le seul levier qui fabrique la couverture manquante
#           quand la main ne porte pas les tags requis, ce qui arrive des la difficulte 2)
#   roll   (+N au jet)
#   le reste (charge, etc.) : mieux que rien.
# Retourne null si rien n'est lisible — l'appelant retombe alors sur la premiere carte.
func _meilleure_greffe(game: Node) -> Node:
	if game._hand_box == null or not ("_graft_by_id" in game):
		return _trouver_carte(game._hand_box)
	var rang: Dictionary = {"talent": 4, "tag": 3, "roll": 2}
	var best: Node = null
	var best_n: int = -1
	for c in game._hand_box.get_children():
		if not ("card" in c) or c.card == null:
			continue
		var cid: String = ""
		if c.card is Object and ("id" in c.card):
			cid = str(c.card.id)
		var g: Dictionary = (game._graft_by_id as Dictionary).get(cid, {}) as Dictionary
		var n: int = int(rang.get(str(g.get("kind", "")), 1))
		if n > best_n:
			best_n = n
			best = c
	return best if best != null else _trouver_carte(game._hand_box)


# Le verbe sur lequel empiler : celui deja choisi, tant qu'il a de la place. Un verbe qui a
# atteint le cap rend la main au premier verbe libre (l'appelant balaie ensuite run.actions).
func _verbe_a_greffer(run: Node) -> Variant:
	if _verbe_prefere != null and (_verbe_prefere.get("grafts") as Array).size() \\
			< int(run.MAX_GRAFTS_PER_ACTION):
		return _verbe_prefere
	return null


# v48.1d — LE PACTE VAUT-IL SA CORRUPTION ? On rejoue le score de TOUTES les paires avec le tag
# propose ajoute aux bonus (c'est exactement ce que la conversion fait dans le jeu : elle etend
# la couverture), et on ne l'accepte que si le meilleur degre atteignable s'ameliore, ou si le
# geste devient sur. Sinon le tag ne sert a rien et la corruption est un pur prix.
func _pacte_utile(game: Node, run: Node) -> Dictionary:
	if _MR == null or not ("_convert_offer_tag" in game):
		return {"utile": true, "motif": ""}
	var tag: String = str(game._convert_offer_tag).strip_edges()
	if tag == "":
		return {"utile": true, "motif": ""}
	var sans: Dictionary = _meilleur_score(game, run, [])
	var avec: Dictionary = _meilleur_score(game, run, [tag])
	if sans.is_empty() or avec.is_empty():
		return {"utile": true, "motif": ""}
	var mieux: bool = int(avec.get("rang", 0)) > int(sans.get("rang", 0)) \\
			or (bool(avec.get("geste_sur", false)) and not bool(sans.get("geste_sur", false)))
	return {"utile": mieux,
		"motif": " (%s → %s)" % [str(sans.get("degre", "?")), str(avec.get("degre", "?"))]}


# Le meilleur (action, trait) atteignable, avec d'eventuels tags offerts en plus. Partage sa
# mecanique avec _choix_couvrant : meme fonction du jeu, memes arguments (R120).
func _meilleur_score(game: Node, run: Node, tags_en_plus: Array) -> Dictionary:
	if _MR == null:
		return {}
	var situ: Dictionary = game._current_situation
	if situ.is_empty() or (run.actions as Array).is_empty() or (run.hand as Array).is_empty():
		return {}
	var reqs: Array = situ.get("required_tags", [])
	var diff: int = int(situ.get("difficulte", 2))
	var btype: String = str(situ.get("type", ""))
	var dcb: int = int(situ.get("dc_bonus", 0))
	var de: int = int(situ.get("die", 0))
	if run.has_method("has_coup_de_pouce_armed") and run.has_coup_de_pouce_armed():
		de = maxi(de, int(situ.get("face_adv", 0)))
	var best: Dictionary = {}
	var meilleur: int = -99999
	for a in run.actions:
		var sm: int = int(run.skill_mod_for(a)) if run.has_method("skill_mod_for") else 0
		var gb: int = int(run.graft_roll_bonus(a)) if run.has_method("graft_roll_bonus") else 0
		for tr in run.hand:
			var combo: Array = [a, tr]
			var bonus: Array = (run.blessed_bonus(combo) if run.has_method("blessed_bonus") else []).duplicate()
			for x in tags_en_plus:
				bonus.append(str(x))
			var r: Dictionary = _MR.resolve(reqs, combo, [], de, bonus, diff, sm, gb, btype, dcb)
			var deg: String = str(r.get("degree", ""))
			var rang: int = 3 if deg == "eclatante" else (2 if deg == "reussite" else (1 if deg == "partiel" else 0))
			var note: int = rang * 1000 + int(r.get("margin", 0)) * 10
			if note > meilleur:
				meilleur = note
				best = {"rang": rang, "degre": deg, "geste_sur": bool(r.get("geste_sur", false)),
					"marge": int(r.get("margin", 0))}
	return best


# Consigne POURQUOI le bot a joue cette paire''',
    "les trois fonctions",
)

# ============================================================================ 5. le departage
t = exact(
    t,
    """			var note: int = rang * 1000 + int(r.get("margin", 0)) * 10 + couv
			if note > meilleur:""",
    """			# v48.1d — a QUALITE EGALE seulement, on prefere le verbe qui porte les greffes :
			# c'est ainsi que la maitrise monte (3 poses du meme verbe = +1, et a 2 le geste
			# devient sur hors Climax). Le poids est de 1, sous la couverture : jamais au prix
			# d'un degre ni d'une marge.
			var fidele: int = 1 if (_verbe_prefere != null and a == _verbe_prefere) else 0
			var note: int = rang * 10000 + int(r.get("margin", 0)) * 100 + couv * 10 + fidele
			if note > meilleur:""",
    "le departage par le verbe",
)

p.write_text(t, encoding="utf-8")
print("v48.1d applique : le bot pilote son draft (talent > tag > roll, tout sur le meme verbe),")
print("evalue ses pactes au lieu de les accepter en aveugle, et departage a qualite egale en")
print("faveur du verbe qu'il fait monter en maitrise.")
