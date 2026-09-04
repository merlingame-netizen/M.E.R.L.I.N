# MERLIN — décisions du 04/09 (heure de Paris)

## 2026-09-04 : régime de la VM — moins de réveils, un vrai atelier de nuit
- Constat mesuré (job-095, s95) : la VM n'est pas surchargée mais BRUYANTE. 4 cœurs, 22,9 Go dont
  15,3 libres, charge 0,00 · 0,22 · 0,30, jeu à l'arrêt. Le coût est le nombre de réveils :
  4 139 par jour côté agents, plus 1 440 pour le keepalive du Studio. Quatre agents se
  réveillaient 688 à 689 fois en 24 h pour constater que rien n'avait changé.
- Maxime a dit « applique » sur la proposition faite après mesure. Appliqué :
  - veilleur du jeu, coupeur d'inactivité, gardien d'Ollama : 2 min → 5 min
  - santé : 5 min → 15 min ; séquence : 6/h → 2/h ; relance : 10 min → 30 min
  - braséro : toutes les 20 min → seulement de 7 h à 23 h (personne ne parle la nuit)
  - facturation : toutes les heures → une fois par jour à 7 h 17
  - Le Courrier reste à 2 min : c'est le canal de commande, le ralentir retarde tout job.
  - Le keepalive (chaque minute) n'est pas touché : il maintient Studio et tunnel, et un simple
    appel à /healthz ne coûte rien. C'est pourtant le premier poste de réveils s'il fallait
    encore descendre.
  → 4 139 → 2 417 réveils d'agents par jour (−42 %), sans rien perdre.
- Deux agents de nuit AJOUTÉS, parce que la VM peut le faire et que c'est ce qui mesure le jeu :
  - `partie-nuit` (4 h 05) : une partie entière par le bot, gardée DATÉE dans
    ~/.cache/merlin-partie/nuit/<date>/ — le journal courant est écrasé à chaque partie, donc
    sans copie il n'y a qu'un seul point de mesure. Visible au réveil dans l'onglet Chronique.
  - `quete-nuit` (4 h 40) : une quête générée, passée au contrat ET à la grille de lecture,
    gardée datée. Un point par jour sur la prose.
  - Trente nuits gardées, puis rotation : au-delà ce sont des images qu'on ne rouvrira pas.
- `smoke-scenes` (3 h) fait AUSSI tourner les trois épreuves en moteur (squelette de quête,
  journal des chroniques, écran des chroniques) et les rapporte dans le même fichier. Un smoke dit
  qu'une scène démarre ; une épreuve dit qu'un mécanisme répond.
- Rappel de ce que la VM ne peut PAS faire, et qu'il ne faut pas lui demander : affiner un modèle
  (aucun GPU), ni faire tourner plus gros que le gemma4 e4b à une vitesse jouable. Le moteur est
  mono-place : deux travaux LLM simultanés se ralentissent l'un l'autre (mesuré sur p93, un beat
  à 83 s). D'où l'étalement 3 h 00 / 3 h 30 / 4 h 05 / 4 h 40.
