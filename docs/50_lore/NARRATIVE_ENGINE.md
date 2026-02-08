# NARRATIVE ENGINE - Le JDR Parlant

> **DRU: Le Jeu des Oghams**
> Document de reference pour le moteur narratif procedurale

---

## 1. Structure Narrative du JDR Parlant

### 1.1 La Voix de Merlin

Merlin est un conteur oral. Il ne lit pas, il raconte. Sa voix porte le poids des siecles et l'ambiguite des anciens.

#### Personnalite

| Trait | Description |
|-------|-------------|
| **Enigmatique** | Ne revele jamais tout, laisse des zones d'ombre |
| **Ancien** | Parle comme si le temps lui etait indifferent |
| **Sage mais espiegle** | Peut etre joueur, taquin, parfois cruel |
| **Ambigu** | Ses mots ont toujours plusieurs sens |
| **Observateur** | Juge les actes, pas les intentions |

#### Registres de Voix

**Neutre (quotidien)**
> "Un voyageur s'approche de ton feu. Ses mains tremblent, mais son regard est fixe."

**Mysterieux (indices)**
> "Les corbeaux se sont tus. Ils savent quelque chose que tu ignores encore."

**Avertissement (danger)**
> "Je sens l'ombre qui s'epaissit. Tes reserves fondent comme neige au soleil."

**Encouragement (reussite)**
> "Tu as bien choisi. Le Bouleau murmure son approbation."

**Malicieux (piege)**
> "Oh, tu crois que c'etait si simple? La lande a sa propre memoire."

### 1.2 Rythme de Narration

Chaque carte suit un micro-rythme narratif:

```
1. ACCROCHE (1 phrase)
   Capturer l'attention, creer une image mentale

2. CONTEXTE (1-2 phrases)
   Poser la situation, les enjeux implicites

3. TENSION (implicite)
   Le choix lui-meme porte la tension

4. RESOLUTION (post-choix)
   L'effet s'exprime narrativement
```

#### Exemple Complet

**Accroche**: "Un druide noir se tient devant toi."

**Contexte**: "Son baton est grave de runes que tu ne reconnais pas. Il te demande l'hospitalite pour la nuit."

**Tension** (les options):
- Gauche: "Le refuser" [-Faveur, +Securite]
- Droite: "L'accueillir" [+Faveur, -Ressources, ?]

**Resolution** (apres choix droite):
> "Il mange en silence. Avant l'aube, il disparait. Tes provisions aussi. Mais sur la table, une rune gravee... tu la sens pulser."

### 1.3 Alternance Dialogue/Description

| Type | Frequence | Usage |
|------|-----------|-------|
| Description pure | 60% | Situations, environnement |
| Dialogue PNJ | 25% | Rencontres, negociations |
| Monologue Merlin | 10% | Avertissements, indices |
| Silence | 5% | Moments de tension |

**Regle**: Jamais deux dialogues consecutifs. Toujours une respiration descriptive entre.

---

## 2. Systeme d'Evenements Aleatoires

### 2.1 Types d'Evenements

#### RENCONTRES (35%)

Personnages que le joueur croise.

| Sous-type | Frequence | Exemples |
|-----------|-----------|----------|
| Voyageurs | 40% | Marchands, pelerins, fugitifs |
| Creatures | 25% | Animaux, etres feeriiques |
| Autochtones | 20% | Villageois, druides, nobles |
| Revenants | 15% | Echos du passe, esprits |

**Conditions de declenchement**:
- Voyageurs: toujours possibles
- Creatures: favorisees par Esprit bas ou haut
- Autochtones: favorisees par Faveur moyenne
- Revenants: favorises par promesses brisees

**Impact narratif**: Etablissent des relations, revelent le monde

**Prompt LLM**:
```
CONTEXTE: Rencontre
TYPE: [voyageur|creature|autochtone|revenant]
JAUGES: Vigueur={v}, Esprit={e}, Faveur={f}, Ressources={r}
AMBIANCE: [matin|jour|soir|nuit]
---
Genere une rencontre courte. 2-3 phrases. Deux options claires.
```

---

#### DILEMMES MORAUX (25%)

