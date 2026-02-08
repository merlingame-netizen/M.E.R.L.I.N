# DOC 09 — Effect Whitelist (exhaustive v0.6)

## Objectif
Tous les effets proposés par Merlin (LLM) ou par des tables d’events/combat doivent être :
- **codés**
- **validés**
- **journalisés**
- **bornés** (caps & règles anti-frustration)

Format recommandé (string) : `CODE:arg1:arg2:...`

---

## A) Ressources RUN

### ADD_RUN_RESOURCE
- `ADD_RUN_RESOURCE:<Vigueur|Concentration|Materiel|Faveur|Nourriture>:<delta>`
- Bornes : res >= 0, cap configurable (ex: 0..9)

### SET_RUN_RESOURCE
- `SET_RUN_RESOURCE:<res>:<value>`
- Usage rare (boss, shop)

### CONSUME_RUN_RESOURCE
- `CONSUME_RUN_RESOURCE:<res>:<delta>`
- alias pratique de ADD négatif, mais validation stricte

---

## B) Meta — Essences / Ogham / Liens

### GAIN_ESSENCE
- `GAIN_ESSENCE:<ELEMENT>:<delta>`
- ELEMENT ∈ 14 types

### CONSUME_ESSENCE
- `CONSUME_ESSENCE:<ELEMENT>:<delta>`

### GAIN_OGHAM
- `GAIN_OGHAM:<delta>`

### CONSUME_OGHAM
- `CONSUME_OGHAM:<delta>`

### GAIN_LIENS
- `GAIN_LIENS:<delta>`

### CONSUME_LIENS
- `CONSUME_LIENS:<delta>`

---

## C) Bestiole — jauges instantanées

### BESTIOLE_NEED
- `BESTIOLE_NEED:<Hunger|Energy|Hygiene|Mood|Stress>:<delta>`
- Bornes : 0..100 (Stress idem)

### BESTIOLE_SET_NEED
- `BESTIOLE_SET_NEED:<need>:<value>`

### BESTIOLE_TENDENCY
- `BESTIOLE_TENDENCY:<Wild|Light|Discipline>:<delta>`
- Bornes : -100..100

---

## D) Bestiole — progression

### BOND_XP
- `BOND_XP:<delta>`
- Le level-up bond se fait côté moteur (seuils)

### BESTIOLE_XP
- `BESTIOLE_XP:<delta>`
- Si vous séparez XP combat et bond

### BESTIOLE_EVOLVE_READY
- `BESTIOLE_EVOLVE_READY:<flag_on|flag_off>`
- Le moteur vérifie coûts & conditions

### UNLOCK_EVOLUTION_STAGE
- `UNLOCK_EVOLUTION_STAGE:<stage>`
- Pour gates de skill tree

---

## E) Combat — HP, dégâts, statuts

### HP_DELTA
- `HP_DELTA:<target player|enemy>:<delta>`
- Bornes : ne pas descendre sous 1 HP hors “death rule”, sauf combat

### SET_HP
- `SET_HP:<target>:<value>`

### APPLY_STATUS
- `APPLY_STATUS:<target player|enemy>:<StatusId>:<turns>`
- StatusId : BRULURE, VENIN, GEL, PEUR, CLAIRVOYANCE, SURCHARGE, etc.
- Bornes : turns cap (ex 5)

### REMOVE_STATUS
- `REMOVE_STATUS:<target>:<StatusId>`

### CLEANSE_ALL_NEG
- `CLEANSE_ALL_NEG:<target>`

### BUFF_STAT
- `BUFF_STAT:<target>:<ATK|DEF|SPD>:<delta>:<turns>`
- Bornes : delta cap (ex ±30%), turns cap (ex 5)

### DEBUFF_STAT
- idem BUFF_STAT

### SET_POSTURE
- `SET_POSTURE:<Prudence|Agressif|Ruse|Serenite>`

### MOMENTUM_DELTA
- `MOMENTUM_DELTA:<delta>`
- Bornes : 0..100

---

## F) Carte / progression run

### ADVANCE_FLOOR
- `ADVANCE_FLOOR:<delta>`
- Souvent delta=1

### SET_NODE_TYPE_NEXT
- `SET_NODE_TYPE_NEXT:<COMBAT|EVENT|SHOP|HEAL|ELITE|BOSS|MYSTERY>`
- Utilisé pour “twists” contrôlés (rare)

### REVEAL_MAP_INFO
- `REVEAL_MAP_INFO:<type intent|node|loot>:<amount>`
- Ex : révèle 1 futur nœud

---

## G) Inventaire & items

### ADD_ITEM
- `ADD_ITEM:<ItemId>:<count>`
- Bornes : stack cap selon item

### REMOVE_ITEM
- `REMOVE_ITEM:<ItemId>:<count>`

### ADD_RELIC
- `ADD_RELIC:<RelicId>`
- Bornes : unicité

### REMOVE_RELIC
- `REMOVE_RELIC:<RelicId>`

---

## H) Achievements / Unlocks / Packages

### ACH_PROGRESS
- `ACH_PROGRESS:<AchId>:<delta>`
- Le moteur check `>= threshold` pour unlock

### ACH_UNLOCK
- `ACH_UNLOCK:<AchId>`

### UNLOCK
- `UNLOCK:<UnlockId>`
- Ex : PKG_SCOUT, DEC_PLANT_01, MOVE_ROOT_SNARE

### GRANT_LOADOUT_PACKAGE
- `GRANT_LOADOUT_PACKAGE:<PkgId>`

### SET_ACTIVE_PACKAGE
- `SET_ACTIVE_PACKAGE:<PkgId>`
- Pré-run seulement (validation)

---

## I) LLM / narration (non mécanique, pour mémoire)
Ces effets n’ont **pas** d’impact chiffré, mais servent à journaliser.

### LOG_STORY_TAG
- `LOG_STORY_TAG:<tag>`
- Ex : “trahison”, “promesse”, “peur_du_feu”

### LOG_MERLIN_TONE
- `LOG_MERLIN_TONE:<Protecteur|Pragmatique|Aventureux|Sombre|Pedagogue>`

### LOG_BESTIOLE_REACTION
- `LOG_BESTIOLE_REACTION:<Calme|Stress|Curieux|Aggressif>`

---

## J) Effets “safe” anti-frustration

### GRANT_PITY
- `GRANT_PITY:<delta>`
- augmente fail_streak bonus (cap)

### REDUCE_DIFFICULTY_NEXT
- `REDUCE_DIFFICULTY_NEXT:<delta>`
- s’applique sur le prochain mini-jeu uniquement

### FORCE_SOFT_SUCCESS
- `FORCE_SOFT_SUCCESS:<flag>`
- transforme un fail en outcome “mitigé”, sans jackpot

---

## Notes d’implémentation
- Toute string inconnue = **refus** + log
- Toute valeur hors bornes = clamp + log
- Le moteur garde un `effect_log[]` avec `source = {SYSTEM|LLM|PLAYER}`
