# Système de Sauvegarde — Architecture Complète

**Dernier mis à jour** : 2026-03-15
**Version système** : 1.0.0
**Source de code** : `scripts/merlin/merlin_save_system.gd`
**Design reference** : `docs/GAME_DESIGN_BIBLE.md` v2.4, section 13.4

---

## 1. Vue d'ensemble

Le système de sauvegarde M.E.R.L.I.N. fonctionne selon un modèle **profil unique** + **état de run sauvegardé**.

- **Profil persistant** (`merlin_profile.json`) : données cross-run (factions, Oghams possédés, Anam, arbre de talents, statistiques)
- **État de run** : données mid-run (vie, biome, index carte, promesses) sauvegardées dans le profil pour la reprise sur interruption
- **Format** : JSON structuré, versioning (v1.0.0 actuelle), migration automatique depuis v0.4.0
- **Sauvegardes** : backup automatique avant chaque write, recovery sur fichier principal corrompu

```
merlin_profile.json                      (PROFILE_PATH)
├─ meta                                  ← Données persistentes
│  ├─ anam                               (Monnaie de progression)
│  ├─ total_runs                         (Compteur global)
│  ├─ faction_rep                        (5 réputations: druides, anciens, korrigans, niamh, ankou)
│  ├─ trust_merlin                       (Confiance 0-100 clampée)
│  ├─ talent_tree                        (Talents débloqués)
│  ├─ oghams                             (Oghams possédés/équipés)
│  ├─ ogham_discounts                    (Réductions de coût)
│  ├─ endings_seen                       (Fins découvertes)
│  ├─ arc_tags                           (Tags narratifs cross-run)
│  ├─ biome_runs                         (Compteurs par biome)
│  └─ stats                              (Statistiques: cartes, minigames, morts)
├─ run_state                             ← Données mid-run (nullable)
│  ├─ biome
│  ├─ card_index
│  ├─ life_essence
│  ├─ equipped_oghams
│  ├─ promises
│  ├─ faction_rep_delta
│  └─ ... (état transitoire complet)
├─ version                               "1.0.0"
└─ timestamp                             (Unix timestamp du dernier write)

merlin_profile.json.bak                  (BACKUP_SUFFIX = ".bak")
└─ Copie de sécurité pré-écriture
```

---

## 2. Format fichier JSON

### 2.1 Structure racine

```json
{
  "version": "1.0.0",
  "timestamp": 1710513912,
  "meta": { ... },
  "run_state": null | { ... }
}
```

| Clé | Type | Description |
|-----|------|-------------|
| `version` | String | Numéro de version sémantique (v1.0.0 actuelle) |
| `timestamp` | int | Unix timestamp du dernier write (pour auditing) |
| `meta` | Dictionary | **Profil persistant** (voir section 2.2) |
| `run_state` | Dictionary ∣ null | **État mid-run** ou null si pas de run actif (voir section 2.3) |

### 2.2 Métadonnées persistantes (`meta`)

```json
{
  "anam": 42,
  "total_runs": 7,
  "faction_rep": {
    "druides": 45.5,
    "anciens": 20.0,
    "korrigans": -15.0,
    "niamh": 30.0,
    "ankou": 0.0
  },
  "trust_merlin": 65,
  "talent_tree": {
    "unlocked": ["talent_1_1", "talent_2_1", "talent_3_2"]
  },
  "oghams": {
    "owned": ["beith", "luis", "quert", "saille", "nion"],
    "equipped": "beith"
  },
  "ogham_discounts": {
    "beith": 2,
    "luis": 1
  },
  "endings_seen": ["ending_foret_bonheur", "ending_marais_trahison"],
  "arc_tags": ["met_the_druids", "promised_to_ankou"],
  "biome_runs": {
    "foret_broceliande": 5,
    "landes_bruyere": 2,
    "cotes_sauvages": 0,
    "villages_celtes": 0,
    "cercles_pierres": 0,
    "marais_korrigans": 7,
    "collines_dolmens": 0,
    "iles_mystiques": 0
  },
  "stats": {
    "total_cards": 156,
    "total_minigames_won": 98,
    "total_deaths": 3,
    "consecutive_deaths": 1,
    "oghams_discovered_in_runs": 8,
    "total_anam_earned": 420
  }
}
```

**Description des champs** :