Choix sans bonne reponse evidente.

| Sous-type | Frequence | Theme |
|-----------|-----------|-------|
| Sacrifice | 30% | Donner pour recevoir |
| Loyaute | 25% | Choisir entre allies |
| Verite | 25% | Mentir ou reveler |
| Survie | 20% | Soi vs autrui |

**Conditions de declenchement**:
- Favorises quand deux jauges sont opposees (une haute, une basse)
- Plus frequents apres une serie de choix "faciles"

**Impact narratif**: Definissent la personnalite du joueur, creent des flags

**Prompt LLM**:
```
CONTEXTE: Dilemme
TENSION: {jauge_haute} vs {jauge_basse}
FLAGS_ACTIFS: {flags}
---
Presente un dilemme sans bonne reponse. Les deux options ont un cout.
```

---

#### DECOUVERTES (15%)

Le joueur trouve quelque chose.

| Sous-type | Frequence | Nature |
|-----------|-----------|--------|
| Lieux | 40% | Clairiere, ruine, source |
| Objets | 35% | Artefact, message, outil |
| Savoirs | 25% | Rune, rituel, secret |

**Conditions de declenchement**:
- Lieux: favorises par Vigueur haute
- Objets: favorises par Ressources basses
- Savoirs: favorises par Esprit eleve

**Impact narratif**: Ajoutent des tags, ouvrent des arcs

**Prompt LLM**:
```
CONTEXTE: Decouverte
TYPE: [lieu|objet|savoir]
SAISON: {saison}
TAGS_ACTIFS: {tags}
---
Le joueur decouvre quelque chose. Description evocatrice. Deux facons de reagir.
```

---

#### CONFLITS (10%)

Tensions avec d'autres personnages.

| Sous-type | Frequence | Nature |
|-----------|-----------|--------|
| Interpersonnels | 50% | Disputes, rivalites |
| Factions | 30% | Clans, villages, ordres |
| Interieurs | 20% | Doutes, tentations |

**Conditions de declenchement**:
- Interpersonnels: apres rencontres avec meme PNJ
- Factions: apres choix repetees dans meme direction
- Interieurs: Esprit < 30 ou Esprit > 80

**Impact narratif**: Escalade ou resolution de tensions

**Prompt LLM**:
```
CONTEXTE: Conflit
TYPE: [interpersonnel|faction|interieur]
HISTORIQUE: {story_log_recent}
---
Une tension eclate. Le joueur doit choisir comment reagir.
```

---

#### MERVEILLES (10%)

Evenements magiques ou inexplicables.

| Sous-type | Frequence | Nature |
|-----------|-----------|--------|
| Visions | 35% | Reves, presages |
| Manifestations | 35% | Phenomenes etranges |
| Dons | 30% | Cadeaux inexpliques |

**Conditions de declenchement**:
- Visions: Esprit extreme (< 20 ou > 80)
- Manifestations: Apres accomplissement de promesse
- Dons: Bond Bestiole > 70

**Impact narratif**: Revelent le lore indirectement, donnent des avantages

**Prompt LLM**:
```
CONTEXTE: Merveille
TYPE: [vision|manifestation|don]
BOND_BESTIOLE: {bond}
PROMESSES_ACTIVES: {promesses}
---
Quelque chose d'inexplicable se produit. Reste mysterieux. Deux reactions possibles.
```

---

#### CATASTROPHES (5%)

Evenements negatifs soudains.

| Sous-type | Frequence | Nature |
|-----------|-----------|--------|
| Naturelles | 50% | Tempete, famine, incendie |
| Surnaturelles | 30% | Malediction, brume, eclipse |
| Humaines | 20% | Raid, trahison, epidemie |

**Conditions de declenchement**:
- Naturelles: liees a la saison
- Surnaturelles: apres promesse brisee
- Humaines: Faveur extreme (< 20 ou > 80)

**Impact narratif**: Creent une crise, forcent des choix difficiles

**Prompt LLM**:
```
CONTEXTE: Catastrophe
TYPE: [naturelle|surnaturelle|humaine]
SAISON: {saison}
JAUGES_CRITIQUES: {jauges_extremes}
---
Une catastrophe frappe. Le joueur doit reagir vite. Options de survie.
```

