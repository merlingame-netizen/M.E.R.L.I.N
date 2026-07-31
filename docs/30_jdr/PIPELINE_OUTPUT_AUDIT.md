# Audit de la sortie réelle du pipeline scénario

> Généré par `tools/check_pipeline_output.py` à partir du dump de `tools/godot/conformance_pipeline.gd`, qui exécute le **vrai code d'équilibrage du jeu** (`ScenarioPlanner._balance_skeleton`) sans Ollama.

Godot 4.4.1-stable (official) — 12 échantillons.

Deux familles de verdicts : **CAPACITÉ** (le pipeline peut-il produire la forme décrite par le contrat ?) et **RÉGLAGE** (sur ce qu'il produit, respecte-t-il les règles d'équilibrage ?). Un échec de capacité est structurel — aucun réglage ne le corrige.

## Synthèse par règle

| Règle | Famille | Échantillons conformes |
|---|---|---|
| longueur canonique | CAPACITE | 1/12  ⚠ |
| branchement 3 routes | CAPACITE | 0/12  ✗ |
| options portees par le beat | CAPACITE | 0/12  ✗ |
| checks de stats (white/red/fatal) | CAPACITE | 0/12  ✗ |
| actes materialises | CAPACITE | 0/12  ✗ |
| caps de types de carte | REGLAGE | 3/12  ⚠ |
| adjacence des types uniques | REGLAGE | 12/12 |
| distribution des raretes | REGLAGE | 3/12  ⚠ |
| placement du LEGENDAIRE | REGLAGE | 12/12 |
| climax LEGENDAIRE + MERLIN_DIRECT | REGLAGE | 12/12 |
| arc emotionnel | REGLAGE | 8/12  ⚠ |
| biais de pole par biome | REGLAGE | 7/12  ⚠ |

## Détail par échantillon

### `fallback_L3/foret_broceliande` — 5 beats en entrée → 5 en sortie — 8 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%
- **FAIL** — biais de pole par biome : dominant Chaos, attendu Liminal

### `fallback_L3/landes_bruyere` — 5 beats en entrée → 5 en sortie — 8 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%
- **FAIL** — biais de pole par biome : dominant Chaos, attendu Ordre

### `fallback_L3/cotes_sauvages` — 5 beats en entrée → 5 en sortie — 9 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%
- **FAIL** — arc emotionnel : finale 'espoir'
- **FAIL** — biais de pole par biome : dominant Chaos, attendu Liminal

### `fallback_L3/villages_celtes` — 5 beats en entrée → 5 en sortie — 7 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%

### `fallback_L3/cercles_pierres` — 5 beats en entrée → 5 en sortie — 9 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%
- **FAIL** — arc emotionnel : ouverture 'emerveillement'
- **FAIL** — biais de pole par biome : dominant Ordre, attendu Liminal

### `fallback_L3/marais_korrigans` — 5 beats en entrée → 5 en sortie — 8 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%
- **FAIL** — arc emotionnel : ouverture 'tension'

### `fallback_L3/collines_dolmens` — 5 beats en entrée → 5 en sortie — 7 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%

### `fallback_L3/iles_mystiques` — 5 beats en entrée → 5 en sortie — 9 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%
- **FAIL** — arc emotionnel : ouverture 'emerveillement'
- **FAIL** — biais de pole par biome : dominant Liminal, attendu Chaos

### `synthetic_llm_5/foret_broceliande` — 5 beats en entrée → 5 en sortie — 7 règle(s) en échec

- **FAIL** — longueur canonique : 5 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure
- **FAIL** — caps de types de carte : NARRATIVE 40% hors [50%-70%]
- **FAIL** — distribution des raretes : COMMUNE 40% vs 68%, LEGENDAIRE 20% vs 4%

### `synthetic_llm_7/foret_broceliande` — 7 beats en entrée → 7 en sortie — 5 règle(s) en échec

- **FAIL** — longueur canonique : 7 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure

### `synthetic_llm_10/foret_broceliande` — 10 beats en entrée → 10 en sortie — 5 règle(s) en échec

- **FAIL** — longueur canonique : 10 beats produits ; le contrat attend une longueur parmi [11, 15, 17, 21, 25] (cible canonique 25 = 5 actes x 5)
- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure

### `contract_scale_25/foret_broceliande` — 25 beats en entrée → 25 en sortie — 4 règle(s) en échec

- **FAIL** — branchement 3 routes : aucun champ de branchement (route_mask / branch_label / leads_to_card_id) sur les beats : la sortie est une sequence lineaire, pas un arbre a 3 voies
- **FAIL** — options portees par le beat : le squelette ne porte aucune option : les 3 choix sont generes plus tard, carte par carte (LLM 4), donc non equilibrables a l'echelle du scenario
- **FAIL** — checks de stats (white/red/fatal) : aucun champ check : les 4 stats Disco et les act gates du contrat ne sont pas exprimables dans le squelette
- **FAIL** — actes materialises : aucun champ act sur les beats : les 5 actes et leurs multiplicateurs de danger ne sont pas portes par la structure

## Constantes du code vs contrat

| Constante | Code | Contrat | Aligné |
|---|---|---|---|
| `CARD_TYPE_CAPS` | `{"EVENT": {"max_count": 4, "min_count": 1}, "MERLIN_DIRECT":` | `{"NARRATIVE": {"min_share": 0.5, "max_share": 0.7}, "EVENT":` | oui |
| `RARITY_TARGETS` | `{"COMMUNE": 0.68, "EPIQUE": 0.08, "LEGENDAIRE": 0.04, "RARE"` | `{"COMMUNE": 0.68, "RARE": 0.2, "EPIQUE": 0.08, "LEGENDAIRE":` | oui |
| `LEGENDARY_START_SHARE` | `0.7` | `0.7` | oui |
| `NO_REPEAT_CARDTYPES` | `["SHOP", "MERLIN_DIRECT", "RUNE_UNLOCK"]` | `["SHOP", "MERLIN_DIRECT", "RUNE_UNLOCK"]` | oui |
