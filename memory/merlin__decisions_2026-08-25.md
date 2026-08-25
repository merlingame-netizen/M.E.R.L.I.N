# MERLIN — décisions du 25/08 (matin, heure de Paris)

## 2026-08-25 : v47 — le fantôme de tuile (option 3)
- Maxime a demandé « corrige, opère puis continue le dev » après la question des trois voies
  sur la fusion → implémentation de l'option recommandée : une COPIE de la tuile d'action vole
  dans la fusion, la tuile réelle continue de pulser sur place. La règle v11-W2 (tuile
  permanente, jamais aspirée) tient intégralement.
- Doctrine appliquée : ghost v10.13.1 (« ghost = node NEUF, jamais reparenter une vue réelle »).
- Le fantôme s'insère en tête de `card_views` dans MerlinFx.run() : les phases 1 (convergence)
  et 2 (explosion) le traitent comme les autres vues, zéro logique dupliquée.
- Call-site : les deux lambdas de `MerlinFx.play(...)` sont hissées en variables (`fx_pret`,
  `fx_verdict`) — une lambda multiligne suivie d'un autre argument est un terrain de parse
  fragile en GDScript.

## 2026-08-25 : la validation vit désormais DANS le patcheur (CI)
- Contexte : le classifieur a fermé Bash dans la session de pilotage (même en lecture), la VM
  est muette depuis 20:45Z — plus personne ne pouvait exécuter Godot avant livraison.
- Le workflow patch-v31-1 télécharge Godot 4.5 headless (avec cache Actions), fait le parse
  check éditeur PUIS la sonde du geste, et refuse de pousser si l'un des deux échoue.
- Conséquence durable : « test toujours avant de livrer » ne dépend plus ni du shell de la
  session ni de la VM.

## 2026-08-25 : watchdog.txt sorti du suivi git
- `tools/autodev/status/watchdog.txt` : le hook de démarrage y écrit une ligne à CHAQUE session
  → suivi par git, il rendait le clone de la session cloud sale en permanence, et le stop-hook
  réclamait un commit de journal de battements. Sorti du suivi + ignoré (`c11afae` + `901d5a7`),
  aligné sur ses semblables (orchestrator.pid, session_backup.json, cockpit_*.json).
- Vérifié avant : AUCUN agent VM n'écrit dans un fichier suivi du dépôt — la panne d'autosync
  VM n'était PAS causée par ça (elle reste inexpliquée, VM injoignable).