| Champ | Type | Range | Modifié par | Notes |
|-------|------|-------|-------------|-------|
| `anam` | int | 0+ | Fin de run (gain proportionnel), achat talent | Monnaie de progression cross-run |
| `total_runs` | int | 0+ | Fin de run | Compteur global depuis création du profil |
| `faction_rep[X]` | float | -100 à +100 (pas de clamp) | Effet `ADD_REPUTATION`, fin de run commit | Réputations persistantes, 5 factions |
| `trust_merlin` | int | 0-100 (clampé) | Effet `CHANGE_TRUST`, fin de run commit | Affects dialogue Merlin, tier T0-T3 |
| `talent_tree.unlocked` | array[string] | n/a | Achat talent tree | IDs de talents débloqués (progression arborescente) |
| `oghams.owned` | array[string] | n/a | Fin de run (découverte) | Noms Oghams possédés (3 starters min: beith, luis, quert) |
| `oghams.equipped` | string | 18 Oghams valides | Changement équipement | Ogham actif durante run |
| `ogham_discounts[X]` | int | 0-10 | Arbre de talents | Réduction du coût de cooldown |
| `endings_seen` | array[string] | n/a | Fin de run unique | Fins découvertes (source: narrative JSON) |
| `arc_tags` | array[string] | n/a | LLM during run | Tags narratifs pour continuité (ex: "promised_to_ankou") |
| `biome_runs[X]` | int | 0+ | Fin de run (si biome complété) | Runs complétés par biome (maturité score = runs×2 + fins×5 + oghams×3 + max_rep×1) |
| `stats.total_cards` | int | 0+ | Fin de run | Somme de toutes les cartes jouées |
| `stats.total_minigames_won` | int | 0+ | Carte minigame (score ≥ seuil) | Victoires minigames |
| `stats.total_deaths` | int | 0+ | Fin de run (si vie = 0) | Morts totales |
| `stats.consecutive_deaths` | int | 0+ | Reset à 0 si vie > 0 à fin | Streak de morts consécutives |
| `stats.oghams_discovered_in_runs` | int | 0+ | Fin de run (découverte unique) | Oghams découverts (cross-run) |
| `stats.total_anam_earned` | int | 0+ | Fin de run (gain total) | Anam gagnée depuis création |

**Contraintes** :
- `faction_rep` : Pas de clamp de la réputé elle-même (peut dépasser ±100), mais certains effets peuvent clamper
- `trust_merlin` : TOUJOURS clampée [0, 100]
- `oghams.owned` : Minimum 3 starters (beith, luis, quert) dès création
- `biome_runs` : Compteur simple, utilisé pour calcul maturité (biome_runs[X] × 2)
- `total_runs` : Incrémenté à fin de run valide

**Relation avec `run_state`** : Les données `meta` sont sauvegardées après fin de run. Le `run_state` transitoire est clearé à ce moment.

### 2.3 État de run (`run_state`)

Sauvegardé **dans le profil** pour reprise sur interruption (alt-tab, crash, fermeture Godot).

```json
{
  "biome": "foret_broceliande",
  "card_index": 23,
  "life_essence": 67,
  "life_max": 100,
  "biome_currency": 315,
  "equipped_oghams": ["beith", "luis"],
  "active_ogham": "beith",
  "cooldowns": {
    "beith": 3,
    "nion": 0
  },
  "promises": [
    { "faction": "druides", "condition": "visit_forest", "reward": 10 }
  ],
  "faction_rep_delta": {
    "druides": 8.0,
    "anciens": -5.0,
    "korrigans": 0.0,
    "niamh": 12.5,
    "ankou": 0.0
  },
  "trust_delta": 5,
  "narrative_summary": "Le druide t'accueille chaleureusement...",
  "arc_tags_this_run": ["met_the_druids"],
  "period": "aube",
  "buffs": ["buff_strength_1", "buff_resilience_2"],
  "events_log": [
    { "turn": 1, "event": "entered_biome", "biome": "foret_broceliande" },
    { "turn": 5, "event": "card_played", "ogham": "beith", "score": 78 }
  ]
}
```

**Description** :

| Champ | Type | Description | Modifié par |
|-------|------|-------------|-------------|
| `biome` | string | Biome courant (8 valides) | Quiz initial, changement biome |
| `card_index` | int | Numéro de carte jouée (0-based) | Chaque carte jouée (+1) |
| `life_essence` | int | Vie courante (0-100) | Drain (-1 per carte), minigame damage/heal, effets |
| `life_max` | int | Vie maximale (normalement 100) | Effets rares de boost permanent |
| `biome_currency` | int | Monnaie du biome (collectée 3D) | Collection 3D (+X), achat Ogham |
| `equipped_oghams` | array[string] | Oghams disponibles cette run | Achat, utilisation |
| `active_ogham` | string | Ogham actuellement actif | Basculement équipement |
| `cooldowns[X]` | int | Tours restants avant réutilisation | Utilisation (-cooldown), fin tour (-1) |
| `promises` | array[object] | Promesses actives (faction, condition, reward) | LLM, résolution mid-run |
| `faction_rep_delta[X]` | float | **Delta** réputé cette run (0 au départ) | Effets `ADD_REPUTATION` |
| `trust_delta` | int | **Delta** confiance cette run | Effets `CHANGE_TRUST` |
| `narrative_summary` | string | Résumé narratif pour contexte LLM | LLM context pour prochaine carte |
| `arc_tags_this_run` | array[string] | Tags narratifs découverts cette run | LLM story branching |
| `period` | string | Période narrative (aube/jour/crepuscule/nuit) | Progression naturelle du biome |
| `buffs` | array[string] | Buffs actifs (ex: strength+1) | Effets, fin run |
| `events_log` | array[object] | Historique complet des événements | Audit, contexte LLM |

