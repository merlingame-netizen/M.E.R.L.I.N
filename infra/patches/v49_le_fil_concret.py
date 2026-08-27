#!/usr/bin/env python3
"""Patch v49 — LE FIL CONCRET : la scene suivante s'ouvre sur ce qui vient VRAIMENT de se passer.

LA DEMANDE. Maxime, 2026-08-27 : « une fois un beat redige + resolu il ne rentre pas dans le
contexte redactionnel du beat qui suit et c'est un probleme car on a des situations du coup qui
ne se suivent pas, on dirait des choix independants, je veux de la continuite ».

LE DIAGNOSTIC. Les six scenes de la derniere partie portent provenance="arc" : elles ont ete
ecrites AVANT d'etre jouees, a partir du seul titre et du pitch. La seule chose du beat N qui
atteint le beat N+1 est un pont MECANIQUE — un registre de verbes plus une locomotion tiree au
sort, sans un nom propre, sans un element du monde.

CE QUI REND CE PATCH POSSIBLE. La matiere de la continuite EXISTE DEJA et le code la jette. La
tete du prompt d'issue exige une derniere phrase qui ouvre la suite ; le modele obeit — « Une
petite creature grise avec des yeux luisants fixe vos mains pendant un instant. » — et
`note_issue_affichee` tronque l'issue a ses 420 PREMIERS caracteres, ce qui perd exactement cette
phrase sur quatre issues sur six. Puis personne ne la lit : `last_issue` n'etait consomme que par
le lookahead, debranche depuis v38.

Autrement dit : la continuite ne coute AUCUNE generation supplementaire. Il suffisait de garder
la bonne moitie du texte et de la lire.

CE QUE LE PATCH NE FAIT PAS : ranimer le lookahead. L'enquete a mesure que la fenetre n'existe
toujours pas — les trois scenes de la derniere tentative ont mis 95 a 108 s pour une fenetre de
53 a 70 s — et surtout que, meme ranime, il ne recevrait PAS l'issue : `issue_prec` prend
`last_gist` en priorite, et `note_outcome` (appele AVANT) le remplit toujours. Il recevrait donc
le meme registre abstrait que le pont. On ne rebranche rien ; on repare ce qui vit.

LES SEPT CHANGEMENTS :
  P1  la derniere phrase de l'issue doit NOMMER l'etre ou l'objet qui reagit (tete stable, 0/beat)
  P2  cette phrase est gardee (troncature par la FIN) et devient le pont (0 token de generation)
  P3  le pont peut etre une phrase pleine, et le Climax y a droit — il n'avait AUCUNE trace
  P4  le filet anti-echo compare a la scene SEULE, sinon il mange la continuite qu'on ajoute
  P5  le fil entre aussi dans le prompt d'issue PAR LA QUEUE, ou rien ne le tronque
  P6  les exemples du prompt systeme sortent : « un vieil homme sort de sa hutte » se recopiait
      verbatim dans la prose et simulait une fausse memoire
  P7  le pont mecanique, qui reste le repli, cesse d'afficher de l'ASCII et de se repeter
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


# =============================================================== merlin_prompt_builder.gd
p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# --- P1 : la derniere phrase NOMME -------------------------------------------------------
t = exact(
    t,
    " TERMINE par UNE phrase courte qui OUVRE LA SUITE (ce qui attend le Voyageur au pas "
    "suivant) : elle relance, elle ne resume ni ne commente. Termine sur une phrase complete.",
    " TERMINE par UNE phrase courte qui OUVRE LA SUITE (ce qui attend le Voyageur au pas "
    "suivant) : elle relance, elle ne resume ni ne commente. Cette DERNIERE phrase COMMENCE par "
    "l'etre, la bete ou l'objet NOMME qui vient de reagir, et dit ce qu'il fait ou ce qu'il "
    "laisse au Voyageur : JAMAIS « Il », « Elle », « Ils », « Cela », JAMAIS une abstraction "
    "('le silence', 'la brume', 'la presence'), AUCUNE parole rapportee. Termine sur une phrase "
    "complete.",
    "P1 la derniere phrase nomme",
)

# --- P5 : le fil entre dans le prompt d'issue PAR LA QUEUE ---------------------------------
t = exact(
    t,
    '''	var prev: String = str(run_thread.get("last_gist", "")).strip_edges()
	if prev != "":
		ctx += "Juste avant : %s. Enchaine sans rompre le fil.\\n" % prev''',
    '''	var prev: String = str(run_thread.get("last_gist", "")).strip_edges()
	if prev != "":
		ctx += "Juste avant : %s. Enchaine sans rompre le fil.\\n" % prev
	# v49 — LE FIL PAR LA QUEUE. La scene affichee le porte deja en tete, mais SITU_MAX coupe
	# la narration PAR L'AVANT : sur la derniere partie le pont n'a survecu au prompt qu'UNE
	# fois sur quatre (narrations de 614, 581, 163, 551 caracteres contre un plafond de 480).
	# Une ligne dediee, en queue, ne peut jamais etre tronquee — et c'est elle qui empeche
	# l'issue N+1 d'ignorer ce que l'issue N avait promis.
	var fil_p: String = str(run_thread.get("last_fil", "")).strip_edges()
	if fil_p != "":
		ctx += "CE QUI ATTENDAIT LE VOYAGEUR EN ARRIVANT : %s\\n" % fil_p''',
    "P5 le fil par la queue",
)

# --- P6 : les fantomes du prompt systeme sortent -------------------------------------------
t = exact(
    t,
    "les personnages AGISSENT et PARLENT (un vieil homme sort de sa hutte, une voix vous hele, "
    "une bete se dresse), ils ont un but a eux.",
    "les personnages AGISSENT et PARLENT, ils ont un but a eux.",
    "P6 les fantomes du systeme",
)

p.write_text(t, encoding="utf-8")

# =============================================================== merlin_scenario.gd
p2 = pathlib.Path("scripts/llm/merlin_scenario.gd")
t2 = p2.read_text(encoding="utf-8")

# --- P2 : garder la FIN, en extraire le fil, en faire le pont -------------------------------
t2 = exact(
    t2,
    '''func note_issue_affichee(prose: String) -> void:
	_run_thread["last_issue"] = prose.strip_edges().substr(0, 420)''',
    '''func note_issue_affichee(prose: String) -> void:
	var p_txt: String = prose.strip_edges()
	# v49 — ON GARDE LA FIN, PAS LE DEBUT. La phrase-crochet vit a la FIN de l'issue : le
	# couperet des 420 PREMIERS caracteres la perdait sur quatre issues sur six (501, 588,
	# 539, 494 caracteres). C'etait exactement la phrase qui portait la continuite.
	_run_thread["last_issue"] = p_txt.substr(maxi(0, p_txt.length() - 420))
	# LE FIL CONCRET. On ne demande RIEN de plus au modele : la phrase existe deja (regle de
	# la tete d'issue), le code cessait seulement de la lire. Fil vide -> le pont mecanique
	# pose par note_outcome reste en place : ce chemin ne peut jamais regresser sous l'existant.
	var fil: String = _extraire_fil(p_txt)
	_run_thread["last_fil"] = fil
	if fil != "":
		_run_thread["bridge"] = fil''',
    "P2 garder la fin et poser le fil",
)

# --- P2 (suite) : l'extracteur, pose a cote du pont mecanique -------------------------------
t2 = exact(
    t2,
    """func _compose_pont_action(action: String, biome: String) -> String:""",
    '''# === v49 — L'EXTRACTION DU FIL ==============================================================
#
# La derniere phrase de l'issue est, par construction (regle de la tete d'issue), celle qui
# NOMME ce qui vient de reagir et ouvre la suite. C'est elle qui doit ouvrir le beat suivant.
# On la prend, on la valide, et on refuse plutot que de servir une phrase qui deviendrait fausse
# une fois transplantee ailleurs. Refuser rend simplement le pont mecanique : jamais pire
# qu'avant.
const FIL_PRONOMS: Array = ["il ", "elle ", "ils ", "elles ", "cela ", "ceci ", "celui ",
	"celle ", "c'est ", "on "]
const FIL_ABSTRAIT: Array = ["silence", "brume", "presence", "présence", "lumiere", "lumière",
	"ombre", "air", "vent", "chaleur", "odeur", "surface", "forme", "masse", "obscurite"]


func _extraire_fil(prose: String) -> String:
	var txt: String = prose.replace("[i]", "").replace("[/i]", "").strip_edges()
	var phrases: Array = MerlinProse.split_sentences(txt)
	for i in range(phrases.size() - 1, -1, -1):
		var s: String = str(phrases[i]).strip_edges()
		# Parole rapportee : on garde ce qui PRECEDE le deux-points. Le tutoiement d'un PNJ ne
		# doit jamais devenir la voix du narrateur au beat suivant.
		var dp: int = s.find(" : ")
		if dp > 20:
			s = s.substr(0, dp).strip_edges() + "."
		if s.length() < 20 or s.length() > 200:
			continue
		var bas: String = s.to_lower()
		if bas.begins_with("tu ") or bas.contains(" tu ") or bas.contains(" t'"):
			continue  # voix cassee une fois transplantee
		var amorce_pronom: bool = false
		for pr in FIL_PRONOMS:
			if bas.begins_with(str(pr)):
				amorce_pronom = true
		if amorce_pronom:
			continue  # un pronom sans antecedent ne veut plus rien dire au beat suivant
		var mots: PackedStringArray = bas.split(" ", false)
		if mots.size() > 1 and FIL_ABSTRAIT.has(str(mots[1]).trim_suffix(",")):
			continue  # « La brume se retire » n'est pas un fil : rien n'y est nomme
		return s
	return ""


func _compose_pont_action(action: String, biome: String) -> String:''',
    "P2 l'extracteur",
)

# --- P7 : le pont mecanique, qui reste le repli, cesse d'etre sale --------------------------
t2 = exact(
    t2,
    "	var act_aff: String = str(affichage.get(action, action))",
    '''	# v49 — l'accent PAR REGISTRE, avant la jointure. note_outcome joint d'abord les registres
	# par « et », si bien que la cle composite ne matchait jamais la table et que l'ASCII
	# passait a l'ecran (« avez trouve les mots »).
	var parts: PackedStringArray = []
	for _r in action.split(" et "):
		parts.append(str(affichage.get(str(_r), str(_r))))
	var act_aff: String = " et ".join(parts)''',
    "P7a l'accent par registre",
)

t2 = exact(
    t2,
    "	var loco: String = str(pool[_rng.randi_range(0, pool.size() - 1)])",
    '''	# v49 — anti-repetition : trois locomotions seulement pour la foret, et un tirage pur
	# rendait deux ponts identiques mot pour mot dans la meme partie. _pick_served existe.
	var loco: String = _pick_served(pool, "loco_%s" % biome)''',
    "P7b l'anti-repetition",
)

# --- P3a : la SCENE SEULE est memorisee, pour le filet anti-echo ---------------------------
t2 = exact(
    t2,
    """		narration = narration.replace(str(_banned), "")
	narration = narration.strip_edges()""",
    """		narration = narration.replace(str(_banned), "")
	narration = narration.strip_edges()
	# v49 — LA SCENE SEULE, sans pont ni ancrage : c'est elle, et elle seule, que le filet
	# anti-echo doit comparer a l'issue. Les coutures posees par le CODE ne sont pas de la
	# prose du modele, et les compter gonflait l'echo de TOUTES les phrases de l'issue —
	# en frappant d'abord celles qui nomment ce qui precede, c'est-a-dire la continuite meme.
	var narration_seule: String = narration""",
    "P3a la scene seule",
)

# --- P3b : le Climax n'avait AUCUNE trace du beat precedent --------------------------------
t2 = exact(
    t2,
    """			var anchor: String = str(CLIMAX_ANCHORS[_rng.randi_range(0, CLIMAX_ANCHORS.size() - 1)]) % qt
			narration = anchor + " " + narration""",
    """			var anchor: String = str(CLIMAX_ANCHORS[_rng.randi_range(0, CLIMAX_ANCHORS.size() - 1)]) % qt
			narration = anchor + " " + narration
		# v49 — LE CLIMAX PORTAIT ZERO TRACE de ce qui venait de se passer : le pont l'exclut
		# explicitement (plus bas) et le lookahead retournait dessus. C'est pourtant le beat ou
		# la continuite compte le plus. Le FIL CONCRET, lui, y entre — en tete, avant l'ancrage
		# au but, parce qu'il raconte d'ou l'on vient et l'ancrage dit ou l'on arrive.
		var fil_cl: String = str(_run_thread.get("last_fil", "")).strip_edges()
		if fil_cl != "" and int(beat.get("n", 1)) > 1:
			narration = fil_cl + " " + narration""",
    "P3b le fil au Climax",
)

# --- P3c : le pont peut etre une PHRASE PLEINE ---------------------------------------------
t2 = exact(
    t2,
    """				if narration.length() > 0:
					narration = narration.substr(0, 1).to_lower() + narration.substr(1)
				narration = bridge + " " + narration""",
    """				# v49 — le pont peut desormais etre une PHRASE PLEINE (le fil concret, qui finit
				# par un point). On ne force la minuscule que pour l'amorce MECANIQUE, qui elle
				# finit en virgule : « pont, situation » coule, « phrase. situation » aussi.
				if bridge.ends_with(",") and narration.length() > 0:
					narration = narration.substr(0, 1).to_lower() + narration.substr(1)
				narration = bridge + " " + narration""",
    "P3c le pont phrase pleine",
)

# --- P3d : la scene seule voyage dans la situation -----------------------------------------
t2 = exact(
    t2,
    """	return {
		"provenance": provenance,
		"narration": narration,""",
    """	return {
		"provenance": provenance,
		"narration": narration,
		# v49 — la narration SANS les coutures du code (pont, ancrage de Climax, annonce de
		# quete) : c'est la reference du filet anti-echo, voir narrate_resolution.
		"narration_seule": narration_seule,""",
    "P3d la scene seule voyage",
)

# --- P4 : le filet anti-echo compare a la scene SEULE ---------------------------------------
t2 = exact(
    t2,
    '\tvar s: String = MerlinProse.strip_scene_echo(MerlinProse.clean_prose(str(r.get("text", "")).strip_edges()), str(situation.get("narration", "")))',
    '\t# v49 — le filet compare a la SCENE SEULE. Depuis P2 la narration COMMENCE par une vraie\n'
    '\t# phrase de prose (le fil du beat precedent) : la laisser dans la reference gonflait\n'
    '\t# mecaniquement le recouvrement de toutes les phrases de l\'issue, et supprimait en\n'
    '\t# priorite celles qui reprennent ce qui precede — exactement la continuite recherchee.\n'
    '\tvar s: String = MerlinProse.strip_scene_echo(MerlinProse.clean_prose(str(r.get("text", "")).strip_edges()), str(situation.get("narration_seule", situation.get("narration", ""))))',
    "P4 le filet compare a la scene seule",
)

p2.write_text(t2, encoding="utf-8")
print("v49 applique (P1, P2, P5, P6, P7) : la derniere phrase de l'issue nomme ce qui reagit,")
print("elle est gardee au lieu d'etre tronquee, elle devient le pont du beat suivant et entre")
print("dans le prompt d'issue par la queue. Zero token de generation supplementaire.")
