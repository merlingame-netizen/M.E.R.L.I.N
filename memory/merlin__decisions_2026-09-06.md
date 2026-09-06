# Décisions — 2026-09-06 (le crible de la VM)

## 2026-09-06 : un seul agent de nuit, qui joue puis génère
- `partie-nuit` (4 h 05) devient l'atelier de nuit : la partie avec le bot COUVRANT, puis la quête,
  dans cet ordre, par le même script ; `quete-nuit` passe « à la demande ». native-bench va à 6 h
  et refuse de tourner sous un harnais.
- Pourquoi : les deux premières nuits, la partie tenait encore le jeu à 4 h 40, la quête sortait en 0
  sans rien écrire, et le banc chargeait un second e4b à 4 h 25 pendant la partie (beats 11-13 à
  98-128 s). Le moteur est mono-place : l'ordre se garantit en enchaînant, pas en espaçant.
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