---

### 2.2 Matrice de Frequence par Etat

| Etat du Jeu | Rencontres | Dilemmes | Decouvertes | Conflits | Merveilles | Catastrophes |
|-------------|------------|----------|-------------|----------|------------|--------------|
| Debut run | 45% | 15% | 25% | 5% | 10% | 0% |
| Milieu run | 30% | 30% | 15% | 15% | 8% | 2% |
| Fin run | 25% | 35% | 10% | 15% | 10% | 5% |
| Jauges stables | 35% | 20% | 20% | 10% | 12% | 3% |
| Jauges critiques | 20% | 40% | 10% | 15% | 5% | 10% |

---

## 3. Retournements de Situation

### 3.1 Mecanique du Twist

Un retournement repose sur trois elements:

```
SETUP (cartes 1-3)
    Indices subtils plantes dans le texte
    PNJs avec comportements ambigus
    Details descriptifs "innocents"

TRIGGER (carte N)
    Evenement revelateur
    Contexte force la revelation

PAYOFF (carte N+1)
    Consequences du twist
    Reevaluation retroactive
```

### 3.2 Types de Revelations

#### Identite Cachee

Le PNJ n'est pas ce qu'il semblait.

**Setup**:
> "Le mendiant te remercie. Ses mains sont calleuses, mais ses mots... choisis."

**Trigger**:
> "Tu reconnais l'anneau a son doigt. Le sceau du Haut-Druide."

**Payoff**:
> "Il sourit. 'Tu as l'oeil. La question est: que fais-tu de ce que tu vois?'"

---

#### Motivation Inverse

Les raisons etaient differentes.

**Setup**:
> "Elle t'a aide a fuir le village. Elle semblait sincere."

**Trigger**:
> "Tu decouvres les ruines. Le village n'existe plus depuis des lunes."

**Payoff**:
> "Qui t'a guide, alors? Et vers quoi?"

---

#### Consequence Differee

Un vieux choix revient.

**Setup**:
> "Tu avais chasse le voyageur. Il etait parti sans un mot."

**Trigger** (10-20 cartes plus tard):
> "Les villageois te regardent avec mefiance. 'Le druide errant a parle de toi.'"

**Payoff**:
> "Les portes se ferment. Ta reputation te precede."

---

#### Fausse Victoire

Le succes cache un echec.

**Setup**:
> "Tu as trouve le tresor. Les runes brillent."

**Trigger**:
> "Les runes s'eteignent. La brume monte."

**Payoff**:
> "Le tresor etait un appat. Quelque chose vient."

---

### 3.3 Timing des Retournements

| Type de Run | Premier Twist | Second Twist | Twist Final |
|-------------|---------------|--------------|-------------|
| Courte (10-30) | Carte 8-12 | - | - |
| Moyenne (30-70) | Carte 15-25 | Carte 40-55 | - |
| Longue (70+) | Carte 20-30 | Carte 50-65 | Carte 85-100 |

**Regles**:
- Jamais deux twists consecutifs
- Minimum 5 cartes entre setup et trigger
- Maximum 30 cartes entre setup et trigger (sinon oublie)

### 3.4 Indices a Planter (Catalogue)

| Indice | Interpretation Innocente | Revelation Possible |
|--------|--------------------------|---------------------|
| "Ses yeux evitent les tiens" | Timidite | Mensonge |
| "La porte etait deja ouverte" | Negligence | Guet-apens |
| "Il connait ton nom" | Reputation | Surveillance |
| "L'oiseau te suit depuis l'aube" | Hasard | Familier espion |
| "Le chemin semble trop facile" | Chance | Piege |
| "Elle parle au passe" | Nostalgie | Revenant |

---

## 4. Arcs Narratifs Proceduraux

### 4.1 Structure d'un Mini-Arc

Un arc procedurale se deroule sur 3-5 cartes liees.

