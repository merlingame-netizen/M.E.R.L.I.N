> **[ARCHIVED — superseded by docs/GAME_DESIGN_BIBLE.md (2026-03-12)]**
> Ce document n'est plus la source de verite. Voir GAME_DESIGN_BIBLE.md.

# DOC 12 — Systeme des Triades (Core Gameplay v2)

*Document cree: 2026-02-08*
*Status: DESIGN VALIDE - En attente implementation*

---

## Vision

Le systeme Merlin est base sur les **Triades Celtiques**:
- 3 aspects au lieu de 4 jauges
- 3 etats discrets au lieu de valeurs 0-100
- 3 options par carte au lieu de 2
- Objectif + survie au lieu de survie pure

**Philosophie:** Le joueur incarne un druide qui doit maintenir l'equilibre entre Corps, Ame et Monde tout en accomplissant une mission.

---

## PARTIE 1: Les 3 Aspects

### 1.1 Corps, Ame, Monde

| Aspect | Symbole | Animal | Theme |
|--------|---------|--------|-------|
| **Corps** | Spirale | Sanglier | Force physique, endurance, sante |
| **Ame** | Triskell | Corbeau | Esprit, magie, equilibre mental |
| **Monde** | Croix celtique | Cerf | Relations, reputation, harmonie sociale |

### 1.2 Les 3 Etats par Aspect

Chaque aspect a exactement **3 etats** — pas de chiffres intermediaires:

| Aspect | Etat Bas | Etat Equilibre | Etat Haut |
|--------|----------|----------------|-----------|
| **Corps** | Epuise | Robuste | Surmene |
| **Ame** | Perdue | Centree | Possedee |
| **Monde** | Exile | Integre | Tyran |

### 1.3 Transitions d'Etat

Les effets des cartes font **monter** ou **descendre** d'un etat:

```
      Epuise ←——— Robuste ———→ Surmene
         ▲           |           ▲
         |           |           |
      [descente]  [stable]   [montee]
```

**Regles:**
- Un aspect ne peut pas "sauter" un etat (Epuise → Surmene impossible)
- Rester en Equilibre ne declenche pas de transition
- Certains effets puissants peuvent forcer 2 transitions (rare)

### 1.4 Visualisation (Symboles Celtiques)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   CORPS            AME             MONDE                    │
│   [🐗]             [🐦‍⬛]           [🦌]                      │
│                                                             │
│   ○ ● ○            ○ ○ ●           ● ○ ○                    │
│   Robuste         Possedee         Exile                    │
│                                                             │
│   Spirale          Triskell        Croix                    │
│   ━━━○━━━          ━━━━━●          ●━━━━━                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Design UI:**
- 3 cercles par aspect (representant Bas/Equilibre/Haut)
- Le cercle actif est rempli (●), les autres sont vides (○)
- Symbole animal au-dessus
- Animation: cercle pulse doucement, transition = flash

---

## PARTIE 2: Les 3 Options par Carte

### 2.1 Structure des Choix

Chaque carte propose **3 options** avec des labels ultra-courts:

| Position | Nom | Description | Cout |
|----------|-----|-------------|------|
| **Gauche** | Action directe | Simple, consequences claires | Gratuit |
| **Centre** | Action sage | Equilibree, souvent neutre | 1 Souffle |
| **Droite** | Action risquee | Audacieuse, consequences extremes | Gratuit |

### 2.2 Exemple de Carte

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Un druide noir te barre le chemin. Derriere lui,          │
│   des villageois ligotes attendent leur sort."              │
│                                                             │
│                        — MERLIN                              │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   [A] FUIR        [B] PARLEMENTER     [C] ATTAQUER         │
│                        (1🌀)                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Labels:** 1-2 mots maximum (FUIR, PARLEMENTER, ATTAQUER)

### 2.3 Impacts Invisibles

**Principe cle:** Le joueur ne voit PAS les impacts avant de choisir.

- Les effets sont decides par le LLM
- Ils sont caches au joueur
- Exception: outils/enchantements revelent les impacts

**Exemple interne (invisible au joueur):**
```json
{
    "options": [
        {"label": "FUIR", "effects": [{"aspect": "Monde", "direction": "down"}]},
        {"label": "PARLEMENTER", "cost": 1, "effects": []},
        {"label": "ATTAQUER", "effects": [
            {"aspect": "Corps", "direction": "down"},
            {"aspect": "Ame", "direction": "up"}
        ]}
    ]
}
```

### 2.4 Controles Multi-Plateformes

| Plateforme | Gauche | Centre | Droite |
|------------|--------|--------|--------|
| **Mobile** | Swipe gauche | Tap carte | Swipe droite |
| **PC** | Fleche gauche | Fleche haut | Fleche droite |
| **Console** | A | B | C (ou X/Y/B) |

---

## PARTIE 3: Souffle d'Ogham

