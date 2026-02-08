# DOC 03 — Système de tests unifié (Event + Combat)

## Objectif
Toute décision FORCE/LOGIQUE/FINESSE déclenche un **test unifié** et des **effets whitelistés**, quelle que soit la scène (route / mystère / combat).

---

## 3.1 Attributs piliers (3)
Bestiole a 3 attributs dédiés aux décisions :

- **Puissance** (FORCE)
- **Esprit** (LOGIQUE)
- **Adresse** (FINESSE)

> Ces attributs coexistent avec HP/ATK/DEF/SPD (combat).

---

## 3.2 Modificateurs instantanés (Bestiole sans mémoire)
Bestiole n’a pas d’historique narratif. Elle réagit selon ses jauges **du moment** :

- Stress ↑ → baisse LOGIQUE & FINESSE
- Énergie ↓ → baisse FORCE
- Humeur ↑ → bonus global léger
- Faim ↓ → baisse globale légère
- Hygiène ↓ → augmente risques (outcomes négatifs plus probables)

---

## 3.3 Modificateurs Merlin (LLM, mémoire permanente)
Merlin a un “style” courant (issu mémoire + contexte) :

Exemples de styles :
- `PROTECTEUR` : +LOGIQUE, -FORCE
- `AVENTUREUX` : +FORCE, +FINESSE, -LOGIQUE
- `PRAGMATIQUE` : +LOGIQUE, +FORCE, -FINESSE
- `SOMBRE` : +FINESSE, -HUMEUR (tendance à dramatiser)
- `PEDAGOGUE` : +LOGIQUE, réduit Risque affiché

---

## 3.4 Postures & Momentum (modificateurs système)
### Postures (persistantes)
- Prudence / Agressif / Ruse / Sérénité
- influencent réussite, coûts, et outcomes.

### Momentum (0..100)
- monte quand on réussit, baisse quand on échoue
- amortit la frustration : un “mauvais” jet n’annule pas toute progression.

---

## 3.5 Résolution d’un test (moteur)
**Merlin ne calcule pas** les résultats : il propose un test, le moteur décide.

**ScoreAction** =
- Base = attribut (Puissance/Esprit/Adresse)
- + bonus posture/momentum
- + bonus skills/reliques/items
- + bonus MerlinStyle
- - pénalités jauges (stress/faim/énergie…)
- + bonus “pity” (fail_streak)

Conversion (moteur) :
- **Chance** (Faible/Moyen/Élevé)
- **Risque** (Léger/Modéré/Sévère)
- **Test caché** : mini-jeu + difficulté (1..10)

---

## 3.6 Pity (anti-frustration)
- `fail_streak` augmente après un échec mini-jeu
- bonus caché par palier :
  - 1 échec : +5%
  - 2 échecs : +10%
  - 3 échecs : +15% (cap)

---

## 3.7 Coûts unifiés
Chaque test peut consommer :
- Vigueur / Concentration / Matériel / Faveur / Nourriture
Le moteur retire les coûts *après validation*, jamais au “survol”.

---

## 3.8 Résultat d’un test
Un test retourne :
- `success` bool
- `score` (0..100) pour nuance d’outcome
- `effects[]` whitelistés (différents selon success/fail)