```
CARTE 1: INTRODUCTION
    - Presenter le personnage/situation
    - Etablir le besoin/conflit
    - Poser un tag d'arc

CARTE 2: COMPLICATION
    - Le probleme s'intensifie
    - Nouveau facteur entre en jeu
    - Choix avec consequences sur l'arc

CARTE 3: CLIMAX
    - Point de non-retour
    - Choix decisif
    - Deux directions narratives possibles

CARTE 4-5: RESOLUTION (optionnel)
    - Consequences du climax
    - Fermeture de l'arc
    - Retrait du tag d'arc
```

### 4.2 Themes d'Arcs

#### Arc de Quete

Un objectif a atteindre.

| Carte | Contenu |
|-------|---------|
| 1 | "Un vieillard te demande de retrouver son fils, parti dans la foret noire." |
| 2 | "Tu trouves des traces. Elles menent vers le dolmen interdit." |
| 3 | "Le fils est la. Mais il ne veut pas partir. Il dit avoir trouve 'la verite'." |
| 4a | (Force) "Tu le ramenes de force. Le pere pleure de joie." [-Esprit fils, +Faveur pere] |
| 4b | (Lacher) "Tu le laisses. Le pere ne te pardonnera jamais." [+Esprit fils, -Faveur pere] |

---

#### Arc de Mystere

Une enigme a resoudre.

| Carte | Contenu |
|-------|---------|
| 1 | "Des moutons disparaissent la nuit. Personne n'a rien vu." |
| 2 | "Tu trouves des traces... humaines. Vers la maison du berger." |
| 3 | "Le berger nie. Mais tu vois de la laine sur ses mains." |
| 4a | (Accuser) "Tu le denonces. On decouvre la verite." [+Faveur village, -Faveur berger] |
| 4b | (Pact) "Tu gardes le secret. Il te devra une faveur." [-Faveur village, +Flag:dette_berger] |

---

#### Arc de Vengeance

Un tort a reparer ou ignorer.

| Carte | Contenu |
|-------|---------|
| 1 | "Un homme te crache dessus. 'Tu as tue mon frere a la bataille.'" |
| 2 | "Tu ne te souviens pas de son frere. Mais lui, il se souvient de toi." |
| 3 | "Il te tend un couteau. 'Finis ce que tu as commence, ou meurs.'" |
| 4a | (Combattre) "Tu te defends. Il tombe." [-Esprit, +Vigueur, +Flag:sang_verse] |
| 4b | (Accepter) "Tu lui tends la gorge. Il hesite... et recule." [+Esprit, -Vigueur, +Faveur] |

---

#### Arc d'Amour

Une relation a cultiver ou rompre.

| Carte | Contenu |
|-------|---------|
| 1 | "La guerisseuse te soigne. Son regard s'attarde." |
| 2 | "Elle t'invite a rester pour la fete. 'Tu pourrais te reposer ici.'" |
| 3 | "Le matin, elle te demande: 'Pars-tu ou restes-tu?'" |
| 4a | (Rester) "Tu restes. Les jours passent comme des heures." [+Vigueur, -Ressources, -Arc mobilite] |
| 4b | (Partir) "Tu pars. Elle ne te regarde pas partir." [+Ressources, -Faveur, +Flag:coeur_froid] |

---

### 4.3 Personnages Recurrents

Les PNJs peuvent revenir selon les flags.

| PNJ | Apparition 1 | Apparition 2 | Apparition 3 |
|-----|--------------|--------------|--------------|
| Le Druide Noir | Rencontre mysterieuse | Demande de service | Revelation de son but |
| La Voyageuse | Croisee sur la route | Retrouvee en danger | Devenue alliee ou ennemie |
| Le Marchand | Echange commercial | Propose un marche douteux | Revele sa vraie nature |
| L'Enfant Perdu | Trouve seul | Appelle a l'aide | Conduit vers un lieu secret |

**Systeme de recurrence**:
```gdscript
# Apres premiere rencontre, ajouter flag
SET_FLAG: "met_druide_noir" = true

# Cartes futures peuvent verifier
conditions: {
    required_flags: ["met_druide_noir"],
    min_cards_since: 10  # Pas avant 10 cartes
}
```

### 4.4 Resolutions Multiples

