#!/usr/bin/env python3
"""Patch v51 — LE TIMEOUT NE BRIQUE PLUS LE MOTEUR.

CE QUE p74 A MESURE, ET CE QUE J'AVAIS MAL LU. J'attribuais les beats 12 et 13 (1741 et 1728
tokens de prompt relus contre 482 de mediane) a une eviction du cache par un prompt d'arc — c'est
ce que dit merlin_scenario.gd:72. C'est faux. Le journal donne la sequence exacte :

    beat 10  vif       492 tok    ok=True     ecriture 80,7 s
    beat 11  vif         0 tok    ok=FALSE    banc de secours
    beat 12  CONTEUR  1741 tok    prompt 85,1 s
    beat 13  vif      1728 tok    prompt 47,1 s
    beat 14  vif       500 tok    prompt 15,0 s   <- tete chaude retrouvee

1741 et 1728 ne sont pas une eviction partielle : c'est CENT POUR CENT du prompt redecode, sur un
moteur dont le cache KV est VIDE. Et le basculement du vif vers le conteur au beat 12 signe un
moteur declare mort, pas un cache bouscule. La cascade est celle-ci : le beat 11 depasse
GEN_TIMEOUT_MS -> la branche timeout rend la voie -> la generation suivante appelle generate_async
sur un moteur dont le fil d'inference vit toujours -> le C++ pose engine_dead
(merlin_llm.cpp:164-176, « Previous generation stuck ») -> reprise, qui REMONTE les deux moteurs a
cache vide -> beats 12 et 13 paient le prompt entier, beat 14 retrouve sa tete chaude.

LE CODE SE CONTREDIT LUI-MEME, et c'est la preuve la plus courte. `busy = false` n'existe qu'a
DEUX endroits du fichier : la branche timeout (l.574) et `_on_result` (l.610), qui ne s'execute
qu'apres la fin reelle du fil. La branche timeout est donc la seule a pouvoir liberer une voie dont
le fil natif tourne encore. Or `cancel()` (l.707-713) refuse deliberement de le faire et ecrit
pourquoi : « On ne touche ni a busy ni a l'id : le fil d'inference tourne encore, liberer la voie
ici lancerait une gen sur un moteur occupe. » La branche timeout fait exactement ce que cancel()
s'interdit.

Le remede de 2026-08-16 avait ete de porter le delai de 90 s a 150 s. Cela rarefie l'evenement sans
le supprimer : p74 mesure une ecriture a 80,7 s au beat 10, juste avant la panne du beat 11.

LE CORRECTIF. Au timeout on annule le natif et on rend la main a l'appelant tout de suite, mais on
ne rend PAS la voie et on ne bump PAS l'id — exactement le protocole de cancel(). `_process`
continue de pomper la voie (l.415-419, il ne poll que si busy), le fil finit, `_on_result`
reconnait son gen_id (d'ou l'id non incremente), convertit en erreur « annulee » (mecanisme deja
pose par v48.1c) et libere alors busy proprement. Plus aucun generate_async ne peut atteindre un
moteur au fil vivant : engine_dead devient inatteignable par ce chemin.

CE QU'ON ECHANGE : pendant que le fil termine — au plus l'evaluation de prompt en cours, ~90 s au
pire mesure — la voie repond « occupee » et le banc de secours sert ce beat-la. Un beat au banc
contre un moteur qui reste chaud pour tous les suivants.

LA SOUPAPE, que les deux enquetes ont reclamee sans la fournir. Si le fil ne revenait JAMAIS (vrai
blocage dans llama_decode), la voie resterait occupee toute la session et ce cerveau serait mort en
SILENCE — une panne muette la ou on avait une panne bruyante. On garde donc une seconde garde,
beaucoup plus longue, dans _process : passe ABANDON_MS depuis le debut de la generation, on libere
de force et on le dit en push_error. Cette soupape ne retablit le comportement d'aujourd'hui que
dans le cas ou le fil est REELLEMENT bloque — cas ou le remontage du moteur est la bonne reponse —
tout en corrigeant le cas courant, celui d'un fil lent mais vivant.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/llm/merlin_native.gd")
t = p.read_text(encoding="utf-8")

# 1. La branche timeout : elle tient la voie jusqu'au retour du fil natif.
t = exact(
    t,
    '\t\tif Time.get_ticks_msec() - t0 > GEN_TIMEOUT_MS:\n'
    '\t\t\tv["id"] = int(v["id"]) + 1\n'
    '\t\t\tif moteur != null:\n'
    '\t\t\t\tmoteur.cancel_generation()\n'
    '\t\t\tv["busy"] = false\n'
    '\t\t\t_partager_les_coeurs()\n'
    '\t\t\tif _peut_dormir():\n'
    '\t\t\t\tset_process(false)\n'
    '\t\t\tpush_warning("[MerlinNative] timeout génération (%d ms) [%s] — annulée" % [GEN_TIMEOUT_MS, cerveau])\n'
    '\t\t\treturn {"error": "timeout"}\n',

    '\t\tif Time.get_ticks_msec() - t0 > GEN_TIMEOUT_MS:\n'
    '\t\t\t# v51 — LE TIMEOUT NE REND PLUS LA VOIE AVANT LE FIL NATIF.\n'
    '\t\t\t# C\'etait le SEUL endroit du fichier a poser busy=false pendant que le fil\n'
    '\t\t\t# d\'inference tournait encore (l\'autre, _on_result, ne s\'execute qu\'apres sa fin).\n'
    '\t\t\t# La generation suivante appelait alors generate_async sur un moteur dont le fil\n'
    '\t\t\t# vivait toujours, le C++ posait engine_dead (merlin_llm.cpp:164-176, « Previous\n'
    '\t\t\t# generation stuck »), et la reprise REMONTAIT les deux moteurs a cache KV VIDE.\n'
    '\t\t\t# Mesure p74 : beat 11 en timeout, puis beats 12 et 13 a 1741 et 1728 tokens de\n'
    '\t\t\t# prompt INTEGRALEMENT redecodes (85,1 s et 47,1 s) la ou une tete chaude n\'en\n'
    '\t\t\t# relit que 414-540 (14-16 s) — et le beat 12 bascule sur le Conteur, ce qui signe\n'
    '\t\t\t# un moteur declare mort et non un cache bouscule.\n'
    '\t\t\t# On applique donc le protocole que cancel() s\'impose deja et pour la raison qu\'il\n'
    '\t\t\t# ecrit (l.707-713) : « liberer la voie ici lancerait une gen sur un moteur occupe ».\n'
    '\t\t\t# L\'appelant recoit son timeout tout de suite ; _process continue de pomper la voie\n'
    '\t\t\t# et _on_result la rendra — en erreur « annulee » — quand le natif aura fini.\n'
    '\t\t\tv["annulee"] = true\n'
    '\t\t\tif moteur != null:\n'
    '\t\t\t\tmoteur.cancel_generation()\n'
    '\t\t\tpush_warning("[MerlinNative] timeout génération (%d ms) [%s] — annulée, voie tenue jusqu\'au retour du fil natif" % [GEN_TIMEOUT_MS, cerveau])\n'
    '\t\t\treturn {"error": "timeout"}\n',
    "la branche timeout",
)

# 2. LA SOUPAPE. Sans elle, un fil qui ne revient jamais tue le cerveau en silence.
t = exact(
    t,
    "const GEN_TIMEOUT_MS: int = 150000\n",
    "const GEN_TIMEOUT_MS: int = 150000\n"
    "# v51 — SOUPAPE. Depuis v51 le timeout ne rend plus la voie : il attend le fil natif, qui\n"
    "# revient au pire apres l\'evaluation de prompt en cours (~90 s au pire mesure sur p74). Mais\n"
    "# si ce fil ne revenait JAMAIS — vrai blocage dans llama_decode — la voie resterait occupee\n"
    "# toute la session et ce cerveau serait mort EN SILENCE, ce qui est pire que la panne bruyante\n"
    "# qu\'on vient de supprimer. Passe ce delai, on libere de force et on le DIT. La soupape ne\n"
    "# retablit l\'ancien comportement que dans le cas ou le fil est reellement bloque — le seul ou\n"
    "# remonter le moteur est la bonne reponse.\n"
    "const ABANDON_MS: int = 300000\n",
    "la constante de soupape",
)

t = exact(
    t,
    '\tif _llm != null and _voies["conteur"]["busy"]:\n'
    '\t\t_llm.poll_result()\n'
    '\tif _llm_vif != null and _voies["vif"]["busy"]:\n'
    '\t\t_llm_vif.poll_result()\n',

    '\tif _llm != null and _voies["conteur"]["busy"]:\n'
    '\t\t_llm.poll_result()\n'
    '\tif _llm_vif != null and _voies["vif"]["busy"]:\n'
    '\t\t_llm_vif.poll_result()\n'
    '\t# v51 — LA SOUPAPE. Une voie annulee qu\'aucun _on_result n\'a rendue passe ce delai signale\n'
    '\t# un fil natif reellement bloque, et non lent. On la libere de force, bruyamment : un\n'
    '\t# cerveau muet pour le reste de la partie serait pire que le remontage qu\'on subissait.\n'
    '\tfor c in ["conteur", "vif"]:\n'
    '\t\tvar vv: Dictionary = _voies[c]\n'
    '\t\tif not bool(vv["busy"]) or not bool(vv.get("annulee", false)):\n'
    '\t\t\tcontinue\n'
    '\t\tif Time.get_ticks_msec() - int(vv["t0"]) <= ABANDON_MS:\n'
    '\t\t\tcontinue\n'
    '\t\tpush_error("[MerlinNative] fil natif [%s] muet depuis %d ms apres annulation — voie liberee de force" % [c, ABANDON_MS])\n'
    '\t\tvv["id"] = int(vv["id"]) + 1\n'
    '\t\tvv["annulee"] = false\n'
    '\t\tvv["busy"] = false\n'
    '\t\t_partager_les_coeurs()\n',
    "la soupape dans _process",
)

p.write_text(t, encoding="utf-8")
print("v51 applique : le timeout tient la voie jusqu'au retour du fil, avec soupape a 300 s.")
