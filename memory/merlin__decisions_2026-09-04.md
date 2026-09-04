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

## 2026-09-04 : le canon est refait, dérivé du jeu (choix 2 de Maxime)
- Devant le constat que gd-content-gap tourne 48 fois par jour sur un canon périmé, Maxime a
  choisi de NE PAS couper l'agent mais de refaire `lore_canon.json` d'abord.
- Le canon écrit à la main le 19/06 décrivait un autre jeu : huit biomes inventés là où il y en a
  douze aux noms bretons, douze PNJ dont aucun n'existe (Maelgwn, Keridwen, Niamh, Manannan,
  Brigid — ces trois derniers étant nommément INTERDITS par le canon que le jeu applique), neuf
  champs lexicaux et des cartes à trois options, système abandonné au pivot v11.
- `refaire_lore_canon.py` le régénère depuis data/biomes, data/figures, data/quete et
  canon_code.json. Les CLÉS ne changent pas — quatre outils les lisent — seul le fond est refait.
  `--verifier` rend 1 si le fichier a dérivé : la dérive se voit le jour même.
- Les figures arrivent avec ce qu'elles VEULENT et leur voix : c'est la leçon de q86, qui avait
  nommé seize figures sans qu'aucune ne veuille quoi que ce soit.
- Séparation posée : le CANON dit ce que le monde est ; le FORMAT produit (carte à trois options,
  effets plafonnés) est porté par `content_gap.py`, avec sa date de péremption écrite. Un canon
  ne doit pas mentir sur le jeu pour arranger un outil.
- CE QUI RESTE FAUX ET QUI EST DIT : le jeu écrit des BEATS, cet atelier écrit des CARTES. Le
  corpus entraîne donc le futur modèle sur une unité de contenu que la production n'emploie plus.
  Le rendre utile demande de retarger analyseur + prompt + validateur sur le beat — un chantier,
  pas un réglage. Décision non prise.

## 2026-09-04 : l'argent ne vient que d'un événement (décision ancienne, enfin codée)
- Règle de Maxime : « Pas de gwenneg gagné si rien en terme de transaction, trésor etc. L'argent
  s'amasse sur un monstre, une transaction, un trésor, une situation qui donne de l'argent. »
- Mesure qui l'a déclenchée (p74) : 2 → 65 gwenneg en vingt beats, aucun événement, zéro achat sur
  onze étals. Deux gwenneg par réussite, quatre par éclatante, plus un butin aléatoire sur 60 %
  des réussites — la moitié du total venait du seul hasard.
- Codé : le degré rend 0, le butin aléatoire rend 0, et un beat déclare son `butin` qui ne tombe
  que sur une réussite. Les deux fonctions restent pour leurs appelants (dont la sonde de soak) —
  les supprimer forcerait un appelant à deviner.
- Conséquence assumée, et Maxime l'avait acceptée d'avance : aucun scénario ne pose `butin`
  aujourd'hui, donc une quête sans argent est possible. Restent la vente à l'étal et le
  remboursement d'une greffe.