Chaque arc a plusieurs fins possibles.

| Fin | Condition | Consequence |
|-----|-----------|-------------|
| **Heroique** | Choix altruistes dominants | Bonus Faveur, flag "heros" |
| **Pragmatique** | Choix equilibres | Bonus Ressources |
| **Sombre** | Choix egoistes dominants | Bonus Vigueur, flag "cruel" |
| **Mysterieuse** | Arc abandonne en cours | Flag "inacheve", peut revenir |

---

## 5. Coherence Narrative

### 5.1 Memory du LLM

Le LLM recoit un contexte structure:

```json
{
    "story_log": [
        {"card_id": "fb_001", "choice": "left", "day": 1},
        {"card_id": "fb_015", "choice": "right", "day": 3},
        ...
    ],
    "active_flags": {
        "met_druide_noir": true,
        "dette_berger": true,
        "coeur_froid": false
    },
    "active_arcs": ["quete_fils_perdu"],
    "recurring_npcs": ["druide_noir", "guerisseuse"],
    "recent_themes": ["mystere", "rencontre"],
    "promises": [
        {"id": "promesse_01", "deadline": 15, "description": "Ramener le fils"}
    ]
}
```

### 5.2 Callbacks aux Choix Precedents

Le LLM doit referencer le passe.

**Patterns de callback**:

| Situation | Phrase de callback |
|-----------|-------------------|
| PNJ deja rencontre | "Tu reconnais le visage. C'est lui." |
| Lieu deja visite | "Tu es deja venu ici. L'air a change." |
| Promesse en cours | "Le temps presse. Tu n'as pas oublie?" |
| Flag actif | "Ta reputation te precede." |
| Arc en cours | "Le fils du vieillard... tu y penses encore." |

**Prompt LLM avec contexte**:
```
CONTEXTE_NARRATIF:
- Tu as rencontre le druide noir il y a 5 cartes
- Tu as une dette envers le berger
- Le fils perdu n'a pas ete retrouve
- Saison: automne, Jour: 12

GENERE une carte qui reference AU MOINS UN element du contexte.
```

### 5.3 Evolution des Relations

Les PNJs ont une relation qui evolue.

```gdscript
# Structure relation
var relation := {
    "npc_id": "druide_noir",
    "trust": 0,  # -100 a +100
    "encounters": 3,
    "last_interaction": "positive"
}

# Impact sur cartes
Si trust > 50: options plus favorables
Si trust < -50: options hostiles
Si encounters > 5: dialogue plus intime
```

### 5.4 Continuite Meta-Narrative

Entre les runs, certains elements persistent.

| Element | Persistance | Impact |
|---------|-------------|--------|
| Fins obtenues | Permanent | Debloque nouvelles fins |
| Personnages rencontres | Semi-permanent | Peuvent reparaitre |
| Lore decouvert | Permanent | References possibles |
| Echecs | Temporaire | Malus debut de run |
| Victoires | Temporaire | Bonus debut de run |

**Meta-flags**:
```gdscript
# Sauvegarde meta
meta.endings_seen: ["epuisement", "folie"]
meta.npc_karma: {"druide_noir": -30}
meta.lore_unlocked: ["secret_menhirs"]
meta.runs_completed: 12
```

---

## 6. Templates de Prompts LLM

### 6.1 Prompt de Base (System)

```
Tu es Merlin, narrateur cryptique.
Court. Francais. Poetique.
JAMAIS repeter. Actions concretes.
```

### 6.2 Prompt pour Rencontre

```
ROLE: Narrateur Merlin
TYPE: Rencontre

CONTEXTE:
{context_json}

CONSIGNE:
Genere une rencontre courte (2-3 phrases).
Un personnage avec un trait visible et un trait cache.
Deux options: une prudente, une audacieuse.

FORMAT:
[TEXTE]
Ta narration ici.

[CHOIX]
1. Option gauche (2-4 mots)
2. Option droite (2-4 mots)
```

### 6.3 Prompt pour Dilemme

