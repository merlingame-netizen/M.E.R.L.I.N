# Rapport d'equilibrage — Scenarios types MERLIN

> Genere par `tools/validate_scenario_balance.py` contre `data/ai/scenario_templates.json` v1.0.0. 100 scenarios valides (validation PAR ROUTE : le pool branchant est projete sur les 3 chemins ordre/chaos/liminal).

**Score moyen : 90.8/100** — min 82, max 97.

## Findings par frequence

| Code | Severite | Occurrences | Scenarios touches |
|---|---|---:|---:|
| RARITY_DRIFT | warn | 104 | 68 |
| FACTION_DRUID_HEAVY | warn | 100 | 100 |
| FACTION_STARVED | warn | 89 | 72 |
| ARC_OPEN | warn | 20 | 20 |
| LEN_BIAS | warn | 10 | 10 |
| TITLE_WORDS | warn | 1 | 1 |

## Equite deck-building : part des factions sur les options

Chaque faction nourrit un build de stat (Logic=druides, Empathie=niamh, Volonte=anciens, Instinct=korrigans). Une faction sous 8% affame le build associe.

| Faction | Part moyenne | Statut |
|---|---:|---|
| druides | 32.5% | SUR-REPRESENTEE (> 30%) |
| anciens | 19.6% | OK |
| korrigans | 11.1% | OK |
| niamh | 9.9% | OK |
| ankou | 7.8% | SOUS-NOURRIE (< 8%) |

## Attrition nette EV first-run (normalisee 25 cartes)

p50 = **22 PV** (min -10 / max 46) — cible : vie finale p50 dans [55, 70] => attrition 30-45 PV.

## Score par archetype

| Archetype | Score moyen | N |
|---|---:|---:|
| forgotten_ritual | 93.7 | 10 |
| ancient_oak_counsel | 93.1 | 10 |
| druid_lineage | 92.5 | 10 |
| threshold_crossing | 91.9 | 10 |
| druidic_awakening | 90.4 | 10 |
| korrigan_trickery | 89.8 | 10 |
| mist_wanderer | 89.8 | 10 |
| forest_trial | 89.8 | 10 |
| hidden_sanctuary | 89.2 | 10 |
| beast_encounter | 88.0 | 10 |

## 5 scenarios les plus faibles

### broc_07_03 (beast_encounter, 17 cartes) — 82/100
- [WARN] LEN_BIAS: longueur 17 hors bias archetype [11, 15, 21]
- [WARN] RARITY_DRIFT: route chaos: COMMUNE 0.53 vs cible 0.68
- [WARN] TITLE_WORDS: titre 'L'Ours-Roi' = 1 mots
- [WARN] ARC_OPEN: ouverture 'tension'
- [WARN] FACTION_STARVED: faction ankou = 5% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_DRUID_HEAVY: druides = 33% des options (> 30%)

### broc_00_09 (druidic_awakening, 11 cartes) — 85/100
- [WARN] RARITY_DRIFT: route ordre: RARE 0.00 vs cible 0.20
- [WARN] RARITY_DRIFT: route liminal: COMMUNE 0.45 vs cible 0.68
- [WARN] RARITY_DRIFT: route liminal: RARE 0.36 vs cible 0.20
- [WARN] FACTION_STARVED: faction niamh = 7% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_STARVED: faction ankou = 7% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_DRUID_HEAVY: druides = 33% des options (> 30%)

### broc_01_09 (korrigan_trickery, 11 cartes) — 85/100
- [WARN] RARITY_DRIFT: route ordre: RARE 0.00 vs cible 0.20
- [WARN] RARITY_DRIFT: route liminal: COMMUNE 0.45 vs cible 0.68
- [WARN] RARITY_DRIFT: route liminal: RARE 0.36 vs cible 0.20
- [WARN] FACTION_STARVED: faction niamh = 6% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_STARVED: faction ankou = 6% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_DRUID_HEAVY: druides = 33% des options (> 30%)

### broc_03_05 (mist_wanderer, 17 cartes) — 85/100
- [WARN] LEN_BIAS: longueur 17 hors bias archetype [11, 15, 21]
- [WARN] RARITY_DRIFT: route chaos: COMMUNE 0.53 vs cible 0.68
- [WARN] FACTION_STARVED: faction niamh = 6% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_STARVED: faction ankou = 7% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_DRUID_HEAVY: druides = 32% des options (> 30%)

### broc_06_00 (hidden_sanctuary, 11 cartes) — 85/100
- [WARN] RARITY_DRIFT: route ordre: RARE 0.00 vs cible 0.20
- [WARN] RARITY_DRIFT: route liminal: COMMUNE 0.45 vs cible 0.68
- [WARN] RARITY_DRIFT: route liminal: RARE 0.36 vs cible 0.20
- [WARN] FACTION_STARVED: faction niamh = 7% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_STARVED: faction ankou = 7% des options (< 8%) — build associe sous-nourri
- [WARN] FACTION_DRUID_HEAVY: druides = 33% des options (> 30%)

---

## Addendum — Simulation Monte-Carlo (2026-07-25)

> Section manuelle (la partie au-dessus est régénérée par `validate_scenario_balance.py --report`).
> Script : `tools/simulate_run_balance.py` — 10 000 runs × 6 profils × 2 seeds.

**Tuning validé** : white -4 / contextuel -8 / red -15 / **fatales 5% du tirage actes IV-V uniquement**
(concentration du budget global 2%) / courbe [0.6, 0.8, 1.0, 1.3, 1.6] / heal 30% des succès +2, crit +5 / 2 shops +8.

| Build | Mort % | Vie finale p50 | Morts actes IV-V |
|---|---:|---:|---:|
| First-run (1/1/1/1) | 17.9% | 70.0 | 100% |
| Druide pur | 12.5% | 85.5 | 100% |
| Berserker | 12.7% | 85.8 | 100% |
| Diplomate | 12.6% | 85.3 | 100% |
| Survivant | 12.8% | 85.8 | 100% |
| Polyvalent | 10.1% | 92.2 | 100% |

**Leçons** :
1. Les dégâts white/red pilotent la tension (vie finale), pas la mortalité — le placement des fatales est LE levier de mortalité.
2. Sous quert actuel (+10/CD4), la mort par attrition PV est quasi impossible — confirme le retuning proposé (CD 6, soin 8).
3. Les 4 builds spécialisés sont identiques en survie tant que les checks sont uniformes — l'expression de build doit venir du `stat_mix` par archétype et du contenu des cartes.
4. Le Polyvalent (12 pts de stats vs 10) est le plus sûr — aligner les budgets ou biaiser les mix par acte.

## Audit final (Wave 2 — game_design_auditor)

**Verdict : PASS-WITH-NOTES.** Corrections appliquées post-audit : table §5.3 de la spec recalculée
depuis le modèle EV, red clampé [12,15] (cap DAMAGE_LIFE), champs typés `params` par archétype +
`anti_degenerescence_params` (consommables par scenario_planner/MOS), enveloppe DANGER_BUDGET du
validator scalée par danger_modifier (faux positifs éliminés), bible §6.2 bornée par route + §6.3bis
(schéma carte skeleton étendu), exception « options voilées » documentée, finding « corpus trop doux »
(attrition EV 22 vs cible 30-45) ajouté aux findings ouverts.
