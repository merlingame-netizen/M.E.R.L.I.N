> **[PARTIALLY OUTDATED — 2026-03-16]** Factions concept valide, mais certaines refs
> (decay 8%, _init_triade_run, Souffle) sont obsoletes. Voir GAME_DESIGN_BIBLE.md v2.4.

# DOC_15 - Systeme Alignement (Factions)

**Version**: 1.0 | **Date**: 2026-02-26

---

## 1. Concept - Reputations ponderees

Reseau de 5 reputations independantes (pas axe Bien/Mal binaire).
- Chaque faction : score -100 a +100 (neutre = 0)
- Joueur peut etre Honore Druides ET Hostile Ankou simultanement
- Persistance cross-run avec decroissance 8%/run

## 2. Les 5 Factions

| ID | Nom | Symbole | Affinite Aspect |
|----|-----|---------|----------------|
| druides | Druides de Bretagne | Chene | Ame |
| korrigans | Korrigans des Marais | Champignon | Monde |
| humains | Clans Humains | Epee | Corps |
| anciens | Les Anciens | Menhir | Ame |
| ankou | L Ankou | Faux | Corps |

## 3. Systeme de Score (-100 a +100)

| Tier | Score min | Label |
|------|-----------|-------|
| honore | 60 | Honore |
| sympathisant | 20 | Sympathisant |
| neutre | -19 | Neutre |
| mefiant | -59 | Mefiant |
| hostile | -100 | Hostile |

## 4. Effets par Faction x Tier (FACTION_RUN_BONUSES)

| Faction | Honore | Sympathisant | Hostile |
|---------|--------|--------------|---------|
| Druides | +2 Souffle | +5 Karma | +25 Tension |
| Korrigans | +20 Vie | +1 Souffle | -10 Vie |
| Humains | +15 Vie | - | +15 Tension |
| Anciens | +1 Souffle | - | -10 Karma |
| Ankou | +10 Vie | - | -15 Vie |

## 5. Liaison Choix -> Reputation

**Path A - GM Brain** : le prompt GM recoit faction_context et emet ADD_REPUTATION.

**Path B - auto-tag keywords** (synchrone, toujours actif) :

| Faction | Mots-cles |
|---------|----------|
| druides | druide, ogham, nemeton, chene, barde |
| korrigans | korrigan, farfadet, marais, lutin, fee |
| humains | clan, village, guerrier, humain, paysan |
| anciens | ancien, menhir, dolmen, eternite, primordial |
| ankou | ankou, mort, faucheuse, ame, trepas |

Match -> ADD_REPUTATION:faction:FACTION_DELTA_MINOR ajoute aux effets option droite.

Valeurs delta : MINOR=5, MAJOR=15, EXTREME=30

## 6. Persistance Cross-Run + Decroissance

Stockage : state["meta"]["faction_rep"] = {druides:0, korrigans:0, humains:0, anciens:0, ankou:0}

Formule (FACTION_DECAY_RATE = 0.08) appliquee au debut de chaque run :
  new_score = int(score * 0.92)  # vers 0

Exemples :
- Score 50 -> run suivant -> 46 -> 42...
- Score -80 -> run suivant -> -74 -> -68...

## 7. Bonus de Debut de Run

Sequence dans le run init (anciennement _init_triade_run) :
1. _decay_faction_rep() -- decroissance 8%
2. _build_and_store_faction_context() -- snapshot meta -> run["faction_context"]
3. _apply_faction_run_bonuses() -- effets concrets selon les tiers

## 8. Integration LLM

Placeholder {faction_status} existant dans merlin_llm_adapter.gd:236.
Peuple par _build_faction_status_string(state) :
- Inclut uniquement les tiers non-neutres
- Format : "Relations: Druides:sympathisant, Ankou:hostile." (~12 tokens)
- Si tout neutre : chaine vide (aucun token ajoute)

## 9. Futur - Extensions

- Panel HubAntre avec 5 jauges visuelles par tier (couleurs: hostile=rouge, honore=or)
- Quetes de faction (reputation >= 60 : carte speciale declenchee par GM)
- Fins verrouillees par reputation (ex: victoire secrete : druides>=80 AND anciens>=60)
- Antagonismes inter-factions (aider Humains = -5 Anciens)

## Fichiers impliques

| Fichier | Changements |
|---------|-------------|
| scripts/merlin/merlin_constants.gd | FACTIONS, FACTION_INFO, FACTION_TIERS, FACTION_RUN_BONUSES, FACTION_DELTA_*, FACTION_DECAY_RATE |
| scripts/merlin/merlin_effect_engine.gd | ADD_REPUTATION (VALID_CODES + handler + _score_to_tier + _build_faction_context) |
| scripts/merlin/merlin_store.gd | faction_rep dans meta, faction_context dans run, decay + bonuses |
| scripts/merlin/merlin_llm_adapter.gd | _build_faction_status_string, peuple {faction_status} |