**Champs importants** :
- **`faction_rep_delta` vs `meta.faction_rep`** : Le delta est sauvegardé mid-run. À fin de run, c'est **additionné** au profil persistent et le run_state est clearé.
- **`card_index`** : Utilisé pour reprise (sauter à cette carte + afficher son state)
- **`cooldowns`** : Décrémenté chaque "tour" (= chaque carte jouée)
- **`events_log`** : Logs complets pour debugging et contexte LLM (non utilisé pour progression)

---

## 3. Versioning et Migration

### 3.1 Versions supportées

| Version | Description | Introduite | Migration vers |
|---------|-------------|------------|-----------------|
| **v1.0.0** | Format actuel (profil unifié + run_state) | 2026-03-14 | (current) |
| v0.4.0 | Ancien format (slots multiples, currencies diverses) | 2025-X-X | v1.0.0 |

**Current version du code** : `CURRENT_VERSION = "1.0.0"` (merlin_save_system.gd:4)

### 3.2 Migration automatique v0.4.0 → v1.0.0

Déclenché automatiquement au `load_profile()` si version détectée < 1.0.0 (merlin_save_system.gd:107-109).

**Étapes de migration** (`_migrate()` merlin_save_system.gd:224-269) :

1. **Fusion des essences en Anam**
   ```gdscript
   # Ancien: essence = { fire: 10, water: 5, air: 3, earth: 2 }
   # Nouveau: anam = 20 (somme de tous les essences)
   essence_total := sum(essence[element] for element)
   meta["anam"] = meta.get("anam", 0) + essence_total
   ```

2. **Suppression des currencies mortes**
   ```gdscript
   meta.erase("essence")
   meta.erase("ogham_fragments")
   meta.erase("liens")
   meta.erase("gloire_points")
   meta.erase("bestiole_evolution")
   meta.erase("unlocked_evolutions")
   ```

3. **Renommage faction (humains → niamh)**
   ```gdscript
   if faction_rep.has("humains") and not faction_rep.has("niamh"):
       faction_rep["niamh"] = faction_rep["humains"]
       faction_rep.erase("humains")
   ```

4. **Ajout champs manquants**
   - Chaque clé du profil par défaut est ajoutée si absente
   - Assure que `faction_rep` a toutes les 5 factions (druides, anciens, korrigans, niamh, ankou)

5. **Mise à jour version et sauvegarde**
   ```gdscript
   migrated["version"] = CURRENT_VERSION
   migrated["run_state"] = migrated.get("run_state")
   ```

**Profils par défaut** (`_get_default_profile()` merlin_save_system.gd:18-46) :
```gdscript
{
  "anam": 0,
  "total_runs": 0,
  "faction_rep": { druides: 0.0, anciens: 0.0, korrigans: 0.0, niamh: 0.0, ankou: 0.0 },
  "trust_merlin": 0,
  "talent_tree": { "unlocked": [] },
  "oghams": { "owned": ["beith", "luis", "quert"], "equipped": "beith" },
  "ogham_discounts": {},
  "endings_seen": [],
  "arc_tags": [],
  "biome_runs": { foret_broceliande: 0, landes_bruyere: 0, ... (8 biomes) },
  "stats": { total_cards: 0, total_minigames_won: 0, total_deaths: 0, ... }
}
```

**État de run par défaut** (`_get_default_run_state()` merlin_save_system.gd:49-70) :
```gdscript
{
  "biome": "foret_broceliande",
  "card_index": 0,
  "life_essence": 100,
  "life_max": 100,
  "biome_currency": 0,
  "equipped_oghams": ["beith"],
  "active_ogham": "beith",
  "cooldowns": {},
  "promises": [],
  "faction_rep_delta": { ... (0 pour chaque faction) },
  "trust_delta": 0,
  "narrative_summary": "",
  "arc_tags_this_run": [],
  "period": "aube",
  "buffs": [],
  "events_log": []
}
```

### 3.3 Migration depuis legacy (slots multiples)

Ancien système : `merlin_save_slot_1.json`, `merlin_save_slot_2.json`, `merlin_autosave.json`

