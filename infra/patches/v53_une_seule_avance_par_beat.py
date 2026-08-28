#!/usr/bin/env python3
"""Patch v53 — UNE SEULE AVANCE PAR BEAT.

LA MESURE. Le journal de p74 porte 20 beats, d'index [1..14, 16..20, 22]. Les index 15 et 21
MANQUENT, alors que le bloc « fin » declare beats_joues=22. Deux beats ont ete joues sans jamais
etre ouverts a la sonde.

POURQUOI CELA COMPTE PLUS QU'UN COMPTAGE. Le verdict juge la partie sur ces entrees. Il a donc
annonce « reussite 20/20 », « continuite 15/19 » et « attente moyenne 33 s » sur un echantillon
incomplet, SANS LE DIRE. Un chiffre dont on ignore le denominateur ne vaut rien.

LA FENETRE COUPABLE, verifiee ligne a ligne dans merlin_game.gd :

    :302  _present_current_beat pose  _beat_transition = true
    :354  ... et efface             _can_advance = false
    :401  le callback de swap_zone relache _beat_transition = false
    :403  ... puis seulement         _state = 1

Entre :302 et :401, `_state` vaut DONC ENCORE 2. Sur un beat « Rencontre », la sous-scene du
colporteur est attendue avant `run.advance_beat()`, et le typewriter de son arrivee (6-8 s) survit
a la fermeture de la vitrine. Si ce typewriter perime finit dans la fenetre de 0,18 s du cross-fade,
`_on_typewriter_done` tombe sur `if _state == 2:` (:2330) et REARME `_can_advance` sur un beat deja
avance. La sonde, qui attend exactement `_state == 2 and _can_advance`, tire une seconde fois : un
beat est consomme sans jamais lui etre presente.

LE CORRECTIF. Une condition, un mot : la garde ne se declenche plus pendant une transition de beat.
`_beat_transition` recouvre la fenetre au caractere pres — il est pose en tete de la fonction
coupable et relache dans le meme callback, une ligne au-dessus de `_state = 1`, sans aucun await
entre les deux. Il n'y avait pas besoin d'inventer un drapeau.

LE RISQUE, ET POURQUOI IL NE TIENT PAS. Si `_beat_transition` restait bloque a true, le caret ne
reviendrait jamais : un softlock, pire que le beat saute. J'ai verifie le mecanisme de relache
plutot que de le supposer. `MerlinVisual.swap_zone` (merlin_visual.gd:209-235) porte une garantie
EXACTEMENT-UNE-FOIS explicite, ajoutee par R159 contre ce risque precis : le build en attente est
suivi en meta, et si un swap relance tue le tween precedent, le kill-handler joue lui-meme le build
avant de le remplacer. Le commentaire du code nomme meme la consequence qu'il previent :
« Un build perdu => l'encart reste fige, le choix ne s'ouvre JAMAIS ». Le drapeau ne peut donc pas
rester leve.

CE QUE CE PATCH NE COUVRE PAS, ET JE PREFERE LE DIRE. Ce mecanisme explique le trou du beat 15,
precede d'un etal de colporteur. Le second trou, apres l'entree 20, n'a NI etal NI incident dans le
journal : je n'ai pas etabli ce qui a re-arme `_can_advance` la. Le correctif du verdict qui
accompagne ce patch declare donc les trous d'index au lieu de les taire — si un beat manque encore
a la prochaine partie, il sera dit, et aucune statistique ne se croira plus exhaustive.
"""
import pathlib
import sys


def exact(t, vieux, neuf, nom):
    n = t.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return t.replace(vieux, neuf)


p = pathlib.Path("scripts/game/merlin_game.gd")
t = p.read_text(encoding="utf-8")

t = exact(
    t,
    "\tif _state == 2:\n"
    "\t\t# Issue entièrement écrite → la VIGNETTE d'effet (degré + Δ jauges + effets) apparaît en Z4",

    "\t# v53 — PAS DE REARMEMENT PENDANT UNE TRANSITION DE BEAT. `_state` vaut ENCORE 2 pendant tout\n"
    "\t# `_present_current_beat` : le drapeau `_beat_transition` est pose en tete (:302) et n'est\n"
    "\t# relache qu'au callback de `swap_zone` (:401), une ligne avant `_state = 1` (:403). Sur un\n"
    "\t# beat « Rencontre », le typewriter d'arrivee du colporteur survit a la fermeture de sa\n"
    "\t# vitrine ; s'il finit dans cette fenetre, ce handler rearmait `_can_advance` sur un beat\n"
    "\t# DEJA avance. La sonde, qui attend exactement `_state == 2 and _can_advance`, tirait alors\n"
    "\t# une seconde fois et un beat etait consomme sans jamais lui etre presente — d'ou les index\n"
    "\t# 15 et 21 absents du journal de p74, pour 22 beats declares joues.\n"
    "\tif _state == 2 and not _beat_transition:\n"
    "\t\t# Issue entièrement écrite → la VIGNETTE d'effet (degré + Δ jauges + effets) apparaît en Z4",
    "la garde de _on_typewriter_done",
)

p.write_text(t, encoding="utf-8")
print("v53 applique : plus de rearmement de _can_advance pendant une transition de beat.")
