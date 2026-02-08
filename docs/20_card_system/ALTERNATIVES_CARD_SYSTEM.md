# Alternatives au Systeme de Cartes — DRU: Le JDR Parlant

*Document cree: 2026-02-08*
*Agent: Game Designer*
*Status: DESIGN - Propositions pour differenciation*

---

## Contexte

Le joueur trouve que DRU copie trop Reigns:
- 4 jauges 0-100
- Swipe binaire gauche/droite
- Mort si jauge atteint 0 ou 100

**Mission:** Proposer des systemes alternatifs qui:
- Gardent des parties COURTES (< 10 minutes)
- Permettent des evenements generes avec qualite
- Offrent un equilibrage profond
- Presentent un systeme de ressources VISIBLE mais different

---

## PROPOSITION 1: Systeme des Triades (Etats Discrets)

### Concept

Remplacer les 4 jauges continues (0-100) par **3 aspects** avec **3 etats discrets** chacun.

### Structure

| Aspect | Etat Bas | Etat Equilibre | Etat Haut |
|--------|----------|----------------|-----------|
| **Corps** | Epuise | Robuste | Surexcite |
| **Esprit** | Perdu | Lucide | Illumine |
| **Lien** | Exile | Integre | Dominant |

### Regles

1. Chaque aspect a **exactement 3 etats** (pas de chiffres)
2. Certains choix font **monter** ou **descendre** d'un etat
3. Les etats **extremes** (Bas ou Haut) declenchent des effets speciaux
4. La **fin de run** arrive quand **2 aspects sont en etat extreme** simultanement

### Visualisation

```
┌───────────────────────────────────────┐
│   CORPS      ESPRIT       LIEN        │
│   [═══]      [═○═]       [══○]        │
│   Epuise     Lucide      Dominant     │
└───────────────────────────────────────┘
```

Utiliser des **symboles celtiques** au lieu de barres:
- Triskell a 3 branches qui s'illuminent
- Ou cercles concentriques

### Pros

- **Tres different de Reigns** visuellement et conceptuellement
- **Plus simple a comprendre** (3 etats vs 100 valeurs)
- **Decisions plus claires** (je monte ou je descends?)
- **Resonance celtique** (triades sacrees: "Trois choses...")
- **Parties plus courtes** car oscillations moins frequentes

### Cons

- Moins de **granularite** pour l'equilibrage fin
- Risque de **situations bloquees** si 2 aspects oscillent en meme temps
- **LLM doit adapter** son output (plus simple = moins de nuances?)

### Impact sur les systemes existants

- **Biomes:** Chaque biome favorise un aspect (ex: Broceliande = Esprit)
- **Oghams:** Skills modifient les etats directement
- **Retournements:** Se declenchent sur etats extremes
- **Promesses:** Concernent des aspects specifiques

### Mitigation

Pour garder de la profondeur:
- Ajouter des **sous-etats temporaires** (ex: "Epuise mais Determine")
- Les **ressources cachees** restent en 0-100 en coulisses
- Les **transitions d'etat** peuvent etre animees (pas instantanees)

---

## PROPOSITION 2: Systeme des Tokens (Ressources Binaires)

### Concept

Remplacer les jauges par **tokens collectionnables** que le joueur peut voir et depenser.

### Structure

**5 types de tokens:**

| Token | Symbole | Obtention | Utilisation |
|-------|---------|-----------|-------------|
| **Vigueur** | Feuille de chene | Actions physiques | Eviter des pertes, combattre |
| **Sagesse** | Triskell | Meditation, etude | Reveler des secrets |
| **Faveur** | Couronne | Aide aux autres | Negocier, commander |
| **Fortune** | Piece d'or | Commerce, trouvailles | Acheter, corrompre |
| **Mystere** | Lune | Rencontres magiques | Magie, vision |

### Regles

1. Le joueur **demarre avec 3 tokens** de chaque type
2. Les cartes **donnent ou prennent** des tokens
3. Certaines cartes **coutent** des tokens pour etre jouees d'une certaine facon
4. **Fin de run** si un type de token tombe a **0**
5. **Maximum 7 tokens** par type (surplus convertis en Gloire)

### Visualisation