Code de migration (`_try_migrate_from_legacy()` merlin_save_system.gd:272-295) :
1. Cherche slot 1, puis slot 2, puis slot 3
2. Si aucun slot, cherche autosave
3. Wraps dans le format profil (version 0.4.0)
4. Applique migration (`_migrate()`)
5. Sauvegarde en tant que nouveau profil unique
6. **Cleanup des fichiers legacy** (`_cleanup_legacy_files()`)

---

## 4. Sauvegarde de l'état de run (interruption)

### 4.1 Timing de sauvegarde

**Quand sauvegarder** : Appel explicite à `save_run_state(run_state: Dictionary)` (merlin_save_system.gd:158-166)

- **Avant minigame** : État avant score minigame (pour reprise exacte)
- **Après chaque carte** : État complet du run (position, vie, cooldowns, deltas)
- **Événements clés** : Achat Ogham, promesse accomplie, etc.

**Code** :
```gdscript
func save_run_state(run_state: Dictionary) -> void:
    var data: Dictionary = _try_load_file(PROFILE_PATH)
    if data.is_empty():
        push_warning("[MerlinSave] No profile found, cannot save run_state")
        return
    data["run_state"] = run_state.duplicate(true)  # Deep copy
    data["timestamp"] = int(Time.get_unix_time_from_system())
    _backup_file(PROFILE_PATH)
    _write_file(PROFILE_PATH, data)
```

### 4.2 Reprise sur interruption

**Détection** : `has_active_run() -> bool` (merlin_save_system.gd:188-189)
```gdscript
func has_active_run() -> bool:
    return not load_run_state().is_empty()
```

**Chargement** : `load_run_state() -> Dictionary` (merlin_save_system.gd:169-176)
```gdscript
func load_run_state() -> Dictionary:
    var data: Dictionary = _try_load_file(PROFILE_PATH)
    if data.is_empty():
        return {}
    var run_state = data.get("run_state")
    if run_state == null or not (run_state is Dictionary):
        return {}
    return run_state as Dictionary
```

**Workflow de reprise** (responsabilité de `MerlinGameController`) :
1. Charger profil : `load_profile()`
2. Vérifier run actif : `has_active_run()`
3. Si run actif :
   - Charger state : `load_run_state()`
   - Restaurer scène 3D + état
   - Afficher carte à `card_index`
   - Continuer depuis cette position
4. Sinon : démarrer nouveau run (biome choice → etc.)

### 4.3 Clearing du run_state

Appelé à fin de run (victoire, mort, abandon) : `clear_run_state()` (merlin_save_system.gd:179-185)

```gdscript
func clear_run_state() -> void:
    var data: Dictionary = _try_load_file(PROFILE_PATH)
    if data.is_empty():
        return
    data["run_state"] = null  # Important: null, pas vide
    data["timestamp"] = int(Time.get_unix_time_from_system())
    _write_file(PROFILE_PATH, data)
```

**Pipeline fin de run** :
1. Appliquer deltas au profil : `meta.faction_rep[X] += faction_rep_delta[X]`
2. Incrémenter `total_runs`
3. Ajouter Anam gagné
4. Sauvegarder profil : `save_profile(meta)`
5. Clearing auto : Le `save_profile()` préserve `run_state` existant (merlin_save_system.gd:86-88), donc doit être explicitement clearé

---

## 5. Corruption et recovery

### 5.1 Stratégie de backup

**Backup créé avant chaque write** (merlin_save_system.gd:349-360) :

```gdscript
func _backup_file(path: String) -> void:
    if not FileAccess.file_exists(path):
        return
    var src: FileAccess = FileAccess.open(path, FileAccess.READ)
    if src == null:
        return
    var content: String = src.get_as_text()
    src.close()
    var dst: FileAccess = FileAccess.open(path + BACKUP_SUFFIX, FileAccess.WRITE)
    if dst:
        dst.store_string(content)
        dst.close()
```

**Emplacements** :
- `merlin_profile.json` → sauvegarde crée `merlin_profile.json.bak`
- Sur prochain write, `.bak` est écrasé (keep only latest pre-write state)

### 5.2 Détection de corruption

**Loading robuste** (`_try_load_file()` merlin_save_system.gd:317-335) :

```gdscript
func _try_load_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var json_text: String = file.get_as_text()
    file.close()
    if json_text.strip_edges().is_empty():
        return {}
    var json: JSON = JSON.new()
    if json.parse(json_text) != OK:
        push_warning("[MerlinSave] JSON parse error in %s: %s" % [path, json.get_error_message()])
        return {}
    var data = json.get_data()
    if typeof(data) != TYPE_DICTIONARY:
        push_warning("[MerlinSave] Invalid save structure in %s" % path)
        return {}
    return data
```

