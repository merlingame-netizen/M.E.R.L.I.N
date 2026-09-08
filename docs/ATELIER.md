# L'atelier — comment le jeu se développe sans que Maxime ait à tout décider

> Décidé le 2026-09-08. Ce fichier est le protocole que suit chaque session de l'atelier ;
> une Routine Claude en lance une par jour. Le modifier change ce que fait la session de demain.

## 1. Le principe

Maxime ne tranche que les **fourches** : les choix qui changent l'expérience du joueur — une
règle, un ton, une coupe de périmètre, une direction visuelle. Tout le reste est fait par des
sessions Claude planifiées, une par jour, un domaine à la fois, avec des preuves. La VM d'Oracle
**n'héberge que le jeu** (décision du 08/09, deuxième tour) : neuf gardiens la tiennent debout,
et rien n'y mesure, ne propose ni ne converse. Une vraie partie sur la VM se demande par un job
du Courrier et se lit à la session suivante.

Ce dispositif remplace deux choses qui n'ont pas marché : le « Cycle Director » d'avril (une
Routine horaire, « créative et expérimentale », qui décidait seule et s'est arrêtée en attendant
une réponse humaine que personne ne lisait) et l'onglet Décider du Studio (70 propositions
d'agents locaux, sans lecteur).

## 2. La rotation

Une session par jour, à 9 h 30 UTC. Jamais deux à la fois.

| Jour (UTC) | Domaine | Ce qu'on y fait |
|---|---|---|
| lundi, vendredi | **règles** | l'équilibre mesuré : les chantiers de `docs/AUDIT_GAME_DESIGN_2026-09-07.md` §3, le bot de la nuit, les épreuves |
| mardi, samedi | **lore** | le corpus écrit (`data/scenarios/`), les figures, les biomes ; `valider.py` vert, jouable par SENTIERS |
| mercredi | **écrans** | ce que le joueur voit : encart, cartes, transitions, décor par biome ; prouvé par capture xvfb |
| jeudi | **outillage** | la nuit, le crible, la courbe, le Studio, les sondes ; sur la branche de l'outillage |
| dimanche | **revue** | relire la semaine : les commits, les jobs du Courrier, les régressions à révert, les fourches périmées, une note de semaine |

## 3. Ce qu'une session fait, dans l'ordre

1. **Se placer.** Deux branches du même dépôt `merlingame-netizen/M.E.R.L.I.N` :
   `feat/practices-docs` (le jeu, ce dossier) et `claude/oracle-free-tier-access-IN1Wm`
   (l'outillage : `tools/`, `infra/`). Cloner le jeu à côté de l'outillage
   (`git clone --branch feat/practices-docs … merlin-jeu`) ; Godot 4.4.1 est installé ;
   `godot --headless --path . --import` avant la première épreuve.
2. **Relever les réponses.** `python3 tools/decisions.py relever --graver --jeu ../merlin-jeu`
   (depuis l'outillage) lit le canal du Courrier, grave chaque réponse de Maxime dans
   `docs/decisions/NNN.md`, et l'affiche. Une fourche tranchée passe **avant tout le reste**
   dans son domaine.
3. **Lire.** `docs/decisions/` (ce qui est ouvert, ce qui est tranché), les vingt dernières
   entrées de `progress.md`, `docs/BIBLE_DES_REGLES.md`, l'audit du 07/09, et les résultats des
   jobs du Courrier déposés par les sessions précédentes (`python3 tools/decisions.py courrier`).
4. **Choisir UN chantier** du domaine du jour, borné : ce qu'une session finit avec ses preuves.
   Pas de nouveau système que Maxime n'a pas tranché. Pas de « pendant que j'y suis ».
5. **Faire, prouver, écrire.** Les preuves par domaine sont au §4. Sans preuve, pas de commit.
   Une entrée dans `progress.md` : ce qui a été fait, mesuré, laissé de côté.
6. **Pousser** sur la branche du domaine (`git push -u origin <branche>`, quatre essais espacés
   si le réseau échoue). Directement, sans PR : les preuves sont le garde-fou, et la courbe des
   nuits dit le lendemain si ça a servi.
7. **Ouvrir une fourche seulement si on est bloqué** sur un choix qui change l'expérience du
   joueur — et seulement s'il y a moins de trois fourches ouvertes. Sinon, on continue sur ce
   qui est tranché et on note le blocage dans `progress.md`.
8. **Rendre compte** en dernier message : trois lignes — fait, mesuré, à trancher. C'est ce que
   Maxime reçoit en notification.

## 4. Les preuves, par domaine

- **règles** : `tools/tests/test_progression.gd` et les épreuves touchées vertes ; la mesure
  annoncée avec sa population (une vraie partie jouée sur la VM par un job du Courrier quand le
  chantier le demande, sinon la simulation, dite comme telle) ; la bible mise à jour si une règle
  change, et `regles.py` si un seuil change.
- **lore** : `python3 tools/scenarios/valider.py` sans refus ; `rendre.py` sans rune inconnue ;
  la quête se charge dans `test_sentier.gd` ; elle se joue par SENTIERS (sonde
  `tools/probe_menu_sentiers.gd`, ou `probe_choix_capture.gd` avec `MERLIN_SENTIER=<cle>`).
- **écrans** : une capture xvfb avant/après dans `docs/captures/`, référencée dans `progress.md`
  (`xvfb-run -a --server-args="-screen 0 1280x720x24" godot --path . --resolution 1280x720
  --script res://tools/<sonde>.gd`) ; le smoke des scènes touchées ; `--check-only` ne compte
  pas (faux positif MerlinAudio).
- **outillage** : les épreuves Python (`tools/merlin_studio/test_*.py`, `tools/scenarios/`),
  et pour un gardien de la VM un job du Courrier qui montre son état réel. La VM n'accueille
  aucun nouvel agent de travail : ce qui doit tourner tourne ici, dans la session.
- **revue** : rien à prouver, tout à lire ; un révert se prouve comme le chantier qu'il défait.

## 5. Les fourches

Une fourche est un fichier `docs/decisions/NNN-titre.md` (format dans `docs/decisions/README.md`) :
la question, deux à trois options avec ce que chacune coûte, les preuves déjà là, une
recommandation. **Trois ouvertes au plus.** Maxime tranche dans l'onglet Décider du Studio ; la
VM ne pousse pas sur GitHub, alors le Studio publie la réponse sur le canal du Courrier, et la
session suivante la grave dans le fichier (étape 2). Une réponse ne vaut que si elle nomme une
option qui existe dans le fichier.

## 6. Ce qu'une session ne fait jamais

- Poser une question à Maxime en cours de route (personne ne regarde) : elle décide sur ce qui
  est tranché, ou elle ouvre une fourche et passe à autre chose.
- Trancher une fourche elle-même, même « évidente ».
- Écrire un secret, une URL de tunnel, un identifiant sur le canal du Courrier (il est public).
- Désactiver une vérification TLS, pousser sur une autre branche, ouvrir une PR, réécrire
  l'historique.
- Lancer « pour essayer » un agent qui joue une partie sur la VM : la nuit est mesurée, pas
  perturbée.
- Nommer un modèle dans un commit, un commentaire ou un fichier du dépôt.

## 7. Les commits

`type(scope): description` en français, le corps dit le pourquoi et la preuve. Fin de message :

```
Co-Authored-By: Claude <noreply@anthropic.com>
```
