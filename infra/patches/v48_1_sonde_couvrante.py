#!/usr/bin/env python3
"""Patch v48.1a — LA SONDE QUI JOUE BIEN ET QUI MESURE JUSTE.

Maxime (2026-08-27) : « Il faut pas de secours et de la reussite complete a chaque fois plus une
duree de max 20s/beat ». Il a precise ensuite que la « reussite complete » vise LA PARTIE TEMOIN
seulement : le jeu reel garde ses des, ses partiels et son equilibrage (R158/R166 intacts).

Ce patch ne touche QUE tools/probe_partie_journal.gd -- le harnais de la chronique, jamais le jeu.
Il repare quatre choses, toutes mesurees sur le journal de p68 :

1. LE BOT JOUAIT EN AVEUGLE. `acts[geste % acts.size()]` et `hand[geste % hand.size()]` cyclaient
   sans jamais regarder les tags que le lieu reclamait. Resultat p68 : 2 reussites, 3 partiels.
   Le beat 3 le montre en clair -- requis [Ruse, Nature], joue COMBATTRE(Force,Endurance) x La
   Presence Calme(Autorite,Empathie) : couverture 0, mods 0, de 6, marge -3, partiel.
   Desormais (MERLIN_BOT_COUVRANT=1) la sonde SCORE chaque paire (action, trait) avec la VRAIE
   fonction du jeu -- MerlinResolution.resolve, les memes arguments que _update_preview (R120) --
   et joue la meilleure. Aucune generation LLM n'est declenchee par ce scoring : on n'appelle
   PAS _update_preview (qui prefetcherait une prose par candidat, guardrail « jamais les 16
   combos ») ; les tuiles ne sont cliquees qu'une fois la paire choisie.
   Sans la variable d'environnement, le cyclage historique est conserve a l'identique.

2. LES MECANIQUES DU JOURNAL ETAIENT MUETTES DEPUIS v34. `_noter_sortie` lit `game._pending_res`,
   mais _pending_res est VIDE a ce moment : il est efface dans _on_typewriter_done
   (merlin_game.gd:2336), qui se produit AVANT que `_can_advance` ne passe a vrai. D'ou, dans
   tous les journaux : dc=0, total=0, geste_sur=false, marge_sure=0, phrase_geste="". Des valeurs
   impossibles (un DC vaut 6, 9 ou 12) que personne n'avait relevees. La sonde en prend desormais
   un INSTANTANE dans la boucle, des que _pending_res est rempli.

3. LA DUREE MESUREE N'ETAIT PAS L'ATTENTE. `duree_beat_s` = entree du beat -> avance, ce qui
   englobe la pose de 25 s du bot, l'etal du colporteur, le draft et le guide de Merlin. Le
   beat 1 de p68 « durait » 29 s dont 25 s de pose deliberee. Juger la cible des 20 s la-dessus
   n'a pas de sens. On ajoute `attente_moteur_s` : du clic Resoudre a l'issue affichee -- le seul
   intervalle ou le joueur attend VRAIMENT la machine, sans rien a faire. `duree_beat_s` est
   conservee telle quelle (comparabilite avec les parties precedentes).

4. LA PAIRE CHOISIE N'ETAIT PAS JUSTIFIEE. On consigne desormais `choix_du_bot` : couverture
   obtenue, marge prevue, et le nombre de paires examinees. Une chronique doit pouvoir montrer
   POURQUOI un geste a ete joue.

Ce que le patch NE fait PAS, volontairement : il ne truque aucun de, ne force aucun degre, ne
baisse aucun DC. Au Climax le « geste sur » reste desactive par regle du jeu (v34/v46), donc
meme une couverture parfaite n'y garantit pas 100 % de reussite -- c'est dit au journal, pas
maquille.
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

# ---------------------------------------------------------------- 1. etat de la sonde
ANCIEN_ETAT = """var _journal: Dictionary = {}
var _shots_dir: String = ""
var _shots: int = 0
var _pick: int = 0
"""

NOUVEAU_ETAT = """var _journal: Dictionary = {}
var _shots_dir: String = ""
var _shots: int = 0
var _pick: int = 0
# v48.1 — LE BOT COUVRANT (MERLIN_BOT_COUVRANT=1). Le harnais choisissait ses cartes en cyclant
# a l'aveugle, sans jamais lire les tags que le lieu reclamait : p68 a fini a 2 reussites pour
# 3 partiels, et le beat 3 y jouait Force+Endurance contre un lieu qui demandait Ruse et Nature.
# Une chronique doit montrer une partie BIEN JOUEE ; le jeu reel, lui, garde ses des et ses
# partiels — ce drapeau ne vit que dans la sonde.
var _couvrant: bool = false
# Charge DYNAMIQUEMENT (jamais de class_name en mode --script : la regle du dossier tools/).
var _MR: GDScript = null
# Instantane des mecaniques, pris DANS la boucle : _pending_res est efface par
# _on_typewriter_done AVANT que _noter_sortie ne s'execute, si bien que dc/total/geste_sur
# etaient a zero dans TOUS les journaux depuis v34.
var _meca: Dictionary = {}
"""
t = exact(t, ANCIEN_ETAT, NOUVEAU_ETAT, "etat de la sonde")

# ---------------------------------------------------------------- 2. lecture du drapeau
ANCIEN_FLAG = """	var biome: String = OS.get_environment("MERLIN_BIOME")
	if biome == "":
		biome = "foret"
	run.biome = biome
