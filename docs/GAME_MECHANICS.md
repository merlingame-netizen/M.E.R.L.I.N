# M.E.R.L.I.N. — GAME MECHANICS COMPLET

> **Version**: 2.0 | **Date**: 2026-03-15
> **Scope**: TOUTES les formules, constantes, seuils, pondérations et comportements du jeu.
> **Source de verite design**: `GAME_DESIGN_BIBLE.md` v2.4 (WHAT + WHY)
> **Etat post-audit**: `DESIGN_STATUS.md` (tracking mecaniques confirmees/supprimees, nettoyage code)
> **Companions**: `GAME_ENCYCLOPEDIA.md` (encyclopedie descriptive) | `GAME_BEHAVIOR.md` (comportement runtime & rendu) — ce document est le referentiel TECHNIQUE.
> **Docs systeme audit (2026-03-15)**: 14 docs dans `10_llm/`, `20_card_system/`, `30_scenes/`, `40_progression/`, `70_graphic/` — voir `DESIGN_STATUS.md` §3 pour l'index complet.

---

## TABLE DES MATIERES

1. [Score & Multiplier Pipeline](#1-score--multiplier-pipeline)
2. [Systeme d'effets — Scaling & Capping](#2-systeme-deffets--scaling--capping)
3. [Life Essence — Barre de vie unique](#3-life-essence--barre-de-vie-unique)
4. [Reputation des 5 Factions](#4-reputation-des-5-factions)
5. [Karma & Tension (Hidden State)](#5-karma--tension-hidden-state)
6. [Trust Merlin — Tiers de confiance](#6-trust-merlin--tiers-de-confiance)
7. [Promesses — Systeme contractuel](#7-promesses--systeme-contractuel)
8. [Oghams — Cooldowns & Effets](#8-oghams--cooldowns--effets)
9. [Anam — Calcul de recompenses cross-run](#9-anam--calcul-de-recompenses-cross-run)
10. [Arbre de Talents — Modificateurs actifs](#10-arbre-de-talents--modificateurs-actifs)
11. [Difficulte adaptative & Pity System](#11-difficulte-adaptative--pity-system)
12. [Ponderation des evenements — 7 facteurs](#12-ponderation-des-evenements--7-facteurs)
13. [Taxonomie d'evenements & Frequence](#13-taxonomie-devenements--frequence)
14. [Periodes in-game & Bonus factions](#14-periodes-in-game--bonus-factions)
15. [Biomes — Effets passifs & Deverrouillage](#15-biomes--effets-passifs--deverrouillage)
16. [Maturite joueur — Score & Seuils](#16-maturite-joueur--score--seuils)
17. [MOS — Convergence & Guardrails](#17-mos--convergence--guardrails)
18. [Pipeline de resolution d'une carte (14 etapes)](#18-pipeline-de-resolution-dune-carte-14-etapes)
19. [Generation de cartes — Selection & Fallback](#19-generation-de-cartes--selection--fallback)
20. [Systeme de deck & Progression de run](#20-systeme-de-deck--progression-de-run)
21. [Fins de run — Conditions & Calculs](#21-fins-de-run--conditions--calculs)
22. [Narrative Scaler — Contenu gate par experience](#22-narrative-scaler--contenu-gate-par-experience)
23. [Session Registry — Bien-etre joueur](#23-session-registry--bien-etre-joueur)
24. [RNG — Generateur pseudo-aleatoire](#24-rng--generateur-pseudo-aleatoire)
25. [Phases lunaires](#25-phases-lunaires)
26. [Power Milestones — Paliers de puissance](#26-power-milestones--paliers-de-puissance)
27. [Profil joueur — 6 traits comportementaux](#27-profil-joueur--6-traits-comportementaux)
28. [Champs lexicaux — Detection & Mapping minigames](#28-champs-lexicaux--detection--mapping-minigames)
29. [Sauvegarde — Structure cross-run vs intra-run](#29-sauvegarde--structure-cross-run-vs-intra-run)
30. [Annexe — Table de reference des constantes](#30-annexe--table-de-reference-des-constantes)

---

## 1. SCORE & MULTIPLIER PIPELINE

Le score (0-100) produit par chaque minigame est converti en multiplicateur qui s'applique a TOUS les effets de l'option choisie.

### Table de conversion score → multiplicateur

| Score | Label | Multiplicateur | Comportement |
|-------|-------|---------------|-------------|
| 0-20 | echec_critique | **-1.5** | Effets INVERSES et amplifies (heal devient damage) |
| 21-50 | echec | **-1.0** | Effets INVERSES (positif → negatif, negatif → positif) |
| 51-79 | reussite_partielle | **+0.5** | Effets ATTENUES (moitie de la valeur brute) |
| 80-94 | reussite | **+1.0** | Effets NORMAUX (valeur brute) |
| 95-100 | reussite_critique | **+1.5** | Effets AMPLIFIES (+50%) |

### Implementation
```gdscript
static func get_multiplier(score: int) -> float:
    for entry in MULTIPLIER_TABLE:
        if score >= int(entry["range_min"]) and score <= int(entry["range_max"]):
            return float(entry["factor"])
    return 1.0  # Fallback
```

### Exemples concrets

| Effet brut | Score 15 (×-1.5) | Score 35 (×-1.0) | Score 65 (×+0.5) | Score 85 (×+1.0) | Score 98 (×+1.5) |
|-----------|------------------|------------------|------------------|------------------|------------------|
| HEAL +10 | **-15** (damage!) | **-10** (damage) | **+5** | **+10** | **+15** |
| DAMAGE +8 | **+12** (amplifie) | **+8** | **+4** | **+8** | **+12** |
| REP +5 | **-7** (perte!) | **-5** (perte) | **+2** | **+5** | **+7** |

**Point critique**: Un echec critique INVERSE les effets — un heal devient un damage et vice-versa. C'est le risque fondamental du jeu.

---

## 2. SYSTEME D'EFFETS — SCALING & CAPPING

### Formule de scaling
```
scaled_amount = int(raw_amount * abs(multiplier))
if multiplier < 0: scaled_amount = -scaled_amount
final_amount = cap_effect(effect_type, scaled_amount)
```

### Caps par type d'effet (limites dures)

| Effet | Cap min | Cap max | Contexte |
|-------|---------|---------|----------|
| ADD_REPUTATION | -20 | +20 | Par application individuelle |
| HEAL_LIFE | — | +18 | Heal normal |
| HEAL_CRITICAL | — | +5 | Heal bonus critique (score 95-100) |
| DAMAGE_LIFE | — | +15 | Damage normal |
| DAMAGE_CRITICAL | — | +22 | Damage echec critique |
| ADD_BIOME_CURRENCY | — | +10 | Monnaie biome |
| UNLOCK_OGHAM | — | 1 par carte | Max 1 ogham par carte |
| effects_per_option | — | 3 | Max 3 effets par option |
| score_bonus_cap | — | 2.0 | Multiplicateur talent max |
| drain_per_card | — | 1 | Drain passif (avant talents) |
| LIFE total | 0 | 100 | Clamp global |

### Chaine complete de resolution d'un effet
```
1. Lire raw_amount depuis le JSON de l'option
2. Appliquer le multiplicateur du score minigame
3. Appliquer le cap par type d'effet
4. Verifier protection Ogham (luis, gort, eadhadh)
5. Appliquer les modificateurs de talent
6. Clamper le resultat au range global [0, 100]
7. Emettre le signal correspondant
```

---

## 3. LIFE ESSENCE — BARRE DE VIE UNIQUE

### Constantes
```gdscript
LIFE_ESSENCE_MAX             := 100    # Vie maximale
LIFE_ESSENCE_START           := 100    # Vie debut de run
LIFE_ESSENCE_DRAIN_PER_CARD  := 1      # Perte passive par carte jouee
LIFE_ESSENCE_LOW_THRESHOLD   := 25     # Seuil alerte UI (bar rouge)
LIFE_ESSENCE_CRIT_FAIL_DAMAGE := 10    # Damage bonus echec critique (score 0-20)
LIFE_ESSENCE_FAIL_DAMAGE     := 0      # Pas de damage supplementaire (score 21-50)
LIFE_ESSENCE_EVENT_FAIL_DAMAGE := 6    # Echec d'evenement/palier
LIFE_ESSENCE_CRIT_SUCCESS_HEAL := 5    # Heal bonus reussite critique (score 95-100)
LIFE_ESSENCE_HEAL_PER_REST   := 18     # Soin au noeud REST de la map
```

### Calcul par carte
```
vie_apres = vie_avant
            - DRAIN_PER_CARD (1)
            + effets_scaled (HEAL_LIFE / DAMAGE_LIFE)
            + bonus_critique (si score 95-100: +5 / si score 0-20: -10)
vie_apres = clamp(vie_apres, 0, LIFE_MAX)
```

### Condition de mort
```gdscript
if life_essence <= 0:
    run_ended = true
    reason = "death"
```

### Drain modifie par talents
- **druides_5 (Racine Celeste)**: drain_reduction = 2 → drain effectif = max(0, 1 - 2) = **0**
- **ankou_1 (Marche avec l'Ombre)**: annule drain → drain = **0**

---

## 4. REPUTATION DES 5 FACTIONS

### Factions et valeurs initiales
```gdscript
FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"]
FACTION_SCORE_MIN   := 0
FACTION_SCORE_MAX   := 100
FACTION_SCORE_START := 10     # Toutes les factions demarrent a 10
```

### Tiers de reputation

| Score | Label | Consequence |
|-------|-------|-------------|
| 80-100 | Venere | Fin de faction debloquee + run-start bonus |
| 60-79 | Honore | Contenu special debloques |
| 40-59 | Sympathisant | Contenu supplementaire |
| 20-39 | Neutre | Aucun effet |
| 5-19 | Mefiant | — |
| 0-4 | Hostile | Penalite run-start |

### Deltas de reputation
```gdscript
FACTION_DELTA_MINOR   := 5      # Geste mineur, mot-cle auto-tag
FACTION_DELTA_MAJOR   := 15     # Choix narratif significatif
FACTION_DELTA_EXTREME := 30     # Acte heroique ou trahison majeure
```

### Application (IMMUTABLE — retourne nouvelle copie)
```gdscript
static func apply_delta(factions: Dictionary, faction: String, delta: float) -> Dictionary:
    var result = factions.duplicate()
    var current = float(result.get(faction, 0.0))
    var new_value = clampf(current + delta, VALUE_MIN, VALUE_MAX)
    result[faction] = new_value
    return result
```

### Bonus/Malus de debut de run (par tier)

| Faction | Tier Honore (80+) | Tier Hostile (0-4) |
|---------|------------------|-------------------|
| Druides | HEAL +15 | DAMAGE +10 |
| Anciens | HEAL +10 | DAMAGE +5 |
| Korrigans | HEAL +20 | DAMAGE +10 |
| Niamh | HEAL +15 | DAMAGE +5 |
| Ankou | HEAL +10 | **DAMAGE +15** (le pire) |

### Auto-detection de faction par mots-cles
```gdscript
FACTION_KEYWORDS := {
    "druides":   ["druide", "ogham", "nemeton", "chene", "barde"],
    "korrigans": ["korrigan", "farfadet", "marais", "lutin", "fee"],
    "niamh":     ["niamh", "eau", "lac", "amour", "nostalgie"],
    "anciens":   ["ancien", "menhir", "dolmen", "eternite", "primordial"],
    "ankou":     ["ankou", "mort", "faucheuse", "ame", "trepas"],
}
```

### Proprietes cles
- **Pas de decay**: la reputation NE diminue PAS automatiquement
- **Cross-run**: les valeurs persistent entre les runs
- **Multiple factions honorees**: chacune compte independamment (+5 Anam chacune)
- **Faction dominante**: seule la plus haute est trackee (pas la somme)

---

## 5. KARMA & TENSION (HIDDEN STATE)

### Stockage
```gdscript
state["run"]["hidden"] = {
    "karma": 0,          # -∞ to +∞ (pas de cap)
    "tension": 0,        # 0-100 (clampe)
    "player_profile": {
        "audace": 0, "prudence": 0,
        "altruisme": 0, "egoisme": 0
    },
    "resonances_active": [],
    "narrative_debt": [],
}
```

### Karma
- **Invisible au joueur** sauf si talent "Oeil de Merlin" (central_3) debloquer
- Affecte le TYPE de fin de run:

| Karma | Type de fin |
|-------|-------------|
| >= +5 | `harmonie` — fin positive |
| <= -5 | `victoire_amere` — victoire amere |
| -4 a +4 | `prix_paye` — prix paye (neutre) |

- Sources de karma: effets ADD_KARMA des cartes, promesses (+/-), choix narratifs

### Tension
- **Clampee [0, 100]** (contrairement au karma)
- Affecte la selection d'evenements (CONS_LUNE_SANG requiert tension > 40)
- Affecte le comportement du MOS (mode crise si tension > 50)
- Sources: evenements, promesses brisees (+10), choix dangereux

---

## 6. TRUST MERLIN — TIERS DE CONFIANCE

### 4 Tiers

| Tier | Score | Label | Ce que Merlin revele |
|------|-------|-------|---------------------|
| T0 | 0-24 | Cryptique | Commentaires vagues, enigmatiques |
| T1 | 25-49 | Indices | Indices narratifs, allusions |
| T2 | 50-74 | Avertissements | Avertissements directs, lore partiel |
| T3 | 75-100 | Secrets | Secrets complets, meta-narrative |

### Deltas de trust

| Evenement | Delta |
|-----------|-------|
| Promesse tenue | **+10** |
| Promesse brisee | **-15** |
| Choix courageux | **+3 a +5** (aleatoire) |
| Choix egoiste | **-5 a -3** (aleatoire) |

### Effet sur le gameplay
- T0: cartes merlin_direct limitees (md_conseil, md_warning)
- T1: debloquer md_secret
- T2: debloquer md_gift
- T3: acces aux revelations finales et evenements SECRET_MEMOIRE_MERLIN

---

## 7. PROMESSES — SYSTEME CONTRACTUEL

### Structure d'une promesse
```gdscript
{
    "id": "promise_id",
    "description": "text",
    "created_day": current_day,
    "deadline_day": current_day + deadline_days,
    "status": "active",            # → "fulfilled" ou "broken"
    "condition_type": "life_above" | "faction_gain" | "minigame_wins" | "no_safe",
}
```

### Regles
- **Max 2 promesses actives** simultanement
- Pas de promesse possible avant **carte 5+**
- Deadline en nombre de cartes (pas de temps reel)

### Resolution
```
A chaque carte jouee:
    Si card_index >= deadline_card:
        Evaluer la condition
        → Condition remplie: status = "fulfilled", trust += 10
        → Condition echouee: status = "broken", trust -= 15, karma -= 15, tension += 10
```

### Tracking par type de condition
| Type | Ce qui est tracke |
|------|------------------|
| life_above | vie actuelle vs seuil |
| faction_gain | delta reputation faction specifique |
| minigame_wins | nombre de victoires (score >= 80) |
| no_safe | ne pas avoir choisi l'option "safe" |

---

## 8. OGHAMS — COOLDOWNS & EFFETS

### 18 Oghams — Specs completes

| Ogham | Arbre | Categorie | Cooldown | Cout Anam | Effet | Details |
|-------|-------|-----------|----------|-----------|-------|---------|
| beith | Bouleau | reveal | 3 | 0 (starter) | reveal_one_option | Revele les effets d'1 option |
| luis | Sorbier | protection | 4 | 0 (starter) | block_first_negative | Bloque le 1er effet negatif |
| quert | Pommier | recovery | 4 | 0 (starter) | heal_immediate | +8 PV |
| coll | Noisetier | reveal | 5 | 80 | reveal_all_options | Revele TOUS les effets |
| ailm | Sapin | reveal | 4 | 60 | predict_next | Predit la prochaine carte |
| gort | Lierre | protection | 6 | 100 | reduce_high_damage | Damage > 10 reduit a 5 |
| eadhadh | Tremble | protection | 8 | 150 | cancel_all_negatives | Annule TOUS effets negatifs |
| duir | Chene | boost | 4 | 70 | heal_immediate | +12 PV |
| tinne | Houx | boost | 5 | 120 | double_positives | Effets positifs ×2 |
| onn | Ajonc | boost | 7 | 90 | add_biome_currency | +10 monnaie biome |
| nuin | Frene | narrative | 6 | 80 | replace_worst_option | Remplace la pire option |
| huath | Aubepine | narrative | 5 | 100 | regenerate_all_options | Re-genere les 3 options |
| straif | Prunellier | narrative | 10 | 140 | force_twist | Force un retournement |
| ruis | Sureau | recovery | 8 | 130 | heal_and_cost | +18 PV, -5 monnaie |
| saille | Saule | recovery | 6 | 90 | currency_and_heal | +8 monnaie, +3 PV |
| muin | Vigne | special | 7 | 110 | invert_effects | Inverse tous les effets |
| ioho | If | special | 12 | 160 | full_reroll | Re-genere toute la carte |
| ur | Bruyere | special | 10 | 140 | sacrifice_trade | -15 PV, +20 monnaie, ×1.3 score |

### Cooldown system
```
Activation → cooldown = N tours
Chaque carte jouee → cooldown -= 1
Quand cooldown = 0 → ogham disponible

Talent central_2 (Flux Accelere): cooldown_reduction = 1
→ cooldown effectif = max(0, cooldown_original - 1)
```

### Starters (cout 0, equipes par defaut)
- beith, luis, quert

### Equipement
- 1 ogham equipe a la fois (defaut)
- Talent "Eveil Ogham" (special): permet 2 equipes simultanement (1→2)

---

## 9. ANAM — CALCUL DE RECOMPENSES CROSS-RUN

### Formule complete
```
anam = BASE (10)
     + VICTORY_BONUS (15, si victoire)
     + minigames_won × 2 (score >= 80 chacun)
     + oghams_used × 1
     + factions_honored × 5 (chaque faction >= 80)

Si NON-victoire (mort/abandon):
    ratio = min(cards_played / 30, 1.0)
    anam = int(anam × ratio)

Puis modificateurs de talents:
    × 2.0 si Tresor du Tertre (korrigans_5)
    + 3   si Doigts de Fee
    × 1.5 si Recolte Sombre (ankou_5) ET vie <= 25
    × 1.5 si Boucle Eternelle (NG+)
```

### Exemples calcules

**Victoire classique** (30 cartes, 5 minigames gagnes, 2 oghams, 1 faction honoree):
```
10 + 15 + (5×2) + (2×1) + (1×5) = 10 + 15 + 10 + 2 + 5 = 42 Anam
```

**Mort precoce** (12 cartes, 1 minigame, 0 ogham, 0 faction):
```
Base: 10 + 0 + 2 + 0 + 0 = 12
Ratio: min(12/30, 1.0) = 0.4
Final: int(12 × 0.4) = 4 Anam
```

**Victoire + talents actifs** (25 cartes, 8 minigames, 3 oghams, 2 factions, Tresor + Recolte, vie=20):
```
Base: 10 + 15 + 16 + 3 + 10 = 54
× 2.0 (Tresor): 108
× 1.5 (Recolte, vie 20 <= 25): 162 Anam
```

---

## 10. ARBRE DE TALENTS — MODIFICATEURS ACTIFS

### Couts par tier

| Tier | Cout min | Cout max |
|------|----------|----------|
| 1 | 50 | 80 |
| 2 | 80 | 120 |
| 3 | 120 | 180 |
| 4 | 180 | 250 |
| 5 | 250 | 350 |

### Talents modifiant les calculs du jeu

| Talent | Branche | Tier | Cout | Modificateur exact |
|--------|---------|------|------|-------------------|
| Racines Profondes | Druides | 1 | 20 | +10 PV au debut de run (100→110 effectif) |
| Seve Guerisseuse | Druides | 2 | 25 | +15% efficacite heal (×1.15) |
| Manteau de Mousse | Druides | 3 | 50 | Protection 1er damage du run (ignore 1 instance) |
| Communion Vegetale | Druides | 4 | 80 | +10% score minigames "perception" |
| Racine Celeste | Druides | 5 | 120 | Drain vie = 0 (reduction de 2, drain base = 1) |
| Memoire de Pierre | Anciens | 1 | 20 | Voit le champ lexical avant de choisir |
| Sagesse du Menhir | Anciens | 2 | 25 | +10% gains reputation toutes factions |
| Voix du Cairn | Anciens | 3 | 50 | 1er ogham du run: cooldown / 2 |
| Chronique Vivante | Anciens | 4 | 80 | Voit 3 prochaines cartes (pas juste 1) |
| Eternite du Dolmen | Anciens | 5 | 120 | Survit a la mort 1×/run (revive a 10 PV) |
| Doigts de Fee | Korrigans | 1 | 20 | +3 Anam par run |
| Rire du Farfadet | Korrigans | 2 | 25 | 15% chance annuler echec minigame (re-roll) |
| Marche aux Ombres | Korrigans | 3 | 50 | Options cachees revelees (4eme option rare) |
| Pacte Malicieux | Korrigans | 4 | 80 | Inverse 1 effet negatif → positif (1×/run) |
| Tresor du Tertre | Korrigans | 5 | 120 | Anam ×2 en fin de run |
| Douceur de Niamh | Niamh | 1 | 20 | +5 PV par reussite critique (score 95-100) |
| Charme Diplomatique | Niamh | 2 | 25 | +10% gains reputation faction |
| Voile d'Oubli | Niamh | 3 | 50 | -50% pertes reputation |
| Quatrieme Voie | Niamh | 4 | 80 | +1 option par carte (3→4 choix) |
| Source Eternelle | Niamh | 5 | 120 | +2 PV regeneration passive toutes les 5 cartes |
| Marche avec l'Ombre | Ankou | 1 | 20 | Annule drain vie (drain = 0) |
| Regard Sombre | Ankou | 2 | 25 | +15% score minigames "esprit" |
| Pacte Sanglant | Ankou | 3 | 50 | Sacrifie 10 PV → +20 Anam (1×/run) |
| Prescience Funebre | Ankou | 4 | 80 | Voit theme ET effets de la prochaine carte |
| Recolte Sombre | Ankou | 5 | 120 | +50% Anam si PV <= 25 en fin de run |
| Coeur Fortifie | Central | 1 | 20 | +10 PV max (100→110) |
| Flux Accelere | Central | 2 | 25 | -1 cooldown global oghams |
| Oeil de Merlin | Central | 3 | 50 | Affiche karma + tension dans le HUD |
| Maitrise Universelle | Central | 4 | 80 | +10% score minigames global |

### Talents speciaux (cross-faction)

| Talent | Cout | Prerequis | Effet |
|--------|------|-----------|-------|
| Calendrier des Brumes | 30 | central_1 | Revele 7 prochains evenements calendaire |
| Harmonie Factions | 60 | druides_1 + anciens_1 + korrigans_1 | +5 Anam/run si toutes factions >= 50 |
| Pacte Ombre-Lumiere | 60 | niamh_1 + ankou_1 | Inverse heal/damage 1×/run |
| Eveil Ogham | 35 | druides_1 | Equipe 2 Oghams (1→2) |
| Instinct Sauvage | 35 | korrigans_1 + anciens_1 | 1 retry minigame gratuit/run |
| Boucle Eternelle | 150 | central_4 + harmonie | NG+: ×1.5 Anam/run |

---

## 11. DIFFICULTE ADAPTATIVE & PITY SYSTEM

### Skill joueur (0.0 - 1.0)
```gdscript
player_skill := 0.5    # novice=0, maitre=1
MIN_SKILL_FACTOR := 0.6
MAX_SKILL_FACTOR := 1.4
skill_factor = lerp(0.6, 1.4, player_skill)
```

### Tiers d'experience

| Tier | Runs | Skill cap |
|------|------|-----------|
| INITIATE | 0-5 | max 0.4 |
| APPRENTICE | 6-20 | 0.3-0.6 |
| JOURNEYER | 21-50 | libre |
| ADEPT | 51-100 | libre |
| MASTER | 100+ | min 0.7 |

### Scaling des effets par skill
```
Pour effets NEGATIFS: amount × skill_factor
    Novice (0.0): amount × 0.6 (40% reduction)
    Expert (1.0): amount × 1.4 (40% amplification)

Pour effets POSITIFS: amount × (2.0 - skill_factor)
    Novice (0.0): amount × 1.4 (40% bonus)
    Expert (1.0): amount × 0.6 (40% reduction)
```

### Pity System

| Condition | Declencheur | Effet |
|-----------|-------------|-------|
| Pity mode | 3 morts consecutives | Active pendant 10 cartes |
| Pity effects | Pendant pity | Negatifs ×0.6, Positifs ×1.4 |
| Quick death | Mort avant carte 20 | Incremente consecutive_deaths |
| Mercy factor | consecutive_deaths > 0 | Negatifs × max(0.5, 1.0 - deaths×0.1) |

### Mode crise
```
Declencheurs:
    - Vie < 20
    - 2+ factions avec |delta| > 15
    - jauges < 15 ou > 85

Effets en crise:
    - Negatifs × 0.5 (moitie)
    - Positifs × 1.5 (bonus recovery)
```

### Filtrage de cartes dangereuses
```
Si pity_mode OU consecutive_deaths > 0:
    Cartes avec max_negative > 20: poids × 0.3

Si mode crise + carte recovery:
    poids × 2.5

Si novice (skill < 0.3) + carte complexe:
    poids × 0.5
```

### Score de complexite d'une carte
```
complexity = 0
if options >= 3: +0.3
if total_effects > 0: +min(0.4, effects × 0.1)
if has_tag("promise"): +0.2
if has_tag("arc"): +0.1
```

---

## 12. PONDERATION DES EVENEMENTS — 7 FACTEURS

### Formule
```
w_final = clamp(
    w_base × f_skill × f_pity × f_crisis × f_conditions × f_fatigue × f_season × f_date,
    0.0,
    3.0
)
```

### Detail des 7 facteurs

#### f_skill — Adaptation au niveau
```
f_skill = lerp(1.2, 0.9, player_skill)
Novice → 1.2 (evenements plus frequents)
Expert → 0.9 (evenements plus rares)
```

#### f_pity — Compensation apres echecs
```
Si pity_mode: 1.5
Si consecutive_deaths > 0: 1.0 + (deaths × 0.1)
Sinon: 1.0
```

#### f_crisis — Recuperation en urgence
```
extreme_count = 0
Pour chaque faction: si |delta| > 15 → extreme_count++
Si vie < 20: extreme_count++

extreme_count >= 2: 1.5
extreme_count == 1: 1.2
sinon: 1.0
```

#### f_conditions — Eligibilite binaire
```
Verifie: min_run_index, min_cards_played, hidden_flag,
         flags_required, reputation thresholds,
         life thresholds, season, karma, tension,
         dominant_faction, trust_merlin, min_endings_seen

Toutes conditions OK → 1.0
Au moins 1 condition KO → 0.0 (evenement bloque)
```

#### f_fatigue — Anti-repetition
```
FATIGUE_PENALTY_PER_REPEAT := 0.15
FATIGUE_HISTORY_WINDOW := 10

penalty = 0.0
Pour chaque event des 10 derniers:
    Si meme event_id: penalty += 0.30
    Si meme categorie: penalty += 0.075

f_fatigue = max(0.1, 1.0 - penalty)
```

#### f_season — Coherence saisonniere
```
Si saison correspond au tag event: 1.15
Si saison opposee: 0.85
Sinon: 1.0
```

#### f_date — Proximite de date
```
DATE_PROXIMITY_BONUS_DAYS := 7
DATE_PROXIMITY_MAX_BONUS := 1.4

Si diff <= 7 jours:
    t = 1.0 - (diff / 7.0)
    f_date = lerp(1.0, 1.4, t)
Sinon: 1.0
```

---

## 13. TAXONOMIE D'EVENEMENTS & FREQUENCE

### 9 Categories

| Categorie | Poids base | Sous-types |
|-----------|------------|------------|
| Rencontre | 0.30 | voyageur, creature, autochtone, revenant, messager |
| Dilemme | 0.20 | sacrifice, loyaute, verite, survie |
| Decouverte | 0.12 | lieu, objet, savoir, passage |
| Conflit | 0.08 | interpersonnel, faction, interieur |
| Merveille | 0.08 | vision, manifestation, don, transformation |
| Epreuve | 0.07 | physique, mentale, rituelle, sociale |
| Catastrophe | 0.05 | naturelle, surnaturelle, humaine |
| Commerce | 0.05 | troc, marche_noir, pacte, offrande |
| Repos | 0.05 | halte, festin, reve_lucide, meditation |

### Matrice de frequence par etat

| Etat | Condition | Modificateurs |
|------|-----------|---------------|
| debut_run | 0-8 cartes | Decouvertes ×1.70, Repos ×1.50 |
| milieu_run | 9-20 cartes | Dilemmes ×1.20, Epreuves ×1.30 |
| fin_run | 21+ cartes | Catastrophes ×1.0, Epreuves ×1.50 |
| jauges_stables | vie > 50 | Decouvertes ×1.35, Merveilles ×1.20 |
| jauges_critiques | vie < 30 OU tension > 50 | **Merveilles ×2.50**, Repos ×1.80 |

### Anti-repetition
```
min_gap_same_category := 2    # Au moins 2 events entre meme categorie
min_gap_same_subtype  := 4    # Au moins 4 events entre meme sous-type
```

---

## 14. PERIODES IN-GAME & BONUS FACTIONS

### Periodes (basees sur cards_played, PAS le temps reel)

| Periode | Cartes | Factions favorisees | Bonus rep |
|---------|--------|--------------------|-----------|
| Aube | 1-5 | Druides | +10% |
| Jour | 6-10 | Anciens, Niamh | +10% |
| Crepuscule | 11-15 | Korrigans | +10% |
| Nuit | 16-20 | **Ankou** | **+15%** (le plus fort) |

### Application
```
Si faction dans la periode courante:
    reputation_gain = raw_gain × (1 + bonus)
    Exemple: +10 rep Druides a l'Aube = 10 × 1.10 = 11
```

---

## 15. BIOMES — EFFETS PASSIFS & DEVERROUILLAGE

### Effets passifs (triggers automatiques)

| Biome | Frequence | Faction affectee | Direction | Effet |
|-------|-----------|-----------------|-----------|-------|
| Foret Broceliande | /5 cartes | Korrigans | UP | Rep +5 ou Heal +5 |
| Landes Bruyere | /6 cartes | Anciens | DOWN | Rep -5 ou Damage +5 |
| Cotes Sauvages | /5 cartes | Niamh | UP | Rep +5 ou Heal +5 |
| Villages Celtes | /4 cartes | Druides | UP | Rep +5 ou Heal +5 |
| Cercles Pierres | /4 cartes | Druides | UP | Rep +5 ou Heal +5 |
| Marais Korrigans | /5 cartes | Korrigans | DOWN | Rep -5 ou Damage +5 |
| Collines Dolmens | /7 cartes | RANDOM | RANDOM | Rep ±5 ou Heal/Damage ±5 |
| Iles Mystiques | /4 cartes | Niamh | RANDOM | Rep ±5 |

### Intervalle de cartes par run (nombre de cartes dans le biome)

| Biome | Min | Max |
|-------|-----|-----|
| Foret Broceliande | 12 | 15 |
| Landes Bruyere | 12 | 15 |
| Cotes Sauvages | 12 | 15 |
| Villages Celtes | 10 | 14 |
| Cercles Pierres | 10 | 14 |
| Marais Korrigans | 10 | 14 |
| Collines Dolmens | 8 | 12 |
| Iles Mystiques | 8 | 12 |

### Conditions de deverrouillage

| Biome | Condition | Seuil maturite |
|-------|-----------|---------------|
| Foret Broceliande | Toujours disponible | 0 |
| Landes Bruyere | 2+ runs | 15 |
| Cotes Sauvages | 3+ runs | 15 |
| Villages Celtes | 5+ runs | 25 |
| Cercles Pierres | 8+ runs, 2+ fins | 30 |
| Marais Korrigans | 10+ runs, fin "harmonie" | 40 |
| Collines Dolmens | 15+ runs, 5+ fins | 50 |
| Iles Mystiques | 20+ runs, 5+ fins, fin "transcendance" | 75 |

---

## 16. MATURITE JOUEUR — SCORE & SEUILS

### Formule de maturite
```
score = (total_runs × 2)
      + (fins_vues × 5)
      + (oghams_debloques × 3)
      + (MAX_faction_rep × 1)
```

**Note**: Seule la PLUS HAUTE reputation faction est prise en compte (pas la somme). Cela encourage la specialisation.

### Poids

| Composante | Poids | Rationale |
|-----------|-------|-----------|
| total_runs | ×2 | Experience de jeu |
| fins_vues | ×5 | Le plus valorise — recompense l'exploration |
| oghams_debloques | ×3 | Progression systeme |
| max_faction_rep | ×1 | Investissement narratif |

### Exemple
```
10 runs, 3 fins, 8 oghams, faction max = 65
Score = (10×2) + (3×5) + (8×3) + (65×1) = 20 + 15 + 24 + 65 = 124
→ Tous biomes debloques (seuil max = 75)
```

---

## 17. MOS — CONVERGENCE & GUARDRAILS

### Parametres de convergence (duree de run)

| Parametre | Valeur | Role |
|-----------|--------|------|
| soft_min_cards | 8 | Run ne devrait pas finir avant |
| target_cards_min | 20 | Duree ideale minimum |
| target_cards_max | 25 | Duree ideale maximum |
| soft_max_cards | 40 | Alerte run trop long |
| hard_max_cards | 50 | **Fin forcee** |
| max_active_promises | 2 | Max promesses simultanees |

### Guardrails LLM

| Guardrail | Valeur | Action |
|-----------|--------|--------|
| Min longueur texte | 30 chars | Rejeter + re-generer |
| Max longueur texte | 800 chars | Tronquer |
| Mots-cles francais requis | 2+ parmi [le, la, de, un, une, du, les, des, en, et] | Rejeter si pas assez francais |
| Similarite repetition | > 50% avec les 15 derniers textes | Rejeter |
| Mots interdits persona | 19 mots (ia, algorithme, token...) | Rejeter |

### Seuils de danger (vie)

| Seuil | Valeur | Comportement MOS |
|-------|--------|-----------------|
| DANGER_LIFE_CRITICAL | 15 | **Bloque** les evenements catastrophe |
| DANGER_LIFE_LOW | 25 | Reduit la difficulte automatiquement |
| DANGER_LIFE_WOUNDED | 50 | Signale au LLM (contexte prompt) |

### Prefetch
```
_prefetch_depth: 1 (legacy) ou 2-3 (swarm mode)
Buffer max: 3 cartes pre-generees
LLM_TIMEOUT_MS: 300000 (5 min, genereux pour cold start)
MAX_RETRIES: 2
```

---

## 18. PIPELINE DE RESOLUTION D'UNE CARTE (14 ETAPES)

```
Etape 1:  AFFICHAGE — Carte affichee avec illustration + texte narratif
Etape 2:  OGHAM CHECK — Si ogham equipe et disponible (cooldown=0), proposer activation
Etape 3:  OGHAM ACTIVATION — Si active: appliquer effet (reveal, protect, heal, etc.)
Etape 4:  CHOIX — Joueur selectionne une option (A, B, ou C)
Etape 5:  FIELD DETECTION — Detecter le champ lexical de l'option (verb → field)
Etape 6:  MINIGAME SELECT — Choisir le minigame selon le field (sauf merlin_direct: skip 6-8)
Etape 7:  MINIGAME PLAY — Joueur joue le minigame overlay
Etape 8:  SCORE → MULTIPLIER — Convertir score (0-100) en multiplicateur via table
Etape 9:  SCALE EFFECTS — Multiplier chaque effet par le multiplicateur + caps
Etape 10: PROTECTION CHECK — Luis/Gort/Eadhadh annulent/reduisent les negatifs
Etape 11: APPLY EFFECTS — Appliquer vie, reputation, karma, tension, monnaie
Etape 12: LIFE CHECK — Si vie <= 0: run terminee (mort)
Etape 13: PROMISE CHECK — Evaluer promesses actives (deadline atteinte?)
Etape 14: COOLDOWN TICK — Reduire cooldown de tous les oghams de 1
```

### Drain passif (entre etape 14 et carte suivante)
```
vie -= DRAIN_PER_CARD (1)
vie -= talent_reduction (druides_5: -2, ankou_1: -1)
vie = max(0, vie)
```

---

## 19. GENERATION DE CARTES — SELECTION & FALLBACK

### Pipeline de generation
```
1. Determiner le type de carte (poids):
   - narrative: 80%
   - event: 10% (seulement apres carte 3+)
   - promise: 5% (seulement apres carte 5+, max 2 actives)
   - merlin_direct: 5%

2. Si event/promise/merlin_direct: piocher dans le pool JSON

3. Si narrative:
   a. ESSAYER LLM (await _llm.generate_card(context))
   b. Si LLM echoue OU retourne invalide: FALLBACK FastRoute
   c. Toujours garantir 3 options (_ensure_3_options)
   d. Annoter les champs lexicaux par option (_annotate_fields)
```

### FastRoute (fallback pre-genere)
```
- 15 cartes narratives (biome-specifiques + generiques)
- 4 cartes merlin_direct (gatees par trust tier)
- Priorite biome (+4.0 boost de poids)
- Tracking _fastroute_seen pour eviter repetitions
- Pool epuise → reset et recycler
```

### Carte merlin_direct
```
- Pas de minigame (skip etapes 6-8)
- Multiplicateur fixe = 1.0
- Gatee par trust_tier (T0: conseil/warning, T1: secret, T2: gift)
```

---

## 20. SYSTEME DE DECK & PROGRESSION DE RUN

### Pas de "deck" traditionnel
- Cartes generees a la demande (LLM ou fallback)
- Pre-buffer de 5 cartes (genere pendant TransitionBiome)
- 30% chance de carte "sequel" si buffer epuise et prerun choices existent

### Etat de run initialise
```gdscript
{
    "biome": biome_id,
    "card_index": 0,
    "cards_played": 0,
    "life_essence": 100,
    "life_max": 100,
    "biome_currency": 0,
    "equipped_oghams": ["beith"],
    "cooldowns": {},
    "active_promises": [],
    "promise_tracking": {},
    "story_log": [],
    "active_tags": [],
    "minigame_wins_this_run": 0,
    "total_healing_this_run": 0,
    "damage_taken_this_run": 0,
    "period": "aube",
    "buffs": [],
    "events_log": [],
    "faction_rep_delta": {},
    "trust_delta": 0,
}
```

### Story log (par carte jouee)
```gdscript
{
    "card_id": "card_001",
    "option_index": 1,
    "score": 85,
    "multiplier": 1.0,
    "effects_count": 2,
}
```

---

## 21. FINS DE RUN — CONDITIONS & CALCULS

### 3 conditions de fin

| Condition | Declencheur | Type |
|-----------|-------------|------|
| Mort | vie <= 0 | Non-victoire |
| Hard max | cards_played >= 50 | Fin forcee |
| Mission complete | mission.progress >= mission.total ET cards >= 25 | Victoire |

### Types de victoire (determines par karma)

| Karma | Type | Description |
|-------|------|-------------|
| >= +5 | harmonie | Fin positive, monde en equilibre |
| <= -5 | victoire_amere | Objectif atteint mais a quel prix |
| -4 a +4 | prix_paye | Neutre, prix paye |

### Ecran fin de run (4 phases)
```
Phase 1: Texte narratif (LLM ou fallback selon raison)
Phase 2: Carte du voyage (timeline cartes jouees)
Phase 3: Bilan recompenses (Anam, deltas rep, trust, promesses)
Phase 4: Choix faction (optionnel, si 2+ factions >= 80)
```

### Score de run
```
Mort: cards_played × 10
Victoire: cards_played × 20
```

---

## 22. NARRATIVE SCALER — CONTENU GATE PAR EXPERIENCE

### Fonctionnalites par tier

| Feature | INITIATE (0-5) | APPRENTICE (6-20) | JOURNEYER (21-50) | ADEPT (51-100) | MASTER (100+) |
|---------|---------------|-------------------|-------------------|----------------|--------------|
| max_arc_length | 0 | 2 | 5 | 7 | 10 |
| max_active_arcs | 0 | 1 | 2 | 2 | 3 |
| foreshadowing | non | non | oui | oui | oui |
| twist_probability | 0% | 5% | 10% | 15% | 20% |
| lore_frequency | 0% | 2% | 5% | 8% | 12% |
| merlin_comments_depth | 1 | 2 | 3 | 4 | 5 |

### Gates de contenu

| Contenu | Tier requis |
|---------|-------------|
| Cartes promesse | APPRENTICE (6+) |
| Arcs personnages | JOURNEYER (21+) |
| Cartes faction | JOURNEYER (21+) |
| Lore profond | ADEPT (51+) |
| Chemin fin secrete | MASTER (100+) |
| Revelation Merlin | MASTER (1000+, easter egg) |

---

## 23. SESSION REGISTRY — BIEN-ETRE JOUEUR

### Seuils de detection

| Parametre | Valeur | Effet |
|-----------|--------|-------|
| RUSHED_DECISION_MS | 1000ms | Decision < 1s = pressee |
| CONTEMPLATED_DECISION_MS | 10000ms | Decision > 10s = contemplative |
| FRUSTRATION_THRESHOLD | 3 morts rapides | Declenche pity mode |
| LONG_SESSION_MINUTES | 90 min | Alerte session longue |
| BREAK_SUGGEST_MINUTES | 60 min | Suggestion de pause |
| FATIGUE_SLOWDOWN_FACTOR | 1.5× | Decision 50% plus lente = fatigue |
| TILT_DEATH_THRESHOLD | 3 morts consecutives | Detection de tilt |

### Niveaux d'engagement
```
LOW:       Lecture lente, skip dialogues, faible interaction
MEDIUM:    Engagement normal
HIGH:      Decisions rapides, utilisation active oghams
VERY_HIGH: Engagement constant, etat de flow
```

---

## 24. RNG — GENERATEUR PSEUDO-ALEATOIRE

### Implementation (LCG custom)
```gdscript
func randf() -> float:
    _state = (_state + 0x6D2B79F5) & 0x7fffffff
    var t = _state
    t = (t ^ (t >> 15)) * (1 | _state)
    t = (t + ((t ^ (t >> 7)) * (61 | t))) ^ t
    return float((t ^ (t >> 14)) & 0x7fffffff) / float(0x7fffffff)
```

### Fonctions derivees
```gdscript
randf_range(min, max) → lerp(min, max, randf())
randi_range(min, max) → min + int(randf() * (max - min + 1))
rand_bool(chance=0.5)  → randf() <= clamp(chance, 0.0, 1.0)
```

### Seed: configurable via `set_seed()` pour runs reproductibles

---

## 25. PHASES LUNAIRES

### 8 Phases

| Phase | Puissance |
|-------|-----------|
| NEW_MOON | 0.0 |
| WAXING_CRESCENT | 0.14 |
| FIRST_QUARTER | 0.28 |
| WAXING_GIBBOUS | 0.42 |
| FULL_MOON | 1.0 |
| WANING_GIBBOUS | 0.42 |
| LAST_QUARTER | 0.28 |
| WANING_CRESCENT | 0.14 |

### Impact gameplay
- **CONS_LUNE_SANG**: requiert FULL_MOON + tension > 40
- Puissance lunaire affecte le poids de certains evenements secrets
- Affichage UI dans le calendrier

---

## 26. POWER MILESTONES — PALIERS DE PUISSANCE

### Bonus automatiques toutes les 5 cartes

| Carte | Type | Valeur | Label | Description |
|-------|------|--------|-------|-------------|
| 5 | HEAL | +15 | Vigueur retrouvee | +15 Vie |
| 10 | MINIGAME_BONUS | +5% | Instinct aiguise | +5% score minigames |
| 15 | HEAL | +10 | Souffle du druide | +10 Vie |
| 20 | HEAL | +20 | Benediction ancienne | +20 Vie |

Ces milestones s'appliquent AUTOMATIQUEMENT sans action du joueur.

---

## 27. PROFIL JOUEUR — 6 TRAITS COMPORTEMENTAUX

### Traits (0.0 - 1.0)

| Trait | Pole 0.0 | Pole 1.0 |
|-------|---------|---------|
| aggression | Prudent | Temeraire |
| altruism | Egoiste | Altruiste |
| curiosity | Pragmatique | Explorateur |
| patience | Impulsif | Methodique |
| trust_merlin | Mefiant | Confiant |
| risk_tolerance | Risquophobe | Risquophile |

### Taux d'apprentissage
```gdscript
TRAIT_LEARNING_RATE   := 0.05    # Vitesse d'evolution des traits
SKILL_LEARNING_RATE   := 0.03    # Vitesse d'evolution du skill
PREFERENCE_THRESHOLD  := 3       # Occurrences avant detection
DECAY_RATE           := 0.995    # Retour lent vers 0.5 par session
```

---

## 28. CHAMPS LEXICAUX — DETECTION & MAPPING MINIGAMES

### 8 Champs et leurs verbes (45 verbes total)

| Champ | Verbes |
|-------|--------|
| chance | cueillir, chercher au hasard, tenter sa chance, deviner |
| bluff | marchander, convaincre, mentir, negocier, charmer, amadouer |
| observation | observer, scruter, memoriser, examiner, fixer, inspecter |
| logique | dechiffrer, analyser, resoudre, decoder, interpreter, etudier |
| finesse | se faufiler, esquiver, contourner, se cacher, escalader, traverser |
| vigueur | combattre, courir, fuir, forcer, pousser, resister physiquement |
| esprit | calmer, apaiser, mediter, resister mentalement, se concentrer, endurer, parler, accepter, refuser, attendre, s'approcher |
| perception | ecouter, suivre, pister, sentir, flairer, tendre l'oreille |

### Mapping champ → minigames

| Champ | Minigames possibles |
|-------|--------------------|
| chance | herboristerie |
| bluff | negociation |
| observation | fouille, regard |
| logique | runes |
| finesse | ombres, equilibre |
| vigueur | combat_rituel, course |
| esprit | apaisement, volonte, sang_froid |
| perception | traces, echo |

### Detection
```
1. Extraire le verbe de l'option (champ "verb")
2. Chercher dans ACTION_VERBS → champ lexical
3. Si pas trouve: fallback = "esprit"
4. Depuis le champ: choisir un minigame aleatoire dans la liste
```

---

## 29. SAUVEGARDE — STRUCTURE CROSS-RUN VS INTRA-RUN

### Profil (persiste entre runs)
```gdscript
{
    "anam": int,                          # Monnaie cross-run
    "total_runs": int,
    "faction_rep": {                      # 5 factions, 0-100 chacune
        "druides": float, "anciens": float,
        "korrigans": float, "niamh": float, "ankou": float
    },
    "trust_merlin": int,                  # 0-100
    "talent_tree": {"unlocked": [str]},   # IDs de noeuds debloques
    "oghams": {
        "owned": [str],                   # Oghams possedes
        "equipped": str                   # Ogham equipe actuel
    },
    "endings_seen": [str],                # Fins debloquees
    "arc_tags": [str],                    # Tags narratifs vus
    "biome_runs": {str: int},             # Runs par biome
    "stats": {
        "total_cards": int,
        "total_minigames_won": int,
        "total_deaths": int,
        "consecutive_deaths": int,
        "total_anam_earned": int,
    },
}
```

### Run (reinitialise a chaque nouveau run)
```gdscript
{
    "biome": str,
    "card_index": int,
    "life_essence": 100,
    "life_max": 100,
    "biome_currency": 0,
    "equipped_oghams": [str],
    "cooldowns": {},
    "active_promises": [],
    "story_log": [],
    "period": "aube",
    "faction_rep_delta": {},
    "trust_delta": 0,
    "hidden": {
        "karma": 0,
        "tension": 0,
        "player_profile": {},
    },
}
```

### Ce qui persiste
- Anam, faction_rep, trust, talents, oghams, fins, stats
- biome_runs, arc_tags

### Ce qui est reinitialise
- Vie (→100), cooldowns (→0), periode (→aube)
- Deltas reputation/trust (→0), karma/tension (→0)
- Promesses, buffs, story_log

---

## 30. ANNEXE — TABLE DE REFERENCE DES CONSTANTES

### Vie
| Constante | Valeur |
|-----------|--------|
| LIFE_MAX | 100 |
| LIFE_START | 100 |
| DRAIN_PER_CARD | 1 |
| CRIT_FAIL_DAMAGE | 10 |
| CRIT_SUCCESS_HEAL | 5 |
| HEAL_PER_REST | 18 |
| LOW_THRESHOLD | 25 |
| EVENT_FAIL_DAMAGE | 6 |

### Factions
| Constante | Valeur |
|-----------|--------|
| SCORE_MIN | 0 |
| SCORE_MAX | 100 |
| SCORE_START | 10 |
| THRESHOLD_CONTENT | 50 |
| THRESHOLD_ENDING | 80 |
| DELTA_MINOR | 5 |
| DELTA_MAJOR | 15 |
| DELTA_EXTREME | 30 |

### Anam
| Constante | Valeur |
|-----------|--------|
| BASE_REWARD | 10 |
| VICTORY_BONUS | 15 |
| PER_MINIGAME | 2 |
| PER_OGHAM | 1 |
| FACTION_HONORE | 5 |
| DEATH_CAP_CARDS | 30 |

### Trust
| Constante | Valeur |
|-----------|--------|
| T0 range | 0-24 |
| T1 range | 25-49 |
| T2 range | 50-74 |
| T3 range | 75-100 |
| PROMISE_KEPT | +10 |
| PROMISE_BROKEN | -15 |
| COURAGEOUS_MIN | +3 |
| COURAGEOUS_MAX | +5 |
| SELFISH_MIN | -5 |
| SELFISH_MAX | -3 |

### MOS Convergence
| Constante | Valeur |
|-----------|--------|
| SOFT_MIN_CARDS | 8 |
| TARGET_MIN | 20 |
| TARGET_MAX | 25 |
| SOFT_MAX | 40 |
| HARD_MAX | 50 |
| MAX_PROMISES | 2 |

### Difficulte
| Constante | Valeur |
|-----------|--------|
| MIN_SKILL_FACTOR | 0.6 |
| MAX_SKILL_FACTOR | 1.4 |
| PITY_THRESHOLD | 3 morts |
| PITY_DURATION | 10 cartes |
| QUICK_DEATH | 20 cartes |
| MERCY_FLOOR | 0.5 |

### Events
| Constante | Valeur |
|-----------|--------|
| W_MIN | 0.0 |
| W_MAX | 3.0 |
| FATIGUE_PENALTY | 0.15 |
| FATIGUE_WINDOW | 10 |
| DATE_PROXIMITY_DAYS | 7 |
| DATE_PROXIMITY_MAX | 1.4 |

### Guardrails LLM
| Constante | Valeur |
|-----------|--------|
| MIN_TEXT_LEN | 30 |
| MAX_TEXT_LEN | 800 |
| FRENCH_KEYWORDS_MIN | 2 |
| REPETITION_THRESHOLD | 50% |
| RECENT_CARDS_MEMORY | 15 |
| LLM_TIMEOUT | 300 000ms |
| MAX_RETRIES | 2 |

### Session
| Constante | Valeur |
|-----------|--------|
| RUSHED_MS | 1000 |
| CONTEMPLATED_MS | 10000 |
| FRUSTRATION_DEATHS | 3 |
| LONG_SESSION | 90 min |
| BREAK_SUGGEST | 60 min |
| FATIGUE_SLOWDOWN | 1.5× |

### Maturite
| Composante | Poids |
|-----------|-------|
| total_runs | ×2 |
| fins_vues | ×5 |
| oghams_debloques | ×3 |
| max_faction_rep | ×1 |

### Narrative Scaler
| Tier | Runs | twist_prob | lore_freq |
|------|------|-----------|-----------|
| INITIATE | 0-5 | 0% | 0% |
| APPRENTICE | 6-20 | 5% | 2% |
| JOURNEYER | 21-50 | 10% | 5% |
| ADEPT | 51-100 | 15% | 8% |
| MASTER | 100+ | 20% | 12% |

### Profil joueur
| Constante | Valeur |
|-----------|--------|
| TRAIT_LEARNING_RATE | 0.05 |
| SKILL_LEARNING_RATE | 0.03 |
| PREFERENCE_THRESHOLD | 3 |
| DECAY_RATE | 0.995 |

---

---

## 31. Anam Reward Calculation — Formule Complete

### 31.1 Formule de Base

```
anam = 10 (base)
     + 15 (victory_bonus, si victoire)
     + minigames_won x 2 (score >= 80)
     + oghams_used x 1 (chaque ogham active)
     + factions_honored x 5 (chaque faction >= 80 rep)
```

### 31.2 Ratio Mort

```
Si NON-VICTOIRE (mort/abort):
    ratio = min(cards_played / 30, 1.0)
    anam = int(anam x ratio)
```

### 31.3 Talent Modifiers (post-calcul)

| Talent | Effet |
|--------|-------|
| korrigans_5 (Tresor du Tertre) | x2.0 Anam final |
| korrigans_1 (Doigts de Fee) | +3 Anam flat |
| ankou_5 (Recolte Sombre) | x1.5 si vie <= 25 a la fin |
| boucle_eternelle (NG+) | x1.5 Anam par run |

### 31.4 Exemple Worked

**Victoire, 28 cartes, 5 minigames, 2 oghams, 1 faction honoree, talent korrigans_1:**
```
base = 10 + 15 + (5x2) + (2x1) + (1x5) = 42
+ korrigans_1 bonus = 42 + 3 = 45 Anam
```

---

## 32. Talent Tree — 34 Noeuds Complets

### 32.1 Branche DRUIDES (5 noeuds — Nature/Soin/Rituel)

| ID | Nom | Cout | Prereq | Effet Mecanique |
|----|-----|------|--------|----------------|
| druides_1 | Vigueur du Chene | 20 | — | +10 vie au debut du run |
| druides_2 | Symbiose Vegetale | 25 | druides_1 | -1 cooldown categorie nature |
| druides_3 | Esprit du Nemeton | 50 | druides_2 | +15% score minigames logique |
| druides_4 | Guerison Profonde | 80 | druides_3 | x2 multiplicateur soin Recovery Oghams |
| druides_5 | Racine Celeste | 120 | druides_4 | Drain reduction (1→0 par carte) |

### 32.2 Branche ANCIENS (5 noeuds — Sagesse/Tradition)

| ID | Nom | Cout | Prereq | Effet Mecanique |
|----|-----|------|--------|----------------|
| anciens_1 | Clairvoyance | 20 | — | Revele 1 effet cache par carte |
| anciens_2 | Sagesse Accumulee | 25 | anciens_1 | +5% score global minigames |
| anciens_3 | Troisieme Oeil | 50 | anciens_2 | Predit le theme de la prochaine carte |
| anciens_4 | Bouclier Ancestral | 80 | anciens_3 | Annule 1 source de degats par run |
| anciens_5 | Immortalite du Souvenir | 120 | anciens_4 | Survit a la mort 1x/run (revive a 10 PV) |

### 32.3 Branche KORRIGANS (5 noeuds — Chaos/Fortune)

| ID | Nom | Cout | Prereq | Effet Mecanique |
|----|-----|------|--------|----------------|
| korrigans_1 | Doigts de Fee | 20 | — | +3 Anam par run complete |
| korrigans_2 | Chance du Lutin | 25 | korrigans_1 | +10% score minigame champ chance |
| korrigans_3 | Miroir Inverseur | 50 | korrigans_2 | Inverse 1 effet negatif en positif par run |
| korrigans_4 | Rythme du Chaos | 80 | korrigans_3 | -1 cooldown global Oghams |
| korrigans_5 | Tresor du Tertre | 120 | korrigans_4 | x2 Anam rewards fin de run |

### 32.4 Branche NIAMH (5 noeuds — Amour/Diplomatie)

| ID | Nom | Cout | Prereq | Effet Mecanique |
|----|-----|------|--------|----------------|
| niamh_1 | Douceur de Niamh | 20 | — | +5 vie sur chaque succes critique |
| niamh_2 | Charme Diplomatique | 25 | niamh_1 | +10% gains reputation toutes factions |
| niamh_3 | Voile d'Oubli | 50 | niamh_2 | -50% pertes reputation |
| niamh_4 | Quatrieme Voie | 80 | niamh_3 | +1 option par carte (3→4 choix) |
| niamh_5 | Source Eternelle | 120 | niamh_4 | +2 PV passif toutes les 5 cartes |

### 32.5 Branche ANKOU (5 noeuds — Mort/Sacrifice)

| ID | Nom | Cout | Prereq | Effet Mecanique |
|----|-----|------|--------|----------------|
| ankou_1 | Marche avec l'Ombre | 20 | — | Drain reduction (1→0 par carte) |
| ankou_2 | Regard Sombre | 25 | ankou_1 | +15% score minigame champ esprit |
| ankou_3 | Pacte Sanglant | 50 | ankou_2 | Sacrifice 10 PV → gain 20 Anam (1x/run) |
| ankou_4 | Prescience Funebre | 80 | ankou_3 | Voit la prochaine carte (theme + effets) |
| ankou_5 | Recolte Sombre | 120 | ankou_4 | +50% Anam si vie <= 25 en fin de run |

### 32.6 Branche CENTRAL (4 noeuds — Universel)

| ID | Nom | Cout | Prereq | Effet Mecanique |
|----|-----|------|--------|----------------|
| central_1 | Coeur Fortifie | 20 | — | +10 vie max (100→110) |
| central_2 | Flux Accelere | 25 | central_1 | -1 cooldown global Oghams |
| central_3 | Oeil de Merlin | 50 | central_2 | Affiche karma + tension dans le HUD |
| central_4 | Maitrise Universelle | 80 | central_3 | +10% score global minigames |

### 32.7 Noeuds SPECIAUX Cross-Faction (6)

| ID | Nom | Cout | Prereq | Effet |
|----|-----|------|--------|-------|
| calendrier_des_brumes | Calendrier des Brumes | 30 | central_1 | Revele 7 prochains events + bonus |
| harmonie_factions | Harmonie des Factions | 60 | druides_1+anciens_1+korrigans_1 | +5 Anam/run si toutes factions >= 50 |
| pacte_ombre_lumiere | Pacte Ombre-Lumiere | 60 | niamh_1+ankou_1 | Inverse soin/degats 1x/run |
| eveil_ogham | Eveil d'Ogham | 35 | druides_1 | Equipe 2 Oghams simultanement |
| instinct_sauvage | Instinct Sauvage | 35 | korrigans_1+anciens_1 | 1 retry gratuit minigame par run |
| boucle_eternelle | Boucle Eternelle (NG+) | 150 | central_4+harmonie_factions | x1.5 Anam par run |

---

## 33. Ogham Cost & Discount System

### 33.1 Table des Prix

| Ogham | Categorie | Cout Base (Anam) | Cout Reduit (50%) | Starter |
|-------|-----------|-----------------|-------------------|---------|
| beith | Reveal | 0 | — | Oui |
| luis | Protection | 0 | — | Oui |
| quert | Recovery | 0 | — | Oui |
| ailm | Reveal | 60 | 30 | Non |
| duir | Boost | 70 | 35 | Non |
| coll | Reveal | 80 | 40 | Non |
| nuin | Narrative | 80 | 40 | Non |
| onn | Boost | 90 | 45 | Non |
| saille | Recovery | 90 | 45 | Non |
| gort | Protection | 100 | 50 | Non |
| huath | Narrative | 100 | 50 | Non |
| muin | Special | 110 | 55 | Non |
| tinne | Boost | 120 | 60 | Non |
| ruis | Recovery | 130 | 65 | Non |
| straif | Narrative | 140 | 70 | Non |
| ur | Special | 140 | 70 | Non |
| eadhadh | Protection | 150 | 75 | Non |
| ioho | Special | 160 | 80 | Non |

### 33.2 Mecanisme de Reduction

```
Premiere rencontre avec un ogham → 50% discovery discount
apply_ogham_discount(ogham_id) → prix reduit enregistre
Stocke dans: state["meta"]["ogham_discounts"][ogham_id]
```

---

## 34. Maturity Score

### 34.1 Formule

```
score = (total_runs x 2)
      + (endings_seen.size() x 5)
      + (oghams_owned.size() x 3)
      + (max_faction_rep x 1)
```

### 34.2 Poids

| Facteur | Poids |
|---------|-------|
| total_runs | 2 |
| fins_vues | 5 |
| oghams_debloques | 3 |
| max_faction_rep | 1 |

### 34.3 Seuils Biome Unlock

| Biome | Seuil Maturity |
|-------|---------------|
| foret_broceliande | 0 |
| landes_bruyere | 15 |
| cotes_sauvages | 15 |
| villages_celtes | 25 |
| cercles_pierres | 30 |
| marais_korrigans | 40 |
| collines_dolmens | 50 |
| iles_mystiques | 75 |

---

## 35. Trust Merlin — Systeme de Confiance

### 35.1 4 Tiers

| Tier | Score | Label | Contenu Debloque |
|------|-------|-------|-----------------|
| T0 | 0-24 | Cryptique | Commentaires vagues, enigmatiques |
| T1 | 25-49 | Indices | Hints narratifs, allusions |
| T2 | 50-74 | Avertissements | Warnings directs, lore partiel |
| T3 | 75-100 | Secrets | Secrets complets, meta-narrative |

### 35.2 Deltas de Confiance

| Action | Delta Trust |
|--------|------------|
| Promesse tenue | +10 |
| Promesse brisee | -15 |
| Choix courageux | +3 a +5 (random) |
| Choix egoiste | -5 a -3 (random) |

### 35.3 Content Unlocks par Tier

```
T0: md_conseil, md_warning
T1+: md_secret
T2+: md_gift
T3: SECRET_MEMOIRE_MERLIN events + revelations completes
```

---

## 36. Promise System — Mecanique Complete

### 36.1 Structure

```json
{
    "id": "promise_id",
    "description": "text",
    "created_day": day_card_created,
    "deadline_day": created_day + deadline_days,
    "status": "active" | "fulfilled" | "broken",
    "condition_type": "life_above" | "faction_gain" | "minigame_wins" | "no_safe"
}
```

### 36.2 Regles

```
Max simultane: 2 promesses
Min carte: 5 avant premiere promesse
Deadline: en cartes (pas en temps)
```

### 36.3 Resolution

```
A chaque carte: si card_index >= deadline_card:
  Condition remplie → status = "fulfilled", trust += 10
  Condition echouee → status = "broken", trust -= 15, karma -= 15, tension += 10
```

### 36.4 Types de Condition

| Type | Tracking | Exemple |
|------|----------|---------|
| life_above | vie courante >= seuil | Rester au-dessus de 25 PV |
| faction_gain | rep faction augmentee de X | +15 druides rep |
| minigame_wins | score >= 80 X fois | 3 minigames gagnes |
| no_safe | jamais choisi l'option "safe" | Pas de centre prudent |

---

## 37. Ending Classification

### 37.1 3 Types de Victoire (base sur le Karma)

| Karma | Type | Texte |
|-------|------|-------|
| >= +5 | harmonie | "Tu as accompli ta quete avec sagesse et bienveillance." |
| <= -5 | victoire_amere | "Ta quete est accomplie, mais a quel prix..." |
| -4 a +4 | prix_paye | "Tu as reussi, mais la foret se souviendra de tes choix." |

### 37.2 Ending Mort

```
Titre: "Essences Epuisees"
Trigger: vie <= 0
Score: cards_played x 10
```

### 37.3 Ending Victoire

```
Conditions:
  mission_progress >= total
  mission_total > 0
  cards_played >= MIN_CARDS_FOR_VICTORY (25)
Score: cards_played x 20
```

---

## 38. Faction Start-Run Bonuses

### 38.1 Bonus par Tier

| Faction | Honore (rep >= 80) | Hostile (rep 0-4) |
|---------|-------------------|-------------------|
| druides | HEAL +15 | DAMAGE +10 |
| anciens | HEAL +10 | DAMAGE +5 |
| korrigans | HEAL +20 | DAMAGE +10 |
| niamh | HEAL +15 | DAMAGE +5 |
| ankou | HEAL +10 | DAMAGE +15 (pire) |

---

## 39. In-Game Periods & Faction Bonuses

### 39.1 Periodes par Index de Carte

| Periode | Cartes | Faction Boost | Bonus |
|---------|--------|---------------|-------|
| aube | 1-5 | druides | +10% rep |
| jour | 6-10 | anciens, niamh | +10% rep |
| crepuscule | 11-15 | korrigans | +10% rep |
| nuit | 16-20 | ankou | +15% rep |

### 39.2 Formule

```gdscript
get_period_bonus(card_index: int, faction: String) -> float
```

---

## 40. Card Type Distribution Weights

```gdscript
CARD_TYPE_WEIGHTS = {
    "narrative": 0.80,
    "event": 0.10,
    "promise": 0.05,
    "merlin_direct": 0.05,
}
```

---

## 41. Min Card Constraints

```
MIN_CARDS_FOR_VICTORY: 25         # Survie minimum avant victoire possible
MIN_CARDS_BEFORE_EVENT: 3         # Attente avant premier event
MIN_CARDS_BEFORE_PROMISE: 5       # Attente avant premiere promesse
```

---

## 42. Ogham Affinity Bonus (Biome)

```gdscript
get_biome_affinity_bonus(biome_id, ogham_id):
    if biome.oghams_affinity contains ogham_id:
        return {score_bonus: 0.10, cooldown_reduction: 1}
    return {score_bonus: 0.0, cooldown_reduction: 0}
```

### 42.1 Affinites par Biome

| Biome | Oghams Affins |
|-------|--------------|
| foret_broceliande | quert, huath, coll |
| landes_bruyere | luis, onn, saille |
| cotes_sauvages | muin, nuin, tinne |
| villages_celtes | duir, coll, beith |
| cercles_pierres | ioho, straif, ruis |
| marais_korrigans | gort, eadhadh, luis |
| collines_dolmens | quert, ailm, coll |
| iles_mystiques | ailm, ruis, ioho |

---

## 43. LLM Prompt Construction

### 43.1 System Prompt

```
Template scenario-based (si disponible)
Fallback enrichi:
  - Nom biome (formate)
  - Index carte + theme
  - Etat vie/karma
  - Hint convergence (si carte >= 8: "quete approche de la fin")
  - Hint balance (depuis _build_balance_hint)
  - Instructions format
```

### 43.2 User Prompt

```
Hook ouverture (rotates par index carte):
  ["Tu decouvres", "Tu entends", "Tu sens", "Tu apercois",
   "Tu te reveilles", "Tu tombes sur", "Tu fais face a",
   "Tu trebuches sur", "Tu reconnais", "Tu touches"]
   [card_index % 10]

+ Description situation + options A) B) C)
+ Inspiration verbes (3 verbes du pool de phase)
+ Contexte scenario/anchor (si disponible)
+ Enrichissement contextuel (flux, tension, talents)
```

### 43.3 Enrichissement Contextuel

```
Axes flux non-neutres
Niveau tension (haut >= 60, modere >= 40)
Tendance joueur
Top 3 talents actifs
```

### 43.4 Vocabulaire Celtique (50 mots, rotation)

```
nemeton sacre, brume matinale, dolmen ancien, sources enchantees,
korrigans farceurs, cercle de pierres, chene millenaire, sidhe lumineux,
lande sauvage, torque d'or, chaudron de Dagda, harpe de Taliesin, ...
```

### 43.5 Verb Pools par Balance State

| Balance | Pool | Strategie |
|---------|------|-----------|
| Safe (>80 PV) | Escalader, Dechiffrer, Contourner | Exploration, curiosite |
| Fragile (30-80) | Panser, Negocier, Braver | Prudence, dilemme |
| Critical (<30) | Cauteriser, Ramper, Sacrifier | Survie, reparation |

---

## 44. Minigame Probability System

### 44.1 Formule Core

```
base_threshold = 0.5 + (5 - difficulty) * 0.05
threshold = clamp(base_threshold + bonus, 0.05, 0.95)
success = roll <= threshold
score = int(clamp(roll * 100.0, 0.0, 100.0))
time_ms = random(450, 1800)
```

### 44.2 Echelle de Difficulte

```
difficulty 1 → threshold 0.90 (facile)
difficulty 5 → threshold 0.50 (moyen)
difficulty 10 → threshold 0.25 (difficile)
```

### 44.3 Labels de Difficulte

| Label | Couleur | Max Score |
|-------|---------|-----------|
| Facile | Vert | 40 |
| Normal | Jaune | 70 |
| Difficile | Rouge | 100 |

---

## 45. Faveurs System

```
FAVEURS_START: 0
FAVEURS_PER_MINIGAME_WIN: 3    # score >= 80
FAVEURS_PER_MINIGAME_PLAY: 1   # score < 80
```

---

*Document genere et mis a jour le 2026-03-15 (v2.0) par extraction exhaustive du codebase.*
*Sources: merlin_constants.gd, merlin_effect_engine.gd, merlin_reputation_system.gd, merlin_store.gd, merlin_card_system.gd, merlin_game_controller.gd, merlin_save_system.gd, merlin_omniscient.gd, difficulty_adapter.gd, event_adapter.gd, narrative_scaler.gd, session_registry.gd, player_profile_registry.gd, merlin_rng.gd, arbre_de_vie_ui.gd, merlin_llm_adapter.gd, merlin_biome_system.gd, merlin_scenario_manager.gd, merlin_minigame_system.gd.*
