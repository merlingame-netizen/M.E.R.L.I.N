# ᚛ SCÉNARIOS TYPES — SPÉCIFICATION CANON ᚜

**Version** : 1.0 — 2026-07-25
**Statut** : Source de vérité pour le contrôle d'écriture + l'équilibrage des scénarios
**Jumeau machine-readable** : `data/ai/scenario_templates.json` (consommé par `tools/validate_scenario_balance.py`, à terme par `scenario_planner.gd::_balance_skeleton`)
**Références bible** : `docs/GAME_DESIGN_BIBLE.md` v3.9 §5 (systèmes), §6 (structure run), §9 (pipeline 4-LLM), §25-§28 (stats/checks/équilibrage), §30 (ce document)

---

## 0. Pourquoi des scénarios types

Le pipeline 4-LLM (titres → intro → skeleton → cartes per-beat, bible §9.1) est
libre par nature. Sans contrat, il produit des scénarios inégaux : climax plats,
routes sans respiration, factions mono-couleur, courbes de danger aléatoires.
Le **scénario type** est le contrat qui contraint chaque étage du pipeline :

| Étage LLM | Ce que le scénario type contrôle |
|---|---|
| 1. Titres | Archétype proposé (3 titres = 3 archétypes distincts), format 2-7 mots |
| 2. Intro | 5-8 phrases, 2e personne, présent, hook sensoriel, palette émotionnelle de l'archétype |
| 3. Skeleton | Longueur canon, séquence d'actes, quotas de types/raretés, arc émotionnel, pôle dominant |
| 4. Cartes | Gradient des 3 options, factions distinctes, budget d'effets, checks par acte |
| Validation | `validate_scenario_balance.py` : score 0-100, erreurs bloquantes |

**Principe** : le LLM écrit la *prose*, le scénario type impose la *forme et
l'économie*. C'est la même séparation que Hand of Fate 2 (le dealer improvise
le boniment, mais le deck de rencontres est composé selon des règles strictes).

---

## 1. Les 10 archétypes canon

Mapping 1:1 archétype ↔ pôle ↔ twist (vérifié sur les 100 références Brocéliande) :

| Archétype | Pôle | Twist pattern | Difficulté | Danger ×; Soins × | Longueurs | Stats dominantes |
|---|---|---|---|---|---|---|
| `druidic_awakening` L'Éveil Druidique | Liminal | calm_revelation | easy | 0.60 ; 1.0 | 11-17 | Logic, Empathie |
| `korrigan_trickery` La Ruse des Korrigans | Chaos | deception_unveiled | medium | 0.80 ; 1.0 | 11-21 | Instinct, Logic |
| `ancient_oak_counsel` Le Conseil du Chêne | Ordre | wisdom_arc | medium | 0.70 ; 1.0 | 17-25 | Logic, Volonté |
| `mist_wanderer` Le Vagabond de Brume | Liminal | lost_then_found | medium | 1.00 ; 1.0 | 11-21 | Instinct, Volonté |
| `forest_trial` L'Épreuve de la Forêt | Chaos | physical_test | hard | 1.10 ; 0.9 | 17-25 | Volonté, Instinct |
| `forgotten_ritual` Le Rite Oublié | Ordre | ritual_completion | hard | 1.00 ; 1.0 | 21-25 | Logic, Volonté |
| `hidden_sanctuary` Le Sanctuaire Caché | Liminal | calm_decision | easy | 0.90 ; 1.5 | 11-17 | Empathie, Logic |
| `beast_encounter` La Bête Cornue | Chaos | wild_communion | hard | 1.25 ; 0.75 | 11-21 | Instinct, Empathie |
| `druid_lineage` La Lignée des Druides | Ordre | ancestral_echo | medium | 1.00 ; 1.0 | 17-25 | Logic, Empathie |
| `threshold_crossing` Le Passage des Seuils | Liminal | transformation | hard | 1.15 ; 1.0 | 21-25 | Volonté, Instinct |

