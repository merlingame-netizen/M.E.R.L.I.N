# Diversité entre runs — mesurée sur l'exécution du jeu

> Généré par `tools/check_run_diversity.py`. Ne mesure pas un fichier de scénarios : mesure ce que le moteur **produit réellement** quand on le fait tourner plusieurs fois de suite. C'est la seule preuve qui vaille pour l'exigence « aucun scénario ne doit ressembler à un autre ».

6 runs joués en autoplay headless.

## Verdict

| Critère | Résultat |
|---|---|
| Titres distincts : 3/6 | **FAIL** — chaque run devrait proposer un titre inédit |
| Parcours de cartes distincts : 6/6 | PASS |
| Recouvrement lexical max entre runs : 74% | **FAIL** — au-delà de 35 %, deux runs racontent la même chose |
| Couverture du pool : 12/12 cartes vues (100%) | PASS |
| Graines de variation distinctes : 6/6 lues | PASS |

## Runs

| Run | Titre | Scénario | Cartes tirées | Vie | Anam |
|---|---|---|---|---:|---:|
| run_1 | Le Chêne Brisé | la_fille_perdue | `arc_broceliande_02 009 007 001 arc_broceliande_01` | 100 | 0 |
| run_2 | L'Ombre des Korrigans | la_fille_perdue | `005 006 001 arc_broceliande_03 003` | 100 | 0 |
| run_3 | L'Ombre des Korrigans | la_fille_perdue | `arc_broceliande_02 arc_broceliande_03 arc_broceliande_01 007 008` | 100 | 0 |
| run_4 | Le Chêne Brisé | la_fille_perdue | `003 arc_broceliande_02 002 004 arc_broceliande_01` | 94 | 0 |
| run_5 | La Voix de Brocéliande | la_fille_perdue | `arc_broceliande_03 006 003 arc_broceliande_01 001` | 100 | 0 |
| run_6 | L'Ombre des Korrigans | la_fille_perdue | `007 005 002 001 008` | 97 | 0 |

## Paires de runs les plus proches

- 74% — `run_2` ≈ `run_5`
- 50% — `run_1` ≈ `run_3`
- 36% — `run_3` ≈ `run_5`
- 32% — `run_1` ≈ `run_5`
- 30% — `run_2` ≈ `run_6`

## Vocabulaire d'actions

34 libellés distincts sur 90 options proposées au joueur, tous runs confondus.

---

## Lecture — avant / après le correctif de déterminisme

| Critère | Avant | Après |
|---|---|---|
| Titres distincts | 1 / 6 | **3 / 6** |
| Parcours de cartes distincts | 1 / 6 | **6 / 6** |
| Recouvrement lexical max | 100 % | **74 %** |
| Couverture du pool | 5 / 12 (42 %) | **12 / 12 (100 %)** |
| Graines de variation distinctes | 6 / 6 | 6 / 6 |
| Vie finale | 94 sur les six runs | 94 · 97 · 100 (trois issues) |

Le mélange du pool a aussi fait remonter des cartes qui n'étaient **jamais** servies :
les cartes d'arc `arc_broceliande_01/02/03` n'apparaissaient dans aucun des six runs
d'avant, et sortent dans quatre des six runs d'après. Elles existaient dans le jeu
sans qu'aucun joueur ne puisse les voir.

### Les deux critères qui restent en échec sont des plafonds de contenu, pas des bugs

**Titres 3/6** — le banc de repli ne contient que trois titres pour Brocéliande
(`_fallback_titles`). Les trois sont désormais tous utilisés : c'est le maximum
atteignable sans génération. Le plafond est le banc lui-même.

**Recouvrement lexical 74 %** — avec douze cartes au pool et cinq tirées par run,
deux runs partagent mécaniquement des cartes. Le recouvrement ne peut pas descendre
sous ce plancher combinatoire tant que le contenu servi vient d'un pool de douze.

Autrement dit : le mécanisme de diversité est maintenant sain, et ce qui limite la
variété est le **volume de contenu**. C'est précisément ce que la génération LLM
native doit résoudre — et la mesure est en place pour le vérifier le jour où elle
tournera.
