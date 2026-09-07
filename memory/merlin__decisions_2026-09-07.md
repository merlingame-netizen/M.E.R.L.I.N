# Décisions — 2026-09-07

## Le geste sûr : la certitude est la récompense de la lecture parfaite
- Couvrir les deux tags en difficulté 2 met le beat hors du hasard. Confirmé par Maxime le 07/09
  au soir : c'est la règle v55 telle qu'elle est codée (~6 % des gestes, contre 77 % avant).
- Le dé reste sur TOUTE Épreuve et TOUT Climax, quelle que soit la couverture.

## Le corpus écrit à la main : Brocéliande et les Falaises, rien d'autre
- Douze quêtes dans les deux biomes JOUABLES. Le modèle apprend ce que le joueur verra, et les
  quêtes servent aussi de contenu. Le lore des dix autres biomes attend le chantier des biomes.
- Annule la formulation de la tâche #37 (« une quête par biome manquant ») : elle contredisait la
  décision du 06/09 de garder deux biomes.

## L'ordre des chantiers de design : le beat « choix » après le corpus
- Deux à quatre options à coût nommé, sans dé, tirées d'une banque écrite à la main : zéro attente
  du modèle, un temps fort tous les cinq beats. C'est la première des neuf mécaniques déclarées
  dans la bible et jamais construites.
- Passent après : l'économie, la main qu'on tient, les douze biomes.

## Kaggle : tout préparer, connecter plus tard
- J'adapte l'orchestrateur à gemma e4b, j'écris le convertisseur GGUF et le chargement natif, je
  laisse un carnet prêt. Maxime pose le jeton quand le corpus est assez gros. Jamais de jeton dans
  le dépôt.

## v55.1 (le soir) : ce que la relecture a change
- Liste blanche des types de beat pour le geste sûr, et « Le créancier revient » entre dans la
  table des natures. Sans ça, la réclamation de Promesse était le seul beat sans dé de la quête.
- `tools/scenarios/regles.py` : le seuil de l'éclatante et les deux planchers durs se lisent dans
  le moteur. Cinq copies supprimées, dont celle qui tourne chaque nuit.
- La monotonie de la couverture est vraie en MARGE, mais hors Épreuve et hors Climax couvrir le
  second tag peut remplacer une éclatante possible (faces 11-12) par une réussite certaine. C'est
  le prix de la certitude, choisi le 07/09. Nommé dans le code, à trancher si Maxime change d'avis.
- Le bot de la nuit reste un oracle (il lit le dé pré-tiré) : la relecture a mesuré qu'il est
  inerte sous v55, et l'aveugler seul dégraderait sa couverture. À faire avec le critère de choix,
  d'un seul tenant, puis remesurer.

## Le soir : les sentiers écrits et le beat « choix » (v56)
- Découverte : les huit quêtes de data/scenarios n'avaient JAMAIS été jouables. Elles deviennent
  du contenu. `MerlinSentier` les charge ; la prose écrite s'affiche telle quelle (zéro attente,
  zéro banc) et la mécanique se joue pour de vrai. Le joueur pose le geste qu'il veut, l'issue
  reste celle qui est écrite : « le dé roule, la prose reste ».
- Le beat « choix » existe : 2 à 4 propositions à la place de la main, aucun dé, un prix. Quatre
  monnaies, bornées DANS LE CODE (2 intégrité, 2 corruption, 6 gwenneg, une rune) pour qu'une
  quête mal réglée ne puisse pas tuer le Voyageur sur une proposition.
- Les options du choix sont écrites à la main, quête par quête. Une quête générée n'en a donc pas.
  La nuit alternera : une nuit générée (mesure la prose et l'attente), une nuit écrite (mesure la
  mécanique pure).
- LE VOCABULAIRE : la bible nomme dix runes (La Patience, La Franchise…), le code en implémente
  seize sous d'autres noms (Le Regard Perçant, Le Cœur Franc…), et le corpus employait ceux de la
  bible. Un coût nommé « La Franchise » ne prélevait rien, en silence. LE JEU GAGNE : le corpus et
  la bible adopteront les seize noms du code.