"""

NOUVEAU_FLAG = """	var biome: String = OS.get_environment("MERLIN_BIOME")
	if biome == "":
		biome = "foret"
	run.biome = biome

	_couvrant = OS.get_environment("MERLIN_BOT_COUVRANT") == "1"
	if _couvrant:
		_MR = load("res://scripts/game/merlin_resolution.gd")
		if _MR == null or not _MR.has_method("resolve"):
			_couvrant = false
			print("[JOURNAL] bot couvrant DEMANDE mais merlin_resolution.gd illisible — cyclage conserve")
	print("[JOURNAL] choix des cartes : %s" % ("COUVRANT (v48.1)" if _couvrant else "cyclage (historique)"))
"""
t = exact(t, ANCIEN_FLAG, NOUVEAU_FLAG, "lecture du drapeau")

# ---------------------------------------------------------------- 3. le choix des cartes
ANCIEN_CHOIX = """			if game._choice_open and (run.hand as Array).size() >= 1:
				var acts: Array = run.actions
				if game._selected_action == null and not acts.is_empty():
					game._on_action_tile(acts[geste % acts.size()])
				elif game._selected_trait == null:
					game._on_trait_card(run.hand[geste % (run.hand as Array).size()])
					geste += 1"""

NOUVEAU_CHOIX = """			if game._choice_open and (run.hand as Array).size() >= 1:
				var acts: Array = run.actions
				if game._selected_action == null and not acts.is_empty():
					var vise: Dictionary = _choix_couvrant(game, run) if _couvrant else {}
					if vise.has("action"):
						game._on_action_tile(vise["action"])
						_noter_choix(vise)
					else:
						game._on_action_tile(acts[geste % acts.size()])
				elif game._selected_trait == null:
					var vise2: Dictionary = _choix_couvrant(game, run) if _couvrant else {}
					if vise2.has("trait"):
						game._on_trait_card(vise2["trait"])
					else:
						game._on_trait_card(run.hand[geste % (run.hand as Array).size()])
					geste += 1"""
t = exact(t, ANCIEN_CHOIX, NOUVEAU_CHOIX, "choix des cartes")

# ---------------------------------------------------------------- 4. horloge du moteur
ANCIEN_HORLOGE = """				else:
					_noter_geste(game)
					game._on_resolve()"""

NOUVEAU_HORLOGE = """				else:
					_noter_geste(game)
					# v48.1 — L'HORLOGE DE L'ATTENTE. Ici commence le seul intervalle ou le
					# joueur attend la MACHINE sans rien a faire : du clic Resoudre a l'issue
					# affichee. `duree_beat_s` melangeait cela avec la pose de 25 s, l'etal et
					# le draft — le beat 1 de p68 « durait » 29 s dont 25 s de pose deliberee.
					var bb: Array = _journal["beats"]
					if not bb.is_empty():
						(bb[bb.size() - 1] as Dictionary)["t_geste_ms"] = Time.get_ticks_msec()
					game._on_resolve()"""
t = exact(t, ANCIEN_HORLOGE, NOUVEAU_HORLOGE, "horloge du moteur")

# ---------------------------------------------------------------- 5. instantane des mecaniques
ANCIEN_SNAP = """		if game._state == 1:
			# ENTRÉE DU BEAT : la situation vient d'être écrite, on la fige avant tout geste."""

