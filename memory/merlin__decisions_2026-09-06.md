# Décisions — 2026-09-06 (le crible de la VM)

## 2026-09-06 : un seul agent de nuit, qui joue puis génère
- `partie-nuit` (4 h 05) devient l'atelier de nuit : la partie avec le bot COUVRANT, puis la quête,
  dans cet ordre, par le même script ; `quete-nuit` passe « à la demande ». native-bench va à 6 h
  et refuse de tourner sous un harnais.
- Pourquoi : les deux premières nuits, la partie tenait encore le jeu à 4 h 40 et la quête sortait
  en 0 sans rien écrire. Le moteur est mono-place : l'ordre se garantit en enchaînant, pas en
  espaçant. CORRIGÉ PAR s100 : le banc de 4 h 25 se reportait bien (le harnais ouvre x11vnc, donc
  vnc_open était vrai) ; j'avais affirmé le contraire sans lire l'état. Les beats 11-13 lents
  (98-128 s) restent à dater — gd-content-gap à 4 h 30 est le suspect qui reste.
- Sans bot couvrant, la cible « réussite » mesure les dés (28 % sans tag, 72 % avec un, DC 9) :
  le verdict dit désormais NON MESURÉE quand `choix_du_bot` est absent.

## 2026-09-06 : rc=75 veut dire « reporté »
- Un agent qui renonce (occupé, mémoire, déjà en cours, harnais) sort en 75 et le dit ; l'état porte
  `ok=true, reporte=true`. Ni un succès, ni un échec : le crible les compte à part.
- agent-run.sh ferme le verrou pour l'enfant (`9>&-`) : `nohup ollama serve &` l'héritait et
  ollama-serve disait « déjà en cours » depuis deux semaines sans ligne rc. cron.log est daté.
- a_ollama_serve ne réchauffe plus le copilote sous harnais ni entre 2 h et 6 h.

## 2026-09-06 : gd-content-gap gardé, mais dans le dépôt et sous porte
- Choix de Maxime : l'agent tourne. Sa cadence (*/30) vivait dans une surcharge hors dépôt contre
  un manifeste qui disait PAUSE ; elle vit maintenant dans agents.json (PAUSE levée : le canon est
  dérivé du jeu depuis le 05/09), et run-gd-agent.sh interroge gates.py avant de prendre le LLM.
- gates.py compte un harnais comme un jeu qui tourne ; router.py donne les fils de jour dès que le
  jeu tourne, nuit comprise. Le recentrage sur le beat (#29) reste ouvert.

## 2026-09-06 : le crible est un agent, la mesure est une courbe
- `a_crible.sh` chaque matin à 7 h 40 (état de chaque agent, fenêtre RÉELLE des réveils, reportés,
  verrous tenus et par qui, nuits, courbe), gardé 30 jours, envoyé sur le sujet du Courrier, jamais
  d'URL ni de secret. job-100 l'applique aujourd'hui (verrou d'ollama-serve retiré, surcharge
  retirée, crontab régénérée) et rend s100.
- `nuits.jsonl` : une ligne par nuit (partie mesurée par verdict_partie.py --json, quête et son
  adresse), même quand rien n'a été joué. Le Studio la trace dans l'onglet Chronique : trois séries
  séparées (banc, réussite, attente médiane), jamais deux échelles sur un axe.
- L'URL du tunnel est une forme sensible pour le Courrier ; a_tunnel_watch ne la met plus dans ses
  résumés (elle vit dans tunnel-history.jsonl, en local).

## 2026-09-06 : ce que la relecture contradictoire a ajouté (34 défauts, 2 bloquants)
- Un harnais ne compte que s'il VIT : `merlin_harnais` (game-env.sh) et gates.py exigent inner.pid
  vivant ou un godot ; un marqueur rassis (Stop du Studio, reboot) est effacé au passage. Sans
  cela, une seule nuit tuée bloquait toutes les suivantes, pour toujours, en « reporté ».
- La CI de commit (game-autosync → ci-commit) ne relance plus le jeu par-dessus une sonde :
  garde harnais + gates, rc=75. Un commit poussé entre 4 h et 5 h 30 aurait tué la partie.
- Le crible masque les URL AVANT de tronquer (une URL coupée à 80 caractères passait tous les
  filtres) ; job-100 refait le test du Courrier avant de joindre quoi que ce soit ; le filtre
  du Courrier matche `trycloud` même tronqué.
- L'atelier tient le verrou LLM du début à la fin, écrit sa ligne de nuit même quand il renonce,
  lit le contrat de la quête dans verdict.txt (pas dans un code de retour), et son code de retour
  porte la quête (refusée = 1, reportée = 75). relance, journal, conseil et les agents gd passent
  par gates ; native-bench à 6 h 05 et gd-content-gap à 7/37 : jamais dans la même seconde.
- « Reporté » existe pour le Studio (pastille, badge, bloqués), le rapport du matin et le
  Contrôleur (qui ne prend plus une durée de report pour une durée de référence).
- La courbe garde les nuits reportées comme des trous visibles ; les mesures disent quand
  l'échantillon est incomplet (trous d'index, beats_joues).

## 2026-09-06 (soir) : le filon, quatre réponses de Maxime
- La référence de « le jeu s'améliore » est la VM et le conteur e4b ; le PC (e2b) suit.
- Le prochain effort sur la prose est le fine-tuning sur GPU distant (LoRA de gemma e4b) ; le
  levier du prompt est épuisé.
- Côté jeu, on commence par la mort et la progression (répit par Rencontre, épreuve de
  progression, puis les chapitres), avant les biomes.
- L'atelier autonome sert à MESURER seulement : garder la nuit, le crible, la courbe ; éteindre
  ce qui propose ou décide sans lecteur (liste précise à confirmer).

## 2026-09-06 (soir) : le filon, deuxième tour
- ÉTEINTS dès demain : gd-content-gap, design-council, gd-balance, gd-run, coder-local, sequence,
  parole, et la plume LLM du journal (le gabarit reste). La tâche #29 (recibler gd-content-gap sur
  le beat) meurt avec l'agent. Restent : la nuit, le crible, la courbe, et ce qui sert Maxime
  directement (relance, brasero, contrôle, santé, smoke, CI).
- Fine-tuning : Kaggle (GPU gratuit), avec un corpus ÉCRIT À LA MAIN élargi de 8 à 15-20 quêtes
  sur les douze biomes — pas de données synthétiques d'un plus gros modèle.
- La mort : une menace réelle et rare, environ une traversée sur dix pour un joueur attentif.
  Cible mesurable sur la nuit avec le bot couvrant : au plus une nuit sur dix finit en mort.
- Le rythme : une nuit par jour, la machine libre le jour. La courbe parle après une semaine.

## 2026-09-06 (soir) : le filon, troisième tour
- Le corpus élargi : Claude écrit dans la voix du corpus existant, une quête par biome ; Maxime
  relit et corrige (chaque correction devient une règle d'écriture).
- L'ordre : la mort et la progression d'abord (une session, effet dès la nuit suivante), puis le
  corpus quête par quête, le LoRA quand il y a ~200 exemples.
