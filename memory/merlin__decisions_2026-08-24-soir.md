# Décisions — 2026-08-24 soir (à fusionner dans merlin__decisions.md)

## 2026-08-24 : LA VEILLE S'ARME DANS LE MÊME TOUR QUE LE LANCEMENT
- Reproche de Maxime, fondé : « quand tu lances des runs tu ne reviens pas automatiquement,
  il n'y a pas de re-wake au bon moment quand c'est terminé ». Il a dû venir demander
  « et là ? » / « alors ? » six fois dans la journée.
- **Règle** : toute partie lancée (job Courrier qui joue) est suivie, **dans le même tour**,
  d'une veille armée qui réveille la session à l'arrivée du verdict. Ordre de préférence :
  1. `Bash(run_in_background)` avec une boucle `until` qui SORT au verdict — une seule
     notification, la session est réinvoquée automatiquement à la fin ;
  2. `Monitor` persistant filtré sur `pXX verdict|pXX ko|fini` (couvrir AUSSI les échecs :
     un filtre qui ne guette que le succès reste muet sur un plantage) ;
  3. `CronCreate` toutes les 7 min avec consigne « ne parle que s'il y a du neuf ».
- **Jamais** finir un tour sur « je te dirai quand ça tombe » sans veille armée : c'est une
  promesse que rien ne tient.
- Limite connue : un classifieur de sécurité peut bloquer Bash/Monitor/Cron **pour le reste
  d'une conversation**. Dans ce cas, le dire explicitement à Maxime au lieu de promettre un
  réveil impossible, et proposer le relais durable (workflow GitHub planifié qui lit le canal
  et commente un fil suivi — les événements GitHub, eux, réveillent la session).

## 2026-08-24 : les grep de diagnostic se vérifient avant d'être livrés
- job-063 cherchait « reserve » et a ramené 4 tranches de `sched_reserve` (bruit llama.cpp) :
  l'autopsie du SECOURS a été perdue pour un motif trop large. Un motif de diagnostic doit
  être ancré sur une phrase COMPLÈTE du code (« la réserve est servie »), jamais sur un mot.

## État des versions au 2026-08-24 soir
- **v42.1 + v43 validés par p63** : prompt_max=501 (contre 2045 à p61), beat1=27 s et
  duree_moy=35 s (records), passe=0, vous=5/5, accomplissement. Le carnet est en place ;
  il se remplira à la fin de chaque partie.
- **Chantier ouvert, 3e occurrence** : le moteur MUET (p40, p59, p63) — 1 token rendu,
  `prompt_ms=0`, moteur vivant. Le filet v35.5 n'apparaît jamais dans les logs. job-064
  cherche la preuve avec les bons motifs avant tout patch.
