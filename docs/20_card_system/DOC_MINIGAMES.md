# Architecture des Minigames — M.E.R.L.I.N.

**Version**: 1.0
**Date**: 2026-03-15
**Source de vérité**: `docs/GAME_DESIGN_BIBLE.md` v2.4
**Code source**: `scripts/minigames/`

---

## 1. Vue d'ensemble

Le système de minigames est le **cœur du gameplay** de M.E.R.L.I.N. Chaque choix narratif du joueur déclenche un minigame, dont le score (0-100) détermine l'intensité des effets de la carte.

### 1.1 Architecture haute niveau

```
Joueur choisit une option
       ↓
Code détecte le champ lexical (texte narratif + tags)
       ↓
Sélection d'un minigame aléatoire du champ
       ↓
Calcul de difficulté (biome, type de carte, progression)
       ↓
Affichage du minigame en overlay 2D
       ↓
Joueur joue et obtient un score (0-100)
       ↓
Score multiplié par les modificateurs (Oghams)
       ↓
Multiplicateur d'effets appliqué aux effets narratifs
       ↓
Fin du minigame + animations de transition
```

### 1.2 Principes de design

| Principe | Justification |
|----------|---------------|
| **Obligatoire, pas de skip** | Le minigame EST le gameplay — pas d'option de contournement |
| **Détection automatique du champ** | Le joueur ne choisit pas le minigame ; le texte narratif décide |
| **Score détermine l'intensité** | Pas de bon/mauvais résultat — juste une gradation d'intensité |
| **24+ minigames** | Un par champ principal, avec variations par difficulté |
| **Difficulté semi-adaptative** | Basée sur le contexte narratif, pas sur la performance du joueur |
| **Temps limite variable** | Entre 5-30s selon le minigame et la difficulté |

---

## 2. Architecture du registre

### 2.1 Fichier: `minigame_registry.gd`

Le registre est la **source de vérité unique** pour :
- Détection des champs lexicaux
- Association minigame-champ
- Bonus Ogham par champ
- Création d'instances

```gdscript
class_name MiniGameRegistry extends RefCounted

# === DONNEES STATIQUES ===

const FIELDS := {
    "chance": [...],        # Mots-clés pour détection
    "bluff": [...],
    "observation": [...],
    # ... 8 champs totaux
}

const GAMES := {
    "chance": ["mg_de_du_destin", "mg_pile_ou_face", "mg_roue_fortune"],
    "bluff": ["mg_joute_verbale", "mg_bluff_druide", "mg_negociation"],
    # ... par champ
}

const OGHAM_FIELD_BONUS := {
    "reveal": "observation",      # Ogham boost → champ
    "protection": "logique",
    "boost": "finesse",
    # ... 8 mappings
}

const TAG_FIELD_MAP := {
    "combat": "finesse",           # Tag narratif → champ
    "danger": "finesse",
    "stranger": "bluff",
    # ... 21 mappings
}

# === METHODES PUBLIQUES ===

static func detect_field(text: String, gm_hint: String, tags: Array) -> String
    # Retourne le champ lexical détecté

static func create_minigame(field: String, difficulty: int, modifiers: Dict) -> MiniGameBase
    # Crée une instance du minigame
```

### 2.2 Données

#### 2.2.1 `FIELDS` — Mots-clés par champ (8 champs)

| Champ | Mots-clés de détection |
|-------|------------------------|
| **chance** | chance, destin, sort, fortune, hasard, tirage, de, etoile |
| **bluff** | parler, negocier, convaincre, mentir, persuader, discuter, diplomate, bluff, ruse |
| **observation** | observer, guetter, voir, chercher, scruter, regarder, epier, decouvrir, cache |
| **logique** | penser, resoudre, comprendre, enigme, deduire, puzzle, noeud, rune, symbole |
| **finesse** | esquiver, attraper, lancer, viser, combattre, frapper, courir, sauter, reflexe |
| **vigueur** | force, endurance, puissance, resistance, muscle, soulever, pousser, tenir, effort |
| **esprit** | volonte, mental, concentration, mediter, calme, serenite, focus, respirer, esprit |
| **perception** | sentir, entendre, percevoir, instinct, flair, ombre, echo, memoire, sens |

**Source code** : `minigame_registry.gd:8-17`

#### 2.2.2 `GAMES` — Minigames par champ (24 minigames)

| Champ | Minigames | Tier |
|-------|-----------|------|
| **chance** | `mg_de_du_destin` | T1 |
| | `mg_pile_ou_face` | T1 |
| | `mg_roue_fortune` | T2 |
| **bluff** | `mg_joute_verbale` | T1 |
| | `mg_bluff_druide` | T2 |
| | `mg_negociation` | T2 |
| **observation** | `mg_oeil_corbeau` | T2 |
| | `mg_trace_cerf` | T3 |
| | `mg_rune_cachee` | T3 |
| **logique** | `mg_enigme_ogham` | T2 |
| | `mg_noeud_celtique` | T3 |
| | `mg_pierre_feuille_racine` | T1 |
| **finesse** | `mg_tir_a_larc` | T1 |
| | `mg_lame_druide` | T3 |
| | `mg_pas_renard` | T3 |
| **vigueur** | `mg_combat_rituel` | T3 |
| | `mg_sang_froid` | T3 |
| | `mg_course` | T3 |
| **esprit** | `mg_volonte` | T3 |
| | `mg_apaisement` | T3 |
| | `mg_meditation` | T3 |
| **perception** | `mg_ombres` | T3 |
| | `mg_regard` | T3 |
| | `mg_echo` | T3 |

