<!-- Updated 2026-03-15: Triade references removed -->
# CANONICAL ONBOARDING FLOW

Date de reference: 2026-02-13
Statut: source de verite runtime pour onboarding + pre-run.

## Flux officiel

```text
IntroPersonalityQuiz -> SceneRencontreMerlin -> HubAntre -> TransitionBiome -> MerlinGame
```

## Scenes et scripts actifs

- `res://scripts/IntroPersonalityQuiz.gd`
  - `NEXT_SCENE := "res://scenes/SceneRencontreMerlin.tscn"`
- `res://scripts/SceneRencontreMerlin.gd`
  - Scene fusionnee Eveil + Antre
  - `NEXT_SCENE := "res://scenes/HubAntre.tscn"`
- `res://scripts/HubAntre.gd`
  - Hub pre-run (destination, outil, condition, lancement)
- `res://scripts/TransitionBiome.gd`
  - Transition finale vers le run (MerlinGame)

## Regles hub pre-run (canon)

- Le lancement de run demande 3 selections:
  - Destination
  - Outil
  - Condition de depart
- Le mode assiste de condition est explicite (toggle visible dans le hub).
- Si le mode assiste est desactive, la condition doit etre choisie manuellement.
- Si le mode assiste est active, la condition est auto-derivee (jour/nuit) et affichee.

## Legacy (non canonique)

- `SceneEveil` et `SceneAntreMerlin` etaient les noms historiques des scenes de transition.
- Elles ont ete remplacees par `SceneRencontreMerlin` et `HubAntre` dans le flow actuel.
- Les scenes archivees sont en `res://archive/scenes/`.
- La spec historique detaillee reste dans `docs/30_scenes/SPEC_TRANSITION_SCENES.md`.
