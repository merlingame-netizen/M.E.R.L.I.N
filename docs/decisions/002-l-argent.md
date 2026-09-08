---
id: 002
titre: D'où vient l'argent, et qu'achète-t-il ?
domaine: regles
ouverte: 2026-09-08
etat: ouverte
---

## La fourche

Depuis la décision d'août (« l'argent ne vient que d'un événement »), la bourse d'une quête
générée reste à **0** toute la traversée : aucun beat généré ne déclare de `butin`, seule la vente
d'une carte à l'étal rapporte, et l'étal s'ouvre quand même à chaque Rencontre. Le joueur voit une
monnaie qui ne bouge jamais et une boutique où il ne peut rien acheter. Les sentiers écrits, eux,
ouvrent avec une bourse (Le Compte Juste : 14, Kado paie 6). Il faut trancher si l'argent est un
système du jeu généré, un système des figures, ou un système des seuls sentiers écrits — les
trois demandent des chantiers différents.

## Aujourd'hui

- `scripts/game/merlin_run.gd` ≈ 1244-1280 : `butin_du_beat` ne paie que si le beat porte
  `butin` et si le geste réussit ; aucun beat généré n'en porte. `new_run` applique
  `bourse_depart` (sentiers écrits seulement, 08/09).
- `scripts/game/merlin_game.gd` ≈ 1550 : l'étal s'ouvre à chaque Rencontre ; ≈ 2006 : le Coup
  de Pouce est grisé sous 9 gwenneg alors qu'il se paie en Promesse ; la Promesse est gratuite à
  bourse 0 ; l'Information n'affiche rien.
- p74 : 65 gwenneg gagnés sans événement, zéro achat sur onze étals. Nuit du 07/09 : bourse 0,
  étals ouverts, rien acheté.
- Corpus écrit : bourse de départ 8-31 (médiane 17), et les figures paient (« effet : gwenneg +6 »
  au beat 2 du Compte Juste) — mais le chargeur n'applique pas encore les `effet`.

## Options

### A — Une source et un prix (l'audit §3.4)
Bourse de départ tirée 8-31. Butin 2-6 sur un beat ordinaire sur cinq, sur réussite seule. Un
étal par quête, jamais sans article payable. La dette se règle sans dé : une rune de la main, ou 2
d'intégrité, ou refus (+2 corruption, et la figure le lit). Coup de Pouce sorti du filtre gwenneg,
Information supprimée.
**Coût** : le plus gros chantier (deux à trois sessions de règles), il touche le générateur de
beats et l'écran de l'étal.
**Mesure** : achats par étal ≥ 0,5 ; bourse finale ≤ 1/3 du départ ; jamais `paid: 0` ; étals
par quête ≤ 1.

### B — L'argent vient des figures
Pas de butin au sol : une figure paie un service (Kado paie le portage), et une figure fait payer
le sien. L'étal une fois par quête. Le corpus écrit le porte déjà (`effet`) ; le générateur doit
apprendre à faire payer une figure, ce qui attend le fine-tuning.
**Coût** : une économie rare (une ou deux transactions par quête) ; sur les quêtes générées elle
n'existera pas avant le LoRA ; une session pour le chargeur (`effet`), une pour le générateur.
**Mesure** : ≥ 1 transaction de figure par quête écrite ; bourse finale ≠ bourse de départ.

### C — L'argent ne vit que sur les sentiers écrits
Bourse cachée et étal fermé sur les quêtes générées, tant que le modèle ne sait pas payer. Les
sentiers écrits portent seuls la monnaie, avec leurs choix qui coûtent.
**Coût** : un système de moins à l'écran pour la plupart des parties ; l'écran de l'étal ne sert
qu'aux sentiers ; une session.
**Mesure** : zéro étal ouvert sur une quête générée ; sur un sentier, achats par étal ≥ 0,5.

**Recommandation** : C maintenant, A quand le bot faillible mesurera un joueur qui a besoin de
soin — une économie n'a de demande que si quelque chose manque, et rien ne manque encore.

## Réponse
_En attente._
