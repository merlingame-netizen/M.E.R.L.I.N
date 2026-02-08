# BESTIOLE & ROUE D'OGHAMS — Design Complet

> **DRU: Le Jeu des Oghams**
> Design document definitif pour Bestiole et son systeme d'Oghams
> Agent: Game Designer (Systems)
> Version: 1.0 — 2026-02-08

---

## Table des Matieres

1. [Vision et Philosophie](#1-vision-et-philosophie)
2. [Bestiole dans le Jeu](#2-bestiole-dans-le-jeu)
3. [Systeme de Bond (Lien)](#3-systeme-de-bond-lien)
4. [Souffle d'Awen (Cout des Oghams)](#4-souffle-dawen-cout-des-oghams)
5. [La Roue d'Oghams (Ogham Wheel)](#5-la-roue-doghams-ogham-wheel)
6. [Les 18 Oghams — Specs Completes](#6-les-18-oghams--specs-completes)
7. [Equilibrage vs Systeme Triade](#7-equilibrage-vs-systeme-triade)
8. [Specs d'Implementation GDScript](#8-specs-dimplementation-gdscript)
9. [Flow d'Interaction Complet](#9-flow-dinteraction-complet)
10. [Considerations de Balance](#10-considerations-de-balance)
11. [Questions Ouvertes](#11-questions-ouvertes)

---

# 1. Vision et Philosophie

## 1.1 Ce qu'est Bestiole

Bestiole n'est pas un animal de compagnie. C'est un **fragment de l'Awen primordial** — un morceau de la force vitale originelle du monde qui a pris forme et conscience. Il est le pont entre le joueur (le Temoin) et la magie ancienne de Broceliande.

**Refs:** `COSMOLOGIE_CACHEE.md` Partie 6, `MERLIN_COMPLETE_PERSONALITY.md` section 5.5

### Principes de Design

| Principe | Explication |
|----------|-------------|
| **Utile, jamais obligatoire** | Les Oghams aident mais ne sont pas necessaires pour gagner |
| **Lien emotionnel** | Le joueur doit vouloir prendre soin de Bestiole, pas y etre force |
| **Non-punitif** | Negliger Bestiole reduit les bonus, ne punit pas le joueur |
| **Profondeur cachee** | Le systeme a des couches que le joueur decouvre progressivement |
| **Celtique authentique** | Chaque Ogham correspond a un arbre reel du systeme oghamique |

### Ce que Bestiole apporte au gameplay

1. **Information** — Reveler les consequences cachees des choix
2. **Protection** — Attenuer les effets negatifs
3. **Amplification** — Booster les effets positifs
4. **Flexibilite** — Modifier les cartes ou les options
5. **Survie** — Restaurer l'equilibre des aspects
6. **Surprise** — Effets speciaux uniques

---

# 2. Bestiole dans le Jeu

## 2.1 Apparence Visuelle

### Icone et Position

Bestiole est presente en permanence dans l'interface du jeu, en bas a gauche de l'ecran de cartes.

```
+------------------------------------------------------------------+
|   CORPS            AME              MONDE                         |
|   [Sanglier]       [Corbeau]        [Cerf]                       |
|   o * o            o o *            * o o                         |
|   Robuste          Possedee         Exile                         |
+------------------------------------------------------------------+
|                                                                    |
|              +---------------------------+                         |
|              |                           |                         |
|              |   "Un druide noir te      |                         |
|              |   barre le chemin..."     |                         |
|              |                           |                         |
|              |        -- MERLIN          |                         |
|              +---------------------------+                         |
|                                                                    |
|  [A] FUIR     [B] PARLEMENTER (1S)    [C] ATTAQUER               |
|                                                                    |
+------------------------------------------------------------------+
|  +----+                                                            |
|  |    |  Bestiole                     Souffle: S S S o o o o      |
|  | ** |  Lien: ||||||||oo  (80)                                   |
|  | /\ |  [TAP pour Oghams]                                        |
|  +----+                                                            |
+------------------------------------------------------------------+
```

### Design de l'Icone

| Element | Description |
|---------|-------------|
| **Taille** | 64x64 px (mobile), 48x48 px (desktop) |
| **Style** | Pixel art / flat Celtic, meme palette que le reste du jeu |
| **Forme** | Creature amorphe, douce, lumineuse — ni chien ni chat ni oiseau |
| **Yeux** | 2 points lumineux (couleur varie avec le bond et l'humeur) |
| **Aura** | Halo subtil en or/ambre (pulse avec la "respiration" de l'Awen) |

### Animations de Bestiole

| Etat | Animation | Duree cycle |
|------|-----------|-------------|
| **Idle** | Respiration douce (scale 0.98 -> 1.02) | 3s |
| **Content** | Leger balancement + etincelles d'Awen | 4s |
| **Alerte** | Yeux plus grands, aura plus vive, tressautement | 2s |
| **Triste** | Affaissement, yeux mi-clos, aura terne | 5s |
| **Skill actif** | Flash lumineux, Ogham Unicode apparait au-dessus | 1.5s |
| **Cooldown** | Semi-transparent, petite spirale qui tourne | - |
| **Bond up** | Coeurs pixel + saut de joie | 2s |
| **Sommeil** | Z Z z... yeux fermes | 6s |

### Expressions de Bestiole selon l'etat

| Bond | Mood | Expression |
|------|------|------------|
| 0-30 | Neutre | Distant, regard detourne, aura invisible |
| 31-50 | Content | Attentif, suit le joueur des yeux |
| 51-70 | Joyeux | Reactive, sursaute aux evenements, aura visible |
| 71-90 | Euphorique | Tres attentive, anticipe les choix, aura brillante |
| 91-100 | Extatique | Fusionnelle, complicite totale, aura fusionnee avec le joueur |

## 2.2 Quand le joueur peut interagir avec Bestiole

### Moments d'interaction

| Moment | Action possible | Contexte |
|--------|-----------------|----------|
| **Avant un choix de carte** | Ouvrir la Roue d'Oghams | Activation d'un skill |
| **Pendant l'affichage de la carte** | Tap sur Bestiole | Info rapide (humeur, bond, skills dispo) |
| **Entre les cartes** | Caresse (geste) | +1 Mood micro-boost, purement cosmétique |
| **Fin de run** | Moment de reunion/adieu | Animation narrative |

**Restriction importante:** Bestiole ne peut etre consultee qu'une seule fois par carte (avant le choix). Pas de multi-activation.

---

# 3. Systeme de Bond (Lien)

## 3.1 Nature du Lien

Le Bond n'est pas une simple barre d'affection. C'est la mesure de la **solidite du fil de realite** entre le joueur et Bestiole. Plus le lien est fort, plus Bestiole peut canaliser l'Awen primordial a travers les Oghams.

**Ref:** `COSMOLOGIE_CACHEE.md` section 6.3 — "Le Lien est un fil de realite"

## 3.2 Bond Tiers (Paliers)

| Tier | Bond | Nom | Slots actifs | Modifier passif | Deblocage |
|------|------|-----|--------------|-----------------|-----------|
| 1 | 0-20 | **Etranger** | 0 (starters seulement) | +0% | Debut de run |
| 2 | 21-40 | **Curieux** | 1 slot supplementaire | +5% effets positifs | Natural |
| 3 | 41-60 | **Compagnon** | 2 slots supplementaires | +10% effets positifs | Natural |
| 4 | 61-80 | **Lie** | 3 slots supplementaires | +15% + hints Merlin | Natural |
| 5 | 81-100 | **Ame soeur** | Tous les slots | +20% + options speciales + synergies | Long term |

### Starters toujours actifs

Les 3 Oghams starter (Beith, Luis, Quert) sont **toujours disponibles** quel que soit le Bond. Ils representent le lien fondamental entre Bestiole et le joueur.

Les "slots supplementaires" debloquent la capacite d'equiper des Oghams non-starter dans la Roue.

## 3.3 Bond Growth (Croissance du Lien)

### Gains de Bond (pendant la run)

| Action | Bond gain | Condition |
|--------|-----------|-----------|
| Carte jouee | +1 | Automatique si aucun need critique |
| Utiliser un Ogham | +2 | A chaque activation reussie |
| Choix "equilibre" (Centre) | +1 | Si 3 aspects equilibres apres |
| Tenir une promesse | +5 | Quand une promesse Merlin est remplie |
| Evenement positif Bestiole | +3 | Carte narrative mentionnant Bestiole |
| Survie longue (20+ cartes) | +1/5 cartes | Bonus incrementiel |

### Pertes de Bond (pendant la run)

| Action | Bond perte | Condition |
|--------|------------|-----------|
| Briser une promesse | -5 | Quand une promesse est rompue |
| 2 aspects extremes | -2 | Quand l'equilibre est rompu |
| Ignorer un hint de Bestiole | -1 | Rare, quand Bestiole signale un danger |

### Bond entre les runs (meta-progression)

| Situation | Effet sur Bond |
|-----------|----------------|
| Debut de nouvelle run | Bond = min(Bond_precedent, 50) + 10 |
| Victoire precedente | Bond + 5 bonus |
| Defaite precedente | Bond inchange |
| Absence prolongee | Bond auto-stabilise a 30 (pas de punition) |

**Philosophie:** Le Bond ne part jamais de zero entre les runs. Le lien persiste a travers les boucles (coherent avec le lore: le fil de realite survit aux iterations temporelles).

---

# 4. Souffle d'Awen (Cout des Oghams)

## 4.1 Separation des deux ressources "Souffle"

**IMPORTANT:** Il existe deux systemes de "Souffle" distincts dans DRU:

| Ressource | Usage | Maximum | Source |
|-----------|-------|---------|--------|
| **Souffle d'Ogham** | Payer l'option Centre des cartes | 7 | Equilibre des 3 aspects |
| **Souffle d'Awen** | Payer l'activation des Oghams | 5 | Bond + cartes jouees |

Le **Souffle d'Ogham** (deja design dans DOC_12) est la ressource pour les choix Centre.
Le **Souffle d'Awen** est la **nouvelle** ressource pour activer les skills de Bestiole.

## 4.2 Souffle d'Awen — Regles

| Propriete | Valeur |
|-----------|--------|
| Maximum | 5 |
| Depart (run) | 2 |
| Regeneration | +1 par tranche de 5 cartes jouees |
| Bonus equilibre | +1 si 3 aspects equilibres au moment de la regen |
| Cout par Ogham | 1-3 selon la puissance (voir table Oghams) |

### Visualisation

```
SOUFFLE D'AWEN
  A A o o o   (2/5)
```

- **A** = Souffle disponible (spirale d'Awen dorée, Unicode ᚛)
- **o** = Souffle manquant (cercle terne)
- Position: A cote de l'icone Bestiole, en bas de l'ecran

### Regeneration naturelle

```
Toutes les 5 cartes:
  +1 Souffle d'Awen
  Si 3 aspects equilibres: +1 additionnel (donc +2 total)

Cap: jamais au-dessus de 5
```

### Pourquoi une ressource separee?

1. **Eviter le dilemme Centre vs Ogham** — Le joueur ne devrait pas avoir a choisir entre une option sage et une activation de skill
2. **Timing different** — Le Souffle d'Ogham reward l'equilibre constant, le Souffle d'Awen reward la progression
3. **Clarification thematique** — L'Ogham vient du druide, l'Awen vient de Bestiole (son fragment d'Awen)

---

# 5. La Roue d'Oghams (Ogham Wheel)

## 5.1 Comment ouvrir la Roue

### Declenchement

| Plateforme | Geste | Alternative |
|------------|-------|-------------|
| **Mobile** | Tap sur l'icone Bestiole | Swipe vers le haut depuis le bas |
| **PC** | Clic sur Bestiole ou touche `Tab` | Touche `Space` |
| **Console** | Bouton L/R (epaule) | - |

### Conditions d'ouverture

- La carte actuelle doit etre affichee (pas pendant une transition)
- Le joueur n'a pas encore fait son choix pour cette carte
- Au moins 1 Ogham est disponible (pas en cooldown + assez de Souffle)
- Si aucun Ogham n'est utilisable: l'icone Bestiole est grisee avec indication

### Animation d'ouverture

```
1. Tap sur Bestiole (0ms)
2. Bestiole s'illumine (0-200ms) — flash d'Awen
3. La carte se decale vers le haut (200-400ms) — ease_out
4. La Roue apparait en spirale depuis Bestiole (400-800ms) — each slot rotates in
5. Roue complete visible (800ms+) — idle pulsation
```

## 5.2 Layout de la Roue

### Structure: Roue en 3 Cercles Concentriques

La Roue est organisee comme un **triskell** — 3 branches spiralees, chacune representant un type d'Ogham.

```
                    [REVEAL]
                   /   |   \
              [ailm] [coll] [beith*]
                 |           |
          [BOOST]             [PROTECT]
         /  |  \             /  |  \
    [onn][tinne][duir]  [eadhadh][gort][luis*]
                 |           |
              [SPECIAL]     [RECOVERY]
             /   |   \     /   |   \
        [ur][ioho][muin] [saille][ruis][quert*]
                 |
             [NARRATIVE]
            /   |   \
      [straif][huath][nuin]
```

**Note:** Les starters (*) sont marques d'une petite etoile doree.

### Layout simplifie (vue joueur)

La roue affiche **au maximum 7 slots visibles** a la fois:
- 3 starters (toujours visibles, anneau interieur)
- Jusqu'a 4 Oghams equipes (anneau exterieur)

```
+--------------------------------------------------+
|                                                    |
|              +---------+                           |
|             /  REVEAL   \                          |
|            / [beith*] [?] \                        |
|           |                |                       |
|    PROTECT |    BESTIOLE   | BOOST                 |
|   [luis*]  |    (centre)   | [duir]               |
|   [gort]   |               | [tinne]              |
|           |                |                       |
|            \ [quert*] [?] /                        |
|             \ RECOVERY  /                          |
|              +---------+                           |
|                                                    |
|  Souffle d'Awen: A A o o o                        |
|  [Fermer]                         [Categories >]  |
|                                                    |
+--------------------------------------------------+
```

### Slots et Categories

| Anneau | Slots | Contenu |
|--------|-------|---------|
| **Centre** | 1 | Icone Bestiole (decoratif, animation) |
| **Interieur** | 3 | Les 3 starters (beith, luis, quert) — fixes |
| **Exterieur** | 4 | Oghams equipes (choisis par le joueur) — variables |

### Navigation dans les categories

Si le joueur possede plus de 7 Oghams, un bouton **[Categories >]** permet de parcourir les 6 categories:
- Tap sur une categorie = filtre les Oghams de cette categorie
- Les Oghams equipes sont surlignes
- Les Oghams non-deverrouilles sont gris avec un cadenas

## 5.3 Comment selectionner un Ogham

### Flow de selection

```
1. Joueur ouvre la Roue (tap Bestiole)
2. Roue apparait avec les Oghams equipes
3. Joueur tap sur un Ogham
4. Preview de l'effet apparait (bulle tooltip):
   "BEITH — Bouleau — Revele l'effet d'une option"
   "Cout: 1 Souffle d'Awen | Cooldown: 3 cartes"
5. Joueur confirme (second tap ou bouton [Activer])
6. Animation d'activation (1.5s)
7. Effet applique
8. Roue se ferme
9. Retour au choix de carte (avec l'effet actif)
```

### Gestion des erreurs

| Situation | Feedback |
|-----------|----------|
| Pas assez de Souffle | Slot grise + texte "Souffle insuffisant" + animation de refus |
| En cooldown | Slot semi-transparent + compteur "2 cartes restantes" |
| Pas deverrouille | Cadenas + texte "Lien [X] requis" |
| Deja utilise ce tour | Toute la Roue grisee + texte "1 Ogham par carte" |

## 5.4 Feedback Visuel d'Activation

### Sequence d'activation

| Phase | Duree | Visuel | Audio |
|-------|-------|--------|-------|
| **1. Selection** | 0-300ms | L'Ogham selectionne pulse | Soft click |
| **2. Canalisation** | 300-800ms | Lignes d'Awen coulent de Bestiole vers l'Ogham | Humming etheree |
| **3. Eclatement** | 800-1200ms | Le symbole Ogham (Unicode) s'agrandit et brille | Chime celtique |
| **4. Application** | 1200-1500ms | L'effet se manifeste (overlay sur la carte) | Specific a l'effet |
| **5. Retour** | 1500-1800ms | La Roue se ferme, Bestiole fait une animation de satisfaction | Soft whoosh |

### Symbole Ogham pendant l'activation

Chaque Ogham a son caractere Unicode qui apparait en grand au centre de l'ecran pendant la phase 3:

```
   +-----------+
   |           |
   |    ᚁ     |   <- Caractere Ogham en grand (64px)
   |   beith   |   <- Nom en petit dessous
   |           |
   +-----------+
```

Le symbole pulse 2-3 fois puis se dissipe en particules.

## 5.5 Gestion des Oghams verrouilles vs deverrouilles

### Sources de deblocage

| Source | Oghams concernes | Condition |
|--------|------------------|-----------|
| **Depart** | beith, luis, quert | Automatique (starters) |
| **Bond tier 2** (21-40) | 1 Ogham au choix | Palier atteint |
| **Bond tier 3** (41-60) | 2 Oghams au choix | Palier atteint |
| **Bond tier 4** (61-80) | 3 Oghams au choix | Palier atteint |
| **Bond tier 5** (81-100) | Tous les restants | Palier atteint |
| **Meta-progression** | Oghams specifiques | Achievements (voir section 6) |
| **Evenements narratifs** | 1 Ogham thematique | Carte rare de deblocage |

### Ecran de gestion des Oghams (entre les runs)

```
+------------------------------------------------------------------+
|  MES OGHAMS                                           [Retour]   |
+------------------------------------------------------------------+
|                                                                    |
|  REVEAL        PROTECTION      BOOST                              |
|  [*beith*] V   [*luis*] V      [duir] V                          |
|  [coll] V      [gort] V        [tinne] L                         |
|  [ailm] L      [eadhadh] L     [onn] L                           |
|                                                                    |
|  NARRATIVE     RECOVERY        SPECIAL                            |
|  [nuin] L      [*quert*] V     [muin] L                          |
|  [huath] L     [ruis] L        [ioho] L                          |
|  [straif] L    [saille] L      [ur] L                            |
|                                                                    |
|  V = Deverrouille  L = Verrouille  * = Starter                    |
|                                                                    |
|  EQUIPES (4 max + 3 starters):                                    |
|  [ beith ] [ luis ] [ quert ] [ duir ] [ gort ] [ _ ] [ _ ]      |
|                                                                    |
+------------------------------------------------------------------+
```

### Deblocage: choix delibere

Quand le joueur atteint un nouveau Bond tier:
1. Animation speciale de Bestiole (evolution du lien)
2. Ecran de choix: "Bestiole te revele un nouvel Ogham"
3. 3 Oghams proposes (parmi ceux non-deverrouilles, de categories differentes)
4. Le joueur en choisit 1
5. L'Ogham est definitivement deverrouille (meta-progression)
6. Il est automatiquement equipe si un slot est libre

---

# 6. Les 18 Oghams — Specs Completes

## 6.0 Adaptation au Systeme Triade

**IMPORTANT:** Le systeme de reference est desormais le **Triade** (3 aspects x 3 etats), pas les 4 jauges Reigns. Les effets des Oghams sont adaptes en consequence.

| Ancien systeme (Reigns) | Nouveau systeme (Triade) |
|--------------------------|--------------------------|
| "+15 a la jauge la plus basse" | "Stabilise 1 aspect vers Equilibre" |
| "Equilibre les jauges vers 50" | "Ramene tous les aspects vers Equilibre" |
| "+50% effet positif" | "Empeche 1 transition negative" |
| "Reduit effet negatif de 30%" | "50% de chance d'annuler 1 shift negatif" |

---

## STARTERS (Toujours actifs)

### BEITH (ᚁ) — Bouleau — Reveal

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Beith |
| **Arbre** | Bouleau (Betula) |
| **Symbole Ogham** | ᚁ |
| **Categorie** | Reveal (Starter) |
| **Cout Awen** | 1 |
| **Cooldown** | 3 cartes |
| **Deblocage** | Starter (automatique) |

**Effet:** Revele l'impact d'**une** option au choix (montre quel aspect sera affecte et dans quelle direction).

**Feedback visuel:** L'option choisie s'illumine brievement, un symbole de l'aspect affecte apparait avec une fleche (haut/bas/stable).

**Signification celtique:** Le bouleau est l'arbre des nouveaux departs. Voir clair pour commencer juste.

**Synergie cachee:** Si utilise 3 fois consecutives (3 cartes d'affilee), la 3eme utilisation revele TOUTES les options au lieu d'une seule.

---

### LUIS (ᚂ) — Sorbier — Protection

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Luis |
| **Arbre** | Sorbier (Sorbus) |
| **Symbole Ogham** | ᚂ |
| **Categorie** | Protection (Starter) |
| **Cout Awen** | 1 |
| **Cooldown** | 4 cartes |
| **Deblocage** | Starter (automatique) |

**Effet:** **Bouclier de Sorbier** — Si le prochain choix du joueur entrainerait un shift negatif (aspect vers l'extreme), 50% de chance d'annuler ce shift.

**Feedback visuel:** Barriere de branches de sorbier autour de la carte. Si le bouclier bloque: flash vert + son protecteur. Si le bouclier echoue: les branches se brisent avec un son de craquement.

**Signification celtique:** Le sorbier est l'arbre de protection contre les mauvais esprits. Les druides le plantaient devant les portes.

**Synergie cachee:** Si utilise quand Ame est en etat "Possedee", la protection est garantie (100% au lieu de 50%).

---

### QUERT (ᚊ) — Pommier — Recovery

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Quert |
| **Arbre** | Pommier (Malus) |
| **Symbole Ogham** | ᚊ |
| **Categorie** | Recovery (Starter) |
| **Cout Awen** | 1 |
| **Cooldown** | 4 cartes |
| **Deblocage** | Starter (automatique) |

**Effet:** **Pomme d'Avalon** — Ramene **un** aspect extreme (Bas ou Haut) vers l'Equilibre. Si aucun aspect n'est extreme, rafraichit 1 Souffle d'Ogham.

**Feedback visuel:** Une pomme doree apparait et se decompose en particules qui entourent le symbole de l'aspect soigne. Transition animee de l'etat (ex: Epuise -> Robuste).

**Signification celtique:** Le pommier est l'arbre d'Avalon — l'Ile des Pommes ou la guerison est eternelle.

**Synergie cachee:** Si utilise quand les 3 aspects sont tous en Equilibre, Quert accorde +2 Souffle d'Awen au lieu de +1 Souffle d'Ogham.

---

## REVEAL (Information)

### COLL (ᚉ) — Noisetier — Reveal

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Coll |
| **Arbre** | Noisetier (Corylus) |
| **Symbole Ogham** | ᚉ |
| **Categorie** | Reveal |
| **Cout Awen** | 2 |
| **Cooldown** | 5 cartes |
| **Deblocage** | Bond tier 2+ ou Achievement "Premier doute" |

**Effet:** **Vision du Noisetier** — Revele les impacts de **toutes les options** (Gauche, Centre, Droite) simultanement.

**Feedback visuel:** Les 3 options s'illuminent avec les symboles d'aspects et fleches directionnelles. Les effets restent visibles pendant 10 secondes ou jusqu'au choix.

**Signification celtique:** Le noisetier est l'arbre de la sagesse. Le Saumon de la Connaissance a mange des noisettes du Puits de Sagesse.

**Condition de deblocage meta:** Avoir termine 3 runs (win ou lose).

---

### AILM (ᚐ) — Epicea — Reveal

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Ailm |
| **Arbre** | Epicea/Pin (Picea) |
| **Symbole Ogham** | ᚐ |
| **Categorie** | Reveal |
| **Cout Awen** | 1 |
| **Cooldown** | 4 cartes |
| **Deblocage** | Bond tier 3+ ou Achievement "Regard lointain" |

**Effet:** **Oeil du Pin** — Revele le **type** de la prochaine carte (narrative, event, promise, merlin_direct) et son theme general (conflict, social, mystique, survie).

**Feedback visuel:** Une aiguille de pin lumineuse pointe vers une icone representant la prochaine carte (epee = conflit, mains = social, etoile = mystique, feu = survie).

**Signification celtique:** Le pin/epicea est l'arbre de la clarte et de la vision lointaine. Ses aiguilles persistantes voient a travers l'hiver.

**Condition de deblocage meta:** Avoir joue 50+ cartes cumulees.

---

## PROTECTION (Defense)

### GORT (ᚌ) — Lierre — Protection

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Gort |
| **Arbre** | Lierre (Hedera) |
| **Symbole Ogham** | ᚌ |
| **Categorie** | Protection |
| **Cout Awen** | 2 |
| **Cooldown** | 6 cartes |
| **Deblocage** | Bond tier 2+ ou Achievement "Survivant" |

**Effet:** **Etreinte du Lierre** — Absorbe completement le **premier** shift negatif du prochain choix. Si le choix a 2 shifts negatifs, seul le premier est absorbe.

**Feedback visuel:** Des lianes de lierre s'enroulent autour de l'aspect protege. Quand le shift est absorbe, les lianes brillent puis se dissolvent.

**Signification celtique:** Le lierre est l'arbre de la tenacite. Il s'accroche, il entoure, il protege par sa persistance.

**Synergie cachee:** Si combine avec Luis (meme carte), la protection absorbe TOUS les shifts negatifs (pas juste le premier).

---

### EADHADH (ᚓ) — Peuplier — Protection

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Eadhadh |
| **Arbre** | Peuplier/Tremble (Populus) |
| **Symbole Ogham** | ᚓ |
| **Categorie** | Protection |
| **Cout Awen** | 3 |
| **Cooldown** | 8 cartes |
| **Deblocage** | Bond tier 4+ ou Achievement "Danse avec la peur" |

**Effet:** **Tremblement du Peuplier** — **Refuse** la carte actuelle. La carte est defaussee et remplacee par une nouvelle carte generee. Le joueur perd 1 Souffle d'Ogham en compensation.

**Feedback visuel:** La carte tremble violemment (comme les feuilles du peuplier dans le vent), puis s'envole en tourbillonnant. Une nouvelle carte glisse depuis le haut.

**Signification celtique:** Le peuplier tremble au moindre vent — il transforme la peur en mouvement. Fuir n'est pas lachete, c'est survie.

**Restriction:** Ne peut pas etre utilise 2 fois d'affilee.

---

## BOOST (Amplification)

### DUIR (ᚇ) — Chene — Boost

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Duir |
| **Arbre** | Chene (Quercus) |
| **Symbole Ogham** | ᚇ |
| **Categorie** | Boost |
| **Cout Awen** | 2 |
| **Cooldown** | 5 cartes |
| **Deblocage** | Bond tier 2+ ou Achievement "Force tranquille" |

**Effet:** **Force du Chene** — Empeche tout shift negatif pour le prochain choix. Les effets positifs sont appliques normalement, les negatifs sont ignores.

**Feedback visuel:** Un chene massif apparait brievement derriere la carte. Ses racines s'etendent sous les symboles d'aspects. Les shifts negatifs rebondissent sur le tronc.

**Signification celtique:** Le chene (Duir) est l'arbre supreme des druides. "Druide" derive possiblement de "dru-wid" = "celui qui connait le chene". Force, endurance, sagesse.

**Synergie cachee:** Si Corps est en etat "Robuste" au moment de l'activation, Duir accorde aussi +1 Souffle d'Ogham.

---

### TINNE (ᚈ) — Houx — Boost

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Tinne |
| **Arbre** | Houx (Ilex) |
| **Symbole Ogham** | ᚈ |
| **Categorie** | Boost |
| **Cout Awen** | 2 |
| **Cooldown** | 5 cartes |
| **Deblocage** | Bond tier 3+ ou Achievement "Guerrier du gui" |

**Effet:** **Lame de Houx** — Le prochain shift positif est **double**: si un aspect devait monter d'un etat, il monte de deux (ex: Bas -> Haut directement, sautant Equilibre).

**Feedback visuel:** Les feuilles de houx (pointues, brillantes) entourent le symbole de l'aspect booste. Le shift s'anime avec une fleche double.

**Signification celtique:** Le houx est le guerrier — equilibre entre attaque et defense, ses feuilles coupantes et ses baies nourricières.

**Restriction:** Si le double shift causerait un etat extreme qui declencherait une fin de run, le shift est reduit a simple (securite).

---

### ONN (ᚑ) — Ajonc — Boost

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Onn |
| **Arbre** | Ajonc (Ulex) |
| **Symbole Ogham** | ᚑ |
| **Categorie** | Boost |
| **Cout Awen** | 3 |
| **Cooldown** | 7 cartes |
| **Deblocage** | Bond tier 4+ ou Achievement "Moisson dorée" |

**Effet:** **Flamme d'Ajonc** — Pour les **3 prochaines cartes**, tous les shifts vers l'Equilibre sont automatiques: si un effet devait pousser un aspect vers l'extreme, il est redirige vers l'Equilibre.

**Feedback visuel:** Bestiole s'entoure de flammes dorées (couleur ajonc). Un compteur "3" apparait et decremente a chaque carte.

**Signification celtique:** L'ajonc (Onn) fleurit meme en hiver. Ses fleurs jaunes sont comme des flammes de soleil dans l'obscurite. Il attire, il collecte, il rayonne.

**Synergie cachee:** Si active pendant le biome "Landes", l'effet dure 5 cartes au lieu de 3.

---

## NARRATIVE (Manipulation de cartes)

### NUIN (ᚅ) — Frene — Narrative

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Nuin |
| **Arbre** | Frene (Fraxinus) |
| **Symbole Ogham** | ᚅ |
| **Categorie** | Narrative |
| **Cout Awen** | 2 |
| **Cooldown** | 6 cartes |
| **Deblocage** | Bond tier 3+ ou Achievement "Pont entre les mondes" |

**Effet:** **Branches du Frene** — Modifie l'option Centre: son cout en Souffle d'Ogham est annule pour cette carte (option Centre gratuite).

**Feedback visuel:** Les branches du frene s'etendent et "soutiennent" l'option Centre. Le cout en Souffle disparait avec une animation de dissolution.

**Signification celtique:** Le frene (Nion) est l'Arbre du Monde (Yggdrasil en nordique, mais aussi present dans la mythologie celtique). Il connecte les mondes, ouvre les passages.

**Note design:** Dans l'ancien systeme, Nuin "ajoutait une 3eme option". Comme le systeme Triade a deja 3 options, l'effet est redefini pour rendre l'option Centre accessible.

---

### HUATH (ᚆ) — Aubepine — Narrative

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Huath |
| **Arbre** | Aubepine (Crataegus) |
| **Symbole Ogham** | ᚆ |
| **Categorie** | Narrative |
| **Cout Awen** | 2 |
| **Cooldown** | 5 cartes |
| **Deblocage** | Bond tier 2+ ou Achievement "Porte de l'aubepine" |

**Effet:** **Porte de l'Aubepine** — Remplace la carte actuelle par une carte du **meme theme** mais avec des options differentes. Les effets seront differents mais le contexte narratif reste coherent.

**Feedback visuel:** Des fleurs d'aubepine (blanches avec coeur rose) tourbillonnent autour de la carte. La carte ancienne se transforme en petales, la nouvelle carte emerge.

**Signification celtique:** L'aubepine marque les entrees du monde des fees. Passer une porte d'aubepine, c'est entrer dans une version differente de la meme histoire.

**Restriction:** La nouvelle carte conserve le meme niveau de tension que l'originale.

---

### STRAIF (ᚎ) — Prunellier — Narrative

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Straif |
| **Arbre** | Prunellier (Prunus spinosa) |
| **Symbole Ogham** | ᚎ |
| **Categorie** | Narrative |
| **Cout Awen** | 3 |
| **Cooldown** | 10 cartes |
| **Deblocage** | Bond tier 5 ou Achievement "Touche par le destin" |

**Effet:** **Epine du Destin** — Force la prochaine carte a etre un **evenement rare** (event special, rencontre de fee, visite de l'Annwn, revelation de Merlin). Ces cartes ont des effets plus puissants (positifs ET negatifs).

**Feedback visuel:** Une epine noire percée de lumiere. L'ecran s'assombrit brievement. Quand la carte speciale arrive, un eclat de lumiere violette.

**Signification celtique:** Le prunellier (Straif) est l'arbre du destin force. Ses epines sont impitoyables. Utiliser Straif, c'est invoquer le changement radical — pour le meilleur ou pour le pire.

**Avertissement UI:** Quand le joueur selectionne Straif, un texte d'avertissement apparait: "Le destin ne se controle pas. Es-tu sur?"

---

## RECOVERY (Guerison)

### RUIS (ᚏ) — Sureau — Recovery

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Ruis |
| **Arbre** | Sureau (Sambucus) |
| **Symbole Ogham** | ᚏ |
| **Categorie** | Recovery |
| **Cout Awen** | 3 |
| **Cooldown** | 8 cartes |
| **Deblocage** | Bond tier 4+ ou Achievement "Fin et commencement" |

**Effet:** **Equilibre du Sureau** — Ramene **tous les aspects** d'un cran vers l'Equilibre. Les aspects en Haut descendent, les aspects en Bas montent, les aspects en Equilibre restent.

**Feedback visuel:** Des baies de sureau (noires, luisantes) tombent en pluie douce. Chaque aspect affecte recoit une baie qui pulse et l'etat se deplace visuellement.

**Signification celtique:** Le sureau est l'arbre de la transformation, de la fin et du commencement. Il equilibre la vie et la mort.

**Restriction:** Si les 3 aspects sont deja en Equilibre, Ruis n'a aucun effet (ne gaspille pas le Souffle d'Awen, mais le cooldown s'active).

---

### SAILLE (ᚄ) — Saule — Recovery

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Saille |
| **Arbre** | Saule (Salix) |
| **Symbole Ogham** | ᚄ |
| **Categorie** | Recovery |
| **Cout Awen** | 2 |
| **Cooldown** | 6 cartes |
| **Deblocage** | Bond tier 3+ ou Achievement "Larmes du saule" |

**Effet:** **Branches Pleureuses** — Pour les **3 prochaines cartes**, si un shift pousserait un aspect vers l'extreme (de Equilibre vers Haut/Bas), ce shift est annule. Les aspects deja extremes ne sont pas affectes.

**Feedback visuel:** Des branches de saule (vertes, fluides) pendent depuis le haut de l'ecran. Quand un shift est absorbe, une branche se souleve puis retombe.

**Signification celtique:** Le saule est l'arbre de l'intuition et des emotions. Il pleure, mais ses larmes guerissent. Il plie sans se rompre.

**Synergie cachee:** Si utilise pres d'un point d'eau dans le biome (Cotes, Marais), l'effet dure 5 cartes.

---

## SPECIAL (Effets uniques)

### MUIN (ᚋ) — Vigne — Special

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Muin |
| **Arbre** | Vigne (Vitis) |
| **Symbole Ogham** | ᚋ |
| **Categorie** | Special |
| **Cout Awen** | 2 |
| **Cooldown** | 7 cartes |
| **Deblocage** | Bond tier 3+ ou Achievement "In vino veritas" |

**Effet:** **Ivresse de Verite** — **Inverse** les directions de shift d'une option au choix. Les shifts "up" deviennent "down" et vice versa. Le joueur voit le resultat de l'inversion avant de choisir.

**Feedback visuel:** Des vrilles de vigne s'enroulent autour de l'option choisie. Les fleches d'impact se retournent avec une animation de rotation. Couleur pourpre.

**Signification celtique:** La vigne est l'arbre de la celebration et de la verite cachee. Le vin revele la verite que la sobriete dissimule.

**Restriction:** L'inversion est revelee avant le choix (le joueur ne joue pas a l'aveugle).

---

### IOHO (ᚔ) — If — Special

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Ioho |
| **Arbre** | If (Taxus) |
| **Symbole Ogham** | ᚔ |
| **Categorie** | Special |
| **Cout Awen** | 3 |
| **Cooldown** | 12 cartes |
| **Deblocage** | Bond tier 5 ou Achievement "Au seuil de la mort" |

**Effet:** **Renaissance de l'If** — **Reroll complet** de la carte actuelle. Le LLM genere une toute nouvelle carte (nouveau texte, nouvelles options, nouveaux effets). Rien de la carte originale n'est conserve.

**Feedback visuel:** La carte se decompose en cendres (noir et rouge). Des pousses vertes emergent des cendres. Une nouvelle carte se materialise, fraiche et verte.

**Signification celtique:** L'if est l'arbre le plus ancien — il peut vivre des milliers d'annees. Il represente la mort et la renaissance. Les ifs poussent dans les cimetieres celtiques.

**Restriction:** Le reroll peut generer une carte plus dangereuse que l'originale. Pas de garantie.

---

### UR (ᚒ) — Bruyere — Special

| Propriete | Valeur |
|-----------|--------|
| **Nom** | Ur |
| **Arbre** | Bruyere (Calluna) |
| **Symbole Ogham** | ᚒ |
| **Categorie** | Special |
| **Cout Awen** | 2 |
| **Cooldown** | 10 cartes |
| **Deblocage** | Bond tier 4+ ou Achievement "Passion des landes" |

**Effet:** **Sacrifice de la Bruyere** — Le joueur choisit **un aspect** et le pousse deliberement vers l'extreme (1 shift dans la direction souhaitee). En echange, les **2 autres aspects** sont ramenes vers l'Equilibre (1 shift chacun).

**Feedback visuel:** La bruyere fleurit (pourpre/rose) autour de l'aspect sacrifie. Les 2 autres aspects sont baignes de lumiere chaude.

**Signification celtique:** La bruyere (Ur) couvre les landes bretonnes. C'est la passion — douce mais tenace, belle mais rude. Le sacrifice consenti pour l'equilibre general.

**Cas d'usage strategique:** Quand 2 aspects sont proches de l'extreme, sacrifier le 3eme (qui va bien) pour sauver les 2 autres.

---

# 7. Equilibrage vs Systeme Triade

## 7.1 Matrice d'impact des Oghams par situation

### Situations critiques et Oghams adaptes

| Situation | Danger | Oghams recommandes | Pourquoi |
|-----------|--------|---------------------|----------|
| 2 aspects a l'extreme (mort imminente) | Critique | **Ruis** (equilibre tout), **Quert** (soigne 1) | Recovery d'urgence |
| 1 aspect extreme, 1 menace | Haut | **Luis** (protection), **Duir** (bloque negatif) | Prevention |
| Pas de Souffle d'Ogham | Moyen | **Nuin** (Centre gratuit) | Economie |
| Choix totalement aveugle | Moyen | **Beith** (revele 1), **Coll** (revele tout) | Information |
| Carte dangereuse | Haut | **Eadhadh** (refuse carte), **Huath** (remplace) | Evitement |
| Besoin de control narratif | Bas | **Straif** (force rare), **Muin** (inverse) | Manipulation |
| Position d'equilibre stable | Bas | **Onn** (protection auto 3 tours), **Saille** (idem) | Consolidation |

## 7.2 Courbe de puissance par Bond tier

```
Bond 0-20 (Etranger):
  3 starters seulement
  Cout 1 Awen chacun
  Capacite: ~2 activations par tranche de 5 cartes
  Impact: faible mais utile

Bond 21-40 (Curieux):
  3 starters + 1 Ogham
  Impact moyen
  Le joueur commence a planifier ses activations

Bond 41-60 (Compagnon):
  3 starters + 2 Oghams
  Impact significant
  Synergies possibles entre starters et Oghams equipes

Bond 61-80 (Lie):
  3 starters + 3 Oghams + hints de Merlin
  Impact fort
  Le joueur peut adapter sa strategie a chaque carte

Bond 81-100 (Ame soeur):
  Tous les Oghams + bonus passifs + synergies
  Impact tres fort
  Le joueur maitrise le systeme
```

## 7.3 Frequence d'utilisation cible

| Par run (30 cartes) | Estimation |
|----------------------|------------|
| Regeneration Souffle d'Awen | ~6 fois (1/5 cartes) + bonus |
| Total Souffle disponible | ~12-15 Awen sur la run |
| Activations Ogham | 6-10 (selon couts) |
| Oghams cout 1 | 4-6 activations |
| Oghams cout 2 | 2-3 activations |
| Oghams cout 3 | 1-2 activations |

**Philosophie:** Le joueur devrait pouvoir activer un Ogham environ **1 fois toutes les 3-4 cartes** en moyenne. Assez frequent pour etre satisfaisant, assez rare pour que chaque activation compte.

## 7.4 Regle anti-abus

| Regle | Raison |
|-------|--------|
| 1 seul Ogham par carte | Empeche le stacking |
| Cooldown minimum 3 cartes | Empeche le spam |
| Souffle d'Awen cap a 5 | Empeche l'accumulation |
| Starters toujours cout 1 | Garantit un acces de base |
| Certains Oghams 1/run max | Pour les plus puissants (Ioho, Straif) |

---

# 8. Specs d'Implementation GDScript

## 8.1 Structure de Donnees — Ogham

```gdscript
# Dans merlin_constants.gd

const OGHAM_FULL_SPECS := {
    # === STARTERS ===
    "beith": {
        "name": "Bouleau",
        "tree_name_breton": "Beith",
        "unicode": "\u1681",  # ᚁ
        "category": "reveal",
        "is_starter": true,
        "awen_cost": 1,
        "cooldown": 3,
        "effect_id": "reveal_one_option",
        "description": "Revele l'impact d'une option au choix",
        "description_short": "Voir 1 option",
        "lore": "Le bouleau est l'arbre des nouveaux departs.",
        "unlock_condition": "starter",
        "synergy_hint": "3 usages d'affilee = revelation complete",
    },
    "luis": {
        "name": "Sorbier",
        "tree_name_breton": "Luis",
        "unicode": "\u1682",  # ᚂ
        "category": "protection",
        "is_starter": true,
        "awen_cost": 1,
        "cooldown": 4,
        "effect_id": "shield_50_percent",
        "description": "50% de chance d'annuler 1 shift negatif",
        "description_short": "Bouclier 50%",
        "lore": "Le sorbier protege contre les mauvais esprits.",
        "unlock_condition": "starter",
        "synergy_hint": "100% si Ame Possedee",
    },
    "quert": {
        "name": "Pommier",
        "tree_name_breton": "Quert",
        "unicode": "\u168A",  # ᚊ
        "category": "recovery",
        "is_starter": true,
        "awen_cost": 1,
        "cooldown": 4,
        "effect_id": "heal_one_extreme",
        "description": "Ramene 1 aspect extreme vers l'Equilibre",
        "description_short": "Soigne 1 aspect",
        "lore": "Le pommier est l'arbre d'Avalon.",
        "unlock_condition": "starter",
        "synergy_hint": "Si tout equilibre: +2 Souffle d'Awen",
    },

    # === REVEAL ===
    "coll": {
        "name": "Noisetier",
        "tree_name_breton": "Coll",
        "unicode": "\u1689",  # ᚉ
        "category": "reveal",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 5,
        "effect_id": "reveal_all_options",
        "description": "Revele les impacts de toutes les options",
        "description_short": "Voir tout",
        "lore": "Le noisetier est l'arbre de la sagesse.",
        "unlock_condition": "bond_tier_2",
        "meta_unlock": "3_runs_completed",
        "synergy_hint": "",
    },
    "ailm": {
        "name": "Epicea",
        "tree_name_breton": "Ailm",
        "unicode": "\u1690",  # ᚐ
        "category": "reveal",
        "is_starter": false,
        "awen_cost": 1,
        "cooldown": 4,
        "effect_id": "predict_next_card",
        "description": "Revele le type et theme de la prochaine carte",
        "description_short": "Prediction",
        "lore": "Le pin voit a travers l'hiver.",
        "unlock_condition": "bond_tier_3",
        "meta_unlock": "50_cards_played",
        "synergy_hint": "",
    },

    # === PROTECTION ===
    "gort": {
        "name": "Lierre",
        "tree_name_breton": "Gort",
        "unicode": "\u168C",  # ᚌ
        "category": "protection",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 6,
        "effect_id": "absorb_first_negative",
        "description": "Absorbe le premier shift negatif du prochain choix",
        "description_short": "Absorbe 1 negatif",
        "lore": "Le lierre s'accroche et protege par sa tenacite.",
        "unlock_condition": "bond_tier_2",
        "meta_unlock": "survive_20_cards",
        "synergy_hint": "Combine avec Luis = absorbe tous les negatifs",
    },
    "eadhadh": {
        "name": "Peuplier",
        "tree_name_breton": "Eadhadh",
        "unicode": "\u1693",  # ᚓ
        "category": "protection",
        "is_starter": false,
        "awen_cost": 3,
        "cooldown": 8,
        "effect_id": "refuse_card",
        "description": "Refuse la carte actuelle, en obtient une nouvelle (-1 Souffle d'Ogham)",
        "description_short": "Refuse carte",
        "lore": "Le peuplier tremble mais survit.",
        "unlock_condition": "bond_tier_4",
        "meta_unlock": "face_death_3_times",
        "synergy_hint": "",
    },

    # === BOOST ===
    "duir": {
        "name": "Chene",
        "tree_name_breton": "Duir",
        "unicode": "\u1687",  # ᚇ
        "category": "boost",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 5,
        "effect_id": "block_all_negative",
        "description": "Empeche tout shift negatif pour le prochain choix",
        "description_short": "Aucun negatif",
        "lore": "Le chene est l'arbre supreme des druides.",
        "unlock_condition": "bond_tier_2",
        "meta_unlock": "5_runs_completed",
        "synergy_hint": "Corps Robuste = +1 Souffle d'Ogham",
    },
    "tinne": {
        "name": "Houx",
        "tree_name_breton": "Tinne",
        "unicode": "\u1688",  # ᚈ
        "category": "boost",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 5,
        "effect_id": "double_positive_shift",
        "description": "Double le prochain shift positif (saute 1 etat)",
        "description_short": "Double positif",
        "lore": "Le houx est le guerrier: attaque et defense.",
        "unlock_condition": "bond_tier_3",
        "meta_unlock": "10_positive_shifts",
        "synergy_hint": "Securite: ne cause jamais de fin de run",
    },
    "onn": {
        "name": "Ajonc",
        "tree_name_breton": "Onn",
        "unicode": "\u1691",  # ᚑ
        "category": "boost",
        "is_starter": false,
        "awen_cost": 3,
        "cooldown": 7,
        "effect_id": "redirect_to_equilibre_3turns",
        "description": "3 cartes: les shifts se redirigent vers l'Equilibre",
        "description_short": "Equilibre force 3t",
        "lore": "L'ajonc fleurit meme en hiver.",
        "unlock_condition": "bond_tier_4",
        "meta_unlock": "achieve_harmony_once",
        "synergy_hint": "Biome Landes = 5 tours au lieu de 3",
    },

    # === NARRATIVE ===
    "nuin": {
        "name": "Frene",
        "tree_name_breton": "Nuin",
        "unicode": "\u1685",  # ᚅ
        "category": "narrative",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 6,
        "effect_id": "free_center_option",
        "description": "L'option Centre est gratuite pour cette carte",
        "description_short": "Centre gratuit",
        "lore": "Le frene est l'Arbre du Monde, connecteur des royaumes.",
        "unlock_condition": "bond_tier_3",
        "meta_unlock": "use_center_10_times",
        "synergy_hint": "",
    },
    "huath": {
        "name": "Aubepine",
        "tree_name_breton": "Huath",
        "unicode": "\u1686",  # ᚆ
        "category": "narrative",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 5,
        "effect_id": "replace_card_same_theme",
        "description": "Remplace la carte par une variante du meme theme",
        "description_short": "Change carte",
        "lore": "L'aubepine marque les entrees du monde des fees.",
        "unlock_condition": "bond_tier_2",
        "meta_unlock": "encounter_fae_event",
        "synergy_hint": "",
    },
    "straif": {
        "name": "Prunellier",
        "tree_name_breton": "Straif",
        "unicode": "\u168E",  # ᚎ
        "category": "narrative",
        "is_starter": false,
        "awen_cost": 3,
        "cooldown": 10,
        "effect_id": "force_rare_event",
        "description": "Force la prochaine carte a etre un evenement rare",
        "description_short": "Force rare",
        "lore": "Le prunellier est l'arbre du destin force.",
        "unlock_condition": "bond_tier_5",
        "meta_unlock": "see_all_endings_3",
        "synergy_hint": "Avertissement: le destin ne se controle pas",
    },

    # === RECOVERY ===
    "ruis": {
        "name": "Sureau",
        "tree_name_breton": "Ruis",
        "unicode": "\u168F",  # ᚏ
        "category": "recovery",
        "is_starter": false,
        "awen_cost": 3,
        "cooldown": 8,
        "effect_id": "equilibrate_all_aspects",
        "description": "Ramene tous les aspects d'un cran vers l'Equilibre",
        "description_short": "Equilibre tout",
        "lore": "Le sureau: fin et commencement.",
        "unlock_condition": "bond_tier_4",
        "meta_unlock": "survive_all_extremes",
        "synergy_hint": "Inactif si tout est deja equilibre",
    },
    "saille": {
        "name": "Saule",
        "tree_name_breton": "Saille",
        "unicode": "\u1684",  # ᚄ
        "category": "recovery",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 6,
        "effect_id": "prevent_extreme_3turns",
        "description": "3 cartes: empeche les shifts vers l'extreme depuis Equilibre",
        "description_short": "Anti-extreme 3t",
        "lore": "Le saule pleure, mais ses larmes guerissent.",
        "unlock_condition": "bond_tier_3",
        "meta_unlock": "play_near_water_biome",
        "synergy_hint": "Biomes aquatiques = 5 tours",
    },

    # === SPECIAL ===
    "muin": {
        "name": "Vigne",
        "tree_name_breton": "Muin",
        "unicode": "\u168B",  # ᚋ
        "category": "special",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 7,
        "effect_id": "invert_option_shifts",
        "description": "Inverse les directions de shift d'une option choisie",
        "description_short": "Inverse effets",
        "lore": "La vigne revele la verite cachee.",
        "unlock_condition": "bond_tier_3",
        "meta_unlock": "discover_hidden_depth",
        "synergy_hint": "L'inversion est revelee avant le choix",
    },
    "ioho": {
        "name": "If",
        "tree_name_breton": "Ioho",
        "unicode": "\u1694",  # ᚔ
        "category": "special",
        "is_starter": false,
        "awen_cost": 3,
        "cooldown": 12,
        "effect_id": "full_card_reroll",
        "description": "Reroll complet: nouvelle carte generee par le LLM",
        "description_short": "Carte neuve",
        "lore": "L'if meurt et renait depuis des millenaires.",
        "unlock_condition": "bond_tier_5",
        "meta_unlock": "survive_30_card_run",
        "synergy_hint": "Aucune garantie sur la nouvelle carte",
    },
    "ur": {
        "name": "Bruyere",
        "tree_name_breton": "Ur",
        "unicode": "\u1692",  # ᚒ
        "category": "special",
        "is_starter": false,
        "awen_cost": 2,
        "cooldown": 10,
        "effect_id": "sacrifice_one_heal_two",
        "description": "Pousse 1 aspect vers l'extreme, ramene les 2 autres vers l'Equilibre",
        "description_short": "Sacrifice/soigne",
        "lore": "La bruyere couvre les landes: passion et sacrifice.",
        "unlock_condition": "bond_tier_4",
        "meta_unlock": "sacrifice_aspect_voluntarily",
        "synergy_hint": "Strategique quand 2 aspects menacent",
    },
}

# Souffle d'Awen constants
const AWEN_MAX := 5
const AWEN_START := 2
const AWEN_REGEN_INTERVAL := 5  # Every N cards
const AWEN_REGEN_BASE := 1
const AWEN_REGEN_EQUILIBRE_BONUS := 1

# Ogham slots by bond tier
const OGHAM_EXTRA_SLOTS_BY_TIER := {
    1: 0,  # 0-20: starters only
    2: 1,  # 21-40: +1 slot
    3: 2,  # 41-60: +2 slots
    4: 3,  # 61-80: +3 slots
    5: -1, # 81-100: unlimited (-1 = all)
}
```

## 8.2 Structure de Donnees — Bestiole State (dans merlin_store.gd)

```gdscript
# Updated bestiole state for merlin_store.build_default_state()
"bestiole": {
    "name": "Bestiole",

    # Bond system
    "bond": 30,  # Start at 30 (not stranger, but not yet friend)
    "bond_tier": 2,  # Calculated from bond value

    # Awen system
    "awen": MerlinConstants.AWEN_START,  # Current Souffle d'Awen
    "awen_max": MerlinConstants.AWEN_MAX,

    # Skills
    "skills_unlocked": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
    "skills_equipped": MerlinConstants.OGHAM_STARTER_SKILLS.duplicate(),
    "skill_cooldowns": {},  # {"beith": 0, "luis": 2, "quert": 0}
    "skill_used_this_card": false,  # Reset each card

    # Active effects (ongoing Oghams)
    "active_effects": [],  # [{"ogham": "onn", "turns_remaining": 3, "effect": "redirect_to_equilibre"}]

    # Synergy tracking (hidden)
    "beith_consecutive_uses": 0,
    "last_ogham_used": "",

    # Mood (cosmetic + minor gameplay)
    "mood": "content",  # "triste", "neutre", "content", "joyeux", "extatique"

    # Meta tracking
    "total_activations": 0,
    "total_activations_by_ogham": {},
},
```

## 8.3 Fonctions cles a implementer

```gdscript
# === BESTIOLE SYSTEM ===

# Bond management
func get_bond_tier(bond: int) -> int:
    """Returns 1-5 based on bond value."""
    if bond <= 20: return 1
    elif bond <= 40: return 2
    elif bond <= 60: return 3
    elif bond <= 80: return 4
    else: return 5

func add_bond(amount: int) -> void:
    """Add bond, cap at 100, emit signal if tier changes."""
    var old_tier := get_bond_tier(state.bestiole.bond)
    state.bestiole.bond = clampi(state.bestiole.bond + amount, 0, 100)
    var new_tier := get_bond_tier(state.bestiole.bond)
    state.bestiole.bond_tier = new_tier
    if new_tier != old_tier:
        emit_signal("bond_tier_changed", old_tier, new_tier)

# Awen management
func regenerate_awen() -> void:
    """Called every AWEN_REGEN_INTERVAL cards."""
    var gain: int = MerlinConstants.AWEN_REGEN_BASE
    if _all_aspects_equilibre():
        gain += MerlinConstants.AWEN_REGEN_EQUILIBRE_BONUS
    state.bestiole.awen = mini(state.bestiole.awen + gain, state.bestiole.awen_max)
    emit_signal("awen_changed", state.bestiole.awen)

func spend_awen(cost: int) -> bool:
    """Spend Awen, returns true if successful."""
    if state.bestiole.awen >= cost:
        state.bestiole.awen -= cost
        emit_signal("awen_changed", state.bestiole.awen)
        return true
    return false

# Ogham activation
func can_use_ogham(ogham_id: String) -> Dictionary:
    """Check if an Ogham can be used. Returns {can: bool, reason: String}."""
    var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_id, {})
    if spec.is_empty():
        return {"can": false, "reason": "Ogham inconnu"}

    # Already used this card?
    if state.bestiole.skill_used_this_card:
        return {"can": false, "reason": "Deja utilise ce tour"}

    # Unlocked?
    if ogham_id not in state.bestiole.skills_unlocked:
        return {"can": false, "reason": "Non deverrouille (Lien requis)"}

    # Equipped? (starters always equipped)
    if not spec.is_starter and ogham_id not in state.bestiole.skills_equipped:
        return {"can": false, "reason": "Non equipe"}

    # Cooldown?
    var remaining_cd: int = state.bestiole.skill_cooldowns.get(ogham_id, 0)
    if remaining_cd > 0:
        return {"can": false, "reason": "Cooldown: %d cartes" % remaining_cd}

    # Awen cost?
    if state.bestiole.awen < spec.awen_cost:
        return {"can": false, "reason": "Souffle d'Awen insuffisant (%d/%d)" % [state.bestiole.awen, spec.awen_cost]}

    return {"can": true, "reason": ""}

func activate_ogham(ogham_id: String) -> Dictionary:
    """Activate an Ogham. Returns the effect to apply."""
    var check := can_use_ogham(ogham_id)
    if not check.can:
        return {"success": false, "reason": check.reason}

    var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_id]

    # Spend Awen
    spend_awen(spec.awen_cost)

    # Set cooldown
    state.bestiole.skill_cooldowns[ogham_id] = spec.cooldown

    # Mark as used this card
    state.bestiole.skill_used_this_card = true

    # Track
    state.bestiole.total_activations += 1
    if ogham_id not in state.bestiole.total_activations_by_ogham:
        state.bestiole.total_activations_by_ogham[ogham_id] = 0
    state.bestiole.total_activations_by_ogham[ogham_id] += 1

    # Bond gain
    add_bond(2)

    # Synergy tracking
    _track_synergy(ogham_id)

    # Build effect
    var effect := _build_ogham_effect(ogham_id, spec)

    emit_signal("ogham_activated", ogham_id, effect)
    return {"success": true, "effect": effect, "ogham": spec}

func _build_ogham_effect(ogham_id: String, spec: Dictionary) -> Dictionary:
    """Build the specific effect dictionary for the Ogham."""
    match spec.effect_id:
        "reveal_one_option":
            var reveal_count := 1
            # Synergy: 3 consecutive beith = reveal all
            if ogham_id == "beith" and state.bestiole.beith_consecutive_uses >= 2:
                reveal_count = 3
            return {"type": "reveal", "count": reveal_count}

        "shield_50_percent":
            var chance := 0.5
            # Synergy: if Ame is Possedee, 100%
            if state.run.aspects.get("Ame") == MerlinConstants.AspectState.HAUT:
                chance = 1.0
            return {"type": "shield", "chance": chance, "max_blocks": 1}

        "heal_one_extreme":
            var extremes := _get_extreme_aspects()
            if extremes.is_empty():
                # No extremes: grant souffle d'ogham instead
                return {"type": "grant_souffle_ogham", "amount": 1}
            return {"type": "heal_extreme", "targets": extremes}

        "reveal_all_options":
            return {"type": "reveal", "count": 3}

        "predict_next_card":
            return {"type": "predict_next"}

        "absorb_first_negative":
            var max_absorb := 1
            # Synergy: with Luis active = absorb all
            if "luis" in _get_active_shield_oghams():
                max_absorb = -1  # unlimited
            return {"type": "absorb_negative", "max_absorb": max_absorb}

        "refuse_card":
            return {"type": "refuse_card", "souffle_ogham_cost": 1}

        "block_all_negative":
            var bonus_souffle := false
            # Synergy: Corps Robuste = +1 Souffle d'Ogham
            if state.run.aspects.get("Corps") == MerlinConstants.AspectState.EQUILIBRE:
                bonus_souffle = true
            return {"type": "block_negative", "bonus_souffle_ogham": bonus_souffle}

        "double_positive_shift":
            return {"type": "double_positive", "safety": true}  # safety = don't cause death

        "redirect_to_equilibre_3turns":
            var turns := 3
            # Synergy: Landes biome = 5
            if state.run.get("biome", "") == "landes":
                turns = 5
            return {"type": "ongoing_redirect", "turns": turns}

        "free_center_option":
            return {"type": "free_center"}

        "replace_card_same_theme":
            return {"type": "replace_card", "keep_theme": true}

        "force_rare_event":
            return {"type": "force_rare"}

        "equilibrate_all_aspects":
            return {"type": "equilibrate_all"}

        "prevent_extreme_3turns":
            var turns := 3
            # Synergy: water biomes = 5
            if state.run.get("biome", "") in ["cotes", "marais"]:
                turns = 5
            return {"type": "ongoing_prevent_extreme", "turns": turns}

        "invert_option_shifts":
            return {"type": "invert_shifts", "reveal_before_choice": true}

        "full_card_reroll":
            return {"type": "full_reroll"}

        "sacrifice_one_heal_two":
            return {"type": "sacrifice_trade", "player_chooses_aspect": true}

    return {}

# Cooldown management
func tick_cooldowns() -> void:
    """Called after each card is resolved."""
    for ogham_id in state.bestiole.skill_cooldowns:
        if state.bestiole.skill_cooldowns[ogham_id] > 0:
            state.bestiole.skill_cooldowns[ogham_id] -= 1

    # Reset per-card flag
    state.bestiole.skill_used_this_card = false

    # Tick ongoing effects
    _tick_ongoing_effects()

    # Awen regeneration check
    state.run.cards_played += 1
    if state.run.cards_played % MerlinConstants.AWEN_REGEN_INTERVAL == 0:
        regenerate_awen()

func _tick_ongoing_effects() -> void:
    """Decrement ongoing effect timers, remove expired ones."""
    var remaining: Array = []
    for effect in state.bestiole.active_effects:
        effect.turns_remaining -= 1
        if effect.turns_remaining > 0:
            remaining.append(effect)
        else:
            emit_signal("ongoing_effect_expired", effect.ogham)
    state.bestiole.active_effects = remaining

# Helper functions
func _all_aspects_equilibre() -> bool:
    for aspect in MerlinConstants.TRIADE_ASPECTS:
        if state.run.aspects.get(aspect) != MerlinConstants.AspectState.EQUILIBRE:
            return false
    return true

func _get_extreme_aspects() -> Array:
    var extremes: Array = []
    for aspect in MerlinConstants.TRIADE_ASPECTS:
        var s: int = state.run.aspects.get(aspect, 0)
        if s != MerlinConstants.AspectState.EQUILIBRE:
            extremes.append({"aspect": aspect, "state": s})
    return extremes

func _track_synergy(ogham_id: String) -> void:
    if ogham_id == "beith":
        if state.bestiole.last_ogham_used == "beith":
            state.bestiole.beith_consecutive_uses += 1
        else:
            state.bestiole.beith_consecutive_uses = 1
    else:
        state.bestiole.beith_consecutive_uses = 0
    state.bestiole.last_ogham_used = ogham_id

func _get_active_shield_oghams() -> Array:
    """Return list of currently active shield-type oghams."""
    var active: Array = []
    for effect in state.bestiole.active_effects:
        if effect.get("type", "") in ["shield", "absorb_negative"]:
            active.append(effect.ogham)
    return active
```

## 8.4 Signals a ajouter a merlin_store.gd

```gdscript
# New signals for Bestiole/Ogham system
signal bond_tier_changed(old_tier: int, new_tier: int)
signal awen_changed(new_value: int)
signal ogham_activated(ogham_id: String, effect: Dictionary)
signal ogham_cooldown_ready(ogham_id: String)
signal ongoing_effect_expired(ogham_id: String)
signal ogham_unlocked(ogham_id: String)
signal ogham_equipped(ogham_id: String)
signal ogham_unequipped(ogham_id: String)
signal bestiole_mood_changed(new_mood: String)
```

---

# 9. Flow d'Interaction Complet

## 9.1 Flow principal (par carte)

```
DEBUT DE CARTE
    |
    v
[1] Afficher la carte (texte + options)
    |
    v
[2] Le joueur voit Bestiole en bas a gauche
    |   - Icone animee (idle/content/alerte)
    |   - Souffle d'Awen affiche
    |   - Si skill disponible: subtle glow indicator
    |
    v
[3] Le joueur peut:
    |
    +---> [3a] CHOISIR DIRECTEMENT (A/B/C)
    |     -> Appliquer effets
    |     -> Tick cooldowns
    |     -> Carte suivante
    |
    +---> [3b] TAP SUR BESTIOLE
          |
          v
    [4] OUVERTURE ROUE D'OGHAMS
          |
          v
    [5] Le joueur voit les Oghams equipes
          |   - Disponibles: brillants, cliquables
          |   - En cooldown: greyed + compteur
          |   - Trop chers: greyed + cout en rouge
          |
          v
    [6] Le joueur peut:
          |
          +---> [6a] FERMER LA ROUE (tap elsewhere / back)
          |     -> Retour a [3]
          |
          +---> [6b] TAP SUR UN OGHAM
                |
                v
          [7] PREVIEW DE L'EFFET
                |   - Description courte
                |   - Cout en Awen
                |   - Cooldown
                |
                v
          [8] Le joueur peut:
                |
                +---> [8a] ANNULER -> Retour a [5]
                |
                +---> [8b] CONFIRMER
                      |
                      v
                [9] ANIMATION D'ACTIVATION (1.5s)
                      |   - Bestiole canalise
                      |   - Symbole Ogham brille
                      |   - Effet s'applique
                      |
                      v
                [10] ROUE SE FERME
                      |
                      v
                [11] RETOUR A LA CARTE (avec effet actif)
                      |   - Si reveal: impacts visibles
                      |   - Si protection: bouclier actif
                      |   - Si narrative: carte modifiee
                      |
                      v
                [12] Le joueur CHOISIT (A/B/C)
                      -> Appliquer effets (modifies par Ogham si applicable)
                      -> Tick cooldowns
                      -> Carte suivante
```

## 9.2 Flow de deblocage d'Ogham

```
BOND TIER UP (ex: 40 -> 41 = Tier 2 -> Tier 3)
    |
    v
[1] Animation speciale de Bestiole
    |   - Flash d'Awen brillant
    |   - Texte: "Le lien avec Bestiole se renforce!"
    |   - Merlin: "Oh! Elle vibre! Tu as senti ca?"
    |
    v
[2] Ecran de choix d'Ogham
    |   - "Bestiole canalise un nouvel Ogham"
    |   - 3 propositions de categories differentes
    |   - Pour chaque: nom, icone, effet, lore
    |
    v
[3] Le joueur choisit 1
    |   -> Ogham deverrouille definitivement
    |   -> Equipe automatiquement si slot libre
    |   -> Merlin commente: "Bon choix! ...Enfin, ils etaient tous bons."
    |
    v
[4] Retour au jeu
```

---

# 10. Considerations de Balance

## 10.1 Balance Target

| Metrique | Cible | Raison |
|----------|-------|--------|
| Activations/run | 6-10 | ~1 activation toutes les 3-4 cartes |
| Oghams qui changent le resultat | 40% | Utiles mais pas toujours decisifs |
| Runs survivables sans Ogham | Oui | L'habilete compense |
| Runs plus faciles avec Oghams | Oui | +15-20% de survie estimee |
| Temps d'ouverture Roue | < 5s | Ne doit pas casser le rythme |
| Temps de selection Ogham | < 10s | Decision rapide |

## 10.2 Cas limites

| Cas | Regle |
|-----|-------|
| Tous les Oghams en cooldown | L'icone Bestiole est grisee, pas d'ouverture de Roue |
| 0 Souffle d'Awen | Les Oghams cout 0 (aucun) ne sont pas actives; tout est greyed |
| Ogham sans effet utile | L'Ogham est utilisable mais le Souffle est depense (design intent: le joueur apprend) |
| 2 ongoing effects en meme temps | OK, ils se stackent |
| Meme Ogham chaque carte | Impossible grace aux cooldowns (minimum 3 cartes) |

## 10.3 Knobs d'equilibrage

| Parametre | Default | Min | Max | Impact |
|-----------|---------|-----|-----|--------|
| AWEN_MAX | 5 | 3 | 7 | Frequence d'activation |
| AWEN_START | 2 | 1 | 3 | Debut de run |
| AWEN_REGEN_INTERVAL | 5 | 3 | 8 | Rythme de regen |
| Cooldown base starters | 3-4 | 2 | 6 | Frequence starters |
| Cooldown base avances | 5-12 | 3 | 15 | Frequence avances |
| Bond gain/carte | 1 | 0.5 | 2 | Vitesse de progression |
| Bond start | 30 | 0 | 50 | Difficulte initiale |

---

# 11. Questions Ouvertes

| # | Question | Options | Recommandation |
|---|----------|---------|----------------|
| 1 | Les Oghams devraient-ils etre utilisables APRES le choix (mais avant resolution)? | Avant / Apres / Les deux | **Avant seulement** — plus strategique, evite l'annulation reactive |
| 2 | Le joueur devrait-il pouvoir changer ses Oghams equipes en mid-run? | Oui / Non / A certains moments | **Non** — choisir avant la run, engage le joueur |
| 3 | Les synergies cachees devraient-elles etre revelees au joueur? | Jamais / Hints / Apres usage | **Hints subtils** via Merlin apres 3+ runs |
| 4 | Faut-il un tutoriel explicite pour les Oghams? | Oui tutoriel / Non decouverte / Merlin explique | **Merlin explique** organiquement pendant les premieres cartes |
| 5 | Les Oghams "ongoing" (3 tours) devraient-ils avoir un indicateur UI permanent? | Oui / Non | **Oui** — petit compteur a cote de Bestiole |
| 6 | Bestiole devrait-elle avoir des lignes de dialogue? | Oui / Non / Juste des sons | **Sons et expressions** — pas de texte, Bestiole ne parle pas en mots |
| 7 | Le Bond devrait-il affecter l'histoire (reactions de Merlin)? | Oui / Non | **Oui** — Merlin commente le lien (ref: MERLIN_COMPLETE_PERSONALITY.md 5.5) |

---

## Annexe A: Table recapitulative des 18 Oghams

| # | ID | Nom | Unicode | Arbre | Categorie | Cout | CD | Deblocage | Effet (court) |
|---|-----|-----|---------|-------|-----------|------|-----|-----------|---------------|
| 1 | beith | Bouleau | ᚁ | Betula | Reveal* | 1 | 3 | Starter | Voir 1 option |
| 2 | luis | Sorbier | ᚂ | Sorbus | Protection* | 1 | 4 | Starter | Bouclier 50% |
| 3 | quert | Pommier | ᚊ | Malus | Recovery* | 1 | 4 | Starter | Soigne 1 extreme |
| 4 | coll | Noisetier | ᚉ | Corylus | Reveal | 2 | 5 | Tier 2 | Voir tout |
| 5 | ailm | Epicea | ᚐ | Picea | Reveal | 1 | 4 | Tier 3 | Predire prochaine |
| 6 | gort | Lierre | ᚌ | Hedera | Protection | 2 | 6 | Tier 2 | Absorbe 1 negatif |
| 7 | eadhadh | Peuplier | ᚓ | Populus | Protection | 3 | 8 | Tier 4 | Refuse carte |
| 8 | duir | Chene | ᚇ | Quercus | Boost | 2 | 5 | Tier 2 | Bloque negatifs |
| 9 | tinne | Houx | ᚈ | Ilex | Boost | 2 | 5 | Tier 3 | Double positif |
| 10 | onn | Ajonc | ᚑ | Ulex | Boost | 3 | 7 | Tier 4 | Equilibre 3t |
| 11 | nuin | Frene | ᚅ | Fraxinus | Narrative | 2 | 6 | Tier 3 | Centre gratuit |
| 12 | huath | Aubepine | ᚆ | Crataegus | Narrative | 2 | 5 | Tier 2 | Change carte |
| 13 | straif | Prunellier | ᚎ | Prunus | Narrative | 3 | 10 | Tier 5 | Force rare |
| 14 | ruis | Sureau | ᚏ | Sambucus | Recovery | 3 | 8 | Tier 4 | Equilibre tout |
| 15 | saille | Saule | ᚄ | Salix | Recovery | 2 | 6 | Tier 3 | Anti-extreme 3t |
| 16 | muin | Vigne | ᚋ | Vitis | Special | 2 | 7 | Tier 3 | Inverse effets |
| 17 | ioho | If | ᚔ | Taxus | Special | 3 | 12 | Tier 5 | Carte neuve |
| 18 | ur | Bruyere | ᚒ | Calluna | Special | 2 | 10 | Tier 4 | Sacrifice/soigne |

*Starters marques d'une etoile

---

## Annexe B: Synergies cachees

| Ogham | Condition | Bonus |
|-------|-----------|-------|
| Beith | 3 usages consecutifs | Revele toutes les options |
| Luis | Ame en etat "Possedee" | Protection 100% |
| Quert | 3 aspects en Equilibre | +2 Souffle d'Awen |
| Gort + Luis | Active meme carte (impossible par design, 1/carte) | Note: synergie entre tours |
| Duir | Corps en Equilibre | +1 Souffle d'Ogham |
| Onn | Biome Landes | 5 tours au lieu de 3 |
| Saille | Biome aquatique (Cotes/Marais) | 5 tours au lieu de 3 |

**Note importante:** Les synergies sont **cachees** par defaut. Merlin peut donner des indices apres que le joueur ait utilise un Ogham plusieurs fois dans des conditions favorables. C'est une des couches de "profondeur cachee" (ref: DOC_13_Hidden_Depth_System.md).

---

## Annexe C: Integration avec le contexte LLM

Quand le joueur active un Ogham, le contexte LLM est enrichi:

```json
{
    "bestiole": {
        "bond": 65,
        "bond_tier": 3,
        "mood": "joyeux",
        "active_ogham": "duir",
        "active_effects": [
            {"ogham": "onn", "turns_remaining": 2, "effect": "redirect_to_equilibre"}
        ]
    },
    "ogham_context": "Le joueur a active le Chene (Duir). Les consequences negatives sont bloquees pour ce choix."
}
```

Le LLM peut alors adapter sa narration:
- Mentionner Bestiole dans le texte ("Ta creature frissonne, ses yeux brillent...")
- Adapter les descriptions d'effets ("Les branches du vieux chene semblent se refermer autour de toi")
- Reagir aux activations puissantes ("Merlin hausse un sourcil — 'Tu devoiles des talents, dis donc.'")

---

*Document cree: 2026-02-08*
*Agent: Game Designer (Systems)*
*Refs: DOC_12_Triade_Gameplay_System.md, COSMOLOGIE_CACHEE.md, MERLIN_COMPLETE_PERSONALITY.md, CELTIC_FOUNDATION.md, BESTIOLE_SYSTEM.md, merlin_constants.gd, merlin_store.gd*