**Fallback** : Si aucun minigame disponible, retour à `mg_de_du_destin`.

**Source code** : `minigame_registry.gd:20-29`

#### 2.2.3 `OGHAM_FIELD_BONUS` — Bonus Ogham par champ

| Catégorie Ogham | Champ bonus | Bonus score | Notes |
|-----------------|-------------|-------------|-------|
| **reveal** | observation | +10% | Détection visuelle |
| **protection** | logique | +10% | Raisonnement tactique |
| **boost** | finesse | +10% | Agilité |
| **narrative** | bluff | +10% | Parole |
| **recovery** | chance | +10% | Fortune |
| **combat** | vigueur | +10% | Force |
| **focus** | esprit | +10% | Mental |
| **sense** | perception | +10% | Sensibilité |
| **special** | (tous) | +5% | Bonus universel |

Si l'Ogham actif correspond au champ du minigame → **+10% score**.
Si Ogham est "special" → **+5% score**.
Sinon → **0% bonus**.

**Source code** : `minigame_registry.gd:32-41`

#### 2.2.4 `TAG_FIELD_MAP` — Détection par tag narratif

| Tag narratif | Champ | Exemple |
|--------------|-------|---------|
| combat | finesse | Carte de combat |
| danger | finesse | Situation périlleuse |
| stranger | bluff | Rencontre d'un étranger |
| social | bluff | Interaction sociale |
| mystery | logique | Énigme |
| magic | logique | Magie / runes |
| exploration | observation | Exploration |
| nature | observation | Nature |
| choice | chance | Moment de destin |
| strength | vigueur | Force physique |
| willpower | esprit | Résistance mentale |
| stealth | perception | Furtivité |
| tracking | perception | Suivi / piste |

**21 mappings au total** : `minigame_registry.gd:46-71`

### 2.3 API du registre

#### `detect_field(narrative_text: String, gm_hint: String = "", tags: Array = []) -> String`

**Détecte le champ lexical** dominant dans un texte narratif.

