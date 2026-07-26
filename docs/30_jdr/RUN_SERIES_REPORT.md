# Diversité entre runs — mesurée sur l'exécution du jeu

> Généré par `tools/check_run_diversity.py`. Ne mesure pas un fichier de scénarios : mesure ce que le moteur **produit réellement** quand on le fait tourner plusieurs fois de suite. C'est la seule preuve qui vaille pour l'exigence « aucun scénario ne doit ressembler à un autre ».

6 runs joués en autoplay headless.

## Verdict

| Critère | Résultat |
|---|---|
| Titres distincts : 1/6 | **FAIL** — chaque run devrait proposer un titre inédit |
| Parcours de cartes distincts : 1/6 | **FAIL** — le parcours le plus fréquent revient 6 fois |
| Recouvrement lexical max entre runs : 100% | **FAIL** — au-delà de 35 %, deux runs racontent la même chose |
| Couverture du pool : 5/12 cartes vues (42%) | **FAIL** — sur plusieurs runs, le joueur devrait voir l'essentiel du pool |
| Graines de variation distinctes : 6/6 lues | PASS |

## Runs

| Run | Titre | Scénario | Cartes tirées | Vie | Anam |
|---|---|---|---|---:|---:|
| run_1 | La Voix de Brocéliande | la_fille_perdue | `001 002 003 004 005` | 94 | 0 |
| run_2 | La Voix de Brocéliande | la_fille_perdue | `001 002 003 004 005` | 94 | 0 |
| run_3 | La Voix de Brocéliande | la_fille_perdue | `001 002 003 004 005` | 94 | 0 |
| run_4 | La Voix de Brocéliande | la_fille_perdue | `001 002 003 004 005` | 94 | 0 |
| run_5 | La Voix de Brocéliande | la_fille_perdue | `001 002 003 004 005` | 94 | 0 |
| run_6 | La Voix de Brocéliande | la_fille_perdue | `001 002 003 004 005` | 94 | 0 |

## Paires de runs les plus proches

- 100% — `run_5` ≈ `run_6`
- 100% — `run_4` ≈ `run_6`
- 100% — `run_4` ≈ `run_5`
- 100% — `run_3` ≈ `run_6`
- 100% — `run_3` ≈ `run_5`

## Vocabulaire d'actions

13 libellés distincts sur 90 options proposées au joueur, tous runs confondus.