NOUVEAU_SNAP = """		# v48.1 — L'INSTANTANE DES MECANIQUES, pris ICI et pas a la sortie. _pending_res
		# est efface dans _on_typewriter_done (merlin_game.gd:2336), qui court AVANT que
		# `_can_advance` ne passe a vrai : _noter_sortie lisait donc un dictionnaire vide, et
		# dc=0 / total=0 / geste_sur=false / phrase_geste="" dormaient dans TOUS les journaux
		# depuis v34 — des valeurs impossibles (un DC vaut 6, 9 ou 12) que rien ne signalait.
		if _meca.is_empty() and ("_pending_res" in game) and game._pending_res is Dictionary \\
				and not (game._pending_res as Dictionary).is_empty():
			_meca = (game._pending_res as Dictionary).duplicate()

		if game._state == 1:
			# ENTRÉE DU BEAT : la situation vient d'être écrite, on la fige avant tout geste."""

t = exact(t, ANCIEN_SNAP, NOUVEAU_SNAP, "instantane des mecaniques")

# ---------------------------------------------------------------- 6. lecture a la sortie
ANCIEN_SORTIE = """	var g_res: Node = current_scene
	if g_res != null and ("_pending_res" in g_res) and g_res._pending_res is Dictionary:
		var pres: Dictionary = g_res._pending_res
		d["geste_sur"] = bool(pres.get("geste_sur", false))
		# v46 : la phrase du geste (composee par le code) et la mise annoncee avant le de.
		d["phrase_geste"] = str(pres.get("phrase_geste", ""))
		d["mise"] = str(pres.get("mise", ""))
		d["marge_sure"] = int(pres.get("marge_sure", 0))
		d["total"] = int(pres.get("total", 0))
		d["dc"] = int(pres.get("dc", 0))"""

NOUVEAU_SORTIE = """	# v48.1 — L'ATTENTE MACHINE, distincte de la duree du beat. `duree_beat_s` ci-dessus compte
	# tout (pose de 25 s, etal, draft, guide) ; celle-ci ne compte que ce que le joueur SUBIT.
	if d.has("t_geste_ms"):
		d["attente_moteur_s"] = float(int(d["t_res_ms"]) - int(d["t_geste_ms"])) / 1000.0
	# v48.1 — les mecaniques viennent de l'instantane pris dans la boucle, plus de _pending_res
	# (efface trop tot : voir le commentaire de la boucle).
	var pres: Dictionary = _meca
	if pres.is_empty():
		var g_res: Node = current_scene
		if g_res != null and ("_pending_res" in g_res) and g_res._pending_res is Dictionary:
			pres = g_res._pending_res
	if not pres.is_empty():
		d["geste_sur"] = bool(pres.get("geste_sur", false))
		# v46 : la phrase du geste (composee par le code) et la mise annoncee avant le de.
		d["phrase_geste"] = str(pres.get("phrase_geste", ""))
		d["mise"] = str(pres.get("mise", ""))
		d["marge_sure"] = int(pres.get("marge_sure", 0))
		d["total"] = int(pres.get("total", 0))
		d["dc"] = int(pres.get("dc", 0))
		d["marge"] = int(pres.get("total", 0)) - int(pres.get("dc", 0))
	_meca = {}"""
t = exact(t, ANCIEN_SORTIE, NOUVEAU_SORTIE, "lecture a la sortie")

# ---------------------------------------------------------------- 7. les deux fonctions
ANCIEN_FIN = """func _noter_geste(game: Node) -> void:"""

