# MERLIN — décisions du 02/09 (heure de Paris)

## 2026-09-02 : les chroniques de traversée, lisibles dans Merlin OS
- Maxime : « J'ai besoin de lire directement sur Merlin OS les chroniques de chaque run, pour
  voir si le jeu s'améliore ! » — trois questions posées avant d'écrire, trois réponses tranchées.
- **Contenu** : mécanique ET prose intégrale, beat par beat. Les chiffres seuls diraient
  l'équilibrage sans dire l'écriture ; la prose seule se lirait sans se relier à rien. Or la
  question posée porte sur l'écriture.
- **Profondeur** : TOUTES les traversées, sans limite. J'avais signalé qu'entassées dans
  `options.cfg` elles feraient grossir sans plafond le fichier relu à chaque démarrage ; la
  promesse est tenue autrement — un fichier par traversée plus un index léger dans
  `user://chroniques/`. Mille traversées ne coûtent rien au boot.
- **Emplacement** : l'écran CHRONIQUES existant devient la liste, palmarès conservé en tête.
  Pas de nouvelle entrée de menu.
- Décision de conception qui en découle : le carnet de `MerlinChronicle` reste plafonné à trois
  pages. Ce plafond sert le RÉCIT (« pas réciter une biographie ») et il est bon pour ce qu'il
  fait ; lire l'historique demandait un autre objet, pas un carnet plus gros.
- Conséquence assumée : une traversée lancée puis abandonnée apparaît « interrompue · 0 beats ».
  C'est la suite directe de « tout garder » — à revoir seulement si Maxime le demande.
- Non rattrapable, et dit dans l'écran : les traversées jouées avant le 02/09 n'ont jamais été
  écrites. La liste vide l'explique au lieu de laisser croire à une panne.

## 2026-09-02 : la génération de quêtes — le prompt a donné ce qu'il pouvait
- Cinq tours (q86 → q92) ont corrigé cinq défauts de REGISTRE, chacun mesuré avant/après :
  adresse, troisième personne, figures sans désir, lieu sans description, vocabulaire moteur qui
  fuit. Aucun n'a fait bouger la NARRATION.
- Décision : le levier du prompt est épuisé. La suite est l'affinage sur le corpus — ce que
  Maxime avait nommé dès le départ. Le conteur tourne déjà sur le plus gros des deux modèles
  présents (e4b) ; monter au-dessus voudrait dire télécharger un GGUF et descendre sous
  5 jetons/s.
- Le jeu de données est prêt : 70 exemples, produits par le code qui pose les questions en
  production (`_prompt_beat` sert aux deux, donc ils ne peuvent pas diverger).