**Règles spéciales par archétype** (détail dans `scenario_templates.json`) :
- `druidic_awakening` : archétype d'onboarding — 0 check red/fatal, 0 interférence.
- `korrigan_trickery` : interférences Merlin ×1.5, Merlin Judges 15%→25% (thème tromperie).
- `ancient_oak_counsel` : échec red = -15 réputation au lieu de PV (danger social, pas physique).
- `mist_wanderer` : 30% des cartes à options voilées (« ??? ») — beith (révélation) y vaut double.
- `forest_trial` : rampe acte V +20% (l'épreuve culmine).
- `forgotten_ritual` : +1 carte PROMISE garantie ; seul archétype où un fatal en acte IV est permis.
- `hidden_sanctuary` : carte repos garantie acte III ; Anam -5 (le refuge coûte l'ambition). Proposé en priorité quand vie ≤ 40 (pity douce).
- `beast_encounter` : le plus létal, MAIS la route Empathie (communion) reste toujours viable.
- `druid_lineage` : +1 XP stat par acte (archétype d'apprentissage).
- `threshold_crossing` : archétype endgame — seul à mettre l'Ankou en faction récurrente ; le climax modifie un élément persistant.

**Sélection des 3 titres (LLM 1)** : 3 archétypes distincts, dont au plus 1
`hard`. Si vie < 40 au moment du pick : exclure `forest_trial`, inclure
`hidden_sanctuary`.

---

## 2. Structure canonique — 5 actes, 3 routes

### 2.1 Actes

Tout scénario, quelle que soit sa longueur canon (11/15/17/21/25), se projette
sur **5 actes égaux** aux rôles fixes :

| Acte | Rôle | Danger × | Contenu obligatoire |
|---|---|:---:|---|
| I | **Ouverture** | 0.6 | Émotion `curiosite` en carte 1 ; carte de choix de route en fin d'acte (3 options = 3 pôles) |
| II | **Pacte** | 0.8 | ≥ 1 carte SHOP (respiration stratégique : soins, dons, équipement rune) |
| III | **Épreuve** | 1.0 | Twist card (EPIQUE, MERLIN_DIRECT) à ~50% du run ; premier check red autorisé |
| IV | **Bascule** | 1.3 | ≥ 1 carte EVENT ; 2e SHOP si longueur ≥ 21 ; fatal autorisé (télégraphié) |
| V | **Climax** | 1.6 | Carte finale = **LEGENDAIRE + MERLIN_DIRECT** ; émotion finale ∈ {sagesse, peur, émerveillement} |

### 2.2 Routes (branchement 3 pôles)

Pattern canon : `tronc → branche 1 ×3 (ordre/chaos/liminal) → twist
(convergence) → branche 2 ×3 → convergence finale`. La **carte d'aiguillage**
est la dernière carte de l'acte I (c2 sur un scénario de 17 cartes, c5 sur un
scénario de 25) : ses 3 options pointent chacune vers une voie de pôle, et ce
sont les seules options du scénario qui changent la topologie. Partout ailleurs
les 3 options mènent à la même carte suivante — le choix pèse sur l'état du
joueur, pas sur le chemin.

Contraintes PAR ROUTE (chemin réellement joué) :
- longueur = `length` du scénario (les 3 routes sont isométriques)
- part NARRATIVE ∈ [0.50, 0.70] ; EVENT 1-4 ; SHOP 1-2 ; MERLIN_DIRECT 0-3 ; PROMISE 0-2 ; RUNE_UNLOCK 0-1
- jamais 2 SHOP / MERLIN_DIRECT / RUNE_UNLOCK consécutifs
- raretés ≈ 68% COMMUNE / 20% RARE / 8% EPIQUE / 4% LEGENDAIRE (tolérance ±15 pts)
- LEGENDAIRE uniquement dans le **dernier 30%** du chemin ; la carte finale l'est toujours

### 2.3 Arc émotionnel

- Vocabulaire fermé : curiosite, tension, peur, espoir, sagesse, fascination, colere, melancolie, emerveillement
- Carte 1 = `curiosite` ; jamais 2 émotions identiques consécutives ; finale ∈ {sagesse, peur, emerveillement}
- Chaque archétype a sa palette (ex. `beast_encounter` : peur/fascination/espoir — jamais melancolie)

---

## 3. Contrôle d'écriture (contraintes mesurables)

| Élément | Contrainte | Vérifié par |
|---|---|---|
| Titre | 2-7 mots, ≤ 60 caractères | validator ✅ + GBNF |
| Intro | 5-8 phrases, 2e personne, présent | guardrails LLM 2 (runtime) |
| Hook | 1 phrase sensorielle (odeur/son/texture/lumière) | prompt template |
| Summary de beat | 8-22 mots | validator ✅ |
| Options | exactement 3 ; verbe infinitif 1 mot ; 3 factions primaires distinctes | validator ✅ + GBNF |
| Effets | ≤ 3 par option ; whitelist §5.4 ; caps ±20 rep, +18 heal, -15 dmg | validator `--strict` ✅ + effect engine |
| Gradient (ordre, prudente jamais red, écart d'EV ≤ 2 PV-éq) | §3 ci-dessous | validator `--strict` ✅ |
| Act gates checks (red III+, fatal IV-V, espacement, télégraphie) | §5.2 | validator `--strict` ✅ |
| Interdits | forbidden words bible §9.4.2 (4e mur, anglicismes, cyber en prose) | guardrails HARD (runtime) |
| Répétition | Jaccard < 0.5 vs références et vs cartes du run | guardrails SOFT (runtime) |

*✅ = vérifié aujourd'hui par `validate_scenario_balance.py` (les lignes
`--strict` ne s'appliquent qu'aux scénarios portant la couche mécanique : le
golden fixture, et à terme les sorties du pipeline). « runtime » = appliqué en
jeu par les guardrails et l'effect engine existants.*

**Gradient des 3 options** (contrat par carte, aligné UX §5) :
- **Position fixe** : gauche = prudente, centre = équilibrée, droite = audacieuse
- EV proche (écart ≤ 2 PV-éq entre options) mais **variance croissante** — c'est
  le principe deck-builder : l'audacieuse ne paie pas plus en moyenne, elle paie
  via le critique (×1.5 + bonus XP) et coûte via l'échec
- La prudente n'est JAMAIS un « skip » gratuit : elle a un coût d'opportunité
  (moins d'XP, pas de critique possible)

---

## 4. Gameplay engagé — simple à jouer, profond à construire

### 4.1 La lecture « simple » (pilier UX §21.1)

Une carte = **une décision**. Budget d'information par option : **3 items
visibles** (verbe, glyphe de stat du check avec % dérivé du build, signal de
risque), le reste au flip (fourchette d'effets, faction) ou caché (valeurs
exactes, branches d'échec). Le Rune-Circuit est une affordance **globale**
(icône HUD pulsante si activable), jamais répétée par option.
Total écran ≈ 7 éléments (loi de Miller). Signalétique du gradient : position
fixe + bordure du parchemin (calme → craquelée) + 1/2/3 étincelles — jamais de
texte « risqué ».

**Anti-patterns interdits** dans un scénario généré :
1. Option sans conséquence inférable depuis son verbe — *exception sanctionnée :
   les options voilées « ??? » de `mist_wanderer` (30%) et de l'interférence
   `hide` de Merlin. Le voile est alors une mécanique diégétique contrable
   (beith révèle, saille détecte), jamais un défaut d'écriture.*
2. Check caché (glyphe de stat toujours visible face avant)
3. Info dupliquée HUD + carte
4. Deux décisions sur une carte (choix + gestion de promesse simultanés)
5. Option à double check (2 stats testées)
6. Gradient contredit (option « prudente » avec check red)
7. Texte d'option > 2 lignes ou chiffres bruts dans le verbe
8. Cible interactive < 44×44 px ou hover-only
9. Carte spéciale de faction sans marqueur visuel distinct

### 4.2 La couche « stratège » (deck-building)

Le « deck » de MERLIN n'est pas une pioche possédée : c'est l'ensemble des
**modificateurs persistants qui filtrent et colorent le flux de cartes** :

| Couche | Équivalent deck-builder | Décision du joueur |
|---|---|---|
| Rune-Circuit équipé (1 + 1 trouvable) | Relique de départ (StS) | Avant le run + switch entre cartes |
| Build 4 stats (+1 XP/choix aligné) | Deck thinning Disco Elysium | Chaque choix construit le personnage |
| Réputation factions (≥ 50 → cartes spéciales) | Deck unlocks Gloomhaven | Orientation long-terme cross-run |
| Promesses (max 2, échéance en cartes) | Quêtes HoF2 (EV différée) | Engagement risqué à terme |
| Dons per-run (aux cartes SHOP) | Draft Vampire-Survivors | Build intra-run |

**Respirations stratégiques** : fin d'acte II (SHOP : équiper la rune trouvée,
jauger les promesses) et fin d'acte IV (SHOP pré-finale). Fins d'actes I/III :
récap 1-tap (deltas rep/stats), pas de shop. Pendant une carte : seul
l'actionnable immédiat est montré.

**Exigence par scénario** : les 5 builds canon (§28.3 : Druide pur, Berserker,
Diplomate, Survivant, Polyvalent) doivent chacun trouver ≥ 1 ligne de jeu
viable — d'où la règle des 3 factions distinctes par carte et l'équité de
distribution des factions (§6.2).

### 4.3 First-run (onboarding) — 1 mécanique nouvelle max par acte

Acte I : loop nu (3 options, 1 tap). Acte II : checks white + glyphes ; SHOP
introduit la rune trouvée. Acte III : activation Rune-Circuit (signalée par
Merlin, diégétique). Acte IV : 1 promesse (max 1). Acte V : consolidation,
rien de nouveau. Jamais de red/fatal, jamais d'interférence
(`onboarding_overrides` du JSON).

---

## 5. Équilibrage mathématique

### 5.1 Unité commune : le PV-équivalent (méthode Dominion)

Tout effet se convertit : 1 PV = 1.0 · 1 Essence = 0.8 · 1 pt rep = 0.4 ·
1 Anam = 2.0 · 1 XP stat = 1.5 · promesse tenue = +8 · brisée = -10.
L'EV d'une option = Σ effets × probabilités. C'est l'outil qui permet de
comparer « +10 rep korrigans » à « -5 PV » sur une même échelle.

### 5.2 Le modèle de check (Disco Elysium calibré)

`pass = 50% + stat × 10%` (+ modificateurs de carte ±10-20%).
Types : white 75% (échec -3/-5 PV, retry-able), contextuel 15% (-7/-9),
red 8% (-12/-15, jamais retry — clamp au cap DAMAGE_LIFE §5.4), fatal 2%
(fin de run).
**Placement par acte** (25 cartes) : red à partir de l'acte III (1/acte max,
jamais 2 dans une fenêtre de 3 cartes), fatal actes IV-V uniquement,
télégraphié (détectable via saille). **Ember rule** : à vie ≤ 15, un fatal
dégrade en red. **Late-game** : actes IV-V utilisent
`pass = 50% + (stat - req) × 10%` avec req 1-3 croissant — un build stat 5+
garde de la tension sans retomber à l'auto-pass.

### 5.3 Budget de danger par acte (first-run, stats=1, pass 60%)

Multiplicateurs d'acte [0.6, 0.8, 1.0, 1.3, 1.6] × danger_modifier d'archétype.
EV dégâts par carte (mult 1.0) = 40% échec × 5.2 PV moyens ≈ 2.1 PV.

| Acte | Dégâts bruts EV | Soins EV | Net EV cumulé |
|---|---:|---:|---:|
| I | ~6 | +4 | -2 |
| II | ~8 | +12 (shop) | +2* |
| III | ~11 | +4 | -5 |
| IV | ~14 | +12 (shop) | -7 |
| V | ~17 | +4 | -20 |

Total : dégâts bruts ≈ 56 PV (bas de l'enveloppe [55-75]), soins nominaux
≈ 36 PV. \*Le clamp à 100 (soins perdus à pleine vie, surtout actes I-II) et
la variance ramènent l'attrition effective à ~30 PV : **vie finale p50
observée en simulation = 70** (first-run).

Ratio soins/dégâts global ≈ 0.33 (fourchette HoF2 : 0.3-0.4). Cibles de
mortalité : first-run 15-30%, build spécialisé 5-15%, aucun profil à 0% ni
> 40%, morts concentrées actes IV-V.

**Résultat clé de la simulation (§5.6)** : les dégâts white/red pilotent la
*tension* (vie finale), pas la *mortalité*. La mortalité est pilotée à ~100%
par le placement des cartes fatales. La règle canon est donc : **le budget
fatal global (2% du pool) est concentré actes IV-V — 5% du tirage sur les 10
dernières cartes, 0% avant.** Avec cette seule règle, toutes les cibles
passent et 100% des morts tombent en actes IV-V.

### 5.4 Économie des Rune-Circuits

Activations sur 25 cartes = 1 + ⌊24/CD⌋. Cible : **35-45 PV-éq de valeur
totale par rune et par run** (60-75% des dégâts bruts attendus — significatif,
jamais auto-win).

**Bug d'équilibrage n°1 détecté** : `quert` (soin +10, CD 4) = 7 activations
× 10 = **70 PV-éq/run**, soit 130% de l'attrition nette des actes I-III.
**Proposition (décision utilisateur requise — canon bible §3.3)** :
quert CD 4→6 et soin 10→8 (= 40 PV-éq) ; luis CD 4→5 ; straif CD 8→7 ;
nuin CD 6→5. beith/duir/saille/muin/ioho inchangés (ioho = soupape anti-fatal
assumée à 36 PV-éq).

### 5.5 Garde-fous anti-dégénérescence

1. **Anti-safe-spam** : après 3 options zéro-risque consécutives, le MOS force une carte sans option neutre.
2. **Anti-farm rep** : ±20/carte (canon) + **±60/faction/run** ; gains ÷2 au-dessus de rep 80.
3. **Anti stat-grind** : 0 XP au-delà de 3 choix consécutifs sur la même stat.
4. **Cap soins** : +18/carte (canon) + **+24/acte** (quert + repos + critique ne stackent plus).
5. **Cap multiplicateurs** : ×2.0 s'applique APRÈS tout cumul (crit ×1.5 × duir ×2.0 → clamp ×2.0).
6. **Prix Essence** : petit soin 8, soin moyen 15, don majeur 25 ; gain max +10/carte.
7. **Équité factions** : chaque faction ≥ 8% des options du pool, druides ≤ 30%.

### 5.6 Validation empirique

Deux outils ferment la boucle :
- `tools/validate_scenario_balance.py` — audit statique par route (score 0-100).
  État du corpus après patch v1.0 : **90.3/100 moyen, 0 erreur** (avant : 24.2,
  600 erreurs — climax plats, légendaires mi-run, routes sans SHOP/EVENT).
- `tools/simulate_run_balance.py` — Monte-Carlo 10 000 runs × 6 profils
  (first-run 1/1/1/1 + les 5 builds §28.3), 2 seeds. Tuning validé :

| Build | Mort % | Vie finale p50 | Morts actes IV-V | Cible |
|---|---:|---:|---:|---|
| First-run | 17.9% | 70.0 | 100% | 15-30% ✓ |
| Druide pur | 12.5% | 85.5 | 100% | 5-15% ✓ |
| Berserker | 12.7% | 85.8 | 100% | 5-15% ✓ |
| Diplomate | 12.6% | 85.3 | 100% | 5-15% ✓ |
| Survivant | 12.8% | 85.8 | 100% | 5-15% ✓ |
| Polyvalent | 10.1% | 92.2 | 100% | 5-15% ✓ |

  Variante « attrition » disponible si l'on veut que la barre de vie tue aussi
  (white -6 / ctx -12 / red -20, courbe [0.4→2.0], heal 20%) : first-run 15.5%
  dont 27% de morts par PV, fins de run tendues (p10 vie = 26).

### 5.7 Findings ouverts (nécessitent une passe de régénération LLM, pas un patch)

| Finding | Mesure | Cible | Remède |
|---|---|---|---|
| Druides sur-représentés | 32.5% des options | ≤ 30% | Régénérer les options des cartes trunk avec quota de factions |
| Ankou affamé | 7.8% | ≥ 8% | Ajouter des options ankou aux archétypes sombres (mist_wanderer, threshold_crossing) |
| 20 arcs ouvrent sur `tension` | 20% | `curiosite` | Passe de régénération des beats 1 concernés |
| EPIQUE résiduel sur certaines routes | drift ≤ 15 pts sur 68 scénarios | ±15 pts | Acceptable (warn) — surveiller à la prochaine génération |
| Builds spécialisés statistiquement identiques en survie | écarts < 0.4 pt | expression de build | Le mix de stats par archétype (§1) + le contenu des cartes portent l'expression, pas la survie — appliquer le `stat_mix` au tirage des checks |
| Polyvalent = build le plus sûr | 10.1% vs 12.5-12.8% | équité | 12 pts de stats vs 10 : aligner les budgets à 12 pts OU biaiser le mix de stats par acte |
| Corpus trop doux | attrition EV p50 = 22 PV | 30-45 | Les danger_modifiers doux dominent le corpus actuel — corriger à la régénération (plus d'archétypes hard) ou relever les dégâts de base |

---

## 6. Intégration pipeline (prochaines étapes code)

1. `scenario_planner.gd::_balance_skeleton` : ajouter la lecture de
   `scenario_templates.json` (archétype → danger/heal modifiers, palette
   émotionnelle, check_act_distribution) — aujourd'hui seuls les caps de types
   et raretés sont enforcés.
2. LLM 1 (titres) : contraindre les 3 titres à 3 archétypes distincts (≤ 1 hard),
   filtre vie < 40.
3. GM (effets) : injecter le budget de danger de l'acte courant dans le prompt
   (`gamemaster_event_effects`) + caps anti-dégénérescence §5.5.
4. MOS : implémenter ember rule, anti-safe-spam, caps par acte/run.
5. CI : `validate_scenario_balance.py --min-score 60` sur toute modification du
   corpus de références.

## 7. Divergences flaggées (décision utilisateur requise — bible §24.1)

1. **Cooldowns Rune-Circuits** : tuning proposé §5.4 modifie le canon bible §3.3.
2. **MOS target** : bible §6.4 dit 15-20 cartes (soft max 30, hard max 40) ; le
   changelog v3.5 + CLAUDE.md §10.4 disent 25 (hard max 50). Les longueurs canon
   du corpus (11-25) collent au §6.4. À réconcilier.
3. **Card flip** : CLAUDE.md §10.4 impose double-tap RotateY, bible §21.5
   interdit le double-tap. Proposition UX : tap simple sur la carte (le choix
   étant un tap sur l'option), ou long-press.
4. **§27.3 vs §3.2** : « faction rep reset à 0 sauf ≥ 80 » contredit « cross-run
   sans decay ». À trancher.
5. **BALANCE_FORMULA.md (2026-04-26)** : obsolète (3 stats Souffle/Esprit/Cœur,
   runs 5 cartes, drain) — à archiver ou réécrire sur la base de ce document.

## 8. Le scénario type de référence (golden fixture)

Un contrat sans exemplaire reste théorique. Le projet maintient donc **un
scénario type de référence** qui incarne toutes les règles ci-dessus et sert
simultanément de trois choses :

1. **Référence d'écriture** — few-shot injecté dans les prompts LLM (via ScenariosRAG).
2. **Fixture de non-régression** — il doit scorer 100/100 au validateur en mode `--strict`.
3. **Cible de conformité** — c'est cette forme que le pipeline in-game doit apprendre à produire.

### 8.1 Deux couches séparées

| Couche | Produite par | Propriété |
|---|---|---|
| **Mécanique** — graphe de cartes, routes, types, raretés, arc, pôles, factions, checks, effets | `tools/build_golden_scenario.py`, dérivée du contrat | déterministe, reproductible, garantie conforme |
| **Prose** — titre, intro, hook, summaries, labels, verbes | LLM (ou humain), injectée via `--merge-prose` | créative, remplaçable sans toucher à l'équilibrage |

Cette séparation est le cœur de la méthode : **on ne négocie jamais l'équilibrage
en écrivant de la prose**. Le générateur mint un squelette parfait, la prose
vient s'y couler.

```bash
python tools/build_golden_scenario.py --prose-slots /tmp/slots.json   # gabarits à remplir
python tools/build_golden_scenario.py --merge-prose /tmp/prose.json \
    --out data/ai/scenario_golden_broceliande.json \
    --markdown docs/30_jdr/SCENARIO_TYPE_GOLDEN.md
python tools/validate_scenario_balance.py \
    --file data/ai/scenario_golden_broceliande.json --strict
```

### 8.2 Le validateur en mode strict

`--strict` ajoute au validateur la couche mécanique que l'audit avait signalée
comme non vérifiée (finding 6) : présence et validité des `check` (stat, type),
**act gates** (pas de red avant l'acte III, pas de fatal avant l'acte IV),
espacement des red, ordre du gradient, interdiction d'une option prudente
portant un check dur, télégraphie des red/fatal, whitelist et caps des effets,
écart d'EV entre options, et anti-safe-spam par acte.

Sur le corpus de 100 références, `--strict` fait tomber le score de 90,8 à 80,8 :
exactement 10 points, soit l'erreur `NO_CHECK_LAYER` — le corpus actuel ne porte
aucune couche mécanique. C'est la mesure chiffrée de ce qu'il reste à générer.

## 9. Vérification : le jeu produit-il ce contrat ?

Le contrat ne vaut que si l'on peut mesurer l'écart avec le jeu réel. Deux outils
ferment la boucle, **sans nécessiter Ollama** (`_balance_skeleton` est statique) :

```bash
godot --headless --path . --script res://tools/godot/conformance_pipeline.gd
python tools/check_pipeline_output.py --report docs/30_jdr/PIPELINE_OUTPUT_AUDIT.md
```

Le harnais exécute le **vrai code d'équilibrage du jeu** sur trois familles
d'entrées : les 8 squelettes de secours livrés en dur (cascade L3), des
squelettes bruts au format GBNF (5/7/10 beats), et un squelette à 25 beats pour
distinguer « le clamp bloque » de « l'équilibrage est faux ». Les entrées
synthétiques sont volontairement **conformes** au contrat sur tout ce qu'elles
peuvent porter, de sorte que toute non-conformité observée en sortie soit
imputable au jeu et non au jeu de test.

L'audit distingue deux familles de verdicts :

- **CAPACITÉ** — le pipeline peut-il seulement produire la *forme* décrite ?
  Un échec est structurel, aucun réglage ne le corrige.
- **RÉGLAGE** — sur ce qu'il produit, respecte-t-il les règles d'équilibrage ?

Résultats et roadmap : `docs/30_jdr/PIPELINE_OUTPUT_AUDIT.md` (chiffres) et
`docs/30_jdr/PIPELINE_CONFORMANCE_REPORT.md` (analyse par fichier:ligne).

## 10. Génération 100 % LLM et non-ressemblance

> **Décision d'architecture 2026-07-26.** Les scénarios sont générés intégralement
> par le LLM, pour un maximum de créativité, et **aucun scénario ne doit ressembler
> à un autre** — dans les limites du bornage posé par la bible. Le système de cartes
> reste le substrat mécanique ; les scénarios, eux, ne sont jamais pré-écrits.

### 10.1 Le few-shot de contenu est la cause du problème, pas la solution

L'architecture v7.7.23 injectait des scénarios de référence complets comme exemples,
pour caler la qualité d'écriture. La mesure du corpus qui sert de source montre où
cela mène :

| Mesure | Corpus de 100 références |
|---|---|
| Intros distinctes | 40 / 100 |
| `essence` et `hook` distincts | 10 / 100 (un par archétype, recopié) |
| Résumés de cartes distincts | **90 / 2 994** |
| Libellés d'options distincts | **18 / 8 982** — « Affronter », « Fuir », « Apaiser » ×803 chacun |
| Paires au-dessus de 0,95 de cosinus | 80, dont plusieurs à 1,000 |

Les « 100 scénarios de référence » sont dix gabarits clonés dix fois. Un modèle à qui
l'on montre ce corpus apprend la copie. **Le few-shot de contenu est donc interdit sur
les champs créatifs** ; les références ne fournissent plus que le bornage.

### 10.2 Ce que les références ont le droit de fournir

| Autorisé | Interdit |
|---|---|
| La voix (registre, rythme, longueur de phrase) via 1-2 extraits **courts** | Injecter un scénario de référence complet |
| Les bornes chiffrées (longueurs, caps, quotas) | Injecter des résumés de cartes comme modèles |
| La liste des motifs déjà utilisés, **en négatif** (à éviter) | Injecter des trios d'options comme modèles |

### 10.3 Deux mécanismes complémentaires

**La graine de variation** (`addons/merlin_ai/scenario_variation.gd`) — avant la
génération, on tire une valeur par axe et on l'**impose** au LLM :

| Axe | Valeurs | Rôle |
|---|:---:|---|
| `lieu` | 9 | le décor central, imposé |
| `entite_centrale` | 9 | ce autour de quoi tourne le scénario |
| `pression` | 8 | ce qui presse le voyageur |
| `registre_sensoriel` | 5 | le sens dominant de l'écriture |
| `mecanisme_du_twist` | 8 | ce sur quoi porte le retournement |

Soit **25 920 combinaisons**, toutes à l'intérieur du bornage celtique de la bible.
Une valeur ne peut pas ressortir avant 3 scénarios (cooldown). Vérifié par simulation :
60 graines distinctes sur 60 tirages, aucune violation de cooldown, 8 lieux différents
sur 10 scénarios consécutifs. La graine est tirée **une fois par scénario** et partagée
par les appels titres / intro / squelette, pour qu'ils décrivent bien le même scénario.

**La porte de nouveauté** — après la génération, le scénario est comparé aux 20 derniers
joués. Au-delà de 0,90 de cosinus (ou 0,35 de Jaccard sur l'intro), une régénération est
lancée avec une graine différente et la mention explicite de ce qu'il faut éviter. Si le
second essai échoue encore, on accepte et on journalise : **on ne bloque jamais le joueur
pour un motif de style**. C'est l'infrastructure d'embeddings existante, utilisée à
l'envers — au lieu de chercher le plus proche pour l'imiter, on rejette ce qui est trop
proche.

### 10.4 La diversité devient une contrainte mesurée

`tools/check_scenario_diversity.py` mesure six axes et répond à une seule question :
deux scénarios se ressemblent-ils ? Les seuils vivent dans
`scenario_templates.json → diversity_contract`.

| Axe | Cible |
|---|---|
| sémantique | cosinus moyen ≤ 0,75 ; aucune paire > 0,90 |
| lexical | aucune paire au-dessus de 0,35 de Jaccard |
| situationnel | ≥ 95 % de résumés de cartes distincts |
| verbal | ≥ 90 % de libellés distincts, ≥ 12 verbes par scénario |
| structurel | ≥ 80 % de signatures distinctes |
| motifs | aucun motif présent dans plus de 50 % des scénarios |

État du corpus de référence à l'introduction de la mesure : **0 / 6 axes conformes**.
C'est le point de départ, pas un échec du contrat — il chiffre exactement ce que la
génération LLM doit désormais produire à la place.

### 10.5 Conséquence sur le rôle du scénario type de référence

Le golden (`Le Rite des Neuf Souffles`, §8) ne devient donc **pas** un modèle à imiter.
Son rôle est double et strictement borné : servir de fixture de non-régression au
validateur (100/100 en `--strict`), et démontrer qu'un scénario pleinement conforme au
contrat est atteignable. Il n'est jamais injecté comme exemple de contenu.
---

*Scénarios types v1.0 — s'inspire de Slay the Spire (courbes acte/rareté),
Dominion (PV-équivalent), Hand of Fate 2 (no-drain, deck de rencontres),
Gloomhaven (unlocks de faction), Disco Elysium (checks & builds) — appliqué aux
mécaniques propres de MERLIN : 5 factions, 4 stats, 9 Rune-Circuits, promesses,
interférences de Merlin.*