NOUVEAU_FIN = '''# === v48.1 — LE CHOIX COUVRANT ===============================================================
#
# Le harnais lit les forces que le lieu reclame et joue la paire (action, trait) qui les couvre.
# Il SCORE avec la vraie fonction du jeu -- MerlinResolution.resolve, les memes arguments que
# _update_preview (R120 : preview = resolution) -- pour que la paire jugee la meilleure ici soit
# EXACTEMENT celle que le jeu resoudra.
#
# CE QU'IL NE FAIT PAS : il n'appelle jamais _update_preview, qui declencherait une
# pre-generation de prose par candidat (guardrail du jeu : « jamais les 16 combos »). Le scoring
# est purement arithmetique, zero LLM, zero attente. Et il ne truque rien : le de est celui du
# beat, le DC celui de la difficulte. Au Climax le geste sur est desactive par regle (v34/v46),
# donc meme une couverture parfaite n'y garantit pas la reussite -- le journal le dira.
#
# Retourne {} si le scoring est impossible (appelant : cyclage historique).
func _choix_couvrant(game: Node, run: Node) -> Dictionary:
	if _MR == null:
		return {}
	var acts: Array = run.actions
	var main: Array = run.hand
	if acts.is_empty() or main.is_empty():
		return {}
	var situ: Dictionary = game._current_situation
	if situ.is_empty():
		return {}
	var reqs: Array = situ.get("required_tags", [])
	var diff: int = int(situ.get("difficulte", 2))
	var btype: String = str(situ.get("type", ""))
	var dcb: int = int(situ.get("dc_bonus", 0))
	# Face effective : identique au calcul du jeu (Coup de Pouce en lecture seule, jamais consomme).
	var de: int = int(situ.get("die", 0))
	if run.has_method("has_coup_de_pouce_armed") and run.has_coup_de_pouce_armed():
		de = maxi(de, int(situ.get("face_adv", 0)))

	var best: Dictionary = {}
	var meilleur: int = -9999
	var examinees: int = 0
	for a in acts:
		var sm: int = int(run.skill_mod_for(a)) if run.has_method("skill_mod_for") else 0
		var gb: int = int(run.graft_roll_bonus(a)) if run.has_method("graft_roll_bonus") else 0
		for tr in main:
			var combo: Array = [a, tr]
			var bonus: Array = run.blessed_bonus(combo) if run.has_method("blessed_bonus") else []
			var r: Dictionary = _MR.resolve(reqs, combo, [], de, bonus, diff, sm, gb, btype, dcb)
			examinees += 1
			# Le classement : d'abord le DEGRE (une reussite bat toute marge d'un partiel), puis
			# la marge, puis la couverture — a egalite, le geste le plus juste pour le lieu.
			var deg: String = str(r.get("degree", ""))
			var rang: int = 3 if deg == "eclatante" else (2 if deg == "reussite" else (1 if deg == "partiel" else 0))
			# La couverture n'est PAS un entier du retour : elle vit sous « coverage »
			# ({covered, missing, extra}) — la lire ailleurs donnait un zero muet.
			var cov: Dictionary = r.get("coverage", {}) as Dictionary
			var couv: int = (cov.get("covered", []) as Array).size()
			var note: int = rang * 1000 + int(r.get("margin", 0)) * 10 + couv
			if note > meilleur:
				meilleur = note
				best = {"action": a, "trait": tr, "degre_prevu": deg,
					"marge_prevue": int(r.get("margin", 0)),
					"couverture": couv,
					"geste_sur": bool(r.get("geste_sur", false)),
					"examinees": examinees}
	if not best.is_empty():
		best["examinees"] = examinees
	return best


# Consigne POURQUOI le bot a joue cette paire — une chronique doit pouvoir le montrer.
func _noter_choix(vise: Dictionary) -> void:
	var b: Array = _journal["beats"]
	if b.is_empty() or vise.is_empty():
		return
	var d: Dictionary = b[b.size() - 1]
	d["choix_du_bot"] = {
		"degre_prevu": str(vise.get("degre_prevu", "")),
		"marge_prevue": int(vise.get("marge_prevue", 0)),
		"couverture": int(vise.get("couverture", 0)),
		"geste_sur": bool(vise.get("geste_sur", false)),
		"paires_examinees": int(vise.get("examinees", 0)),
	}


func _noter_geste(game: Node) -> void:'''
t = exact(t, ANCIEN_FIN, NOUVEAU_FIN, "les deux fonctions")

p.write_text(t, encoding="utf-8")
print("v48.1a applique : la sonde joue couvrant (MERLIN_BOT_COUVRANT=1), prend l'instantane des")
print("mecaniques a temps (dc/total/geste_sur n'etaient plus mesures depuis v34), et separe")
print("l'attente machine de la duree du beat.")
