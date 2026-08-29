#!/usr/bin/env python3
"""Patch v55 — LE REGISTRE DES HAUTS FAITS SE REMPLIT VRAIMENT.

CE QUI MANQUAIT. v54 a fait de l'eclat la recompense d'un chapitre, et le squelette de quete sait
depuis lire les verrous — mais RIEN ne notait jamais un haut fait. Le registre existait vide et le
restait : tous les chapitres au-dela du premier etaient infranchissables a jamais, sans que rien ne
distingue « le joueur n'a pas encore fait ca » de « le jeu ne sait pas le voir ».

CE QUI EST BRANCHE ICI. `record_end` note, a la fin de chaque traversee, les trois hauts faits dont
la matiere existe deja dans la run :

    traversee_corruption_5    corruption finale >= 5 et la fin n'est pas une mort
    corruption_10_survecue    corruption_max >= 10 et la fin n'est pas une corruption totale
    voie_rare                 la Voie atteinte est Rare, Epique ou Mythique

`corruption_max` — le PIC atteint sur la traversee, qui peut retomber via PURGE — existait deja
(merlin_run.gd:127) et n'etait lu que par le recap de fin. C'est exactement ce que demande le canon
(« Avoir atteint Corruption 10 et EN ETRE REVENU ») : la corruption finale ne suffirait pas, elle
serait retombee.

UNE CORRECTION DE MA PROPRE FICHE. J'avais marque `epitaphe_gagnee` implementable. Il ne l'est pas :
aucune notion d'epitaphe n'existe dans scripts/ — la recherche ne rend rien. Le catalogue est
corrige et porte la vraie raison. Trois hauts faits sur onze sont donc notables aujourd'hui, pas
quatre, et le diagnostic du squelette le dira.

POURQUOI PASSER PAR record_end ET PAS AILLEURS. C'est le seul point du code ou une traversee se
termine, quelle qu'en soit l'issue. Noter ailleurs — a la mort, a la victoire, dans l'ecran de fin —
aurait multiplie les endroits ou l'oubli est possible, et un haut fait oublie est perdu pour de bon
puisque la run n'existe plus apres.

CE QUE CE PATCH NE FAIT PAS. Il ne note pas `promesse_tenue` (l'acquittement d'une promesse n'est
signale nulle part), ni les trois verrous de reputation (aucun systeme de reputation n'existe), ni
`meta_deux_branches` (l'arbre meta n'expose pas ses branches investies). Ces cinq-la restent des
chantiers, et `MerlinQuete.diagnostic()` les nomme un par un plutot que de laisser croire a une
difficulte.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


# ── 1. La fiche de l'epitaphe disait vrai a tort.
p = pathlib.Path("data/quete/hauts_faits.json")
t = p.read_text(encoding="utf-8")
t = exact(
    t,
    '   "note_a": "la fin de traversee de type mort, quand l\'epitaphe a ete accordee",\n'
    '   "implemente": true',
    '   "note_a": "la fin de traversee de type mort, quand l\'epitaphe a ete accordee",\n'
    '   "implemente": false,\n'
    '   "pourquoi_pas": "aucune notion d\'epitaphe n\'existe dans scripts/ — rien ne l\'accorde ni ne la nomme."',
    "la fiche epitaphe_gagnee",
)
p.write_text(t, encoding="utf-8")

# ── 2. record_end recoit le pic de corruption, seule donnee qui lui manquait.
p = pathlib.Path("scripts/game/merlin_chronicle.gd")
t = p.read_text(encoding="utf-8")
t = exact(
    t,
    'entree: Dictionary = {}, chapitre: String = "") -> void:',
    'entree: Dictionary = {}, chapitre: String = "", corruption_max: int = -1) -> void:',
    "la signature de record_end",
)

# ── 3. Les trois hauts faits notables le sont, ici et nulle part ailleurs.
t = exact(
    t,
    '\tcfg.set_value(SECTION, "last_run_iso", Time.get_datetime_string_from_system())\n',

    '\tcfg.set_value(SECTION, "last_run_iso", Time.get_datetime_string_from_system())\n'
    '\t# v55 — LE REGISTRE DES HAUTS FAITS SE REMPLIT ICI, et nulle part ailleurs : c\'est le seul\n'
    '\t# point du code ou une traversee se termine quelle qu\'en soit l\'issue. Un haut fait oublie\n'
    '\t# est perdu pour de bon, la run n\'existant plus apres.\n'
    '\t# La sauvegarde de cfg intervient plus bas ; MerlinHautsFaits.noter() ecrit de son cote sur\n'
    '\t# le meme fichier, donc on note APRES avoir pose les valeurs mais l\'ordre est sans effet :\n'
    '\t# les cles sont disjointes et chaque ecriture recharge le fichier.\n'
    '\t_noter_hauts_faits(end_type, corruption, corruption_max, voie)\n',
    "l'appel de notation",
)

# ── 4. La fonction elle-meme, en fin de fichier : les conditions du canon, une par une.
t = exact(
    t,
    'static func carnet_lire() -> Array:',

    '## v55 — Les hauts faits qu\'une fin de traversee peut etablir. Chaque condition reprend la\n'
    '## prose du canon, et rien de plus : ce qui n\'est pas nommable ici n\'est pas note.\n'
    '## `corruption_max` est le PIC atteint sur la traversee (il peut retomber via PURGE) — c\'est\n'
    '## lui qu\'exige « avoir atteint Corruption 10 ET EN ETRE REVENU », la corruption finale\n'
    '## serait deja retombee. Un appelant qui ne le passe pas (-1) laisse ce fait de cote plutot\n'
    '## que de le deduire faussement de la valeur finale.\n'
    'static func _noter_hauts_faits(end_type: String, corruption: int, corruption_max: int, voie: String) -> void:\n'
    '\tif end_type != "mort" and corruption >= 5:\n'
    '\t\tMerlinHautsFaits.noter("traversee_corruption_5")\n'
    '\tif end_type != "corrompu" and corruption_max >= 10:\n'
    '\t\tMerlinHautsFaits.noter("corruption_10_survecue")\n'
    '\tif voie != "" and ["Rare", "Épique", "Mythique"].has(voie):\n'
    '\t\tMerlinHautsFaits.noter("voie_rare")\n'
    '\n'
    '\n'
    'static func carnet_lire() -> Array:',
    "la fonction de notation",
)
p.write_text(t, encoding="utf-8")

# ── 5. L'appelant passe le pic. Il l'a sous la main, il ne le transmettait pas.
p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")
t = exact(
    t,
    '\tMerlinChronicle.record_end(_end_type, title, int(run.get("integrite")), '
    'int(run.get("corruption")), faction, pilier, voie_nom, page)',

    '\t# v55 — le PIC de corruption part avec le reste : il existait deja (merlin_run.gd:127) et\n'
    '\t# n\'etait lu que par le recap de fin. Sans lui, « avoir atteint Corruption 10 et en etre\n'
    '\t# revenu » serait indecidable, la corruption finale etant retombee.\n'
    '\tvar corr_max: int = int(run.get("corruption_max")) if run.get("corruption_max") != null else -1\n'
    '\tMerlinChronicle.record_end(_end_type, title, int(run.get("integrite")), '
    'int(run.get("corruption")), faction, pilier, voie_nom, page, "", corr_max)',
    "l'appel dans merlin_game",
)
p.write_text(t, encoding="utf-8")

print("v55 applique : trois hauts faits notes en fin de traversee, et l'epitaphe dit la verite.")
