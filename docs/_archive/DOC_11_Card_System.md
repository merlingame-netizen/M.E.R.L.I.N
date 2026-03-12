# DOC 11 — Systeme de Cartes Narratives (Core Gameplay)

## But
Systeme de choix narratifs par cartes, ou chaque carte presente un scenario et le joueur choisit entre options qui impactent ses ressources.

---

## 11.1 Principes de Design

### Philosophie
- **Simple a jouer**: Swipe gauche/droite ou clic
- **Profond en consequences**: Chaque choix a des repercussions
- **Narratif dynamique**: LLM genere les scenarios
- **Equilibre constant**: Ressources a maintenir

### Inspiration
- **Card-based narrative games**: Swipe cards, gauges, death if extreme
- **Gnosia**: Narration emergente, relations
- **Slay the Spire**: Roguelite structure, meta progression

---

## 11.2 Structure d'une Carte

```gdscript
var card := {
    # Identite
    "id": "card_123",
    "type": "narrative",  # narrative, event, promise, merlin_direct

    # Contenu
    "speaker": "MERLIN",  # ou "" pour narration pure
    "text": "Un voyageur s'approche de ton campement...",
    "portrait": "traveler_01",  # optionnel

    # Choix
    "options": [
        {
            "direction": "left",
            "label": "Le chasser",
            "preview_hint": "[-Faveur, +Securite]",  # optionnel
            "effects": [
                {"type": "ADD_RESOURCE", "target": "Securite", "value": 10},
                {"type": "REMOVE_RESOURCE", "target": "Faveur", "value": 15},
            ]
        },
        {
            "direction": "right",
            "label": "L'accueillir",
            "preview_hint": "[+Faveur, -Ressources]",
            "effects": [
                {"type": "ADD_RESOURCE", "target": "Faveur", "value": 20},
                {"type": "REMOVE_RESOURCE", "target": "Ressources", "value": 10},
            ]
        }
    ],

    # Conditions
    "conditions": {
        "min_day": 0,
        "required_flags": [],
        "forbidden_flags": [],
    },

    # Bestiole interaction
    "bestiole_can_help": true,
    "bestiole_help_effect": "reveal_consequences",

    # Meta
    "tags": ["social", "stranger", "early_game"],
    "weight": 1.0,  # probabilite de selection
}
```

---

## 11.3 Systeme de Ressources

### 4 Jauges Principales (0-100)
| Jauge | Description | 0 = | 100 = |
|-------|-------------|-----|-------|
| **Vigueur** | Sante physique/energie | Epuisement mortel | Surmenage |
| **Esprit** | Sante mentale/magie | Folie | Possession |
| **Faveur** | Reputation/relations | Exile | Tyrannie |
| **Ressources** | Materiel/provisions | Famine | Pillage |

### Regles de Fin de Run
- Si **n'importe quelle** jauge atteint 0 ou 100 = **Fin de Run**
- Chaque fin a une narration specifique (8 fins possibles)
- Meta progression selon duree de survie + accomplissements

### Modificateurs Bestiole
Le bond et l'etat de Bestiole modifient les effets:
```
effect_final = effect_base * bestiole_modifier

Exemple:
- Bond elevé (>80): +20% effets positifs
- Bestiole affamé: -10% tous effets
- Bestiole heureux: revele les hints
```

---

## 11.4 Types de Cartes

### Narrative (80%)
Scenarios generes par LLM avec choix binaires.
- Rencontres
- Dilemmes moraux
- Evenements quotidiens

### Event (10%)
Cartes speciales liees a l'etat du monde.
- Changement de saison
- Evenement calendaire
- Consequence d'une promesse

### Promise (5%)
Merlin propose un pacte.
- Choix: Accepter ou Refuser
- Accepter = bonus immediat + obligation future
- Briser promesse = consequences graves

### Merlin Direct (5%)
Merlin parle directement au joueur.
- Indices
- Avertissements
- Revelations de lore

---

## 11.5 UI Layout

```
+------------------------------------------+
|  [Vigueur]  [Esprit]  [Faveur]  [Ress.]  |
|   ████░░     ██████    ███░░░    █████   |
+------------------------------------------+
|                                          |
|           ┌─────────────────┐            |
|           │   [Portrait]    │            |
|           │                 │            |
|           │  "Texte de la   │            |
|           │   carte ici..." │            |
|           │                 │            |
|           │   — MERLIN      │            |
|           └─────────────────┘            |
|                                          |
|  ← Refuser                   Accepter →  |
|    (hint)                      (hint)    |
|                                          |
+------------------------------------------+
|  [🐾 Bestiole: Content | Bond: 72]       |
+------------------------------------------+
```

### Interactions
- **Desktop**: Clic sur boutons gauche/droite, ou fleches clavier
- **Mobile**: Swipe la carte gauche/droite
- **Bestiole**: Clic sur icone pour activer aide (si disponible)

---

## 11.6 Whitelist d'Effets

Le LLM ne peut proposer **que** ces effets:

### Ressources
```gdscript
{"type": "ADD_RESOURCE", "target": str, "value": int}
{"type": "REMOVE_RESOURCE", "target": str, "value": int}
{"type": "SET_RESOURCE", "target": str, "value": int}
```

### Flags
```gdscript
{"type": "SET_FLAG", "flag": str, "value": bool}
{"type": "INCREMENT_FLAG", "flag": str, "value": int}
```

### Bestiole
```gdscript
{"type": "MODIFY_BESTIOLE", "stat": str, "value": int}
# stats: hunger, energy, mood, bond
```