```
┌───────────────────────────────────────────────┐
│  🍃×4   🌀×2   👑×5   🪙×3   🌙×6              │
│  Vigueur Sagesse Faveur Fortune Mystere       │
└───────────────────────────────────────────────┘
```

Les tokens sont des **objets visuels** sur l'ecran, pas des barres.

### Mecaniques de choix enrichies

**Nouveau:** Certaines cartes offrent des **options payantes**:

```
Carte: "Le mendiant demande l'aumone"

[Gauche] Ignorer         → -1 Faveur
[Droite] Donner (1 Fortune) → +1 Faveur, +1 Mystere
         ↑ Option payante (necessite 1 Fortune)
```

Cela ajoute une **3eme dimension** aux choix sans ajouter de boutons.

### Pros

- **Tangible et satisfaisant** (collecter des tokens)
- **Decisions a cout visible** (je peux "payer" pour un meilleur resultat)
- **Tres different visuellement** de Reigns
- **Economie claire** pour le joueur
- **Resonance celtique** possible (tokens = talismans, runes)

### Cons

- **Plus complexe** a equilibrer
- **UI plus chargee** (afficher 5 types de tokens)
- **Risque d'hoarding** (joueur qui accumule au lieu de depenser)
- **LLM doit generer** des couts en tokens

### Impact sur les systemes existants

- **Biomes:** Modifient les types de tokens gagnes/perdus
- **Oghams:** Certains skills permettent de convertir des tokens
- **Retournements:** Peuvent forcer une "taxe" de tokens
- **Promesses:** Engagement de tokens futurs

### Mitigation

- Ajouter un **decay lent** (perdre 1 token par X cartes)
- Certaines cartes **forcent** a depenser
- Maximum strictement limite

---

## PROPOSITION 3: Systeme du Cycle (Ressources qui se Transforment)

### Concept

Une **seule ressource circulaire** qui se transforme en traversant 4 phases, comme les saisons ou les elements.

### Structure: Le Cycle des Oghams

```
        LUMIERE (Esprit, Magie)
             ▲
            /│\
           / │ \
          /  │  \
CREATION ◄───┼───► DESTRUCTION
  (Vie)      │      (Mort)
          \  │  /
           \ │ /
            \│/
             ▼
        MATIERE (Corps, Terre)
```

### Regles

1. Le joueur a **un marqueur** sur le cycle
2. Chaque choix **deplace le marqueur** dans une direction
3. Rester trop longtemps **dans une zone** declenche une fin
4. L'**equilibre parfait** (centre) est l'objectif ideal
5. Certaines **zones** donnent des bonus/malus

### Les 4 Quadrants

| Quadrant | Theme | Bonus | Risque |
|----------|-------|-------|--------|
| Lumiere-Creation | Espoir, Guerison | +Magie, +Vie | Possession |
| Lumiere-Destruction | Vengeance, Justice | +Pouvoir | Folie |
| Matiere-Creation | Prosperite, Fertilite | +Ressources | Avidite |
| Matiere-Destruction | Survie, Pragmatisme | +Endurance | Deshumanisation |

### Visualisation

```
┌─────────────────────────────────────┐
│                                     │
│           ○ ← Marqueur              │
│          /                          │
│    [Lumiere]                        │
│     ╱    ╲                          │
│ [Creation]—[Destruction]            │
│     ╲    ╱                          │
│    [Matiere]                        │
│                                     │
│   ZONE: Lumiere-Creation            │
│   Bonus: +10% gains magiques        │
└─────────────────────────────────────┘
```

### Mecaniques de choix

Les choix affichent la **direction** du deplacement:

```
Carte: "Le villageois malade supplie"

[Gauche] Le laisser (→ Matiere-Destruction)
[Droite] Le guerir  (→ Lumiere-Creation)
```

### Pros

