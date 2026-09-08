# Les neuf gardiens — la VM n'héberge que le jeu

> Décision de Maxime, 2026-09-08. La machine d'Oracle (4 cœurs ARM, 22 Go, pas de GPU) était trop
> petite pour héberger le jeu ET faire tourner quarante agents de mesure, de design et de
> conversation. Tout ce qui travaillait a été retiré. Le développement est assuré par des sessions
> Claude, hors de la VM : le protocole est `docs/ATELIER.md` sur la branche du jeu.

| Gardien | Cadence | Ce qu'il fait |
|---|---|---|
| game-watchdog | toutes les 5 min | relance le jeu s'il est mort alors qu'il devait tourner |
| game-idle | toutes les 5 min | coupe le jeu après 5 min sans spectateur |
| game-autosync | toutes les 15 min | récupère le dernier commit du jeu, importe, relance s'il tournait |
| tools-autosync | toutes les 15 min | récupère l'outillage, régénère le crontab, relance le Studio |
| courrier | toutes les 2 min | exécute les `courrier/job-*.sh` commités et remonte le résultat par ntfy — les seules mains de Claude sur la VM |
| tunnel-watch | toutes les 10 min | vérifie que le portail répond |
| health | toutes les 15 min | CPU, RAM, disque, charge, historisés |
| disk-guard | toutes les heures | purge les vieux journaux au-delà de 80 % |
| billing | 7 h 17 | relève la facture Oracle : elle doit rester à zéro |

`agents.json` est le manifeste ; `install-agents.sh` en fait le crontab ; `agent-run.sh` lance
chaque passage sous verrou, journalise (`~/.cache/merlin-agents/cron.log`, une ligne datée par
passage, `rc=75` = reporté) et écrit `state/<id>.json`. `overrides.py` permet un réglage local
hors dépôt. `etape.sh` et `notify.sh` sont les deux aides partagées.

## Mesurer le jeu, à la demande

Quand un chantier a besoin d'une vraie partie sur la VM, on dépose un `courrier/job-NNN-*.sh` qui
la joue (le jeu, son moteur, une sonde), et le Courrier remonte le journal par ntfy. La session
suivante le lit avec `python3 tools/decisions.py courrier`. Rien ne tourne la nuit tout seul.

## Le Studio

`tools/merlin_studio/` : Jouer (le jeu en direct par VNC), Décider (les fourches, `tools/decisions.py`),
Chronique (les parties jouées), Santé (la machine et les gardiens). Rien d'autre.
