# Décisions MERLIN — 2026-09-08 (suite)

## 2026-09-08 : SENTIERS — le joueur lance une quête écrite depuis le menu
- Une entrée de menu à côté de CHRONIQUES, pas l'écran de sélection (occupé 38 s par le voile).
- La ligne montre titre, lieu, longueur, première ligne du préambule : assez pour choisir, rien
  qui déflore. Le préambule écrit ouvre la traversée, la bourse de départ écrite est appliquée.

## 2026-09-08 : L'ATELIER — la plateforme qui développe le jeu, Maxime ne tranche que les fourches
- Constat de Maxime : trop de décisions en attente, un design plein de défauts. Il veut une
  plateforme qui développe et intensifie le jeu, avec PEU de choix, concrets et percutants, que lui
  seul tranche ; le reste aux agents cycliques (lore, game design, écrans, animations).
- QUI FAIT : des sessions Claude planifiées (Routines), une par jour, domaines en rotation —
  lundi règles, mardi lore, mercredi écrans, jeudi outillage, vendredi règles, samedi lore,
  dimanche revue. Jamais deux à la fois. Le modèle local de la VM ne code ni ne dessine : la VM
  MESURE (nuit, crible, courbe, bot), Claude EXÉCUTE.
- CE QUI REMONTE : seulement les fourches qui changent l'expérience du joueur (règle, ton, coupe
  de périmètre, direction visuelle). Plafond dur : TROIS ouvertes à la fois ; au-delà, les agents
  continuent sur ce qui est tranché et n'en ouvrent pas d'autre. Chaque fourche : 2-3 options,
  preuves (mesures, captures), coût de chaque option.
- OÙ : une page « À trancher » du Studio (l'onglet Décider, qui remplace les 70 propositions sans
  lecteur), gravée dans le dépôt : docs/decisions/NNN.md sur la branche du jeu.
- LE RETOUR : la VM ne pousse pas sur GitHub. Le Studio enregistre le choix sur la VM et le publie
  sur le canal du Courrier (ntfy, public) ; la session du domaine le lit au démarrage, le grave
  dans le fichier, committe, agit. Une réponse ne vaut que si elle nomme une option existante.
- BRANCHE : directement feat/practices-docs, les preuves comme garde-fou (épreuves, sonde xvfb,
  smoke) ; Maxime ne fusionne rien ; une régression se voit dans la courbe et se révert.
- AMORCE : trois fourches ouvertes le 08/09 — 001 le perdant, 002 l'argent, 003 la dixième quête.
- CE QUE ÇA REMPLACE : l'ancien Cycle Director (Routine horaire d'avril, « tout faire », « jamais
  AskUserQuestion ») mort en état AWAITING_HUMAN_DECISION ; l'onglet Décider et ses 70 propositions.