- **Systeme unique et elegant**
- **Resonance celtique forte** (cycles, equilibre, roue de l'annee)
- **Visuellement distinctif** de Reigns
- **Profondeur philosophique** (equilibre des forces)
- **Tres court a comprendre** (une seule ressource!)

### Cons

- **Abstrait** pour certains joueurs
- **Moins de controle fin** sur les jauges individuelles
- **Risque de mouvements chaotiques** si mal calibre
- **LLM doit penser en termes de directions** pas de valeurs

### Impact sur les systemes existants

- **Biomes:** Chaque biome "tire" vers un quadrant
- **Oghams:** Skills permettent de contrer ou accelerer le mouvement
- **Retournements:** Se declenchent aux extremites du cycle
- **Promesses:** Concernent une direction du cycle

### Mitigation

- Ajouter une **inertie** (le marqueur revient lentement vers le centre)
- Les **zones de danger** sont aux extremites, pas dans les quadrants
- Afficher clairement la **distance au danger**

---

## PROPOSITION 4: Systeme des Intentions (Plus de 2 Options)

### Concept

Garder un systeme de ressources proche de Reigns mais **changer la mecanique de choix**:
- **3 ou 4 options** par carte au lieu de 2
- Chaque option a une **intention** claire
- Les options sont **presentees en cercle** autour de la carte

### Structure des Options

| Intention | Symbole | Effet Typique |
|-----------|---------|---------------|
| **Force** | Epee | Direct, brutal, rapide |
| **Ruse** | Renard | Subtil, risque, recompense |
| **Sagesse** | Hibou | Equilibre, neutre, prudent |
| **Coeur** | Feuille | Empathique, social, lent |

### Visualisation

```
┌─────────────────────────────────────┐
│                                     │
│           [Force]                   │
│              ⚔️                     │
│                                     │
│    [Ruse]  ┌───────┐  [Sagesse]     │
│      🦊   │ CARTE │    🦉          │
│            │       │                │
│            └───────┘                │
│              ❤️                     │
│           [Coeur]                   │
│                                     │
└─────────────────────────────────────┘
```

### Regles

1. Chaque carte propose **2 a 4 options** selon le contexte
2. Les options sont **disposees autour** de la carte
3. Le joueur **clique/tap** sur l'option choisie (pas de swipe)
4. Les **intentions** sont consistantes (Force = toujours agressif)
5. Les **effets** varient selon le contexte

### Mecaniques enrichies

**Combos d'intentions:**
- 3 choix Force consecutifs = "Rage" (bonus temporaire + malus futur)
- Alterner Sagesse/Coeur = "Equilibre" (bonus de stabilite)

**Intentions bloquees:**
- Si une jauge est trop basse, certaines intentions sont grises
- Ex: Vigueur < 20 = Force bloquee

### Pros

- **Plus de variete strategique**
- **Garde la simplicite des jauges** (moins de changement)
- **Pas de swipe** = different de Reigns
- **Personnalite du joueur emerge** (quel type de druide es-tu?)
- **Compatible avec le LLM actuel** (generer 4 options au lieu de 2)

### Cons

- **UI plus complexe** (4 boutons vs 2)
- **Risque de paralysis** (trop de choix?)
- **Mobile moins intuitif** que le swipe
- **Equilibrage 4x plus complexe**

### Impact sur les systemes existants

- **Biomes:** Certaines intentions favorisees par biome
- **Oghams:** Peuvent debloquer/forcer une intention
- **Retournements:** Peuvent supprimer temporairement une intention
- **Promesses:** Liees a une intention specifique

### Mitigation

- Toujours afficher au moins **2 options** pour la rapidite
- Les **4 options** reservees aux moments cles
- **Raccourcis clavier** (F/R/S/C) pour desktop

---

## PROPOSITION 5: Systeme Hybride (RECOMMANDATION)

### Concept

Combiner les meilleures idees des propositions precedentes pour creer un systeme **unique mais accessible**.

### Elements retenus

| Source | Element | Adaptation |
|--------|---------|------------|
| Prop 1 (Triades) | Etats discrets | 3 etats par jauge (Bas/Moyen/Haut) |
| Prop 2 (Tokens) | Ressource depensable | 1 type: "Souffle d'Ogham" |
| Prop 3 (Cycle) | Visualisation circulaire | Roue celtique pour l'equilibre |
| Prop 4 (Intentions) | Plus de 2 options | 3 options (gauche/centre/droite) |

### Structure Finale

**3 Aspects avec 3 Etats:**

| Aspect | Bas | Moyen | Haut | Fin si Bas | Fin si Haut |
|--------|-----|-------|------|------------|-------------|
| **Corps** | Epuise | Robuste | Surmene | Epuisement | Surmenage |
| **Ame** | Perdue | Centree | Possedee | Folie | Possession |
| **Monde** | Exile | Integre | Tyran | Exile | Tyrannie |

**1 Ressource Depensable: Souffle d'Ogham**

- Maximum: 7 Souffles
- Usage: Debloquer l'option "Centre" (Sagesse)
- Regeneration: 1 Souffle par carte si aspect equilibre

**3 Options par carte:**

| Direction | Intention | Cout |
|-----------|-----------|------|
| Gauche | Action directe | Gratuit |
| Centre | Action sage | 1 Souffle |
| Droite | Action risquee | Gratuit |

### Visualisation

```
┌─────────────────────────────────────────────────┐
│   CORPS        AME         MONDE                │
│  [▼ ● ○]     [○ ● ○]     [○ ○ ▲]              │
│   Epuise      Centree     Tyran                 │
│                                                 │
│           ╭───────────────╮                     │
│           │   SOUFFLE     │                     │
│           │   🌀🌀🌀🌀🌀⚪⚪  │   ← 5/7 Souffles  │
│           ╰───────────────╯                     │
│                                                 │
│  ┌─────────────────────────────────────────┐    │
│  │                                         │    │
│  │  "Le druide noir te defie..."           │    │
│  │                                         │    │
│  └─────────────────────────────────────────┘    │
│                                                 │
│  [FUIR]      [NEGOCIER🌀]      [COMBATTRE]      │
│  Corps▼       Stable           Corps▲ Ame▼     │
└─────────────────────────────────────────────────┘
```

### Regles de Fin

1. Si **2 aspects** sont en etat **extreme** (Bas OU Haut) = Fin de run
2. Chaque combinaison de 2 extremes = **1 fin unique** (9 fins possibles)
3. **Ending secret:** Garder les 3 aspects en "Moyen" pendant 50+ cartes

### Tableau des Fins

| Aspect 1 Extreme | Aspect 2 Extreme | Fin |
|------------------|------------------|-----|
| Corps Bas | Ame Basse | La Mort Oubliee |
| Corps Bas | Ame Haute | Le Sacrifice |
| Corps Bas | Monde Bas | L'Abandon |
| Corps Bas | Monde Haut | L'Usurpation |
| Corps Haut | Ame Basse | La Bete |
| Corps Haut | Ame Haute | L'Ascension |
| Corps Haut | Monde Bas | Le Solitaire |
| Corps Haut | Monde Haut | Le Conquerant |
| Ame Basse | Monde Bas | L'Errance |

*(9 fins minimum, extensible)*

### Duree de Partie

- **Transitions d'etat:** Plus rares que les +/- de Reigns
- **Effet moyen:** Reste dans l'etat actuel
- **Effet fort:** Monte/descend d'un etat
- **Ciblage:** Run de 30-50 cartes (~8-12 minutes)

### Pros

- **Tres different de Reigns** visuellement et mecaniquement
- **Plus simple** que 4 jauges continues
- **3 options = plus strategique** que binaire
- **Souffle = ressource interessante** a gerer
- **Fins variees** (9+ au lieu de 8)
- **Resonance celtique forte** (triades, souffles, equilibre)

### Cons

- **Nouveau systeme a apprendre** pour le joueur
- **LLM doit etre reentrainer** pour generer 3 options
- **Equilibrage a refaire** completement
- **UI plus complexe** que Reigns

### Impact sur les systemes existants

| Systeme | Adaptation |
|---------|------------|
| **Biomes** | Chaque biome modifie les transitions d'etat |
| **Oghams** | Skills donnent des Souffles ou forcent des transitions |
| **Retournements** | Se declenchent sur etats extremes |
| **Promesses** | Engagent des Souffles futurs |
| **Ressources cachees** | Fonctionnent toujours en coulisses |

---

## COMPARATIF FINAL

| Critere | Reigns Actuel | Triades | Tokens | Cycle | Intentions | Hybride |
|---------|---------------|---------|--------|-------|------------|---------|
| **Simplicite** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Differenciation** | ⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Profondeur** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Parties courtes** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Celtique** | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Effort LLM** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Effort Dev** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐ |
| **TOTAL** | 22/35 | 27/35 | 24/35 | 26/35 | 23/35 | **28/35** |

---

## RECOMMANDATION PRINCIPALE

### Adopter le Systeme Hybride (Proposition 5)

**Raisons:**

1. **Maximum de differenciation** avec Reigns
2. **Resonance celtique** (triades, souffles, equilibre)
3. **3 options enrichit le gameplay** sans le complexifier excessivement
4. **Parties courtes** grace aux etats discrets
5. **Profondeur cachee** via les ressources invisibles existantes
6. **9+ fins** pour la rejouabilite

### Plan d'Implementation

| Phase | Action | Effort |
|-------|--------|--------|
| 1 | Prototyper UI des 3 etats | 2 jours |
| 2 | Adapter DruStore pour etats discrets | 3 jours |
| 3 | Implementer Souffle d'Ogham | 1 jour |
| 4 | Modifier UI pour 3 options | 2 jours |
| 5 | Reentrainer LLM pour 3 options | 3 jours |
| 6 | Reecrire fallback cards (50) | 5 jours |
| 7 | Tests et equilibrage | 5 jours |
| **TOTAL** | | **~3 semaines** |

### Questions Ouvertes

1. L'option "Centre" devrait-elle toujours exister ou etre conditionnelle?
2. Le Souffle devrait-il se regenerer passivement ou uniquement via cartes?
3. Les fins devraient-elles avoir des conditions de deblocage (comme Reigns)?
4. Comment representer les etats visuellement (barres segmentees? symboles?)?

---

## Annexe: Exemples de Cartes (Systeme Hybride)

### Exemple 1: Rencontre Simple

```json
{
    "text": "Un voyageur epuise s'effondre sur ton chemin.",
    "speaker": "MERLIN",
    "options": [
        {
            "direction": "left",
            "label": "L'ignorer",
            "cost": 0,
            "effects": [
                {"type": "SHIFT_ASPECT", "target": "Monde", "direction": "down"}
            ],
            "preview": "Monde ▼"
        },
        {
            "direction": "center",
            "label": "L'observer d'abord",
            "cost": 1,
            "effects": [],
            "preview": "Stable (1🌀)"
        },
        {
            "direction": "right",
            "label": "Le secourir",
            "cost": 0,
            "effects": [
                {"type": "SHIFT_ASPECT", "target": "Corps", "direction": "down"},
                {"type": "SHIFT_ASPECT", "target": "Monde", "direction": "up"}
            ],
            "preview": "Corps ▼ Monde ▲"
        }
    ]
}
```

### Exemple 2: Dilemme Complexe

```json
{
    "text": "Le druide noir exige le passage. Derriere lui, des villageois prisonniers.",
    "speaker": "MERLIN",
    "options": [
        {
            "direction": "left",
            "label": "L'affronter seul",
            "cost": 0,
            "effects": [
                {"type": "SHIFT_ASPECT", "target": "Corps", "direction": "down"},
                {"type": "SHIFT_ASPECT", "target": "Ame", "direction": "up"}
            ],
            "preview": "Corps ▼ Ame ▲"
        },
        {
            "direction": "center",
            "label": "Negocier leur liberte",
            "cost": 2,
            "effects": [
                {"type": "ADD_SOUFFLE", "value": -2},
                {"type": "SET_FLAG", "flag": "druide_noir_parle", "value": true}
            ],
            "preview": "Stable (2🌀)"
        },
        {
            "direction": "right",
            "label": "Contourner dans l'ombre",
            "cost": 0,
            "effects": [
                {"type": "SHIFT_ASPECT", "target": "Monde", "direction": "down"},
                {"type": "SET_FLAG", "flag": "villageois_abandonnes", "value": true}
            ],
            "preview": "Monde ▼"
        }
    ]
}
```

---

## Sources de Recherche

- [Games like Reigns - RAWG](https://rawg.io/games/reigns/suggestions)
- [Best Card Games on Steam 2026](https://rocketbrush.com/blog/10-best-card-games-on-steam)
- [Roguelike Deckbuilders - Rogueliker](https://rogueliker.com/roguelike-deckbuilders/)
- [Top 5 Card Game Trends 2026 - VNK Playing Card](https://www.vnkplayingcard.com/top-5-card-game-trends-of-early-2026-for-indie-designers)
- [Indie Card Games with Unique Mechanics - ThisGenGaming](https://thisgengaming.com/2025/02/13/indie-card-games-with-unique-mechanics/)

---

*Document version: 1.0*
*Auteur: Game Designer Agent*
*Status: DESIGN - En attente validation utilisateur*