```
ROLE: Narrateur Merlin
TYPE: Dilemme moral

CONTEXTE:
{context_json}

CONSIGNE:
Presente une situation sans bonne reponse.
Les deux options ont un prix.
Pas de jugement dans le texte.

FORMAT:
[TEXTE]
Ta narration ici.

[CHOIX]
1. Option A (avec sacrifice)
2. Option B (avec sacrifice different)
```

### 6.4 Prompt pour Retournement

```
ROLE: Narrateur Merlin
TYPE: Retournement

SETUP_PRECEDENT:
{description_setup}

CONSIGNE:
Revele un element cache plante avant.
Le joueur doit sentir que c'etait previsible.
Deux facons de reagir a la revelation.

FORMAT:
[TEXTE]
La revelation narree.

[CHOIX]
1. Reaction A
2. Reaction B
```

### 6.5 Prompt pour Climax d'Arc

```
ROLE: Narrateur Merlin
TYPE: Climax narratif

ARC_EN_COURS: {arc_id}
CARTES_PRECEDENTES: {arc_history}

CONSIGNE:
C'est le moment decisif de l'arc.
Le choix ferme definitivement une porte.
Les deux options sont des fins differentes.

FORMAT:
[TEXTE]
Le moment crucial.

[CHOIX]
1. Fin A de l'arc
2. Fin B de l'arc
```

### 6.6 Prompt pour Catastrophe

```
ROLE: Narrateur Merlin
TYPE: Catastrophe

CONTEXTE:
{context_json}
CAUSE_PROBABLE: {cause}

CONSIGNE:
Quelque chose de terrible se produit.
Le joueur doit choisir vite.
Une option protege, l'autre sacrifie.
Ton urgent mais pas panique.

FORMAT:
[TEXTE]
La catastrophe.

[CHOIX]
1. Se proteger
2. Proteger autre chose
```

---

## 7. Exemples de Dialogues Merlin

### 7.1 Debut de Run

> "Tu t'eveilles dans la brume. La lande s'etend devant toi, silencieuse. Le chemin n'est pas trace, mais il existe."

### 7.2 Avertissement de Jauge

**Vigueur basse**:
> "Ton souffle se fait court. Meme les pierres semblent lourdes."

**Esprit bas**:
> "Les ombres murmurent. Ou est-ce toi qui leur reponds?"

**Faveur basse**:
> "Les regards se detournent. Tu marches seul, maintenant."

**Ressources basses**:
> "Tes poches sont vides. La faim a une voix, tu sais."

### 7.3 Fin de Run

**Epuisement (Vigueur = 0)**:
> "Tes jambes cedent. La lande t'accueille dans son sommeil de mousse. Tu ne te releveras pas."

**Surmenage (Vigueur = 100)**:
> "Tu ne sais plus t'arreter. Ton coeur bat trop vite. Trop fort. Puis... plus du tout."

**Folie (Esprit = 0)**:
> "Les voix ont gagne. Tu ne sais plus lesquelles sont tiennes."

**Possession (Esprit = 100)**:
> "Quelque chose d'autre regarde a travers tes yeux. Tu es encore la?"

**Exile (Faveur = 0)**:
> "Les portes se ferment. Les routes se bloquent. Tu n'es plus le bienvenu nulle part."

**Tyrannie (Faveur = 100)**:
> "Ils te craignent maintenant. Mais la peur engendre la haine, et la haine... le couteau."

**Famine (Ressources = 0)**:
> "Le dernier grain est mange. Le dernier feu eteint. Le froid entre."

**Pillage (Ressources = 100)**:
> "Tu as tout pris. Meme ce qui n'etait pas a prendre. La lande se souvient."

### 7.4 Promesses

**Proposition**:
> "Je peux t'offrir quelque chose. Mais tu me devras quelque chose en retour. Acceptes-tu sans savoir?"

**Rappel**:
> "Le temps passe. Tu n'as pas oublie ce que tu m'as promis, n'est-ce pas?"

**Accomplissement**:
> "Tu as tenu parole. Les pierres s'en souviendront."

**Bris**:
> "Tu as brise ta promesse. La brume se referme. Le chemin se retrecit."

---

*Document cree: 2026-02-08*
*Version: 1.0*
*Agent: Narrative Writer*
