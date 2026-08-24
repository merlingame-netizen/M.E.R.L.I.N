# Décisions — 2026-08-24 (à fusionner dans merlin__decisions.md)

## 2026-08-24 : la chronique est SYSTÉMATIQUE après chaque partie
- Toute partie témoin ou de contrôle est suivie de **sa chronique HTML livrée en fichier**, sans
  que Maxime ait à la demander. Le verdict compact ne suffit pas : il donne les comptes, pas ce
  que le joueur LIT — or c'est sur le texte que se jugent le ton, la cohérence et les PNJ.
- Contenu minimal d'une chronique : verdict (chaque cible avec son compte, réussies ET manquées),
  les trois sentiers, l'intro du modèle, **chaque beat verbatim** (narration + issue + geste +
  jauges + **bourse**), les étals croisés, la fin chiffrée, la note technique (version du jeu,
  provenance des mesures, chantiers ouverts).
- Marquage obligatoire : bandeau ROUGE sur toute issue du banc, or sur les faits notables
  (lookahead servie, re-essai réussi), et la frise porte temps + bourse par beat.

## 2026-08-24 : protocole de mesure (rappel consolidé)
- Une variable à la fois par partie ; chaque cible manquée est dite avec son compte exact.
- Le verdict du job porte désormais : `beats SECOURS prov vous=X/6 beat1 tps1 duree_moy
  issue_s_moy gw fin corr titre` — de quoi juger rythme, style et économie sans ouvrir le journal.
- Autopsie À CHAUD (grep du log dans le même job que la partie) pour tout ce que le journal ne
  porte pas : gardes, re-essais, tok/s par génération.

## Versions du jour
- **v39** — l'arc s'efface devant toute issue en vol (repatience étendue aux issues).
- **v40** — écriture au Voyageur : sujets abstraits bannis + garde CODE (1re phrase sans « Vous »
  → un re-essai) ; colporteur NARRÉ (3 arrivées au banc, pattern R128) avant son étal ; bourse
  toujours visible (même à 0) + butin « (+X) » ; gwenneg par beat au journal de sonde.
- **v41** — l'arc se tait pendant le premier beat (après l'ouverture) : p59 mesure beat1 39 s et
  8,8 tok/s contre 68-70 s et 1,83 tok/s — sans coût pour l'arc (arc:6 tenu, 2 tranches écrites).

## Chantiers ouverts (avec leur compte)
- Filet du **moteur muet** : p59 beat 2 a rendu 1 token à 0,03 tok/s, moteur vivant → banc servi,
  alors que v35.5 devait re-essayer. Le log ne montre aucun re-essai « muet » — autopsie en cours.
- **Le re-essai jette sa première version** : si la seconde écriture échoue, on a perdu un texte
  valide. À corriger : garder la première prose en réserve et la servir en dernier recours.
- **1re phrase au Voyageur** : 5/6 à p58 et p59 (le re-essai réussit une fois sur deux).