**Erreurs gérées** :
1. Fichier inexistant → `{}`
2. Fichier non ouvrable (permissions) → `{}`
3. Fichier vide ou whitespace → `{}`
4. JSON invalide (parse error) → warning + `{}`
5. JSON non-Dictionary au top level → warning + `{}`

### 5.3 Recovery cascade

Appelé dans `load_profile()` (merlin_save_system.gd:92-116) :

**Ordre de tentative** :
1. Charger `merlin_profile.json`
   - Si vide → warning de parse/corruption
2. Si corrompu, charger `merlin_profile.json.bak`
   - Si succès → push_warning("[MerlinSave] Primary corrupted, loaded from backup")
3. Si backup absent/corrompu, migrer depuis legacy
   - Cherche `merlin_save_slot_1.json` (puis slot 2, 3, autosave)
4. Si aucune source trouvée → retourner `{}`
   - `load_or_create_profile()` crée un nouveau profil par défaut

**Code** :
```gdscript
func load_profile() -> Dictionary:
    var data: Dictionary = _try_load_file(PROFILE_PATH)
    if data.is_empty():
        var bak_path: String = PROFILE_PATH + BACKUP_SUFFIX
        if FileAccess.file_exists(bak_path):
            data = _try_load_file(bak_path)
            if not data.is_empty():
                push_warning("[MerlinSave] Primary corrupted, loaded from backup")
    if data.is_empty():
        data = _try_migrate_from_legacy()
    if data.is_empty():
        return {}
    # ... version check + validation
    return meta
```

### 5.4 Validation de profil

Après chargement, validation des champs requis (`_validate()` merlin_save_system.gd:196-217) :

```gdscript
static func _validate(meta: Dictionary) -> bool:
    var required_keys: Array = [
        "anam", "total_runs", "faction_rep", "trust_merlin",
        "talent_tree", "oghams", "endings_seen", "arc_tags",
        "biome_runs", "stats",
    ]
    for key in required_keys:
        if not meta.has(key):
            push_warning("[MerlinSave] Missing required key: %s" % key)
            return false
    # Verify faction_rep has all 5 factions
    var faction_rep: Dictionary = meta.get("faction_rep", {})
    for faction in MerlinConstants.FACTIONS:
        if not faction_rep.has(faction):
            push_warning("[MerlinSave] Missing faction in faction_rep: %s" % faction)
            return false
    # Verify oghams structure
    var oghams: Dictionary = meta.get("oghams", {})
    if not oghams.has("owned") or not oghams.has("equipped"):
        push_warning("[MerlinSave] Invalid oghams structure")
        return false
    return true
```

**Validations** :
- Toutes les clés requises présentes
- `faction_rep` contient les 5 factions (druides, anciens, korrigans, niamh, ankou)
- `oghams` a les clés `owned` et `equipped`
- Aucune vérification stricte des valeurs (délégué au code métier)

---

## 6. API publique

### 6.1 Gestion du profil

#### `save_profile(meta: Dictionary) -> bool`
**Source** : merlin_save_system.gd:77-89

Sauvegarde les métadonnées persistantes du profil. Préserve l'état de run existant si présent.

```gdscript
var save_system = MerlinSaveSystem.new()
var meta = {
    "anam": 50,
    "total_runs": 5,
    # ... autres champs
}
var success = save_system.save_profile(meta)
```