**Priorités** (ordre d'application) :
1. **GM hint** : Si fourni et valide → retour immédiat
2. **Tags narratifs** : Si tags fournis → recherche dans `TAG_FIELD_MAP`
3. **Mots-clés du texte** : Analyse du texte brut pour comptage des mots-clés

**Exemple d'exécution** :
```gdscript
var field = MiniGameRegistry.detect_field(
    "Tu escalades la falaise, vertige...",  # narrative_text
    "",                                      # gm_hint (vide)
    ["danger", "exploration"]                # tags
)
# Résultat : "danger" → tag_field_map["danger"] = "finesse"
```

**Algorithme de détection par texte** :
```gdscript
scores = {"chance": 0, "bluff": 0, ..., "perception": 0}

for field in FIELDS:
    for keyword in FIELDS[field]:
        if lower_text.find(keyword) >= 0:
            scores[field] += 1

return field_with_highest_score  # Défaut: "chance"
```

**Source code** : `minigame_registry.gd:74-101`

#### `create_minigame(field: String, difficulty: int = 5, modifiers: Dictionary = {}) -> MiniGameBase`

**Crée une instance minigame** avec configuration.

**Paramètres** :
- `field` : Champ lexical ("chance", "bluff", etc.)
- `difficulty` : 1-10 (affecte la vitesse, la complexité)
- `modifiers` : Bonus Ogham, karma, etc.

**Processus** :
```gdscript
# 1. Si champ invalide → défaut "chance"
if not GAMES.has(field):
    field = "chance"

# 2. Sélection aléatoire parmi les minigames du champ
game_list = GAMES[field]
game_id = game_list[randi() % game_list.size()]

# 3. Préchargement script (match sur game_id)
game = preload("res://scripts/minigames/mg_de_du_destin.gd").new()

# 4. Configuration
game.setup(difficulty, modifiers)

return game
```

**Source code** : `minigame_registry.gd:105-150`

#### `get_ogham_bonus(ogham_category: String, game_field: String) -> int`

**Calcule le bonus score** d'un Ogham pour un minigame.

```gdscript
bonus_field = OGHAM_FIELD_BONUS.get(ogham_category, "")

if bonus_field == game_field:
    return 10  # +10% score bonus

if ogham_category == "special":
    return 5   # +5% universel

return 0  # Pas de bonus
```

**Source code** : `minigame_registry.gd:154-160`

---

## 3. Détection du champ lexical

### 3.1 Flow complet de détection

```
Joueur choisit option "Escalader la falaise"
    ↓
Carte contient:
  - text: "Tu escalades une falaise escarpée, le vertige t'etreint..."
  - tags: ["danger", "exploration"]
    ↓
MiniGameRegistry.detect_field(text, "", tags)
    ↓
Etape 1: GM hint vide → passer
    ↓
Etape 2: Tags = ["danger", "exploration"]
  TAG_FIELD_MAP["danger"] = "finesse" ✓ (priorite 1)
  TAG_FIELD_MAP["exploration"] = "observation" (priorite 2)
  Retour: "finesse" (premier match)
    ↓
Champ = "finesse"
    ↓
Minigames du champ "finesse" : ["mg_tir_a_larc", "mg_lame_druide", "mg_pas_renard"]
Sélection aléatoire → "mg_tir_a_larc"
    ↓
Création instance + start()
```

### 3.2 Cas d'usage: détection par texte seul

Si **pas de tags** fournis :

```gdscript
detect_field("Tu cueilles les herbes rares du marais...", "", [])
    ↓
Texte comporte: "cueillir" (dans FIELDS["chance"])
Score["chance"] = 1, autres = 0
    ↓
Retour: "chance"
```

### 3.3 Cas d'usage: hint du GM

Si le LLM/GM fournit un **hint explicite** :

```gdscript
detect_field("Tu observes les empreintes...", "perception", [])
    ↓
gm_hint = "perception" ✓ (valide)
    ↓
Retour immédiat: "perception" (skip texte et tags)
```

---

## 4. Catalogue détaillé des minigames par champ

### 4.1 Champ: **CHANCE** (3 minigames)

#### `mg_de_du_destin` (T1 — Fallback)

**Description** : Le joueur lance un dé magique. Entre 1-3 pour échec, 4-6 pour succès.

**Mécanique** :
- Écran avec dé animé
- Clic ou espacementr → lancer
- Résultat simple : 1-50% score ou 51-100% score
- Durée : ~5-10s

**Difficultés intégrées** :
- D1-3 : simple (dé lent)
- D4-7 : moyen (dé rapide)
- D8-10 : complexe (plusieurs dés?)

**Source** : `scripts/minigames/mg_de_du_destin.gd`

#### `mg_pile_ou_face` (T1)

**Description** : Lancer une pièce. Prédire le résultat avant qu'il n'apparaisse.

**Mécanique** :
- Joueur choisit pile ou face
- Pièce tourne, révèle résultat
- Succès: score élevé (70-100)
- Échec: score bas (0-30)
- 1-2 secondes

**Difficultés intégrées** :
- Pièce tourne lentement (D1) ou rapidement (D10)

**Source** : `scripts/minigames/mg_pile_ou_face.gd`

#### `mg_roue_fortune` (T2)

**Description** : Une roue de fortune avec secteurs colorés (bonus/malus). Le joueur doit arrêter la roue sur le bon secteur.

**Mécanique** :
- Roue qui tourne
- Clic pour arrêter (timing)
- Positionnement détermine le score
- 10-20s

**Difficultés intégrées** :
- Roue tourne lentement (D1) ou très rapidement (D10)
- Nombre de secteurs augmente

**Source** : `scripts/minigames/mg_roue_fortune.gd`

### 4.2 Champ: **BLUFF** (3 minigames)

#### `mg_joute_verbale` (T1)

**Description** : Dialogue rapide avec des répliques. Le joueur doit choisir les bonnes répliques parmi 3 options.

**Mécanique** :
- Texte du PNJ affiché
- 3 répliques proposées
- Joueur choisit la meilleure (timing)
- 4 échanges = 4 tours
- Score basé sur qualité des choix

**Difficultés intégrées** :
- Répliques plus évidentes (D1) ou subtiles (D10)
- Temps de réponse réduit (D8+)

**Source** : `scripts/minigames/mg_joute_verbale.gd`

#### `mg_bluff_druide` (T2)

**Description** : Un druide teste votre sincérité. Vous devez mentir de façon convaincante.

**Mécanique** :
- 3 questions posées
- Répondre vrai ou faux (bluff)
- Cohérence interne évaluée
- Score basé sur convainquement

**Difficultés intégrées** :
- Questions plus ou moins évidentes
- Druide peut détecter (mécanisme d'intuition)

**Source** : `scripts/minigames/mg_bluff_druide.gd`

#### `mg_negociation` (T2)

**Description** : Marchander avec un PNJ. Proposer un prix qui équilibre profit et acceptation.

**Mécanique** :
- Objet à vendre avec prix initial
- Slider de prix à proposer
- PNJ accepte ou refuse selon la gamme
- 1-3 tours de négociation

**Difficultés intégrées** :
- Fourchette de prix acceptée plus ou moins large
- Attentes du PNJ moins connues (D8+)

**Source** : `scripts/minigames/mg_negociation.gd`

### 4.3 Champ: **OBSERVATION** (3 minigames)

#### `mg_oeil_corbeau` (T2)

**Description** : Observer une scène riche en détails. Retrouver des éléments spécifiques cachés.

**Mécanique** :
- Image stylisée du biome affichée
- Liste d'éléments à trouver (ex: une amulette, une rune)
- Clic pour pointer (doit être à proximité correcte)
- Score basé sur nombre trouvés en temps limité (20-30s)

**Difficultés intégrées** :
- Plus/moins d'objets cachés
- Objets plus subtils (couleurs proches)

**Source** : `scripts/minigames/mg_oeil_corbeau.gd`

#### `mg_trace_cerf` (T3)

**Description** : Suivre les empreintes d'un cerf sur le sol. Le chemin est sinueux et parfois cryptique.

**Mécanique** :
- Piste visuelle de traces animales
- Joueur doit suivre en cliquant les mailles correctes
- Les mauvais chemins mènent à des impasses
- Score = pourcentage de piste correcte

**Difficultés intégrées** :
- Piste plus/moins claire
- Traces partielles effacées (D8+)

**Source** : `scripts/minigames/mg_trace_cerf.gd`

#### `mg_rune_cachee` (T3)

**Description** : Une rune mystérieuse est cachée dans un paysage. Localiser sa position exacte en analysant l'environnement.

**Mécanique** :
- Paysage 3D stylisé
- Indices auditifs/visuels guident vers la rune
- Joueur clique pour fouiller
- Score basé sur précision (distance du clic à la rune)

**Difficultés intégrées** :
- Indices plus/moins clairs
- Zone de fouille plus grande (D8+)

**Source** : `scripts/minigames/mg_rune_cachee.gd`

### 4.4 Champ: **LOGIQUE** (3 minigames)

#### `mg_pierre_feuille_racine` (T1)

**Description** : Pierre-Feuille-Ciseaux celtique. 3 manches contre une IA.

**Mécanique** :
- Règle: Pierre > Racine > Feuille > Pierre (modification du RPS classique)
- 3 manches
- Score = (manches gagnées / 3) × 100

**Difficultés intégrées** :
- IA joue aléatoirement (D1-7) ou avec pattern awareness (D8+)

**Source** : `scripts/minigames/mg_pierre_feuille_racine.gd`

#### `mg_enigme_ogham` (T2)

**Description** : Résoudre une énigme liée aux Oghams.

**Mécanique** :
- Énigme texte générée ou pré-écrite
- 4 réponses proposées
- 1 seule bonne réponse
- Score = 100 (succès) ou 0 (échec)
- ~15-30s pour réfléchir

**Difficultés intégrées** :
- Énigmes plus/moins obscures
- Réponses plus/moins ambiguës

**Source** : `scripts/minigames/mg_enigme_ogham.gd`

#### `mg_noeud_celtique` (T3)

**Description** : Résoudre un nœud celtique entrelacé. Tracer le chemin correct à travers les spirales.

**Mécanique** :
- Nœud celtique dessiné
- Joueur clique pour tracer le chemin (éviter impasses)
- Score = pourcentage du chemin correctement tracé
- Temps limité (20-30s)

**Difficultés intégrées** :
- Nœuds plus simples (4 spirales, D1) à complexes (12+ spirales, D10)

**Source** : `scripts/minigames/mg_noeud_celtique.gd`

### 4.5 Champ: **FINESSE** (3 minigames)

#### `mg_tir_a_larc` (T1)

**Description** : Tirer une flèche sur une cible. Viser et déclencher au bon moment.

**Mécanique** :
- Cible affichée
- Arc avec curseur qui oscille
- Clic pour tirer
- Score basé sur position de la flèche sur la cible (bullseye = 100)
- Variantes: vent, distance, mouvement cible

**Difficultés intégrées** :
- Curseur oscille lentement (D1) ou rapidement (D10)
- Cible peut se déplacer (D7+)

**Source** : `scripts/minigames/mg_tir_a_larc.gd`

#### `mg_lame_druide` (T3)

**Description** : Combat de danse au sabre avec un druide. Esquiver et frapper au bon rythme.

**Mécanique** :
- Séquence de mouvements attendus (haut, bas, droite, gauche)
- QTE : Joueur doit reproduire la séquence
- Score basé sur précision temporelle
- Durée: 20-30s

**Difficultés intégrées** :
- Séquences plus longues (D1=3 mouvements, D10=8+ mouvements)
- Fenêtre de timing plus serrée (D8+)

**Source** : `scripts/minigames/mg_lame_druide.gd`

#### `mg_pas_renard` (T3)

**Description** : Se faufiler furtivement à travers des pièges et des patrolles. Équilibre entre vitesse et discrétion.

**Mécanique** :
- Vue de haut (top-down)
- Personnage bouge parmi obstacles/patrouilles
- WASD ou souris pour se déplacer
- Score basé sur vitesse de completion + nombre de détections (malus)
- Durée: 30-45s

**Difficultés intégrées** :
- Plus/moins d'obstacles
- Patrouilles plus attentives (D8+)

**Source** : `scripts/minigames/mg_pas_renard.gd`

### 4.6 Champ: **VIGUEUR** (3 minigames)

#### `mg_combat_rituel` (T3)

**Description** : Combat rituel dans un cercle sacré. Timing des coups et défenses.

**Mécanique** :
- Adversaire attaque en patterns
- QTE pour esquiver (flèches directionnelles)
- QTE pour contre-attaquer
- 3-4 rounds
- Score = combos réussis × multiplicateur de dégâts

**Difficultés intégrées** :
- Patterns d'attaque plus complexes
- Fenêtre d'esquive plus serrée (D8+)

**Source** : `scripts/minigames/mg_combat_rituel.gd`

#### `mg_sang_froid` (T3)

**Description** : Maintenir une concentration malgré une pulsation cardiaque qui s'accélère. Curseur doit rester stable.

**Mécanique** :
- Curseur horizontal avec oscillation aléatoire
- Joueur maintient la touche spacebar
- Le curseur bouge indépendamment (dérives aléatoires)
- Score = temps stable sans dérives
- Durée: 10-20s

**Difficultés intégrées** :
- Amplitude d'oscillation plus grande (D8+)
- Accélération progressive des dérives (D10)

**Source** : `scripts/minigames/mg_sang_froid.gd`

#### `mg_course` (T3)

**Description** : Courir dans une direction en maintenant la vitesse. QTE pour sauter obstacles.

**Mécanique** :
- Écran de parcours (obstacles apparaissent)
- Spacebar pour sauter
- Timing des sauts critique
- Score basé sur distance parcourue sans collision
- Durée: 20-30s

**Difficultés intégrées** :
- Obstacles plus rapprochés
- Personnage accélère (D8+)

**Source** : `scripts/minigames/mg_course.gd`

### 4.7 Champ: **ESPRIT** (3 minigames)

#### `mg_volonte` (T3)

**Description** : Résister aux murmures d'esprits qui essaient de vous distraire. Maintenir la concentration.

**Mécanique** :
- Texte/voix de murmures apparaît
- Joueur doit rester concentré (pas de clic, pas de mouvement)
- Distraction = perte de points
- Score = durée maintenue sans distraction
- Durée: 15-25s

**Difficultés intégrées** :
- Murmures plus intenses/fréquents (D8+)
- Pop-ups de distraction supplémentaires

**Source** : `scripts/minigames/mg_volonte.gd`

#### `mg_apaisement` (T3)

**Description** : Apaiser un gardien/créature par le rythme. Cliquer au bon tempo.

**Mécanique** :
- Créature/gardien affichée avec barre d'apaisement
- Clic en rythme (battement de cœur stylisé)
- Bonne cadence = apaisement
- Mauvaise cadence = escalade
- Score = barre remplie / temps

**Difficultés intégrées** :
- Tempo augmente progressivement
- Créature devient plus agitée (impulsions aléatoires)

**Source** : `scripts/minigames/mg_apaisement.gd`

#### `mg_meditation` (T3)

**Description** : Méditer pour accéder à une vision. Atteindre l'équilibre mental (2D cursor balancé).

**Mécanique** :
- Cursor 2D au centre de l'écran
- Champs de force poussent le curseur (turbulences mentales)
- Joueur clique pour re-centrer
- Score = temps maintenu au centre
- Durée: 20-30s

**Difficultés intégrées** :
- Forces mentales plus chaotiques (D8+)
- Zone de centre plus petite

**Source** : `scripts/minigames/mg_meditation.gd`

### 4.8 Champ: **PERCEPTION** (3 minigames)

#### `mg_ombres` (T3)

**Description** : Se déplacer entre les ombres sans être vu. Éviter les zones éclairées.

**Mécanique** :
- Environnement avec zones d'ombre/lumière
- Joueur clique pour se déplacer d'ombre en ombre
- Si détecté en zone lumière = malus
- Score basé sur chemin pris sans détection
- Durée: 20-30s

**Difficultés intégrées** :
- Moins d'ombres disponibles (D8+)
- Patrouilles de lumière se rapprochent

**Source** : `scripts/minigames/mg_ombres.gd`

#### `mg_regard` (T3)

**Description** : Observer et mémoriser une séquence de symboles. Les reproduire après.

**Mécanique** :
- Séquence de 3-6 symboles affichée (2-3 secondes)
- Symboles disparaissent
- Joueur doit cliquer les symboles dans le bon ordre
- Score = précision de reproduction
- Durée: 10-20s

**Difficultés intégrées** :
- Séquence plus longue (D1=3, D10=8+)
- Symboles similaires (formes proches)

**Source** : `scripts/minigames/mg_regard.gd`

#### `mg_echo` (T3)

**Description** : Suivre un son (écho mystique) vers sa source. Intensité du son guide.

**Mécanique** :
- Écran noir avec barre d'intensité sonore
- Joystick/WASD pour se déplacer
- Intensité augmente quand approche source
- Clic quand intensité = maximum
- Score basé sur nombre de fois trouvé la source (3 sources)
- Durée: 20-30s

**Difficultés intégrées** :
- Intensité moins linéaire (courbe erratique)
- Sources bougent légèrement

**Source** : `scripts/minigames/mg_echo.gd`

---

## 5. Classe de base: `MiniGameBase`

### 5.1 Structure

```gdscript
class_name MiniGameBase extends Control

signal game_completed(result: Dictionary)

var _difficulty: int = 5
var _modifiers: Dictionary = {}
var _started: bool = false
var _finished: bool = false
var _start_time_ms: int = 0

var _in_card_mode: bool = false
var _card_host: Control = null
```

### 5.2 API

#### `setup(difficulty: int, modifiers: Dictionary = {}) -> void`

Configure le minigame avant démarrage.

**Paramètres** :
- `difficulty` : 1-10 (appliqué avant le start)
- `modifiers` : Dict optionnel (bonus Ogham, etc.)

```gdscript
func setup(difficulty: int, modifiers: Dictionary = {}) -> void:
    _difficulty = clampi(difficulty, 1, 10)
    _modifiers = modifiers
```

#### `setup_in_card(host: Control) -> void`

Attache le minigame dans le body de la carte (lieu affichage).

```gdscript
func setup_in_card(host: Control) -> void:
    _in_card_mode = true
    _card_host = host
    host.add_child(self)
```

#### `start() -> void`

Lance le minigame (appelé par le controller de carte).

```gdscript
func start() -> void:
    _started = true
    _finished = false
    _start_time_ms = Time.get_ticks_msec()
    _on_start()  # Appelé par subclasse
```

#### `_on_start() -> void`

**Virtuelle** — Override dans les subclasses pour construire l'UI.

```gdscript
func _on_start() -> void:
    # Override in subclasses
    pass
```

#### `_unhandled_input(event: InputEvent) -> void`

Capture les inputs clavier (pas souris).

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if _finished:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        _on_key_pressed(event.keycode)
```

#### `_on_key_pressed(keycode: int) -> void`

**Virtuelle** — Override pour traiter les touches.

#### `_complete(success: bool, score: int) -> void`

**Finalize le minigame** et émet le signal.

**Processus** :
1. Clamp score 0-100
2. Appliquer bonus Ogham (`_modifiers["score_bonus"]`)
3. Jouer SFX (succès/échec)
4. Émettre signal `game_completed`
5. Fade out et queue_free

```gdscript
func _complete(success: bool, score: int) -> void:
    if _finished:
        return
    _finished = true
    var elapsed: int = Time.get_ticks_msec() - _start_time_ms

    # Bonus Ogham
    var bonus: int = int(_modifiers.get("score_bonus", 0))
    score = clampi(score + bonus, 0, 100)

    var result := {"success": success, "score": score, "time_ms": elapsed}

    # SFX
    var sfx := get_node_or_null("/root/SFXManager")
    if sfx and sfx.has_method("play"):
        if success:
            sfx.play("minigame_success")
        else:
            sfx.play("minigame_fail")

    game_completed.emit(result)

    # Fade out
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.3)
    tw.tween_callback(queue_free)
```

### 5.3 Palette de couleurs

```gdscript
const MG_PALETTE := {
    "bg": Color(0.06, 0.12, 0.06, 0.95),      # Vert très sombre (CRT)
    "ink": Color(0.20, 1.00, 0.40),            # Vert clair (texte)
    "accent": Color(1.00, 0.75, 0.20),         # Orange-or
    "gold": Color(1.00, 0.85, 0.40),           # Or clair
    "green": Color(0.20, 1.00, 0.40),          # Vert vif
    "red": Color(1.00, 0.25, 0.20),            # Rouge alerte
    "paper": Color(0.04, 0.08, 0.04),          # Noir papier
}
```

**Thème CRT monochromes** — Cohérent avec l'esthétique retro-futuriste du jeu.

### 5.4 Helpers d'UI

#### `_build_overlay() -> void`

Crée l'overlay de base (fond, rect, centering).

```gdscript
func _build_overlay() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    var bg := ColorRect.new()
    bg.color = MG_PALETTE.bg
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
```

#### `_make_label(text: String, font_size: int = 22, color: Color = MG_PALETTE.ink) -> Label`

Factory pour créer des labels stylisés.

#### `_make_button(text: String, callback: Callable) -> Button`

Factory pour créer des boutons stylisés.

#### `score_to_d20(score: int) -> int`

**Conversion score → D20** (utilisée rarement).

```gdscript
static func score_to_d20(score: int) -> int:
    if score <= 10:
        return 1
    elif score <= 25:
        return randi_range(2, 5)
    elif score <= 50:
        return randi_range(6, 10)
    elif score <= 75:
        return randi_range(11, 15)
    elif score <= 95:
        return randi_range(16, 19)
    else:
        return 20
```

---

## 6. Scoring et multiplicateurs

### 6.1 Table de multiplicateurs (MULTIPLIER_TABLE)

**Conversion score minigame → multiplicateur d'effets** :

| Plage | Label | Multiplicateur | Bonus Anam | Notes |
|-------|-------|:---:|:---:|---------|
| **0-20** | Échec critique | **×1.5** (négatif) | 0 | Effets négatifs intensifiés |
| **21-50** | Échec | **×1.0** (neutre) | 0 | Effets normalisés |
| **51-79** | Réussite partielle | **×0.5** | 0 | Effets positifs réduits |
| **80-100** | Réussite | **×1.0** | **+2** | Seuil bonus Anam à 80 inclus |
| **95-100** | Réussite critique | **×1.5** | **+2** | Tous les effets intensifiés |

**Exemple d'application** :
```
Carte propose: +15 reputation Druides
Joueur score: 60 (réussite partielle)
Effet appliqué: +15 × 0.5 = +7.5 reputation
```

### 6.2 Bonus Ogham sur le score

Si un **Ogham actif** booste le champ du minigame :

```gdscript
var bonus = MiniGameRegistry.get_ogham_bonus(ogham_category, field)
final_score = min(score + bonus, 100)
```

**Exemple** :
```
Ogham actif: "boost" (catégorie)
Champ minigame: "finesse"
OGHAM_FIELD_BONUS["boost"] = "finesse" ✓
Bonus: +10 points

Joueur score 75 → 75 + 10 = 85 (réussite)
```

### 6.3 Application des multiplicateurs dans le pipeline

**Étape 6 du pipeline (EFFET)** :

```gdscript
# 1. LLM GM suggère des effets
effects = [
    {"type": "ADD_REPUTATION", "faction": "druides", "amount": 15},
    {"type": "DAMAGE_LIFE", "amount": 10}
]

# 2. Minigame joué → score obtenu
minigame_score = 65  # Réussite partielle

# 3. Calculer multiplicateur
multiplier = get_multiplier(minigame_score)  # → 0.5

# 4. Appliquer multiplicateur
for effect in effects:
    if effect["type"] == "ADD_REPUTATION":
        effect["amount"] *= multiplier  # 15 × 0.5 = 7.5
    elif effect["type"] == "DAMAGE_LIFE":
        effect["amount"] *= multiplier  # 10 × 0.5 = 5

# 5. Appliquer les effets modifiés
apply_effects(effects)
```

---

## 7. Difficulté semi-adaptive

### 7.1 Calcul de difficulté

La difficulté est **pré-calculée** avant que le joueur ne joue. Pas d'adaptation basée sur la performance.

**Formule** :
```gdscript
difficulty = 5  # Défaut

# Modificateur par biome
difficulty += BIOME_MODIFIERS[biome]  # -1 à +3

# Modificateur par type de carte
if card_type == "event":
    difficulty += 1
# Merlin Direct: pas de minigame

# Modificateur par progression (nombre de cartes jouées)
if cards_played >= 30:
    difficulty += 1
if cards_played >= 50:
    difficulty += 1

# Multiplicateur Ogham (pas d'ajustement, bonus direct au score)

difficulty = clampi(difficulty, 1, 10)
```

### 7.2 Modificateurs par biome

| Biome | Modificateur | Raison |
|-------|:---:|---------|
| Forêt de Broceliande | -1 | Biome d'accueil (facile) |
| Landes de Bruyère | 0 | Équilibré |
| Côtes Sauvages | 0 | Équilibré |
| Villages Celtes | -1 | Biome social (facile) |
| Cercles de Pierres | +1 | Biome mystique |
| Marais des Korrigans | +2 | Biome piégé |
| Collines aux Dolmens | 0 | Équilibré |
| Îles Mystiques | +3 | Biome final (difficile) |

### 7.3 Modificateurs par type de carte

| Type | Modificateur | Notes |
|------|:---:|---------|
| Narrative | 0 | Défaut |
| Événement | +1 | Enjeu élévé |
| Promesse | +1 | Quête importante |
| Merlin Direct | N/A | Pas de minigame |

### 7.4 Modificateurs par progression

| Cartes jouées | Modificateur supplémentaire |
|:---:|:---:|
| 0-29 | 0 |
| 30-49 | +1 |
| 50+ | +2 |

---

## 8. Intégration dans le pipeline de carte

### 8.1 Pipeline complet (13 étapes)

Le minigame est l'**étape 5 du pipeline** :

```
1. DRAIN_LIFE          : -1 PV au début de la carte
2. CARTE_AFFICHEE      : Texte + 3 options visibles
3. OGHAM?              : Joueur peut activer Ogham avant choix
4. CHOIX               : Joueur sélectionne une option
5. MINIGAME ⭐         : Exécution du minigame → score
6. SCORE               : Calcul multiplicateur (0-100)
7. EFFETS              : Application des effets (×multiplicateur)
8. PROTECTION          : Vérifier protections (Oghams)
9. VIE=0?              : Vérifier mort
10. PROMESSES          : Vérifier expirations
11. COOLDOWN           : Gérer cooldowns Oghams
12. RETOUR_3D          : Fade in de la scène 3D
13. LOG_HISTOIRE       : Logger la carte jouée
```

**Références** :
- `docs/GAME_DESIGN_BIBLE.md` section 13.3 (Pipeline effet)
- `scripts/merlin/merlin_card_system.gd` (implémentation)

### 8.2 Détails de l'étape 5 (MINIGAME)

```gdscript
# 4. Joueur a choisi une option
selected_option = card.options[chosen_index]

# 5. MINIGAME
field = MiniGameRegistry.detect_field(
    selected_option["label"],  # Texte d'action
    "",                         # GM hint (optionnel)
    card.get("tags", [])        # Tags narratifs
)

difficulty = calculate_difficulty(biome, card.type, cards_played)

modifiers = {
    "score_bonus": MiniGameRegistry.get_ogham_bonus(active_ogham.category, field)
}

minigame = MiniGameRegistry.create_minigame(field, difficulty, modifiers)
minigame.setup_in_card(card_body)
minigame.start()

# Attendre completion
var result = await minigame.game_completed
minigame_score = result["score"]
minigame_success = result["success"]
```

### 8.3 Intégration UI

**Pendant l'affichage de la carte** :

```
┌──────────────────────────────────────┐
│ [♥ 75/100]                 [🌿 x12] │
│ [📜 1/2]                  [⚬ Beith] │
│                                      │
│    [TEXTE NARRATIF]                  │
│                                      │
│  ← Refuser               Accepter →  │
│     [Preview]              [Preview] │
└──────────────────────────────────────┘
        ↓ (Joueur clique)
     MINIGAME OVERLAY
     (écran plein, 2D)
        ↓ (Complété)
     Fade out minigame
     Appliquer effets
     Retour 3D
```

---

## 9. Modifier le système (guide développeur)

### 9.1 Ajouter un nouveau minigame

**Étapes** :

1. **Créer le script** : `scripts/minigames/mg_mon_minigame.gd`
   ```gdscript
   extends MiniGameBase

   func _on_start() -> void:
       _build_overlay()
       # TODO: construire UI

   func _on_key_pressed(keycode: int) -> void:
       # TODO: logique input
       pass

   # À la fin:
   _complete(success: bool, score: int)
   ```

2. **Enregistrer dans registry** : Ajouter à `GAMES` :
   ```gdscript
   const GAMES := {
       "chance": ["mg_de_du_destin", ..., "mg_mon_minigame"],
   }
   ```

3. **Tester** :
   ```gdscript
   var minigame = MiniGameRegistry.create_minigame("chance", 5)
   add_child(minigame)
   minigame.start()
   await minigame.game_completed
   ```

### 9.2 Modifier la détection de champ

**Ajouter des mots-clés** :
```gdscript
const FIELDS := {
    "chance": [..., "nouvelle_cle", ...],
}
```

**Ajouter un tag narratif** :
```gdscript
const TAG_FIELD_MAP := {
    ...,
    "nouveau_tag": "champ_correspondant",
}
```

### 9.3 Modifier les multiplicateurs

**Dans `merlin_effect_engine.gd`** :
```gdscript
func get_multiplier(score: int) -> float:
    if score <= 20:
        return 1.5  # Échec critique
    # ... etc
```

### 9.4 Modifier la difficulté

**Dans le controller de carte** :
```gdscript
func calculate_difficulty(biome: String, card_type: String, cards_played: int) -> int:
    var diff = 5
    diff += BIOME_MODS.get(biome, 0)
    # ... ajuster formule
    return clampi(diff, 1, 10)
```

---

## 10. État actuel & limitations

### 10.1 Minigames implémentés (24)

| Champ | Nombre | État |
|-------|:---:|---------|
| chance | 3 | ✓ Complétés |
| bluff | 3 | ✓ Complétés |
| observation | 3 | ✓ Complétés |
| logique | 3 | ✓ Complétés |
| finesse | 3 | ✓ Complétés |
| vigueur | 3 | ✓ Complétés |
| esprit | 3 | ✓ Complétés |
| perception | 3 | ✓ Complétés |

**Objectif** : 15+ minigames uniques → atteint avec 24.

### 10.2 Limitation connues

| Limitation | Impact | Workaround |
|-----------|--------|-----------|
| Pas d'adaptation difficulté temps réel | Score fixe dès le start | Prévu pour fairness |
| Minigames T1-T3 mal différenciés | Peu de progression | À revoir après playtest |
| Aucun minigame de type "construction" | Gameplay monotone | Ajouter puzzle/building game |
| Pas de cross-field minigames | Champ rigide | Explorer hybrides après v1.0 |

### 10.3 Prochaines améliorations (post-MVP)

- [ ] Ajouter 3-5 minigames supplémentaires (construction, puzzle 3D, etc.)
- [ ] Implémenter minigame "story branching" (choix pendant le jeu affecte le score)
- [ ] Difficulté adaptative fine-grained per-player
- [ ] Leaderboard local per-minigame
- [ ] Cosmétiques déblocables (skins minigames)
- [ ] Audio dynamique (BPM augmente avec difficulté)

---

## 11. Références croisées

### Code

- `scripts/minigames/minigame_registry.gd` — Registre et API
- `scripts/minigames/minigame_base.gd` — Classe de base
- `scripts/minigames/mg_*.gd` — Implémentations individuelles
- `scripts/merlin/merlin_card_system.gd` — Intégration pipeline
- `scripts/merlin/merlin_effect_engine.gd` — Application des multiplicateurs

### Documentation

- `docs/GAME_DESIGN_BIBLE.md` section 2.5 — Design complet
- `docs/GAME_DESIGN_BIBLE.md` section 13.3 — Pipeline effet
- `docs/70_graphic/UI_UX_BIBLE.md` — Palette CRT minigames
- `docs/20_card_system/DOC_09_Effect_Whitelist.md` — Effets autorisés

### Assets

- Aucun asset audio/visuel spécifique (UI générée procedurally)
- Palette CRT : `MG_PALETTE` dans `minigame_base.gd`

---

## Glossaire

| Terme | Définition |
|-------|-----------|
| **Champ lexical** | Catégorie sémantique détectée dans le texte narratif (8 au total) |
| **Minigame** | Micro-jeu d'épreuve résolvant une action narrative |
| **Difficulté** | 1-10, pré-calculée selon contexte narratif |
| **Multiplicateur** | Facteur appliqué aux effets selon le score minigame |
| **Score** | 0-100, résultat du minigame |
| **Bonus Ogham** | +10% ou +5% score si Ogham actif correspond au champ |
| **Registry** | Dict statique mappant champs → minigames |
| **CRT** | Cathode Ray Tube — style rétro monochromes vert/or |
| **Fallback** | `mg_de_du_destin` par défaut si champ invalide |

---

**Document généré**: 2026-03-15
**Auteur**: Documentation System
**Statut**: Complet et validé
**Prochaine révision**: Après feedback playtest v1.0

