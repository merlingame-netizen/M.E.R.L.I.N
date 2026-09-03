# MERLIN — décisions du 03/09 (heure de Paris)

## 2026-09-03 : un lancement sans beat n'est pas une traversée
- Maxime a choisi l'option 1 (« ne pas ouvrir de chronique pour un harnais ») devant la preuve :
  après un jour, quatre des cinq chroniques écrites par le jeu sur la VM étaient des lancements
  sans partie — 0 beat, 191 octets — dont un à 03:00 par un agent de nuit.
- Implémentation retenue : la chronique ne s'écrit qu'au PREMIER BEAT JOUÉ (un geste posé par un
  joueur ou un bot), et non sur une variable d'environnement de harnais. « Joué » et non
  « posé » : lancé sans personne, le jeu présente le beat 1 de lui-même — un smoke de cent
  secondes l'a montré en écrivant une chronique à un beat et zéro geste. Raison : le lancement de 03:00 est un smoke qui ne porte
  aucune variable ; la règle par variable l'aurait laissé passer. La règle par beat couvre tous
  les cas et garde les parties témoins, qui jouent des beats.
- Les deux liseuses (écran CHRONIQUES du jeu, onglet Chronique du Studio) ignorent les fichiers
  à 0 beat antérieurs à la règle : on ne supprime pas des données de jeu, on ne les affiche pas
  comme des traversées.
- « Tout garder, sans limite » (02/09) reste vrai pour les traversées ; il ne s'applique pas à
  ce qui n'en est pas une.