### 3.1 Definition

Le **Souffle d'Ogham** est la ressource qui permet de choisir l'option Centre.

| Propriete | Valeur |
|-----------|--------|
| Maximum | 7 |
| Depart | 3 |
| Cout Centre | 1 Souffle |

### 3.2 Regeneration

Le Souffle se regenere si les **3 aspects sont equilibres** apres un choix:

```gdscript
func _after_choice():
    if corps == "Robuste" and ame == "Centree" and monde == "Integre":
        souffle = min(souffle + 1, 7)
```

**Strategie:** Le joueur est incentive a maintenir l'equilibre pour regenerer ses Souffles.

### 3.3 Souffle Vide + Option Centre

Que se passe-t-il si le joueur veut choisir Centre mais n'a plus de Souffle?

**Regle:** L'option reste disponible mais comporte un **risque**.

```
[PARLEMENTER] ← (0🌀 - RISQUE!)
```

**Mecanisme de risque:**
- 50% chance: Effet normal de l'option Centre
- 25% chance: Effet + 1 aspect descend aleatoirement
- 25% chance: Effet + 1 aspect monte aleatoirement

### 3.4 Visualisation du Souffle

```
┌───────────────────────────────────────┐
│   SOUFFLE D'OGHAM                     │
│   🌀 🌀 🌀 🌀 🌀 ○ ○   (5/7)           │
└───────────────────────────────────────┘
```

- Spirales pleines = Souffles disponibles
- Cercles vides = Souffles manquants
- Animation de regeneration: spirale apparait avec rotation

---

## PARTIE 4: Conditions de Fin

### 4.1 Double Condition: Objectif + Survie

La partie se termine de deux facons:

#### A. Mort (Echec de Survie)

**Trigger:** 2 aspects en etat extreme (Bas OU Haut)

| Aspect 1 Extreme | Aspect 2 Extreme | Fin |
|------------------|------------------|-----|
| Corps Bas | Ame Basse | La Mort Oubliee |
| Corps Bas | Ame Haute | Le Sacrifice Vain |
| Corps Bas | Monde Bas | L'Abandon Total |
| Corps Bas | Monde Haut | L'Usurpation |
| Corps Haut | Ame Basse | La Bete Sauvage |
| Corps Haut | Ame Haute | L'Ascension Folle |
| Corps Haut | Monde Bas | Le Solitaire |
| Corps Haut | Monde Haut | Le Conquerant |
| Ame Basse | Monde Bas | L'Errance Eternelle |
| Ame Basse | Monde Haut | Le Pantin |
| Ame Haute | Monde Bas | Le Prophete Exile |
| Ame Haute | Monde Haut | La Possession Divine |

**12 fins negatives** en tout.

#### B. Victoire (Objectif Atteint)

**Trigger:** Accomplir la mission de la run

**Missions possibles (generees par LLM):**
- Delivrer un message au cercle de pierres
- Trouver 3 ingredients pour un rituel
- Survivre jusqu'au festival de Samhain
- Reconcilier deux clans en conflit
- Resoudre le mystere du voyageur disparu

**Fins de victoire:**
| Type | Condition | Fin |
|------|-----------|-----|
| Victoire equilibree | Mission + 3 aspects equilibres | L'Harmonie |
| Victoire fragile | Mission + 1 aspect extreme | Le Prix Paye |
| Victoire sombre | Mission + karma negatif | La Victoire Amere |

### 4.2 Duree de Partie

| Cible | Cartes | Temps |
|-------|--------|-------|
| Partie courte | 15-20 | 5-7 min |
| Partie standard | 25-35 | 8-10 min |
| Partie longue (rare) | 40-50 | 12-15 min |

**Parametres pour 8-10 minutes:**
- 25-35 cartes par run
- 15-20 secondes par carte
- Mission revelee a la carte 3-5
- Climax autour de la carte 20-25

---

## PARTIE 5: Integration LLM

### 5.1 Contexte envoye au LLM

```json
{
    "aspects": {
        "corps": "Robuste",
        "ame": "Centree",
        "monde": "Exile"
    },
    "souffle": 5,
    "mission": {
        "type": "delivery",
        "target": "cercle_pierres",
        "progress": 2,
        "total": 3
    },
    "card_count": 12,
    "biome": "broceliande",
    "season": "automne",
    "hidden": {
        "karma": 15,
        "tension": 45,
        "faction_druides": 30
    }
}
```

### 5.2 Format de sortie LLM

