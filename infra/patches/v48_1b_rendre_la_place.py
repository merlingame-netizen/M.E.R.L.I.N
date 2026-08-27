#!/usr/bin/env python3
"""Patch v48.1b — RENDRE LA PLACE D'ECRIRE.

LE FAIT, mesure sur le journal de p68 et confirme dans le C++ : le nombre de tokens ecrits vaut
EXACTEMENT n_ctx moins la longueur du prompt. Beat 1 : prompt 1964, 84 ecrits. Beat 2 : 2033,
15 ecrits. Beat 5 : 2022, 26. Beats 3 et 4 : 2045, 2 ecrits -- « Vous calez », puis le mur, puis
le secours. `n_past` demarre a la longueur TOTALE du prompt (merlin_llm.cpp:408), que le prefixe
KV ait ete reutilise ou non, et la boucle d'echantillonnage s'arrete a `n_ctx - 1`
(merlin_llm.cpp:414). Autrement dit `max_tokens` ne veut plus rien dire : le budget d'ecriture
est ce qui RESTE du contexte. Au-dela de 2044 tokens le prompt est en plus tronque, ce qui
DESACTIVE la reutilisation du prefixe -- d'ou les 40 a 57 secondes passees a relire un prompt
qui ne laissera rien ecrire.

Ce plafond est ANTERIEUR a v48 : LORE_CANON ne figure pas dans le prompt d'issue (il ne sert
qu'au Conteur -- selection, intro, scene_jit). Le vrai poids est le PREFIXE FIXE de l'issue :
~1572 tokens, 77 % du contexte, dont le seul bloc REGLES pese ~1013 tokens -- la MOITIE de la
fenetre. Personne ne l'avait vu parce qu'aucune partie complete n'avait tourne du 24 au 27/08.

CE QUE FAIT CE PATCH : il applique a l'ECRITURE la doctrine deja actee pour l'affichage en v46 --
« ce qui doit etre vrai a 100 % ne se demande pas a un LLM ». Le code compose deja la phrase du
geste (MerlinResolution.phrase_du_geste : socle du verbe + maniere du trait, 25 concepts). Elle
ne servait qu'a l'ecran. On la DONNE desormais au modele, en queue de prompt, comme ancrage de sa
premiere phrase. Quatre segments de regles abstraites qui tentaient d'obtenir le meme invariant
par la persuasion -- le sens des cinq registres, les cinq gloses de verbe, la maniere portee par
le trait, l'interdit des gestes inventes : ~425 tokens -- deviennent inutiles et disparaissent.
Trois autres segments verbeux sont resserres sans rien perdre de leur contrainte.

BUDGET VISE : prefixe fixe ~1572 -> ~990 tokens ; prompt complet ~1960-2120 -> ~1410-1570 ; place
d'ecriture 2-84 -> ~480 tokens minimum. `max_tokens` (125-160) redevient le vrai plafond, ce
qu'il n'aurait jamais du cesser d'etre. Et le prefixe reste STABLE d'un beat a l'autre : le
cache KV saute son evaluation des le 2e beat, la queue seule est relue.

CE QUE LE PATCH NE FAIT PAS : il ne touche ni au canon, ni au Conteur, ni a l'equilibrage, ni a
une seule regle du jeu. Le modele ecrit toujours sa premiere phrase LUI-MEME, avec ses mots et le
detail de la scene -- on lui donne le geste a accomplir, pas la phrase a recopier.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_prompt_builder.gd")
t = p.read_text(encoding="utf-8")

# ============================================================================================
# 1. LES ~425 TOKENS DU GESTE -> UNE LIGNE QUI RENVOIE A LA QUEUE
# Segments remplaces : sens des registres (150 t), gloses des cinq verbes (126 t), maniere du
# trait (104 t), interdit des gestes inventes (45 t).
# ============================================================================================
ANCIEN_GESTE = (
    "Ta TOUTE PREMIERE phrase est l'ACTION du heros, ECRITE ENTRE [i] et [/i], commencant par "
    "\\u00ab Vous \\u00bb, qui FOND les deux forces en UN geste concret du bon registre. "
    "(Sens des registres : PAROLE = vous parlez/convainquez/rusez/charmez ; FORCE = vous agissez "
    "physiquement, poussez/tenez bon ; PERCEPTION = vous voyez/ressentez/parlez aux choses ; "
    "PROTECTION = vous resistez/protegez ; OMBRE = vous appelez une force trouble a un prix.) "
    "Si c'est PAROLE, l'action est VERBALE, JAMAIS 'vous posez la main'."
)
NOUVEAU_GESTE = (
    "Ta TOUTE PREMIERE phrase est le GESTE, ECRITE ENTRE [i] et [/i] et commencant par "
    "\\u00ab Vous \\u00bb. LE GESTE T'EST DONNE EN FIN DE PROMPT : accomplis-le avec TES mots et "
    "le detail de CETTE scene, sans y ajouter aucun autre geste."
)

# Les chaines ci-dessus portent des guillemets francais : le source GDScript les ecrit en clair,
# pas en echappement. On repare avant de chercher.
ANCIEN_GESTE = ANCIEN_GESTE.replace("\\u00ab", "«").replace("\\u00bb", "»")
NOUVEAU_GESTE = NOUVEAU_GESTE.replace("\\u00ab", "«").replace("\\u00bb", "»")
t = exact(t, ANCIEN_GESTE, NOUVEAU_GESTE, "le geste (registres)")

ANCIEN_VERBES = (
    " Le VERBE DU GESTE t'est donne en fin de prompt : ta premiere phrase l'ACCOMPLIT "
    "LITTERALEMENT — PARLER = au moins une parole PRONONCEE ; COMBATTRE = un coup ou un "
    "affrontement REEL contre un etre nomme ; OBSERVER = un examen precis qui APPREND quelque "
    "chose ; REVELER = un cache rendu VISIBLE ou nomme ; AGIR = un geste physique precis sur un "
    "objet nomme. Une premiere phrase qui ne joue pas ce verbe est HORS-SUJET. LE TRAIT DONNE LA "
    "MANIERE, et elle se voit dans le MEME geste : un trait de PERCEPTION (voir, sentir, "
    "pressentir, se souvenir, ecouter) ne touche RIEN et n'ajoute AUCUN geste physique — il "
    "regarde, il ecoute, il devine ; un trait de PAROLE se prononce ; un trait de FORCE ou "
    "d'AGILITE engage le corps ; un trait d'OMBRE appelle une force trouble. INTERDIT d'inventer "
    "un geste (des mains posees, un fer, un pas, une main tendue) que NI le verbe NI le trait ne "
    "portent : c'est la faute la plus grave."
)
t = exact(t, ANCIEN_VERBES, "", "les gloses de verbe et de trait")

# ============================================================================================
# 2. UNE REFERENCE DEVENUE ORPHELINE
# « ces categories en majuscules » designait la legende des registres, qui vient de disparaitre.
# On nomme la chose au lieu de pointer un texte absent.
# ============================================================================================
t = exact(
    t,
    " TRADUIS les forces en gestes ; n'ecris JAMAIS le mot 'registre' ni ces categories en "
    "majuscules ; ne CITE JAMAIS de formule entre guillemets.",
    " TRADUIS les forces en gestes ; n'ecris JAMAIS le mot 'registre' ni PAROLE / FORCE / "
    "PERCEPTION / PROTECTION / OMBRE en majuscules ; ne CITE JAMAIS de formule entre guillemets.",
    "reference orpheline",
)

# ============================================================================================
# 3. TROIS SEGMENTS RESSERRES (meme contrainte, moins de mots)
# ============================================================================================
t = exact(
    t,
    " Ta consequence REPREND AU MOINS UN element NOMME de la situation (l'etre, l'objet ou le "
    "lieu precis) et le fait AGIR ou REAGIR -- c'est ce qui prouve que l'issue appartient a "
    "CETTE scene et a aucune autre.",
    " Ta consequence fait AGIR ou REAGIR au moins un element NOMME de la situation : c'est ce "
    "qui prouve que l'issue appartient a CETTE scene.",
    "consequence ancree",
)

t = exact(
    t,
    " SUJETS INTERDITS : une abstraction ne fait JAMAIS l'action — 'la sensation', 'une "
    "forme', 'la presence', 'le silence', 'l'air', 'la brume' ne sont jamais sujets d'un verbe "
    "d'action ; chaque phrase a pour sujet le Voyageur, un personnage, une creature ou un objet "
    "NOMME (jamais 'le vide'/'le nom').",
    " Chaque phrase a pour sujet le Voyageur, un etre ou un objet NOMME : une abstraction ('le "
    "silence', 'la brume', 'la presence') n'agit JAMAIS.",
    "sujets interdits",
)

t = exact(
    t,
    " TERMINE par UNE derniere phrase qui OUVRE LA SUITE : ce que le Voyageur fait maintenant, "
    "ou ce qui l'attend au pas suivant. Elle ne resume RIEN et ne commente RIEN — elle "
    "relance, et elle est courte.",
    " TERMINE par UNE phrase courte qui OUVRE LA SUITE (ce qui attend le Voyageur au pas "
    "suivant) : elle relance, elle ne resume ni ne commente.",
    "phrase de suite",
)

# ============================================================================================
# 4. LA QUEUE PORTE LE GESTE COMPOSE PAR LE CODE
# `verbe_hint` ne donnait que le VERBE ; il donne desormais la phrase entiere -- socle du verbe
# + maniere du trait -- que MerlinResolution compose deja pour l'ecran depuis v46. En QUEUE et
# non en tete : elle change a chaque beat, elle ne doit donc jamais casser le cache de prefixe.
# ============================================================================================
ANCIEN_HINT = '''	var verbe_hint: String = ""
	if played_cards.size() >= 1 and played_cards[0] is Object and "card_name" in played_cards[0]:
		var _vb: String = str(played_cards[0].card_name).strip_edges()
		if _vb != "":
			verbe_hint = "\\nVERBE DU GESTE : " + _vb + " — ta PREMIERE phrase l'accomplit litteralement."'''

NOUVEAU_HINT = '''	# v48.1b — LE GESTE ENTIER, PAS SEULEMENT LE VERBE. Le code compose deja cette phrase pour
	# l'ecran depuis v46 (socle du verbe + maniere du trait, 25 concepts couverts) ; la donner
	# ICI applique a l'ecriture la doctrine actee alors : ce qui doit etre vrai a 100 % ne se
	# demande pas a un LLM. Elle remplace ~425 tokens de regles qui tentaient d'obtenir le meme
	# invariant par la persuasion — le sens des registres, les gloses des cinq verbes, la maniere
	# du trait, l'interdit des gestes inventes.
	# En QUEUE, jamais en tete : elle change a chaque beat, elle casserait le cache de prefixe.
	var verbe_hint: String = ""
	var _geste: String = str(res.get("phrase_geste", "")).strip_edges()
	if _geste != "":
		verbe_hint = "\\nLE GESTE (ta PREMIERE phrase le dit, avec tes mots et le detail de la scene) : " + _geste
	elif played_cards.size() >= 1 and played_cards[0] is Object and "card_name" in played_cards[0]:
		# Repli si le call-site n'a pas de phrase composee (harnais legacy) : le verbe seul.
		var _vb: String = str(played_cards[0].card_name).strip_edges()
		if _vb != "":
			verbe_hint = "\\nVERBE DU GESTE : " + _vb + " — ta PREMIERE phrase l'accomplit litteralement."'''

t = exact(t, ANCIEN_HINT, NOUVEAU_HINT, "le geste en queue")

p.write_text(t, encoding="utf-8")

# ============================================================================================
# 5. LE COMPTE, DIT A VOIX HAUTE (un patch de budget doit prouver son budget)
# ============================================================================================
import re

lignes = t.split("\n")
regles = [x for x in lignes if x.strip().startswith("return ex + _regle_passe_issue()")][0]
bloc = re.search(r'\+ ("(?:[^"\\]|\\.)*")$', regles).group(1)
sysp = re.search(r'const SYSTEM_PREFIX: String = ("(?:[^"\\]|\\.)*")', t, re.S).group(1)
ex = 435
passe = 147
fixe = len(sysp) - 2 + ex + passe + len(bloc) - 2
print("v48.1b applique.")
print("  bloc REGLES : %d caracteres (~%d tokens) — etait 3315 (~1005)" % (len(bloc) - 2, (len(bloc) - 2) / 3.3))
print("  prefixe fixe de l'issue : %d caracteres (~%d tokens) — etait 5193 (~1573)" % (fixe, fixe / 3.3))
print("  place d'ecriture estimee : ~%d tokens (etait 2 a 84)" % (2048 - fixe / 3.3 - 500))