### Narration
```gdscript
{"type": "QUEUE_CARD", "card_id": str}  # Force une carte specifique
{"type": "ADD_TAG", "tag": str}  # Ajoute un tag pour filtrage futur
{"type": "TRIGGER_ARC", "arc_id": str}  # Demarre un arc narratif
```

### Promise
```gdscript
{"type": "CREATE_PROMISE", "id": str, "deadline_days": int, "reward": {}, "penalty": {}}
{"type": "FULFILL_PROMISE", "id": str}
{"type": "BREAK_PROMISE", "id": str}
```

---

## 11.7 LLM Contract

### Input Context
```json
{
    "resources": {
        "Vigueur": 65,
        "Esprit": 40,
        "Faveur": 80,
        "Ressources": 30
    },
    "bestiole": {
        "name": "Gwenn",
        "mood": "content",
        "bond": 72,
        "active_skill": "reveal"
    },
    "day": 15,
    "hour_slice": 14,
    "season": "autumn",
    "active_promises": [...],
    "story_log": ["card_001", "card_015", ...],
    "active_tags": ["war_brewing", "met_druide"],
    "current_arc": "stranger_arrival"
}
```

### Output Card
```json
{
    "text": "Le druide noir que tu as croise revient...",
    "speaker": "MERLIN",
    "options": [
        {
            "direction": "left",
            "label": "Fuir",
            "effects": [
                {"type": "REMOVE_RESOURCE", "target": "Faveur", "value": 10}
            ]
        },
        {
            "direction": "right",
            "label": "Affronter",
            "effects": [
                {"type": "REMOVE_RESOURCE", "target": "Vigueur", "value": 20},
                {"type": "ADD_RESOURCE", "target": "Esprit", "value": 15}
            ]
        }
    ],
    "tags": ["druide_noir", "confrontation"]
}
```

---

## 11.8 Bestiole Integration

### Role: Support Passif
Bestiole n'agit pas directement mais donne des avantages:

| Bond Level | Bonus |
|------------|-------|
| 0-30 | Aucun |
| 31-50 | Hints partiels |
| 51-70 | Hints complets |
| 71-90 | Modifie effets +10% |
| 91-100 | Option speciale parfois |

### Skills Actifs (Cooldown)
- **Reveal**: Montre les effets exacts (cooldown: 3 cartes)
- **Comfort**: Reduit un effet negatif de 50% (cooldown: 5 cartes)
- **Sense**: Predit le type de la prochaine carte (cooldown: 4 cartes)

### Needs Impact
```
Si Bestiole.hunger < 30: skills indisponibles
Si Bestiole.energy < 20: bonus reduits de moitie
Si Bestiole.mood < 25: hints brouilles
```

---

## 11.9 Flow d'une Session

```
1. INIT
   - Charger state ou creer nouveau run
   - Initialiser ressources a 50/50/50/50
   - Bestiole au repos

2. LOOP
   a. Verifier conditions de fin (jauges 0 ou 100)
   b. Si fin: afficher ecran de fin, calculer score
   c. Sinon: demander carte au LLM (ou fallback)
   d. Afficher carte avec animation
   e. Attendre input joueur (swipe/clic)
   f. Appliquer effets avec animations
   g. Mettre a jour bestiole (decay lent)
   h. Logger dans story_log
   i. Retour a (a)

3. FIN DE RUN
   - Calculer score: jours survecu * multiplicateur
   - Debloquer achievements
   - Sauvegarder meta progression
```

---

## 11.10 Fallback System (Sans LLM)

Si LLM indisponible, utiliser une banque de cartes pre-ecrites:

```gdscript
const FALLBACK_CARDS := [
    {
        "id": "fb_001",
        "text": "Le vent souffle fort ce soir...",
        "options": [
            {"direction": "left", "label": "Se reposer", "effects": [...]},
            {"direction": "right", "label": "Continuer", "effects": [...]}
        ],
        "weight": 1.0,
        "conditions": {}
    },
    # ... 50-100 cartes de base
]
```

Selection basee sur:
- Conditions remplies
- Tags actifs
- Poids * random

---

## 11.11 Migration depuis Combat System

### A Supprimer
- `dru_combat_system.gd`
- Combat screens dans `main_game.gd`
- Enemy data (sauf si reutilise pour rencontres)

### A Adapter
- `dru_event_system.gd` -> `dru_card_system.gd`
- `dru_action_resolver.gd` -> Resoudre effets de cartes
- `game_manager.gd` -> 4 jauges au lieu de HP/stats combat

### A Creer
- `dru_card_system.gd` - Gestion du deck/flow
- `card_ui.gd` - Affichage et swipe
- `resource_bars.gd` - UI des 4 jauges

---

## 11.12 Metriques de Balancing

### Duree de Run Cible
- Run moyenne: 50-100 cartes (~15-30 minutes)
- Run courte (mort rapide): 10-30 cartes
- Run longue (optimal): 150+ cartes

### Distribution d'Effets
- Effet moyen par carte: -5 a +10 sur une jauge
- Cartes purement positives: rare (5%)
- Cartes purement negatives: rare (5%)
- Tradeoffs: commun (90%)

### Pity System
Si joueur proche de 0 ou 100:
- Augmenter poids des cartes "equilibrantes"
- LLM recoit signal "low_vigueur" dans context

---

*Document cree: 2026-02-05*
*Status: DESIGN - En attente implementation*