```json
{
    "text": "Le druide noir te barre le chemin...",
    "speaker": "MERLIN",
    "options": [
        {
            "position": "left",
            "label": "FUIR",
            "effects": [
                {"aspect": "Monde", "direction": "down"}
            ],
            "narrative": "Tu tournes les talons..."
        },
        {
            "position": "center",
            "label": "PARLEMENTER",
            "cost": 1,
            "effects": [],
            "narrative": "Tu leves les mains en signe de paix..."
        },
        {
            "position": "right",
            "label": "ATTAQUER",
            "effects": [
                {"aspect": "Corps", "direction": "down"},
                {"aspect": "Ame", "direction": "up"}
            ],
            "narrative": "Tu invoques ton Ogham..."
        }
    ],
    "mission_progress": false,
    "tags": ["druide_noir", "confrontation"]
}
```

### 5.3 Regles pour le LLM

**Labels:**
- Maximum 2 mots
- Verbe a l'infinitif de preference (FUIR, ATTAQUER, AIDER)
- Pas de ponctuation

**Effets:**
- Maximum 2 transitions par option
- L'option Centre doit etre "neutre" ou "equilibree"
- Les options Gauche/Droite doivent avoir des consequences claires

**Narrative:**
- 40-60 mots maximum pour le texte principal
- 10-20 mots pour chaque narrative de choix

---

## PARTIE 6: Outils et Enchantements

### 6.1 Reveler les Impacts

Certains outils/skills permettent de voir les impacts:

| Outil | Effet | Source |
|-------|-------|--------|
| **Vision du Corbeau** | Revele tous les impacts | Ogham "fearn" |
| **Intuition** | Revele 1 impact aleatoire | Bestiole bond > 70 |
| **Presage** | Revele si un aspect va changer | Biome Cercles |

### 6.2 Modifier les Options

| Enchantement | Effet | Source |
|--------------|-------|--------|
| **Force du Sanglier** | Option Gauche sans consequence Corps | Ogham "duir" |
| **Sagesse du Cerf** | Option Centre gratuite (1 fois) | Ogham "coll" |
| **Vol du Corbeau** | Nouvelle option apparait | Ogham "luis" |

---

## PARTIE 7: Equilibrage

### 7.1 Frequence des Transitions

| Type de carte | Transition probable |
|---------------|---------------------|
| Narrative simple | 1 aspect, 1 direction |
| Dilemme | 2 aspects, directions opposees |
| Crise | 2 aspects, meme direction |
| Opportunite | 1 aspect positif OU risque gros |

### 7.2 Distribution par Run

Sur 30 cartes:
- 20 cartes = 1 transition
- 7 cartes = 2 transitions
- 3 cartes = 0 transition (Centre neutre)

### 7.3 Survie Moyenne

| Skill joueur | Cartes survie | Victoire rate |
|--------------|---------------|---------------|
| Debutant | 15-20 | 10% |
| Intermediaire | 25-35 | 40% |
| Expert | 35-50 | 70% |

---

## PARTIE 8: Migration depuis l'Ancien Systeme

### 8.1 Fichiers a Modifier

| Fichier | Changement |
|---------|------------|
| `dru_store.gd` | State structure: aspects + souffle + mission |
| `dru_card_system.gd` | 3 options, effets discrets |
| `dru_effect_engine.gd` | SHIFT_ASPECT au lieu de ADD_RESOURCE |
| `dru_llm_adapter.gd` | Nouveau format de prompt/response |
| `dru_constants.gd` | Nouvelles constantes (ASPECTS, ETATS) |
| `triade_game_ui.gd` | UI 3 options, symboles celtiques |

### 8.2 Nouveaux Effets

```gdscript
# Remplace ADD_RESOURCE/REMOVE_RESOURCE
{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}
{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"}

# Remplace SET_RESOURCE
{"type": "SET_ASPECT", "aspect": "Monde", "state": "Equilibre"}

# Nouveau
{"type": "USE_SOUFFLE", "amount": 1}
{"type": "ADD_SOUFFLE", "amount": 1}
{"type": "PROGRESS_MISSION", "step": 1}
```

### 8.3 Compatibilite Biomes

Les biomes existants s'adaptent:

| Biome | Aspect favorise | Modificateur |
|-------|-----------------|--------------|
| Broceliande | Ame | +1 Souffle si Ame equilibree |
| Landes | Corps | Transitions Corps moins frequentes |
| Cotes | Monde | Missions commerce bonus |
| Villages | Monde | Options sociales bonus |
| Cercles | Ame | Vision gratuite 1x/run |
| Marais | Corps | Risque Centre augmente |
| Collines | Tous | Regeneration Souffle x2 |

---

## Annexe: Glossaire

| Terme | Definition |
|-------|------------|
| **Aspect** | Corps, Ame, ou Monde |
| **Etat** | Bas, Equilibre, ou Haut |
| **Transition** | Changement d'etat (monter ou descendre) |
| **Souffle** | Ressource pour l'option Centre |
| **Mission** | Objectif de la run |
| **Triade** | Groupe de 3 elements |

---

*Document version: 1.0*
*Auteurs: Game Designer + UX Research + User*
*Status: DESIGN VALIDE*
