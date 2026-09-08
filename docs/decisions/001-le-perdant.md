---
id: 001
titre: Que reçoit le perdant ?
domaine: regles
ouverte: 2026-09-08
etat: tranchee
---

## La fourche

Aujourd'hui tout ce qui fait grandir le Voyageur tombe sur la réussite : la greffe (le draft
« 1 carte sur 3 ») ne s'arme qu'après une réussite ou une éclatante, et le point de talent ne vient
que sur réussite. Celui qui rate ne reçoit rien, et celui qui réussit reçoit de quoi réussir
encore. Depuis v55 la mort redevient possible ; si le perdant ne reçoit rien, une mauvaise passe
devient une spirale, et la traversée se joue au beat 5. Il faut trancher **qui reçoit quoi**, parce
que les trois options donnent trois jeux différents, et que l'atelier ne peut pas mesurer les
trois.

## Aujourd'hui

- `scripts/game/merlin_game.gd` ≈ 916 : le draft ne s'arme que sur `reussite` / `eclatante`.
- `scripts/game/merlin_run.gd` (talent) : +1 point sur réussite, 0 sur partiel et échec.
- Partie p74 (avant v55) : 8 greffes en 13 beats. Nuit du 07/09 (bot couvrant) : 25 gestes,
  25 réussites, 20 « sûrs » — le perdant n'existe pas encore dans la mesure, il apparaîtra avec le
  bot faillible (tâche #39).
- L'audit du 07/09 (§3.2) juge le draft-sur-degré et le recommande « au monde ».

## Options

### A — Le draft appartient au monde, le talent au temps
La greffe se propose sur une Rencontre sur deux, ou après un revers ; jamais parce qu'on a réussi.
Cap : 5 greffes par traversée. Un point de talent par beat joué, 2 sur éclatante, cap 3 par
traversée. Le perdant progresse au même rythme que le vainqueur ; la réussite paie en intégrité
gardée, pas en pouvoir.
**Coût** : le vainqueur perd son jouet ; la règle est plus longue à dire ; une session de règles,
et le bot de la nuit à relire.
**Mesure** : zéro draft consécutif à un degré ; greffes ≤ 5 ; points gagnés sur partiels > 0.

### B — Le perdant reçoit le point, le vainqueur la greffe
On apprend en ratant : partiel ou échec donnent +1 talent ; la réussite garde le draft comme
aujourd'hui, avec un cap de 5 greffes. Deux monnaies, deux destins.
**Coût** : garde la spirale du fort (la greffe reste au vainqueur) ; changement plus petit, mais
deux règles à expliquer au lieu d'une.
**Mesure** : points gagnés sur partiels > 0 ; greffes ≤ 5 ; mortalité inchangée ± 2 points.

### C — Rien avant la mesure du bot faillible
On ne touche à rien tant que la nuit n'a pas montré un perdant réel (tâche #39 : bot aveugle au
dé, qui rate une fois sur dix). Une semaine de nuits, puis on rouvre cette fourche avec le chiffre.
**Coût** : une semaine de plus ; l'atelier des règles travaille ailleurs (cinq tuiles, main
qu'on tient).
**Mesure** : la mortalité et l'intégrité minimale des nuits, avec la population du bot.

**Recommandation** : A — c'est la seule option où le degré ne paie plus deux fois, et la mesure
existe déjà dans `verdict_partie.py` (gestes sûrs, éclatantes, intégrité minimale).

## Réponse
**Tranchée le 2026-09-08 : A.** tranchée avec Claude en session, 08/09