**Comportement** :
- Crée backup de l'ancien profil (`.bak`)
- Charge le profil existant (s'il existe)
- Préserve `run_state` existant (pour reprise)
- Écrit le nouveau profil avec timestamp courant
- Retourne `true` si succès, `false` si écriture impossible

#### `load_profile() -> Dictionary`
**Source** : merlin_save_system.gd:92-116

Charge les métadonnées persistantes. Applique migration si version < 1.0.0.

```gdscript
var save_system = MerlinSaveSystem.new()
var meta = save_system.load_profile()
if meta.is_empty():
    meta = save_system.load_or_create_profile()
```

**Cascade de recovery** :
1. Tente charger `merlin_profile.json`
2. Si corrompu, tente backup (`.bak`)
3. Si absent, tente migration depuis legacy
4. Applique migration version si nécessaire
5. Assure tous les champs par défaut existent

#### `load_or_create_profile() -> Dictionary`
**Source** : merlin_save_system.gd:119-124

Charge ou crée un nouveau profil (convenience wrapper).

```gdscript
var meta = save_system.load_or_create_profile()
# Garantie: non vide, version actuelle, tous champs présents
```

#### `profile_exists() -> bool`
**Source** : merlin_save_system.gd:127-128

Vérifie existence du fichier de profil (sans charger).

```gdscript
if not save_system.profile_exists():
    # Premier lancement du jeu
    var meta = MerlinSaveSystem._get_default_profile()
    save_system.save_profile(meta)
```

#### `reset_profile() -> void`
**Source** : merlin_save_system.gd:131-136

**Danger** : Supprime le profil ET son backup. Utilisé pour réinitialiser complètement.

```gdscript
save_system.reset_profile()  # Profil complètement supprimé
```

#### `get_profile_info() -> Dictionary`
**Source** : merlin_save_system.gd:139-151

Retourne un résumé non-sauvegardé du profil (pour affichage Hub).

```gdscript
var info = save_system.get_profile_info()
# {
#   "anam": 42,
#   "total_runs": 7,
#   "talents_unlocked": 3,
#   "endings_seen": 2,
#   "faction_rep": { ... },
#   "oghams_owned": 5,
#   "trust_merlin": 65
# }
```

### 6.2 Gestion de l'état de run

#### `save_run_state(run_state: Dictionary) -> void`
**Source** : merlin_save_system.gd:158-166

Sauvegarde l'état mid-run pour reprise sur interruption.

```gdscript
var run_state = {
    "biome": "foret_broceliande",
    "card_index": 23,
    "life_essence": 67,
    # ... autres champs
}
save_system.save_run_state(run_state)
```

**Timing recommandé** :
- Après chaque carte jouée
- Avant minigame (pour reprise exacte)
- Au changement d'équipement Ogham
- Promesse accomplie

**Backup** : Crée backup avant write (preserves previous state)

#### `load_run_state() -> Dictionary`
**Source** : merlin_save_system.gd:169-176

Charge l'état mid-run. Retourne `{}` si absent ou corrompu.

```gdscript
var run_state = save_system.load_run_state()
if not run_state.is_empty():
    # Reprendre le run
    game_controller.restore_run_state(run_state)
else:
    # Nouveau run
    game_controller.start_new_run()
```

#### `clear_run_state() -> void`
**Source** : merlin_save_system.gd:179-185

Supprime l'état de run (normallement appelé à fin de run).

```gdscript
# À fin du run (victoire, mort, abandon)
save_system.clear_run_state()
```

#### `has_active_run() -> bool`
**Source** : merlin_save_system.gd:188-189

Teste existence d'un run actif (shortcut pour `load_run_state().is_empty()`).

```gdscript
if save_system.has_active_run():
    # Proposer "Continuer" au menu
    show_continue_button()
else:
    # Seul "Nouveau Run" disponible
    hide_continue_button()
```

---

## 7. Emplacements fichiers

### 7.1 Profil actuel

| Chemin | Contenu | Godot |
|--------|---------|-------|
| `user://merlin_profile.json` | Profil v1.0.0 (meta + run_state) | `PROFILE_PATH` constant |
| `user://merlin_profile.json.bak` | Backup pré-write précédent | `PROFILE_PATH + BACKUP_SUFFIX` |

**Godot `user://` mapping** :
- **Windows** : `%APPDATA%/Godot/app_userdata/M.E.R.L.I.N./` (approx.)
- **Linux** : `~/.local/share/godot/app_userdata/M.E.R.L.I.N./`
- **macOS** : `~/Library/Application Support/Godot/app_userdata/M.E.R.L.I.N./`

### 7.2 Fichiers legacy (migration)

**Source** : merlin_save_system.gd:8-11

| Chemin | Status | Cleanup |
|--------|--------|---------|
| `user://merlin_save_slot_1.json` | Legacy (migré) | Suppressible après migration |
| `user://merlin_save_slot_2.json` | Legacy (migré) | Suppressible après migration |
| `user://merlin_save_slot_3.json` | Legacy (migré) | Suppressible après migration |
| `user://merlin_autosave.json` | Legacy (migré) | Suppressible après migration |
| `user://merlin_save_slot_*.bak` | Legacy backup | Suppressible après migration |
| `user://merlin_autosave.json.bak` | Legacy backup | Suppressible après migration |

**Cleanup automatique** : `_cleanup_legacy_files()` (merlin_save_system.gd:298-310) supprime tous les fichiers legacy après migration réussie.

---

## 8. Schéma complet du profil

```
merlin_profile.json (v1.0.0)
│
├─ version: "1.0.0"
├─ timestamp: <unix_int>
│
├─ meta: {
│   ├─ anam: <int>
│   ├─ total_runs: <int>
│   │
│   ├─ faction_rep: {
│   │   ├─ druides: <float>
│   │   ├─ anciens: <float>
│   │   ├─ korrigans: <float>
│   │   ├─ niamh: <float>
│   │   └─ ankou: <float>
│   │
│   ├─ trust_merlin: <int> [0-100]
│   ├─ talent_tree: {
│   │   └─ unlocked: [<string>, ...]
│   │
│   ├─ oghams: {
│   │   ├─ owned: [<string>, ...]
│   │   └─ equipped: <string>
│   │
│   ├─ ogham_discounts: {
│   │   └─ <ogham_name>: <int>
│   │
│   ├─ endings_seen: [<string>, ...]
│   ├─ arc_tags: [<string>, ...]
│   │
│   ├─ biome_runs: {
│   │   ├─ foret_broceliande: <int>
│   │   ├─ landes_bruyere: <int>
│   │   ├─ cotes_sauvages: <int>
│   │   ├─ villages_celtes: <int>
│   │   ├─ cercles_pierres: <int>
│   │   ├─ marais_korrigans: <int>
│   │   ├─ collines_dolmens: <int>
│   │   └─ iles_mystiques: <int>
│   │
│   └─ stats: {
│       ├─ total_cards: <int>
│       ├─ total_minigames_won: <int>
│       ├─ total_deaths: <int>
│       ├─ consecutive_deaths: <int>
│       ├─ oghams_discovered_in_runs: <int>
│       └─ total_anam_earned: <int>
│
└─ run_state: null | {
    ├─ biome: <string>
    ├─ card_index: <int>
    ├─ life_essence: <int>
    ├─ life_max: <int>
    ├─ biome_currency: <int>
    ├─ equipped_oghams: [<string>, ...]
    ├─ active_ogham: <string>
    │
    ├─ cooldowns: {
    │   └─ <ogham_name>: <int>
    │
    ├─ promises: [{
    │   ├─ faction: <string>
    │   ├─ condition: <string>
    │   └─ reward: <int>
    │ }, ...]
    │
    ├─ faction_rep_delta: {
    │   ├─ druides: <float>
    │   ├─ anciens: <float>
    │   ├─ korrigans: <float>
    │   ├─ niamh: <float>
    │   └─ ankou: <float>
    │
    ├─ trust_delta: <int>
    ├─ narrative_summary: <string>
    ├─ arc_tags_this_run: [<string>, ...]
    ├─ period: <string> [aube|jour|crepuscule|nuit]
    │
    ├─ buffs: [<string>, ...]
    │
    └─ events_log: [{
        ├─ turn: <int>
        ├─ event: <string>
        └─ ... (custom fields per event type)
      }, ...]
}
```

---

## 9. Bonnes pratiques

### 9.1 Sauvegarde

- **Fréquence** : Après chaque action métier (Ogham, promesse, fin carte)
- **Granularité** : Sauvegarder état de run AVANT minigame (pour reprise exacte)
- **Backup** : Automatique, pas besoin de gérer
- **Erreurs** : Vérifier retour bool de `save_profile()`, logged via `push_warning()`

**Template** :
```gdscript
var run_state = {
    # ... remplir state
}
save_system.save_run_state(run_state)

var meta = save_system.load_profile()
meta["anam"] += 10
save_system.save_profile(meta)
```

### 9.2 Chargement

- **Toujours vérifier empty** : `if meta.is_empty()`
- **Utiliser fallback** : `meta.get("key", default_value)`
- **Validation** : Appeler `_validate()` après load (optionnel, internal check)

**Template** :
```gdscript
var meta = save_system.load_profile()
if meta.is_empty():
    meta = save_system.load_or_create_profile()

var anam = meta.get("anam", 0)
var trust = meta.get("trust_merlin", 0)
```

### 9.3 Reprise

- **Always check** : `has_active_run()`
- **Charger state complet** : `load_run_state()`
- **Restaurer exactement** : biome, card_index, life, cooldowns, deltas
- **Clear après fin** : `clear_run_state()`

**Pipeline complet** :
```gdscript
func _ready():
    if save_system.has_active_run():
        var meta = save_system.load_profile()
        var run_state = save_system.load_run_state()
        restore_game(meta, run_state)
    else:
        show_main_menu()

func _on_run_finished(victory: bool):
    var run_state = game_state.get_run_state()
    var meta = save_system.load_profile()

    # Appliquer deltas
    for faction in run_state["faction_rep_delta"]:
        meta["faction_rep"][faction] += run_state["faction_rep_delta"][faction]
    meta["trust_merlin"] = clamp(meta["trust_merlin"] + run_state["trust_delta"], 0, 100)
    meta["total_runs"] += 1
    meta["anam"] += run_state.get("anam_earned", 0)

    # Sauvegarder et clearer
    save_system.save_profile(meta)
    save_system.clear_run_state()
```

### 9.4 Migration

- **Transparent** : Activation automatique au `load_profile()`
- **Testable** : Créer un vieux profil v0.4.0 pour vérifier migration
- **Cleanup** : Ancien système (slots) supprimé automatiquement

**Vérification de migration** :
```gdscript
# Dans les tests
var old_data = JSON.parse_string(old_json)
var migrated = save_system._migrate(old_data)
assert migrated["version"] == "1.0.0"
assert migrated["meta"]["anam"] == expected_anam_sum
```

---

## 10. Diagnostic et debugging

### 10.1 Logs fournis

Le système émet `push_warning()` pour tous les événements clés :

```
[MerlinSave] JSON parse error in user://merlin_profile.json: Unexpected "}" on line 42
[MerlinSave] Invalid save structure in user://merlin_profile.json
[MerlinSave] Missing required key: faction_rep
[MerlinSave] Missing faction in faction_rep: niamh
[MerlinSave] Invalid oghams structure
[MerlinSave] Primary corrupted, loaded from backup
[MerlinSave] Migrated legacy save to profile v1.0.0
[MerlinSave] No profile found, cannot save run_state
[MerlinSave] Cannot write to user://merlin_profile.json
```

### 10.2 Inspection manuelle

**Sur Windows** (Godot userdata) :
```powershell
# Localiser le fichier
ls %APPDATA%/Godot/app_userdata/ | grep -i merlin

# Afficher contenu
cat "%APPDATA%/Godot/app_userdata/M.E.R.L.I.N./merlin_profile.json" | jq .
```

**Via Godot FileSystem dock** :
1. Vue "File System" → `user://`
2. Clic droit `merlin_profile.json` → "Open in External Program"

### 10.3 Test de corruption

**Simuler corruption** :
```bash
# Éditer merlin_profile.json, supprimer une accolade
# Relancer le jeu → devrait charger depuis backup

# Supprimer aussi le backup
# Relancer → migration legacy ou default profile
```

---

## 11. Relation avec autres systèmes

### 11.1 MerlinGameController

**Orchestrateur du flow jeu** : Gère la transition Hub ↔ Run

- Appel `load_or_create_profile()` au startup
- Appel `has_active_run()` pour proposer "Continuer"
- Appel `save_run_state()` après chaque carte
- Appel `clear_run_state()` + `save_profile()` à fin de run

### 11.2 MerlinStore

**State central Redux-like** : Gère faction_rep, trust, oghams pendant le run

- Stocke deltas (faction_rep_delta, trust_delta)
- À fin de run, appelle `save_profile()` pour committer deltas au persistant

### 11.3 MerlinEffectEngine

**Applique les effets des cartes** : Modifie run_state via store

- Effets: `ADD_REPUTATION`, `CHANGE_TRUST`, `HEAL_LIFE`, `DAMAGE_LIFE`, `PROMISE`
- Tous les effets modifient le store (= run_state en mémoire)
- `save_run_state()` appelé après minigame complet

### 11.4 MerlinLLMAdapter

**Génération narrative** : Consomme contexte persistant et mid-run

- Consomme `meta.faction_rep` (contexte global)
- Consomme `run_state.faction_rep_delta`, `arc_tags_this_run` (contexte run)
- Sortie: carte narrative + promises

---

## 12. Feuille de route & limitations

### 12.1 Features futures

| Feature | Impact | Priorite |
|---------|--------|----------|
| Encryption de profil | Sécurité (anti-cheat) | Basse |
| Cloud sync | Multi-device | Moyenne |
| Stats détaillées | Analytics | Basse |
| Rollback manuel | UX | Basse |
| Export profil | Social sharing | Très basse |

### 12.2 Limitations actuelles

- **Un seul profil** : Pas de système de "personnages" multiples
- **Backup unique** : Seulement la dernière pré-write est keepée (pas historique)
- **Pas de encryption** : Profil lisible en texte brut (JSON)
- **Pas de validation stricte des valeurs** : Délégué au code métier

---

## Annexe A: Exemple d'un profil complet

Voir fichier JSON en section 2.2 et 2.3 pour structure complète.

---

## Annexe B: Résumé API

```gdscript
# Profil
save_profile(meta: Dictionary) -> bool
load_profile() -> Dictionary
load_or_create_profile() -> Dictionary
profile_exists() -> bool
reset_profile() -> void
get_profile_info() -> Dictionary

# Run state
save_run_state(run_state: Dictionary) -> void
load_run_state() -> Dictionary
clear_run_state() -> void
has_active_run() -> bool

# Defaults (static)
_get_default_profile() -> Dictionary
_get_default_run_state() -> Dictionary

# Internal
_validate(meta: Dictionary) -> bool
_migrate(data: Dictionary) -> Dictionary
_try_migrate_from_legacy() -> Dictionary
_try_load_file(path: String) -> Dictionary
_write_file(path: String, data: Dictionary) -> bool
_backup_file(path: String) -> void
_cleanup_legacy_files() -> void
```

---

**Document généré par Claude Code**
Versioning: CLAUDE.md v3.3 | Save System v1.0.0 | Game Design v2.4
