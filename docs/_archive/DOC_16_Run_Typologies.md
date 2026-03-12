# DOC_16 - Typologies de Run

**Version**: 1.0 | **Date**: 2026-02-26

---

## 1. Concept - Couche orthogonale au systeme Triade

Couche modificatrice appliquee par-dessus la Triade (modifie, ne remplace pas).
  Triade x Biome x Typology = Experience unique

## 2. Catalogue des 5 Typologies

| ID | Icone | Timer | D20 mod | DC mod | Faction mult | Particularite |
|----|-------|-------|---------|--------|--------------|---------------|
| classique | - | Non | 0 | 0 | x1 | Run standard (defaut) |
| urgence | ! | 10s | 0 | +2 | x1 | Timeout force choice 0, ADD_TENSION:15 |
| parieur | ? | Non | 0 | 0 | x1 | Crit >=17 (+Souffle+Karma), Fumble <=4 (-Vie+Tension) |
| diplomate | O | Non | +2 | -1 | x2 | Rep x2, card bias narratives 90% |
| chasseur | > | Non | 0 | 0 | x1 | Bestiole +1 awen/tour, minigame +25% |

### LLM Hints par Typology

| Typology | Hint (suffix user_prompt, ~10 tokens) |
|----------|---------------------------------------|
| urgence | URGENCE: crise immediate, options breves. |
| parieur | PARIEUR: hasard capricieux, consequences imprevues. |
| diplomate | DIPLOMATE: alliances, factions, negociation. |
| chasseur | CHASSEUR: traque, Bestiole, nature, instinct. |

## 3. Flux de Selection

  HubAntre -> BiomeRadialSelector -> TypologySelectionPanel (5 boutons)
    -> dispatch SET_TYPOLOGY -> store["run"]["typology"]
    -> TransitionBiome lance

Default = classique (skip = classique).

## 4. Stack DC/D20 (ordre application)

  1. typology_modifier (DC-1 Diplomate ou pas)
  2. d20_modifier (+2 roll Diplomate ou pas)
  3. roll D20 (1-20)
  4. compare roll vs DC (succes/echec)
  5. apply parieur_modifier (si crit/fumble -> effets bonus/malus)
  6. apply card effects (effets normaux)

## 5. Mecanique Urgence - Timer

- Timer delta-process dans _process() avec headless_mode guard
- _start_typology_timer() apres affichage carte
- _stop_typology_timer() au debut de _on_option_chosen()
- _on_typology_timer_timeout() : ADD_TENSION:15 + force _on_option_chosen(0)

## 6. Mecanique Parieur - D20 Outcome Modifier

Apres resolution D20 normale dans _resolve_choice_with_dc() :
  roll >= 17 (CRITIQUE) -> new_effects += [ADD_SOUFFLE:1, ADD_KARMA:3]
  roll <= 4  (FUMBLE)   -> new_effects += [DAMAGE_LIFE:5, ADD_TENSION:10]

## 7. Mecanique Diplomate - Factions Amplifiees

Dans merlin_effect_engine.gd -> _apply_faction_reputation() :
  if typology == diplomate:
    delta = int(float(delta) * RUN_TYPOLOGIES["diplomate"]["faction_delta_mult"])  # x2

## 8. Biais de Generation Cartes (card_bias)

| Type | Classique | Urgence | Parieur | Diplomate | Chasseur |
|------|-----------|---------|---------|-----------|----------|
| narrative | 80% | 75% | 80% | 90% | 65% |
| event | 10% | 15% | 10% | - | 20% |
| promise | 5% | - | 5% | 5% | 5% |
| merlin_direct | 5% | 10% | 5% | 5% | 10% |

## 9. Interaction Alignement x Typologies

| Scenario | Mecanique |
|----------|-----------| 
| Diplomate + Druides Honore | DC-1 + D20+2 + rep x2 -> run tres favorable |
| Parieur + Ankou Hostile | Fumbles amplifient malus Ankou de debut de run |
| Urgence + Humains Mefiant | Timer + malus tension -> run tres difficile |
| Chasseur + Korrigans Sympa | Mini-jeux frequents, ton Korrigan bienveillant |

## 10. Futures Typologies

| Nom | Concept | Mecanique signature |
|-----|---------|---------------------|
| Mystique | Visions et pressentiments | Revele effets options avant le choix |
| Prophete | Actions consequences differees | Effets appliques au run SUIVANT |
| Ascete | Vie reduite, recompenses amplifiees | Vie max=50, tous gains x2 |
| Berserker | Corps en avant | Effets physiques x2, mental fragile |
| Sage | Sagesse calme | Timer infini, DC-2, gain Souffle reduit |

## Fichiers impliques

| Fichier | Changements |
|---------|-------------|
| scripts/merlin/merlin_constants.gd | RUN_TYPOLOGIES dict complet |
| scripts/merlin/merlin_store.gd | typology + typology_state dans run, SET_TYPOLOGY action |
| scripts/ui/triade_game_controller.gd | Timer _process, _start/_stop/_on_timeout, _apply_parieur_modifier |
| scripts/merlin/merlin_llm_adapter.gd | typology_hint suffix, typology dans build_triade_context |
| scripts/ui/merlin_game_ui.gd | show/update/hide_typology_timer, badge typology |
| scripts/HubAntre.gd | TypologySelectionPanel, _on_typology_selected |