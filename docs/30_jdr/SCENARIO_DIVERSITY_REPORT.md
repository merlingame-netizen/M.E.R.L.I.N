# Diversité des scénarios — scenarios_reference_broceliande.json

> Généré par `tools/check_scenario_diversity.py`. Répond à une seule question : **deux scénarios se ressemblent-ils ?** La conformité au contrat (forme, économie) est mesurée séparément par `validate_scenario_balance.py`.

100 scénario(s) analysé(s).

| Axe | Mesuré | Cible | Verdict |
|---|---|---|---|
| sémantique | moyenne 0.800, max 1.000 | moyenne ≤ 0.75, aucune paire > 0.9 | **FAIL** |
| lexical | Jaccard moyen 0.10, max 1.00 | aucune paire > 0.35 | **FAIL** |
| situationnel | 90/2994 résumés distincts (3%) | ≥ 95% | **FAIL** |
| verbal | 18/8982 libellés distincts (0%), 14 verbes distincts | libellés ≥ 90%, verbes ≥ 120 | **FAIL** |
| structurel | 35/100 signatures distinctes (35%) | ≥ 80% | **FAIL** |
| motifs | 30 motif(s) au-dessus du seuil | aucun motif dans plus de 50% des scénarios | **FAIL** |

## sémantique

125 paire(s) au-dessus du seuil sur 4950

- 1.000 — « Le Septième Ogham » ≈ « Le Geste Oublié »
- 1.000 — « L'Écorce qui Parle » ≈ « L'Arbre qui Pleure »
- 1.000 — « La Pomme qui Rit » ≈ « Les Pas qui Reviennent »
- 1.000 — « Le Cerf Sans Crainte » ≈ « Le Repos Inattendu »
- 1.000 — « La Porte Sans Cadre » ≈ « La Note Tenue »

## lexical

311 paire(s) au-dessus du seuil sur 4950

- 1.00 — « Ton Nom dans l'Écorce » ≈ « La Cape de Feuilles Cousues »
- 1.00 — « Le Crâne en Attente » ≈ « L'Achèvement Silencieux »
- 1.00 — « Les Six Pierres et Toi » ≈ « L'Offrande sans Demande »
- 1.00 — « L'Arbre qui Pleure » ≈ « L'Enseignement du Tronc »
- 0.88 — « La Brume qui Souvient » ≈ « Le Voyageur qui Dort Debout »

## situationnel

2904 résumés dupliqués

- ×116 — « Un druide voyageur te demande de témoigner pour lui devant un cercle.… »
- ×107 — « Une créature étrange te défie en silence. Tu peux fuir, lutter, ou lui… »
- ×102 — « Le temps ralentit sans raison. Tu peux profiter, fuir, ou tenter de co… »
- ×100 — « Des pierres alignées attendent qu'on les complète. Tu choisis quoi y a… »

## verbal

vocabulaire d'action offert au joueur

- ×803 — « Affronter »
- ×803 — « Fuir »
- ×803 — « Apaiser »
- ×640 — « Donner »

## structurel

archétype + pôle + twist + longueur + début d'arc

- ×7 — threshold_crossing / Liminal / transformation / 21 cartes
- ×6 — forgotten_ritual / Ordre / ritual_completion / 25 cartes
- ×5 — druidic_awakening / Liminal / calm_revelation / 17 cartes
- ×5 — druid_lineage / Ordre / ancestral_echo / 17 cartes

## motifs

images et entités récurrentes

- « merlin » dans 100/100 scénarios (100%)
- « demande » dans 97/100 scénarios (97%)
- « voix » dans 95/100 scénarios (95%)
- « suivre » dans 91/100 scénarios (91%)
- « fuir » dans 91/100 scénarios (91%)
- « seul » dans 91/100 scénarios (91%)
