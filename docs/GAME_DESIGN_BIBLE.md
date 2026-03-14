# GAME DESIGN BIBLE — M.E.R.L.I.N. : Le Jeu des Oghams v2.4

> **Source de verite unique** pour le game design de M.E.R.L.I.N.
> Remplace et supersede : MASTER_DOCUMENT.md, DOC_12, DOC_13, DOC_11, NEW_MECHANICS_DESIGN.md
> Date de creation : 2026-03-12 | Derniere mise a jour : 2026-03-14 (v2.4)

---

## 1. Vision & Core Loop

### 1.1 Pitch

M.E.R.L.I.N. est un **jeu de cartes narratif roguelite** ancre dans la mythologie celtique de Broceliande. Le joueur explore des biomes enchantes, fait des choix narratifs, et resout des minigames lies a ses actions. Chaque run est une aventure unique generee par un LLM local. La rejouabilite est le moteur principal.

### 1.2 Piliers de design

| Pilier | Description |
|--------|-------------|
| **Exploration** | Decouvrir des Oghams, des fins, des cartes rares, des biomes. La rejouabilite est le plaisir principal. |
| **Narration generative** | Chaque run raconte une histoire unique, generee par IA locale (Qwen 3.5). |
| **Minigames comme verbes** | Chaque choix narratif se traduit en un defi ludique lie au verbe d'action. |
| **Progression permanente** | Entre les runs, debloquer des Oghams et bonus via un arbre de talents. |

### 1.3 Core Loop

Le run se deroule **en 3D permanente** : le personnage avance automatiquement sur un rail dans le biome. Entre les cartes, le joueur collecte des ressources et observe le monde. Les cartes apparaissent via fondu enchaine.

```
┌──────────────────────────────────────────────────────────────┐
│                    BOUCLE D'UN RUN                            │
│                                                              │
│  Hub 2D → Choix biome → Choix Ogham                          │
│         ↓                                                     │
│  SCENE 3D : personnage avance sur rail (on-rails)            │
│         ↓                                                     │
│  [5-15s] Collecte monnaie biome, observation decor, events   │
│         ↓                                                     │
│  [FONDU] → Carte 2D affichee (texte + 3 options)             │
│         ↓                                                     │
│  Joueur choisit un VERBE D'ACTION (toujours 3 options)       │
│         ↓                                                     │
│  MINIGAME en overlay 2D sur la 3D figee                      │
│         ↓                                                     │
│  Score 0-100 → Multiplicateur direct → Effets appliques      │
│         ↓                                                     │
│  [FONDU] → Retour SCENE 3D (personnage reprend la marche)    │
│         ↓                                                     │
│  [Repeter] jusqu'a fin narrative ou vie = 0                  │
│         ↓                                                     │
│  Fin → Fondu narratif → Carte du voyage → Ecran gains → Hub │
└──────────────────────────────────────────────────────────────┘
```

**Principes cles** :
- La 3D est **permanente** : le personnage marche toujours, les cartes interrompent via fondu
- Les **minigames** s'affichent en overlay 2D sur la scene 3D figee
- Le joueur **doit toujours jouer** le minigame (pas de skip)
- Chaque carte a exactement **3 options** (sauf cartes Merlin Direct : 3 options sans minigame)
- Le **MOS decide** quand la narration converge (pas de minimum de cartes impose)

### 1.4 Meta Loop (entre les runs)

```
[Fin de run] → Gains : Anam (proportionnel aux cartes jouees)
       ↓
[Hub 2D / Antre] → Dialogue Merlin (LLM, basé sur le dernier run)
       ↓
[Arbre de talents] → Depenser Anam (progression lente, ~10 runs/noeud)
       ↓
[Choisir biome] → Debloque via score de maturite (MOS organique)
       ↓
[Nouveau run] → Scenario genere par LLM
```

---

## 2. Systemes de jeu

### 2.1 Vie (barre unique)

Une seule barre de vie remplace tous les anciens systemes (4 jauges, Triade, Life Essence).

| Parametre | Valeur |
|-----------|--------|
| Maximum | 100 |
| Depart | 100 |
| Drain de base | -1 par carte (pression de survie) |
| Degats echec critique | -10 |
| Degats evenement rate | -6 |
| Soin succes critique | +5 |
| Soin noeud REST | +18 |
| Seuil alerte UI | 25 |
| A 0 | Fin de run (avec narration, pas "game over") |
| Drain timing | Le drain -1 s'applique **au debut** de chaque carte (avant choix et effets) |
| Vie min | 0 (ne peut pas etre negatif) |
| Verification mort | Apres application de TOUS les effets de la carte (minigame termine + effets appliques) |

### 2.2 Oghams — 18 pouvoirs hybrides

Les 18 Oghams sont des pouvoirs du joueur (pas d'un compagnon). Certains sont **actifs** (pouvoir a activer pendant le run), d'autres sont des **cles narratives** (debloquent du contenu).

#### Equipement et utilisation

- Le joueur **equipe 1 Ogham** au debut de chaque run (ecran de choix pendant le demarrage 3D)
- Pendant un run, il peut **trouver 1-2 Oghams supplementaires** (evenements, PNJ, arcs)
- A tout moment, **1 seul Ogham est actif** (affiche sur le HUD, cliquable)
- Le joueur peut **switcher** vers un autre Ogham equipe/trouve, mais :
  - L'Ogham desactive **arrete de se recharger** (cooldown en pause)
  - Seul l'Ogham actif **se recharge** (cooldown diminue a chaque carte)
  - Switcher est strategique : il faut planifier les rotations
- **Le dernier Ogham utilise reste equipe** entre les runs (changeable dans le Hub)

#### Timing d'activation d'un Ogham

L'Ogham actif peut etre active **uniquement pendant l'affichage de la carte** (apres le texte, avant le choix d'option). C'est le moment strategique. Le bouton Ogham est dans le HUD.

| Moment | Activation possible ? |
|--------|:---:|
| Marche 3D (entre les cartes) | Non |
| Affichage de la carte (avant choix) | **Oui** |
| Pendant le minigame | Non |
| Apres le minigame (avant effets) | Non |

**Consequence** : le joueur doit decider d'utiliser son Ogham AVANT de choisir une option et de jouer le minigame. Cela force l'anticipation.

#### Switch d'Ogham actif

Le joueur peut changer son Ogham actif **a tout moment pendant la marche 3D** (entre les cartes) ou **pendant l'affichage de la carte** (avant le choix). Le switch est instantane (pas d'animation). L'Ogham precedent arrete de se recharger immediatement.

#### Cooldown — regle

Le cooldown diminue de **1 a chaque carte jouee** (pas en temps reel pendant la marche 3D). Seul l'Ogham **actif** voit son cooldown diminuer. Les Oghams equipes mais inactifs ont leur cooldown en pause.

#### Deblocage des Oghams

**Tous les 18 Oghams** se debloquent dans l'**arbre de talents** (achat avec Anam). Il n'y a pas de deblocage automatique par faction ou autre.

**3 starters** debloques des le debut : `beith` (Reveal), `luis` (Protection), `quert` (Recovery). Ils sont places dans la **branche centrale** de l'arbre (tier 0, cout 0 Anam). Ils servent de racines pour debloquer les branches faction adjacentes.

**Decouverte en run** : pendant un run, le joueur peut **rencontrer** un Ogham non-debloque (evenements, PNJ, arcs, conditions specifiques). Il est alors **utilisable temporairement** pendant ce run. Apres le run, l'Ogham apparait dans l'arbre a **-50% du cout Anam**. Le joueur doit l'acheter pour le garder definitivement.

> La decouverte en run est un moment fort : le joueur essaie un Ogham gratuitement, puis decide s'il vaut l'investissement.

**Conditions de decouverte** : Les 15 Oghams non-starters peuvent tous etre decouverts en run. Le MOS choisit lequel apparait en fonction du **biome** (Oghams d'affinite privilegies) et du **contexte narratif**. Max 1-2 decouvertes par run.

| Trigger de decouverte | Probabilite |
|----------------------|:-----------:|
| PNJ marchand propose un Ogham | 40% (1 par run max) |
| Arc narratif du biome atteint une etape-cle | 30% |
| Evenement aleatoire 3D (rune/inscription) | 20% |
| Carte FastRoute avec tag `ogham_discovery` | 10% |

**Si l'Ogham decouvert est deja possede** : le joueur gagne **+5 Anam** a la place (bonus de familiarite). Pas de doublon.

#### Affinite biome

Chaque biome a 3 **Oghams d'affinite**. Les utiliser dans leur biome donne :
- **+10% score** au prochain minigame
- **-1 cooldown** (recharge plus rapide)

#### Catalogue des 18 Oghams

| # | Cle | Nom | Arbre | Cat. | Effet detaille | Cooldown | Cout Anam |
|---|-----|-----|-------|------|---------------|:---:|:---:|
| 1 | `beith` | Bouleau | Betula | Reveal | Revele l'effet complet d'**1 option** au choix | 3 | 0 (starter) |
| 2 | `coll` | Noisetier | Corylus | Reveal | Revele les effets de **toutes les options** | 5 | 80 |
| 3 | `ailm` | Sapin | Abies | Reveal | Predit le **theme + champ lexical** de la prochaine carte | 4 | 60 |
| 4 | `luis` | Sorbier | Sorbus | Protection | Bloque le **prochain effet negatif unique** (1 seul, le premier applique) | 4 | 0 (starter) |
| 5 | `gort` | Lierre | Hedera | Protection | Reduit tout degat **> 10 PV a 5 PV** (1 instance, ce tour) | 6 | 100 |
| 6 | `eadhadh` | Tremble | Populus | Protection | Annule **tous les effets negatifs** de la carte courante | 8 | 150 |
| 7 | `duir` | Chene | Quercus | Boost | Soin immediat de **+12 PV** | 4 | 70 |
| 8 | `tinne` | Houx | Ilex | Boost | Double les effets positifs de **l'option choisie** par le joueur | 5 | 120 |
| 9 | `onn` | Ajonc | Ulex | Boost | Genere **+10 monnaie biome** instantanement | 7 | 90 |
| 10 | `nuin` | Frene | Fraxinus | Narratif | Remplace la **pire option** (plus de negatifs) par une nouvelle generee par LLM | 6 | 80 |
| 11 | `huath` | Aubepine | Crataegus | Narratif | Regenere les **3 options** de la carte (nouveau LLM call ou FastRoute) | 5 | 100 |
| 12 | `straif` | Prunellier | Prunus | Narratif | Force un **retournement** : le MOS insere un twist narratif majeur dans la carte suivante | 10 | 140 |
| 13 | `quert` | Pommier | Malus | Recovery | Soin de **+8 PV** | 4 | 0 (starter) |
| 14 | `ruis` | Sureau | Sambucus | Recovery | Soin massif **+18 PV** mais -5 monnaie biome (equilibre) | 8 | 130 |
| 15 | `saille` | Saule | Salix | Recovery | Regenere **+8 monnaie biome** + **+3 PV** | 6 | 90 |
| 16 | `muin` | Vigne | Vitis | Special | **Inverse** positifs/negatifs de l'option choisie. Echec critique → bonus x1.5, succes → malus x1.5 | 7 | 110 |
| 17 | `ioho` | If | Taxus | Special | **Defausse** la carte entiere et en genere une **completement nouvelle** (nouveau LLM call) | 12 | 160 |
| 18 | `ur` | Bruyere | Calluna | Special | Sacrifie **15 PV** → gagne **+20 monnaie biome** + buff **x1.3 score** au prochain minigame | 10 | 140 |

> **Note** : Les Oghams narratifs (Nuin, Huath, Straif) ne creent jamais de 4eme option — ils remplacent/regenerent les options existantes (toujours 3).

### 2.3 Factions — 5 reputations

| Faction | Theme | Mots-cles | Seuil Contenu | Seuil Fin |
|---------|-------|-----------|:---:|:---:|
| **Druides** | Connaissance, nature, rituels | druide, ogham, nemeton, chene, barde | 50 | 80 |
| **Anciens** | Traditions, ancetres, magie ancienne | ancien, ancetre, tradition, sagesse | 50 | 80 |
| **Korrigans** | Chaos, fees, malice | korrigan, fee, feu follet, farce, tresor | 50 | 80 |
| **Niamh** | Amour, Tir na nOg, nostalgie | niamh, eau, lac, amour, nostalgie | 50 | 80 |
| **Ankou** | Mort, passage, nuit | ankou, mort, passage, nuit, ombre | 50 | 80 |

**Echelle** : 0.0 a 100.0 par faction.

**Effets des seuils** :
- **≥ 50** : Cartes speciales de la faction debloquees dans le pool
- **≥ 80** : Fin narrative de la faction disponible (declenchee en fin de run)

**Persistance cross-run** : Oui, **sans decay naturel**. Seules les actions negatives (briser une promesse, choix hostiles a une faction) reduisent la reputation.

**Affichage** : PAS dans le HUD — ecran stats dedie accessible via menu.

**Cross-faction** : ~10% des cartes creent des trade-offs (aider Druides = -rep Korrigans). Reserve aux moments narratifs forts. La majorite des cartes ne touchent qu'une faction.

### 2.4 Monnaies

#### Anam — monnaie cross-run

> Du gaelique "anam" = ame. Monnaie permanente entre les runs.

| Propriete | Detail |
|-----------|--------|
| Nom | **Anam** |
| Persistance | Cross-run (permanente) |
| Sources | Fin de run (base + bonus), collecte rare en 3D (~5% events) |
| Usage | Arbre de talents : debloquer Oghams + bonus passifs |

#### Economie Anam (progression lente)

**Rythme** : ~10 runs pour debloquer un noeud moyen de l'arbre de talents. Chaque deblocage est significatif.

| Source | Anam |
|--------|------|
| Base par run | 10 |
| Bonus victoire (fin narrative) | +15 |
| Minigames gagnes | +2 par minigame (score ≥ 80) |
| Oghams utilises | +1 par usage |
| Faction honoree (rep ≥ 80) | +5 par faction |
| Collecte rare en 3D | +1-3 (rare, ~5% des events) |

**Recompense en cas de mort/abandon** : proportionnelle aux cartes jouees, plafonnee a 100%.
```
Anam final = Anam calcule x min(cartes_jouees / 30, 1.0)
```
- Mort a 10 cartes = 33% des gains
- Mort a 25 cartes = 83% des gains
- Mort a 30+ cartes = 100% des gains (cap)
- Fin narrative (victoire) = 100% + bonus victoire (+15 Anam)
- Abandon (menu pause) = meme formule que mort, sans bonus victoire

**Couts de l'arbre de talents** (fourchette) :
| Tier | Cout Anam | Runs pour debloquer |
|------|-----------|---------------------|
| Tier 1 | 50-80 | ~5-8 runs |
| Tier 2 | 80-120 | ~8-12 runs |
| Tier 3 | 120-180 | ~12-18 runs |
| Tier 4 | 180-250 | ~18-25 runs |
| Tier 5 | 250-350 | ~25-35 runs |

> Les valeurs exactes seront equilibrees au playtest. L'objectif est que le joueur sente une progression lente mais constante, style Dark Souls.

#### Monnaie biome (per-run)

| Propriete | Detail |
|-----------|--------|
| Type | Different selon le biome (herbes, coquillages, runes, etc.) |
| Persistance | Per-run uniquement (perdue en fin de run) |
| Sources | Marche 3D (clic au sol), recompense de minigames, evenements narratifs |
| Usages | **Polyvalente** — 3 types de depense (voir ci-dessous) |

**Depenses de la monnaie biome pendant un run** :
| Usage | Description |
|-------|-------------|
| **Marchands/esprits** | PNJ recurrents visibles dans la scene 3D. Cliquer dessus declenche une carte marchand (overlay). Acheter soins, buffs, indices. |
| **Boost minigames** | Depenser 3-5 monnaie avant un minigame pour un avantage : +10% score minimum garanti (le score ne peut pas descendre en dessous de 40). |
| **Offrandes narratives** | Certaines cartes proposent des offrandes : laisser de la monnaie biome pour gagner de la rep faction, debloquer un chemin, calmer un esprit. |

**Prix variables par marchand/PNJ** : chaque PNJ recurrent a ses propres tarifs. Le joueur apprend au fil des runs quels marchands sont avantageux.

| PNJ | Biome | Style de prix |
|-----|-------|-------------|
| Gwenn la Cueilleuse | Broceliande | Pas cher, soins et herbes |
| Puck le Lutin | Marais Korrigans | Cher, mais objets puissants/surprenants |
| Bran le Passeur | Cotes Sauvages | Prix moyens, informations rares |
| Seren l'Etoilee | Cercles de Pierres | Troc (monnaie biome contre buff mystique) |

> Les valeurs exactes des prix seront definies au playtest. Fourchette indicative : petit achat 2-5, moyen 5-10, gros 10-20 monnaie biome.

**Taux de collecte monnaie biome (marche 3D)** :
| Parametre | Valeur |
|-----------|--------|
| Frequence d'apparition | 1 event monnaie toutes les 3-5 secondes de marche |
| Valeur par clic | +1-2 monnaie biome (aleatoire) |
| Total par run (~20 cartes) | ~15-25 monnaie biome |
| Fenetre de clic | 1.5 secondes avant disparition |
| Feedback | Son + particules au clic reussi |

### 2.5 Minigames — Le coeur du gameplay

**Regle fondamentale** : Chaque choix narratif declenche un minigame. Le type est determine par **detection de champ lexical** dans le texte narratif et les tags de la carte.

#### Flow

```
Joueur choisit option "Escalader la falaise"
       ↓
Code analyse le texte : detecte mots-cles "escalader", "falaise", "vertige"
       ↓
Champ lexical detecte : "finesse" (mots: vertige, pont, equilibre...)
       ↓
Minigame associe : "equilibre" (champ finesse → equilibre ou ombres)
       ↓
Difficulte = contexte narratif (biome, carte, faction) — semi-adaptatif
       ↓
Score 0-100 → effets proportionnels
```

#### 8 champs lexicaux

Le code detecte des mots-cles dans le texte narratif et les tags pour determiner le champ lexical dominant. Chaque champ est associe a 1-2 minigames.

| Champ | Minigames | Keywords (detection) |
|-------|-----------|----------------------|
| **chance** | herboristerie | cueillir, potion, hasard, plante, herbe, champignon, racine |
| **bluff** | negociation | marchander, convaincre, mentir, negocier, esprit, fae, korrigan |
| **observation** | fouille, regard | chercher, voir, fixer, memoriser, indice, vision, forme, apparition |
| **logique** | runes | dechiffrer, symbole, inscription, rune, ogham, gravure |
| **finesse** | ombres, equilibre | discret, cacher, pont, vertige, gouffre, ombre, embuscade |
| **vigueur** | combat_rituel, course | combattre, courir, fuir, duel, guerrier, lame, epee, sprint |
| **esprit** | apaisement, volonte, sang_froid | calmer, resister, apaiser, courage, murmure, doute, piege, danger |
| **perception** | traces, echo | piste, ecouter, suivre, son, empreinte, voix, appel, echo, cri, chant |

#### Catalogue des minigames (14 types, objectif 15+)

| Minigame | Champ | Description |
|----------|-------|-------------|
| **Traces** | perception | Suivre des empreintes sans quitter le chemin |
| **Runes** | logique | Dechiffrer un ogham dans la pierre |
| **Equilibre** | finesse | Maintenir l'equilibre sur un passage instable |
| **Herboristerie** | chance | Identifier la bonne plante parmi les toxiques |
| **Negociation** | bluff | Convaincre un esprit par les mots justes |
| **Combat Rituel** | vigueur | Esquiver dans un cercle sacre |
| **Apaisement** | esprit | Calmer un gardien par le rythme |
| **Sang-froid** | esprit | Curseur stable malgre les pulsations |
| **Course** | vigueur | QTE pour maintenir la poursuite ou fuir |
| **Fouille** | observation | Trouver l'indice cache en temps limite |
| **Ombres** | finesse | Se deplacer entre couvertures sans etre vu |
| **Volonte** | esprit | Tenir le focus malgre les murmures |
| **Regard** | observation | Memoriser puis reproduire une sequence |
| **Echo** | perception | Suivre l'intensite sonore vers la bonne direction |

#### Difficulte semi-adaptive

La difficulte des minigames depend du **contexte narratif**, PAS de la performance du joueur :

| Facteur | Impact |
|---------|--------|
| Biome | Modificateur fixe par biome (-1 a +3) |
| Type de carte | Event = +1 (Merlin Direct : pas de minigame, pas de difficulte) |
| Faction dominante | Bonus +10% score si Ogham actif correspond |
| Progression (nb cartes) | Difficulte augmente legerement au fil du run |

Le joueur ne percoit pas d'ajustement lie a sa performance — le jeu reste consistant.

**Responsabilite** :
- Le **LLM** ecrit le texte narratif librement (pas de liste fermee de verbes)
- Le **code** detecte le champ lexical dans le texte + tags
- Le **code** choisit le minigame associe au champ dominant
- Le **code** determine la difficulte (contexte narratif, biome, faction)

#### Resultat du minigame

**Multiplicateur direct** : le score du minigame determine l'intensite des effets de la carte. Les effets proposes par le GM sont multiplies par le facteur correspondant.

| Score | Label | Multiplicateur d'effets |
|-------|-------|------------------------|
| 0-20 | Echec critique | Effets negatifs x1.5 |
| 21-50 | Echec | Effets negatifs x1.0 |
| 51-79 | Reussite partielle | Effets positifs x0.5 |
| 80-100 | Reussite | Effets positifs x1.0 (80 inclus — seuil pour bonus Anam +2) |
| 95-100 | Reussite critique | Effets positifs x1.5 + bonus |

Exemple : une carte donne "+15 rep Druides" sur succes. Score 60 (reussite partielle) = +15 x 0.5 = +7.5 rep.

**Minigames obligatoires** : le joueur doit toujours jouer le minigame. Pas de skip. Le minigame EST le gameplay.

**Exception** : les cartes **Merlin Direct** n'ont pas de minigame (effets a 100%).

---

## 3. Structure d'un run

### 3.1 Demarrage

1. Joueur choisit un **biome** dans le Hub 2D (parmi ceux debloques)
2. Ecran rapide de **choix d'Ogham** (au debut de la scene 3D)
3. LLM genere une **trame narrative** (outline + premieres cartes) pendant le chargement
4. **Scene 3D** demarre : personnage avance sur rail, vie=100, monnaie biome=0
5. Le joueur collecte monnaie biome et observe le decor pendant 5-15s
6. Premiere carte apparait via fondu enchaine

#### Premier run (onboarding)

Le **tout premier run** est special :
- **Biome force** : Foret de Broceliande (pas de choix)
- **Trame semi-scriptee** : les 2-3 premieres cartes sont **fixes** (pas generees par LLM) et servent d'introduction
- Merlin se presente, explique la barre de vie, les options de choix
- Le premier minigame est accompagne d'un texte explicatif de Merlin
- A partir de la carte 4, le LLM prend le relais normalement
- Les tooltips progressives se declenchent en parallele (section 10)

#### Interruption mid-run (resume)

Si le joueur quitte en plein run :
- L'etat du run est **sauvegarde** (carte courante, vie, monnaie, oghams, cooldowns, tags, promesses, factions, confiance)
- Le **contexte narratif** est sauvegarde comme resume JSON (trame, PNJ rencontres, arcs actifs, derniers choix). Au resume, ce resume est injecte comme contexte "previously on..." au LLM.
- Au relancement, le jeu **reprend exactement** ou le joueur en etait
- Pas d'ecran de choix — le run reprend automatiquement
- Si le joueur veut abandonner : option dans le menu pause → retour au Hub avec **Anam proportionnel** (meme formule que la mort : Anam x cartes/30, SANS bonus victoire)

### 3.2 Scenario hybride

- Le LLM genere un **outline/trame** au debut (pitch du scenario, arc narratif, personnages)
- Les **premieres cartes** sont pre-generees a partir de la trame
- Les **choix du joueur** influencent les cartes suivantes (generees dynamiquement)
- **Longueur tres variable** (10-40+ cartes) — le MOS decide quand la narration converge
- **Pas de minimum de cartes** impose — le MOS peut declencher une fin quand la narration l'exige
- **Heuristiques MOS de convergence** :
  - Soft min : **8 cartes** (en dessous, le MOS ne declenche pas de fin sauf mort)
  - Target : **20-25 cartes** (duree optimale)
  - Soft max : **40 cartes** (le MOS force la convergence progressive)
  - Hard max : **50 cartes** (fin forcee — narration conclut, peu importe le contexte)
  - La convergence est declenchee par : tension narrative ≥ 0.7, arc resolu, ou faction ≥ 80
- Le run **se termine** quand la narration converge vers une fin ou quand la vie atteint 0

### 3.3 Carte — structure

```
{
  "text": String,              // Texte narratif (genere par LLM Narrator)
  "speaker": String,           // "Merlin" ou NPC
  "options": [
    {
      "label": String,         // Texte d'action (le code detecte le champ lexical)
      "effects": [Dictionary], // Effets suggeres par LLM GM, valides par code
    },
    // ... toujours 3 options
  ],
  "type": "narrative" | "event" | "promise" | "merlin_direct",
  "tags": Array,               // Tags narratifs pour contexte
}
```

**Toujours 3 options** par carte, sans exception. Standardise pour le joueur et le LLM.

### 3.4 Types de cartes

| Type | Poids | Description | Minigame ? |
|------|:---:|-------------|:---:|
| Narrative | 80% | Carte de choix standard | Oui |
| Evenement | 10% | Evenement contextuel (apres carte 3) | Oui |
| Promesse | 5% | Quete avec delai (max 2 actives) | Oui |
| Merlin Direct | 5% | Intervention directe de Merlin | **Non** |

#### Cartes Merlin Direct (sans minigame)

Merlin parle et propose 3 options narratives. Le joueur choisit, et les **effets s'appliquent a 100%** (multiplicateur x1.0, pas de score). Ce sont des moments de choix pur, sans epreuve.

Exemples : Merlin propose un deal ("Donne-moi 10 vie et je te revele l'avenir"), offre un conseil, revele du lore selon le tier de confiance.

### 3.5 Promesses / Quetes

Les cartes de type "Promesse" creent des quetes avec un **countdown + choix** :
- La promesse a un delai (**X cartes**, affiche dans le HUD)
- **Countdown variable** : le MOS decide selon la difficulte (urgentes 3-5 cartes, longues 10-15 cartes)
- Avant l'expiration, une carte propose explicitement de **tenir ou briser** la promesse
- Si le joueur n'agit pas avant le delai → echec automatique (malus reputation)
- **Max 2 promesses actives** simultanement
- Resultat : tenir = rep faction + / confiance Merlin +10, briser = rep faction - / confiance -15, ignorer = pire malus

### 3.6 Chaines d'evenements (arcs narratifs par biome)

Chaque biome a **1 arc narratif exclusif** (3-5 cartes) + **1 arc cross-biome** (le mystere central).

#### Arcs par biome
Les arcs se declenchent progressivement sur **plusieurs runs** (pas en un seul run). Le joueur decouvre 1-2 cartes de l'arc par run, selon ses choix et les conditions.

| Biome | Arc | Cartes | Condition declenchement |
|-------|-----|:---:|--------------------------|
| Foret de Broceliande | Le Chene Chantant | 3 | Rep Druides ≥ 30 |
| Landes de Bruyere | L'Ermite du Vent | 4 | 3+ runs dans ce biome |
| Cotes Sauvages | Le Phoque d'Argent | 3 | Rep Niamh ≥ 30 |
| Villages Celtes | L'Assemblee Secrete | 5 | Rep Anciens ≥ 40 |
| Cercles de Pierres | Le Rituel Oublie | 4 | 2+ Oghams debloques |
| Marais des Korrigans | Le Tresor des Feux | 4 | Rep Korrigans ≥ 40 |
| Collines aux Dolmens | La Voix des Rois | 3 | 5+ fins vues |
| Iles Mystiques | Le Passage de Morgane | 5 | Rep Ankou ≥ 50 |

#### Arc cross-biome : "Le Murmure des Oghams"
Un mystere central qui se deroule sur **plusieurs biomes** (8-12 cartes au total). Le joueur decouvre des fragments dans differents biomes. Completer l'arc debloque la fin "Transcendance".

#### Tracking des arcs (cross-run)
La progression des arcs est stockee dans le profil joueur via des **tags persistants** :
- Chaque etape d'un arc = un tag (ex: `arc_chene_1`, `arc_chene_2`, `arc_chene_3`)
- Les tags sont ajoutes au profil quand le joueur joue la carte d'arc correspondante
- Au debut de chaque run, le MOS consulte les tags pour savoir quelles etapes inserer
- **Max 1-2 cartes d'arc par run** (le MOS ne force pas l'arc — il l'insere organiquement quand les conditions sont remplies)
- Un arc complete ajoute un tag `arc_complete_X` et ne se redeclenche plus

### 3.7 PNJ recurrents

Chaque biome a **1 PNJ nomme recurrent** que le joueur retrouve d'un run a l'autre. Sa relation evolue selon le contexte du biome.

| Biome | PNJ | Role | Lien |
|-------|-----|------|------|
| Foret de Broceliande | Gwenn la Cueilleuse | Guide nature, marchande d'herbes | Druides |
| Landes de Bruyere | Aedan l'Ermite | Sage solitaire, enigmes | Neutre (guide biome) |
| Cotes Sauvages | Bran le Passeur | Marchand maritime, informations | Anciens |
| Villages Celtes | Morwenna la Forge | Forgeronne, politique locale | Neutre (guide biome) |
| Cercles de Pierres | Seren l'Etoilee | Druidesse mystique, rituels | Druides |
| Marais des Korrigans | Puck le Lutin | Farceur, marchand de pieges | Korrigans |
| Collines aux Dolmens | Taliesin le Barde | Conteur, gardien de memoire | Anciens |
| Iles Mystiques | Branwen la Spectrale | Esprit enigmatique, epreuves | Ankou |

En plus des PNJ recurrents, le LLM genere des **PNJ generiques** (villageois, esprits, marchands ambulants) a chaque run.

### 3.8 Conditions de fin

| Condition | Fin |
|-----------|-----|
| Vie = 0 | Fin narrative "mort" (pas un game over — le LLM personalise) |
| Faction ≥ 80 en fin de scenario | Fin de faction disponible |
| Scenario termine (narration converge) | Fin naturelle |
| Conditions speciales (cartes, combinaisons) | Fins secretes |

**Principe** : Il n'y a pas de "mauvaise fin". Toute fin est narrativement valide.

**Fins multiples** : Si plusieurs factions sont ≥ 80 en fin de run, le **joueur choisit** laquelle debloquer via un ecran de choix narratif ("Vers qui vous tournez-vous ?"). Les autres fins restent disponibles pour les runs suivants (la rep ne decay pas).

---

## 4. Biomes — 8 mondes celtiques

### 4.1 Vue d'ensemble

| # | Cle | Nom | Sous-titre | Saison | Difficulte | Unlock |
|---|-----|-----|------------|--------|:---:|--------|
| 1 | `foret_broceliande` | Foret de Broceliande | Ou les arbres ont des yeux | Printemps | 0 | Starter |
| 2 | `landes_bruyere` | Landes de Bruyere | L'horizon sans fin | Automne | 1 | Score maturite (MOS) |
| 3 | `cotes_sauvages` | Cotes Sauvages | L'ocean murmurant | Ete | 0 | Score maturite (MOS) |
| 4 | `villages_celtes` | Villages Celtes | Flammes obstinees | Ete | -1 | Score maturite (MOS) |
| 5 | `cercles_pierres` | Cercles de Pierres | Ou le temps hesite | Hiver | 1 | Score maturite (MOS) |
| 6 | `marais_korrigans` | Marais des Korrigans | Deception et feux follets | Automne | 2 | Score maturite (MOS) |
| 7 | `collines_dolmens` | Collines aux Dolmens | Les os de la terre | Printemps | 0 | Score maturite (MOS) |
| 8 | `iles_mystiques` | Iles Mystiques | Au-dela des brumes | Samhain | 3 | Score maturite (MOS) |

#### Deblocage des biomes — Score de maturite (MOS organique)

Les biomes ne se debloquent **pas par compteur** (X runs). Le MOS calcule un **score de maturite** multi-criteres et decide **organiquement** quand inserer une **carte-cle** dans un run.

**Mecanisme en 2 temps** :
1. **Carte-cle pendant un run** : le MOS insere une carte speciale (portail, vision, invitation) quand le score de maturite depasse un seuil
2. **Biome disponible au Hub** : apres la carte-cle, le nouveau biome apparait dans le Hub au run suivant

**4 criteres du score de maturite** :
- Nombre total de runs
- Fins vues / debloquees
- Oghams debloques
- Reputation max atteinte (toutes factions)

**Poids initiaux (ajustables au playtest)** :
```
Score = (total_runs x 2) + (fins_vues x 5) + (oghams_debloques x 3) + (max_faction_rep x 1)
```

**Seuils par biome** :
| Biome | Seuil | Exemple de profil |
|-------|:---:|-------------------|
| Landes de Bruyere | 15 | ~5 runs, 1 fin, 2 oghams |
| Cotes Sauvages | 15 | ~4 runs, 1 fin, 3 oghams |
| Villages Celtes | 25 | ~8 runs, 2 fins, 3 oghams |
| Cercles de Pierres | 30 | ~10 runs, 2 fins, 4 oghams |
| Marais des Korrigans | 40 | ~12 runs, 3 fins, 5 oghams |
| Collines aux Dolmens | 50 | ~15 runs, 4 fins, 6 oghams |
| Iles Mystiques | 75 | ~25 runs, 6 fins, 8 oghams |

> Les seuils seront ajustes au playtest. L'ordre de deblocage reste l'objectif mais le MOS a la liberte du timing au sein de chaque "tier" de seuil.

**Garde-fou** : le MOS ne peut PAS inserer une carte-cle tant que le score de maturite est en dessous du seuil minimum du biome.

### 4.2 Detail par biome

#### Foret de Broceliande (starter)
- **Theme** : Nature ancienne, mystere vegetal, brume enchantee, korrigans
- **Creatures** : Fees, korrigans, loups anciens, arbres animes
- **Atmosphere** : Brume perpetuelle, lumiere filtree, echos de voix anciennes
- **Oghams bonus** : quert, huath, coll
- **Monnaie biome** : Herbes / Baies enchantees

#### Landes de Bruyere
- **Theme** : Survie, solitude, endurance, vent hurlant
- **Creatures** : Rapaces, lievres, ermites, esprits du vent
- **Atmosphere** : Landes balayees par le vent, ciel immense, bruyere violette
- **Oghams bonus** : luis, onn, saille
- **Monnaie biome** : Brins de bruyere / Plumes de rapace

#### Cotes Sauvages
- **Theme** : Commerce, exploration, danger maritime, tempetes
- **Creatures** : Phoques, mouettes, marchands etrangers, sirenes
- **Atmosphere** : Falaises battues par les vagues, sel et algues, ports de peche
- **Oghams bonus** : muin, nuin, tinne
- **Monnaie biome** : Coquillages / Perles de brume

#### Villages Celtes
- **Theme** : Politique, social, intrigues, assemblee tribale
- **Creatures** : Villageois, chefs de clan, druides, forgerons
- **Atmosphere** : Huttes rondes, feux de camp, assemblees, rumeurs
- **Oghams bonus** : duir, coll, beith
- **Monnaie biome** : Pieces de cuivre / Faveurs de clan

#### Cercles de Pierres
- **Theme** : Magie, spirituel, liminal, rituels druidiques
- **Creatures** : Esprits ancestraux, druides anciens, ombres du passe
- **Atmosphere** : Menhirs millenaires, energie palpable, etoiles differentes
- **Oghams bonus** : ioho, straif, ruis
- **Monnaie biome** : Fragments de rune / Eclats de menhir

#### Marais des Korrigans
- **Theme** : Danger, mystere, tentation, tresors caches
- **Creatures** : Korrigans, feux follets, creatures des tourbieres, morts-vivants
- **Atmosphere** : Eaux stagnantes, brume epaisse, lumieres trompeuses
- **Oghams bonus** : gort, eadhadh, luis
- **Monnaie biome** : Pierres phosphorescentes / Gouttes de marais

#### Collines aux Dolmens
- **Theme** : Sagesse, ancestral, memoire, paix profonde
- **Creatures** : Esprits d'anciens rois, sages, animaux paisibles
- **Atmosphere** : Collines douces, dolmens et tumulus, air paisible et lourd de memoire
- **Oghams bonus** : quert, ailm, coll
- **Monnaie biome** : Os graves / Cailloux de sagesse

#### Iles Mystiques
- **Theme** : Transcendance, passage, monde invisible, liminalite absolue
- **Creatures** : Selkies, banshees, fees des vagues, esprits anciens, gardienne Morgane
- **Atmosphere** : Brume eternelle, vagues phosphorescentes, chants lointains, tour en ruines
- **Oghams bonus** : ailm, ruis, ioho
- **Monnaie biome** : Ecume solidifiee / Larmes de Morgane

### 4.3 Run 3D permanent (on-rails)

Le run se deroule **entierement en 3D**. Le personnage avance automatiquement sur un **chemin fixe (rail)** dans le biome. Le joueur interagit en cliquant sur les objets/evenements qui apparaissent au passage. Les cartes narratives arrivent via **fondu enchaine** apres 5-15 secondes de marche.

#### Flow d'un run
```
3D (marche rail) → [5-15s collecte/observation] → [Fondu] → Carte 2D
→ Choix (3 options) → Minigame overlay 2D → Effets → [Fondu] → 3D (marche)
→ [Repeter] → Fin narrative → Fondu → Carte du voyage → Gains → Hub 2D
```

#### Rythme entre les cartes
Variable selon le biome — determine la duree de marche 3D entre deux cartes :

| Biome | Intervalle entre cartes | Style visuel |
|-------|------------------------|-------------|
| Foret de Broceliande | Calme (12-15s) | Meditatif, lumieres douces, brume |
| Landes de Bruyere | Modere (8-10s) | Vent, obstacles naturels |
| Cotes Sauvages | Rythme par les vagues (6-8s) | Embruns, coquillages, falaises |
| Villages Celtes | Social, modere (8-10s) | PNJ, etals, feux |
| Cercles de Pierres | Lent, mystique (10-12s) | Runes lumineuses, energies |
| Marais des Korrigans | Frenetique, piegeux (4-6s) | Feux follets, fondrieres |
| Collines aux Dolmens | Paisible (10-12s) | Animaux, pierres gravees |
| Iles Mystiques | Imprevisible (3-15s) | Spectral, vagues phosphorescentes |

#### Interactions pendant la marche 3D
Entre deux cartes, le joueur peut cliquer sur des elements du decor :

| Type d'evenement | Action | Recompense/Consequence |
|------------------|--------|------------------------|
| Monnaie au sol | Cliquer au bon moment | +monnaie biome |
| Plante/Source | Cliquer | +soin (vie) |
| Piege/Obstacle | Eviter (touche) ou rater | -degat (vie) |
| Rune/Inscription | Cliquer | +indice narratif (enrichit le contexte LLM) |
| Esprit/Apparition | Cliquer | +buff temporaire (+5% score minigame, -1 cooldown) |
| Anam rare | Cliquer (fenetre courte) | +Anam (rare, ~5% des events) |

**Pas de bouton skip** — la 3D est le run. Le joueur qui interagit bien avec le decor obtient un run enrichi (plus de contexte, monnaie, buffs).

**Duree des buffs 3D** : Les buffs temporaires obtenus par les evenements 3D (Esprit/Apparition : +5% score, -1 cooldown) durent **jusqu'a la prochaine carte** (1 carte). Ils disparaissent apres que la carte est resolue. Les inputs joueur sont **desactives pendant les fondus** (1-2s de transition).

#### Transitions carte ↔ 3D
- **3D → Carte** : fondu enchaine (la scene 3D s'assombrit, la carte 2D apparait)
- **Carte → Minigame** : le minigame s'affiche en **overlay 2D** sur la scene 3D figee
- **Minigame → 3D** : fondu enchaine inverse (la carte disparait, la scene 3D reprend)
- Chaque transition dure ~1-2 secondes

---

## 5. Progression meta

### 5.1 Arbre de talents

Debloque avec les **Anam** (cross-run).

**Structure** : Branches thematiques par faction + branche centrale.

```
                    [CENTRAL]
                   /    |    \
            [DRUIDES] [NEUTRE] [ANCIENS]
              /                    \
       [KORRIGANS]            [NIAMH]
              \                    /
                    [ANKOU]
```

**~30-34 noeuds** redistribues sur 5 branches factions + branche centrale.

**Contenu des branches** :
- **3 starters** (branche centrale, tier 0, cout 0) : beith, luis, quert
- **15 Oghams** repartis dans les 5 branches faction (3 par branche)
- **~15-19 bonus passifs** — ex: +10% rep, -1 cooldown, +vie max, +score minigame, etc.
- **Prerequis** — noeuds tier N necessitent ≥1 noeud tier N-1 de la meme branche
- **Cout** : en Anam (monnaie cross-run, voir section 2.4 pour les fourchettes)

**Repartition des Oghams par branche** :
| Branche | Oghams (3) | Logique |
|---------|-----------|---------|
| **Druides** | coll (Reveal), duir (Boost), nuin (Narratif) | Connaissance + nature |
| **Anciens** | ailm (Reveal), tinne (Boost), straif (Narratif) | Sagesse + tradition |
| **Korrigans** | onn (Boost), muin (Special), huath (Narratif) | Chaos + surprises |
| **Niamh** | saille (Recovery), ruis (Recovery), gort (Protection) | Amour + protection |
| **Ankou** | eadhadh (Protection), ioho (Special), ur (Special) | Mort + sacrifice |
| **Central** (starters) | beith (Reveal), luis (Protection), quert (Recovery) | Bases universelles |

### 5.2 Fins — catalogue + LLM

**~10-15 fins cataloguees** :

| Type | Condition | Description |
|------|-----------|-------------|
| Fin Druides | Rep Druides ≥ 80 | Le joueur est accueilli par le cercle des druides |
| Fin Anciens | Rep Anciens ≥ 80 | Les ancetres reconnaissent le joueur |
| Fin Korrigans | Rep Korrigans ≥ 80 | Le joueur entre dans le monde des fees |
| Fin Niamh | Rep Niamh ≥ 80 | Niamh invite le joueur a Tir na nOg |
| Fin Ankou | Rep Ankou ≥ 80 | Le joueur devient passeur entre les mondes |
| Fin Mort | Vie = 0 | Fin narrative liee au contexte du moment |
| Fin Naturelle | Scenario termine | Le run s'acheve paisiblement |
| Fin Harmonie | Toutes factions ≥ 60 | Equilibre parfait entre les 5 factions |
| Fin Transcendance | Arc "Le Murmure des Oghams" complete | Revelation des secrets des Oghams |
| Fins Secretes | Combinaisons rares | Decouvertes par exploration |

**Personnalisation LLM** : Le LLM genere le texte de chaque fin en fonction du contexte specifique du run (choix faits, biome, factions, evenements). Deux "Fin Druides" ne seront jamais identiques.

**Pas de hierarchie** : Toute fin est narrativement valide. Finir tot n'est pas un echec.

**Fins secretes** : Pas prioritaire pour le MVP. A designer quand le core loop est solide.

### 5.3 Ecran de fin de run

Le flow apres la fin d'un run (mort, fin de scenario, fin de faction) :

```
1. FONDU NARRATIF — L'ecran s'assombrit, le texte de fin LLM apparait
   comme un dernier souffle de Merlin. Pas de "Game Over". Juste la
   narration qui se clot. Le joueur clique pour continuer.

2. CARTE DU VOYAGE — Le parcours du joueur affiche sur une carte
   stylisee du biome, avec des epingles aux moments cles (choix
   importants, minigames, evenements, rencontres). Comme une carte
   au tresor completee. Hover sur les epingles = details.

3. ECRAN DE GAINS — Anam gagnes, reputations factions modifiees,
   statistiques du run (cartes jouees, minigames gagnes, vie restante,
   duree). Bouton "Continuer" → retour au Hub.
```

### 5.4 Profil unique (save system)

Le jeu utilise un **profil unique** avec auto-continue (style Hades).

| Propriete | Detail |
|-----------|--------|
| Type | Profil unique (1 seul fichier `merlin_profile.json`) |
| Auto-continue | Au lancement, le profil charge automatiquement — pas d'ecran de selection |
| Contenu | Meta-progression uniquement (pas de save mid-run) |
| Mid-run | Pas de save **manuelle**. Si le joueur quitte, l'etat du run est sauvegarde automatiquement (voir section 3.1 Interruption). |
| Autosave | La meta-progression est sauvegardee automatiquement en fin de run |
| Reset | Option cachee dans le menu Options/Parametres avec confirmation |

**Contenu d'un profil** :
- Anam (monnaie cross-run)
- Reputation des 5 factions
- Oghams debloques
- Arbre de talents (noeuds actives)
- Fins vues / debloquees
- Nombre de runs, biomes decouverts
- Statistiques (temps de jeu, minigames joues, etc.)

### 5.5 Ce qui persiste entre les runs

| Persiste | Perdu |
|----------|-------|
| Anam | Vie |
| Reputation factions (pas de decay) | Monnaie biome |
| Oghams debloques | Cartes jouees |
| Arbre de talents | Scenario/trame |
| Nombre de runs, fins debloquees | Tags actifs, promesses |

---

## 6. Architecture LLM

### 6.1 Multi-Brain (Qwen 3.5 via Ollama)

| Cerveau | Modele | RAM | Role | Temperature |
|---------|--------|-----|------|:-----------:|
| **Narrator** | Qwen 3.5 4B | ~3.2 GB | Texte narratif + verbes d'action | 0.70 |
| **Game Master** | Qwen 3.5 2B | ~1.8 GB | Effets JSON (suggeres) | 0.15 |
| **Judge** | Qwen 3.5 0.8B | ~0.8 GB | Scoring qualite du Narrator | 0.30 |

### 6.2 Profils hardware

| Profil | RAM | Mode | Cerveaux |
|--------|-----|------|----------|
| NANO | 4 GB | Resident | 1 (0.8B tout) |
| SINGLE | 6 GB | Resident | 1 (2B tout) |
| SINGLE+ | 7 GB | Time-sharing | 2 (4B Narrator + 2B GM) |
| DUAL | 12 GB | Parallele | 2 (4B + 2B simultane) |
| TRIPLE | 14 GB | Parallele | 3 (4B + 2B + 0.8B) |
| QUAD | 16 GB | Parallele | 4 (4B + 2B + 0.8B Judge + 0.8B Worker) |

### 6.3 Pipeline de generation de carte

```
1. CODE construit le contexte (etat du jeu, biome, heure, factions)
2. NARRATOR/4B genere le TEXTE (~6-8s, 200 tokens, T=0.70)
   → Texte narratif + options avec verbes de la liste fermee
3. GAME MASTER/2B genere les EFFETS JSON (~2-3s, 120 tokens, T=0.15)
   → Effets suggeres par option
4. CODE valide les effets (whitelist, caps, guardrails)
5. CODE mappe les verbes vers les minigames
6. JUDGE/0.8B evalue la qualite du texte Narrator
7. AFFICHAGE de la carte au joueur
```

### 6.4 Contrat LLM — ce que le Narrator doit produire

Le Narrator genere un JSON contenant :
- `text` : texte narratif en francais (1-4 phrases)
- `speaker` : "Merlin" ou nom de PNJ
- `options` : **toujours 3 options**, chacune avec un `label` (verbe d'action de la liste fermee)

**Contraintes** :
- **Toujours 3 options** par carte (jamais plus, jamais moins)
- Francais uniquement, sans anglicismes
- Verbes d'action exclusivement dans la **liste fermee** (40+ verbes)
- Jamais de meta-references (pas de "simulation", "algorithme", "token", "IA")
- Vocabulaire celtique encourage (brume, ogham, nemeton, menhir, dolmen, etc.)

**Liste fermee des verbes d'action (45 verbes)** :

| Champ | Verbes |
|-------|--------|
| **chance** | cueillir, chercher au hasard, tenter sa chance, deviner, fouiller a l'aveugle |
| **bluff** | marchander, convaincre, mentir, negocier, charmer, amadouer |
| **observation** | observer, scruter, memoriser, examiner, fixer, inspecter |
| **logique** | dechiffrer, analyser, resoudre, decoder, interpreter, etudier |
| **finesse** | se faufiler, esquiver, contourner, se cacher, escalader, traverser |
| **vigueur** | combattre, courir, fuir, forcer, pousser, resister physiquement |
| **esprit** | calmer, apaiser, mediter, resister mentalement, se concentrer, endurer |
| **perception** | ecouter, suivre, pister, sentir, flairer, tendre l'oreille |
| **neutre** | parler, accepter, refuser, attendre, s'approcher |

> Le LLM doit utiliser UNIQUEMENT ces verbes dans les labels d'option. Le code les mappe aux champs lexicaux pour choisir le minigame.

**Verbes neutres et minigames** : Les verbes de la categorie "neutre" (parler, accepter, refuser, attendre, s'approcher) sont mappes au champ **esprit** par defaut. Le minigame associe sera "apaisement" ou "volonte" selon le contexte narratif. Ainsi, meme un choix "passif" implique une epreuve mentale.

### 6.5 Contrat LLM — ce que le Game Master doit produire

Le GM produit un JSON d'effets par option :
```json
{
  "option_0": [
    {"type": "ADD_REPUTATION", "faction": "druides", "amount": 15},
    {"type": "DAMAGE_LIFE", "amount": 5}
  ],
  "option_1": [
    {"type": "HEAL_LIFE", "amount": 10},
    {"type": "UNLOCK_OGHAM", "ogham": "duir"}
  ]
}
```

**Effets autorises (whitelist)** :

| Effet | Format | Description |
|-------|--------|-------------|
| `ADD_REPUTATION` | faction + amount | Modifier reputation faction |
| `HEAL_LIFE` | amount | Soigner la barre de vie |
| `DAMAGE_LIFE` | amount | Infliger des degats |
| `UNLOCK_OGHAM` | ogham_name | Debloquer un Ogham |
| `ADD_TAG` | tag_name | Ajouter un tag narratif |
| `REMOVE_TAG` | tag_name | Retirer un tag |
| `TRIGGER_EVENT` | event_id | Declencher un evenement |
| `PROMISE` | promise_id | Creer une promesse/quete |
| `PLAY_SFX` | sound_id | Jouer un son |
| `ADD_BIOME_CURRENCY` | amount | Ajouter de la monnaie biome |
| `SHOW_DIALOG` | dialog_id | Afficher un dialogue |

Le CODE valide, ajuste (caps), et peut rejeter des effets proposes par le GM.

**Caps par effet (guardrails code)** :
| Effet | Cap par carte | Note |
|-------|:---:|------|
| ADD_REPUTATION | ±20 par faction par carte | Empeche les swings excessifs |
| HEAL_LIFE | +18 max | Ruis est le soin max (18 PV) |
| DAMAGE_LIFE | -15 max (sauf echec critique) | Echec critique peut aller a -15 x 1.5 = -22 |
| ADD_BIOME_CURRENCY | +10 max | Onn est le max (10) |
| UNLOCK_OGHAM | 1 max par carte | Pas de double deblocage |
| Total effets par option | 3 max | Le GM ne peut pas empiler plus de 3 effets par option |
| Score minigame bonus | Additifs entre eux, cap global a **x2.0** | Affinite biome + talents + buffs 3D |

### 6.6 RAG — contexte injecte

Budget par cerveau :
- Narrator : 800 tokens (contexte 8192)
- GM : 400 tokens (contexte 4096)
- Judge/Worker : 200 tokens (contexte 2048)

Priorite des sections de contexte :
1. Detection de crise (CRITIQUE)
2. Contrat de scene
3. Narration recente
4. Arcs actifs
5. Biome + ambiance
6. Ton
7. Profil joueur
8. Promesses actives
9. Niveau de danger

### 6.7 Fallback — FastRoute (pre-genere offline)

Si le LLM echoue ou timeout : **FastRoute** — pool de **500+ cartes pre-generees offline** par un LLM cloud puissant (Claude/GPT).

| Propriete | Detail |
|-----------|--------|
| Volume | 500+ cartes |
| Generation | LLM cloud (Claude ou GPT) en batch — cout unique |
| Indexation | Par biome, faction dominante, champ lexical |
| Qualite | Superieure aux cartes live (LLM plus puissant, revue manuelle) |
| Selection | Le code choisit la carte la plus pertinente selon le contexte actuel |
| Objectif | Taux de fallback < 5% |

Les cartes FastRoute sont stockees dans un fichier JSON local, charge au demarrage.

### 6.8 MOS — Merlin Omniscient System

Le MOS est le **cerveau central** qui orchestre les 3 cerveaux LLM, dirige le jeu, et applique les guardrails. Il fait de Merlin un personnage vivant qui evolue avec le joueur.

#### 3 roles du MOS

| Role | Description |
|------|-------------|
| **Orchestrateur LLM** | Route les cartes via FastRoute (70% hit rate) ou LLM. Valide les outputs, gere les fallbacks, coordonne Narrator/GM/Judge. |
| **Directeur de jeu** | Gere le pacing (tension narrative 0-0.8), la difficulte (rubber-banding), les arcs narratifs (max 2 actifs, 7 cartes/arc), les rebondissements. |
| **Guardrails** | Valide l'equilibre des cartes (total effet <50, 90% tradeoff), previent la mort instantanee, filtre le contenu (pas de mots modernes, pas de meta-references). |

#### Mecanismes cles

| Mecanisme | Detail |
|-----------|--------|
| **Pacing** | Applique 20% mercy (-scaling) apres 3 morts consecutives. Force carte de recuperation si vie <20. |
| **Tension** | Pression narrative (0-0.8) drive la probabilite de twist. Systeme de fatigue thematique pour eviter repetition. |
| **Difficulte** | Semi-adaptive : depend du contexte narratif (biome, carte, faction), PAS de la performance joueur. Rubber-banding sur morts consecutives. |
| **Confiance** | 4 tiers (T0-T3, seuils 25/50/75). Promesse tenue = +10, brisee = -15. Voir detail ci-dessous. |
| **Voix de Merlin** | 5 modes : neutre, mysterieux, avertissement, moquerie, melancolie. Le MOS choisit selon le contexte. |

#### Registres persistants

Le MOS maintient 6 registres pour tracker l'etat du jeu :
1. **Player Registry** — comportement, preferences, tendances
2. **Narrative Registry** — arcs actifs, PNJ rencontres, twist resolus
3. **Faction Registry** — reputation, interactions, alignements
4. **Card Registry** — cartes jouees, themes vus, fatigue
5. **Promise Registry** — promesses actives, delais, resolutions
6. **Trust Registry** — confiance Merlin/joueur (T0-T3)

#### Confiance Merlin — detail des tiers

| Tier | Seuil | Comportement de Merlin | Ce qu'il revele |
|------|:---:|------------------------|-----------------|
| **T0** | 0-24 | Cryptique, distant | Rien — textes enigmatiques, pas d'aide concrete |
| **T1** | 25-49 | Curieux, indices | Indices sur les effets des options (avant le choix) |
| **T2** | 50-74 | Bienveillant, avertissements | Avertit des dangers, signale les pieges narratifs |
| **T3** | 75-100 | Complice, secrets | Revele des chemins caches, des fins secretes, des raccourcis |

**Persistance** : cross-run (permanente). La confiance se construit au fil des runs. Depart a 0 (T0).
**Bornes** : min 0, max 100. Ne peut pas etre negative. Le changement de tier est **immediat** (mid-run si la confiance passe un seuil, le comportement de Merlin change pour les cartes suivantes).

La confiance evolue par les actions du joueur :
- Promesse tenue : +10
- Promesse brisee : -15
- Choix courageux / altruiste : +3-5 (selon contexte, MOS decide)
- Choix egoiste / destructeur : -3-5

> Ref technique : `docs/20_card_system/GDD_MERLIN_OMNISCIENT_SYSTEM.md`
> Code : `addons/merlin_ai/merlin_omniscient.gd`

---

## 7. Calendrier & temps

### 7.1 Hybride : reel + in-game

| Composante | Source | Impact |
|------------|--------|--------|
| Ambiance visuelle (lumiere 3D) | **Heure reelle** du joueur | Visuel uniquement |
| Bonus mecaniques (factions) | **Cycle in-game** (avance avec les cartes) | Gameplay |
| Festivals | **Cycle in-game** | Contenu special |

### 7.2 Periodes (cycle in-game)

Le cycle in-game avance avec les cartes. **1 periode = 5 cartes**. L'ordre est fixe : Aube → Jour → Crepuscule → Nuit → (boucle). Un run de 20 cartes traverse 4 periodes.

| Periode | Cartes | Faction active | Effet |
|---------|:---:|----------------|-------|
| Aube | 1-5 | Druides | +10% gains rep Druides |
| Jour | 6-10 | Anciens / Niamh | +10% gains rep Anciens ET Niamh |
| Crepuscule | 11-15 | Korrigans | +10% gains rep Korrigans |
| Nuit | 16-20 | Ankou | +15% gains rep Ankou (plus genereux car plus dangereux) |

> Le cycle boucle : carte 21 = retour a l'Aube. Le bonus s'applique aux gains de reputation de la faction indiquee (pas aux pertes).

### 7.3 Saisons & festivals

| Saison | Mois | Festival | Effet |
|--------|------|----------|-------|
| Hiver | Dec-Fev | Imbolc (Fev) | Pool Niamh +20% |
| Printemps | Mar-Mai | Beltane (Mai) | Pool Druides +20% |
| Ete | Jun-Aout | Lughnasadh (Aout) | Pool Anciens +20% |
| Automne | Sep-Nov | Samhain (Oct) | Pool Ankou +30% |

---

## 8. HUD & UI

### 8.1 HUD en jeu

#### Pendant la marche 3D (entre les cartes)
HUD **minimaliste** : indicateurs discrets pour ne pas casser l'immersion.
```
┌──────────────────────────────────────────┐
│ [♥ ████████░░]              [🌿 x12]    │  ← Vie + Monnaie biome
│ [📜 1/2]                     [⚬ Beith]   │  ← Promesses actives + Ogham actif (cliquable pour switch)
│                                           │
│           [SCENE 3D du biome]             │
│        (personnage avance sur rail)       │
│                                           │
│                              [☀ Jour]     │  ← Periode in-game (discret)
└──────────────────────────────────────────┘
```

**Interactions HUD 3D** :
- Clic sur l'Ogham : ouvre le menu de switch (si 2+ Oghams equipes)
- Clic sur les promesses : affiche le detail (countdown, faction)
- Tous les autres clics : interaction avec le decor 3D

#### Pendant une carte (overlay)
L'UI de carte apparait via fondu enchaine :
```
┌──────────────────────────────────────────┐
│ [♥ ████████░░ 75/100]        [🌿 x12]   │  ← Vie + Monnaie biome
│                              [⚬ Beith]   │  ← Ogham actif (cliquable)
│                                           │
│     [TEXTE NARRATIF DE LA CARTE]          │
│                                           │
│  [Option A: Escalader]  [Option B: Parler]│  ← 3 verbes d'action
│  [Option C: Observer]                     │
└──────────────────────────────────────────┘
```

**Dialogue Merlin** : Options predefinies seulement (pas de chat libre). Le joueur interagit via les options de la carte.

### 8.2 Hub / Antre (entre les runs)

Menu stylise **2D** avec boutons thematiques. Le Hub est **minimaliste** — pas de craft, pas de boutique, pas de mini-jeux.

**Contenu du Hub** :
- **Dialogue Merlin** : A chaque retour au Hub, le LLM genere un **commentaire de Merlin** base sur le dernier run (felicitations, moquerie, conseil, lore). Unique a chaque fois.
- **Arbre de talents** : Depenser les Anam (hexagonal, runes)
- **Choisir biome** : Carte des biomes debloques
- **Stats** : 5 factions (jauges de reputation), Anam, nombre de runs
- **Oghams** : Collection des 18, equiper l'Ogham actif
- **Journal** : Fins debloquees, biomes decouverts
- **Options** : Parametres, reset profil (avec confirmation)

Le dialogue Merlin est **optionnel** — le joueur peut le passer. Il utilise le **Narrator 4B** (meme cerveau que les cartes).

---

## 9. Audio

### 9.1 Musique dynamique par biome (stems mix)

Chaque biome a un **theme musical decompose en stems** (melodie, percussion, basse, ambiance). La tension narrative (MOS, 0-0.8) controle le mix :

| Tension MOS | Stems actifs | Ambiance |
|:-----------:|-------------|----------|
| 0.0 - 0.2 | Ambiance seule | Contemplatif, exploration |
| 0.2 - 0.4 | + Melodie legere | Curiosite, decouverte |
| 0.4 - 0.6 | + Basse | Tension narrative, enjeux |
| 0.6 - 0.8 | + Percussion | Danger, climax, confrontation |

Les stems se **crossfadent progressivement** (2-3 secondes). Le joueur percoit une evolution naturelle, pas de coupure.

### 9.2 SFX feedback

Le SFXManager (30+ sons proceduraux) fournit un feedback pour chaque action :
- Clic sur option, succes/echec minigame, ogham active, rep faction change
- Degats vie, soin, mort, transition, monnaie biome collectee
- Sons specifiques par biome (vagues, vent, feux follets, chants)

### 9.3 Audio pendant la marche 3D

Pendant la marche 3D (entre les cartes), l'ambiance sonore evolue avec le biome et les evenements rencontres. Les stems se crossfadent selon la tension MOS (voir 9.1).

---

## 10. Tutoriel & Onboarding

### 10.1 Approche : diegetique + tooltips

Le tutoriel est **integre dans la narration** (Merlin explique) + **tooltips discretes** pour les elements UI.

#### Diegetique (Merlin guide)
- Les 2-3 premieres cartes du **premier run** contiennent des explications de Merlin dans le texte narratif
- Merlin introduit : la barre de vie, les options de choix, le premier minigame
- Pas de popup, pas de fleches — tout est dans la voix de Merlin
- "Ah, voyageur, tu vois cette barre? C'est ta force vitale..."

#### Tooltips progressives
Des tooltips apparaissent **la premiere fois** que le joueur rencontre chaque mechanique :
| Declencheur | Tooltip |
|-------------|---------|
| 1er minigame | "Chaque action declenche une epreuve. Ton score determine l'intensite des effets." |
| 1er Ogham disponible | "Clique sur l'icone Ogham pour activer ton pouvoir." |
| 1ere rep faction change | "Ta reputation aupres des factions evolue. Elle persiste entre les runs." |
| 1ere monnaie biome | "La monnaie biome peut etre depensee aupres des marchands ou en offrandes." |
| 1ere promesse | "Les promesses ont un delai. Tiens-les pour gagner en reputation." |

Les tooltips sont stockees dans un flag `tutorial_shown` du profil — jamais reaffichees.

## 11. Systemes SUPPRIMES (reference historique)

> Ces systemes ont ete retires du design. Ils peuvent encore exister dans le code (nettoyage en cours).

| Systeme | Raison de suppression | Date |
|---------|-----------------------|------|
| **Triade** (Corps/Ame/Monde) | Remplace par Factions | 2026-03-11 |
| **Souffle d'Ogham** (0-7) | Plus de cout — options gratuites | 2026-03-11 |
| **4 Jauges** (Vigueur/Esprit/Faveur/Ressources) | Remplace par 1 barre de vie | 2026-03-12 |
| **Bestiole** (compagnon + bond + besoins) | Supprime — Oghams sont du joueur | 2026-03-12 |
| **Awen** (0-5, ressource bestiole) | Supprime avec la bestiole | 2026-03-12 |
| **D20 / dice roll** | Remplace par minigames systematiques | 2026-03-12 |
| **3 options fixes (G/C/D)** | Remplace par 3 options standardisees (toujours 3) | 2026-03-14 |
| **Flux System** (terre/esprit/lien) | Complexite inutile, factions suffisent | 2026-03-12 |
| **Run Typologies** (classique/urgence/parieur/diplomate/chasseur) | Trop pour MVP, biomes suffisent | 2026-03-12 |

---

## 12. Glossaire

| Terme | Definition |
|-------|------------|
| **Ogham** | Pouvoir du joueur (18 au total), lie a un arbre celtique |
| **Faction** | L'un des 5 groupes de reputation (Druides, Anciens, Korrigans, Niamh, Ankou) |
| **Anam** | Monnaie cross-run (du gaelique "ame") pour l'arbre de talents |
| **Monnaie biome** | Ressource per-run, specifique au biome, collectible en 3D |
| **Run** | Une partie complete (depart → fin narrative) |
| **Trame** | Scenario narratif genere par le LLM au debut du run |
| **Champ lexical** | L'un des 8 champs (chance, bluff, observation, logique, finesse, vigueur, esprit, perception) |
| **Minigame** | Epreuve ludique declenchee par detection de champ lexical |
| **MOS** | Merlin Omniscient System — cerveau central (orchestrateur + directeur + guardrails) |
| **Profil** | Sauvegarde joueur contenant la meta-progression (pas de save mid-run) |
| **Hub / Antre** | Menu stylise 2D entre les runs (arbre de talents, choix de biome, stats, options) |
| **FastRoute** | Pool de cartes de secours si le LLM echoue |
| **Narrator** | Cerveau LLM 4B qui genere le texte narratif |
| **Game Master** | Cerveau LLM 2B qui genere les effets JSON |
| **Judge** | Cerveau LLM 0.8B qui evalue la qualite des textes |
| **Run 3D (on-rails)** | Le run entier se deroule en 3D permanente — le personnage avance sur un rail, le joueur clique sur les evenements entre les cartes |
| **Promesse** | Quete avec countdown (X cartes) + choix explicite de tenir ou briser |
| **Chaine d'evenements** | Arc narratif de 3-5 cartes specifique a un biome, decouvert sur plusieurs runs |
| **Stems** | Pistes audio separees (melodie, percussion, basse, ambiance) mixees dynamiquement selon la tension |
| **Carte du voyage** | Ecran de fin de run : carte stylisee du biome avec epingles aux moments cles |
| **Score de maturite** | Score multi-criteres (runs, fins, oghams, rep) calcule par le MOS pour debloquer les biomes organiquement |
| **Carte-cle** | Carte speciale inseree par le MOS pour debloquer un nouveau biome (portail, vision, invitation) |
| **Confiance Merlin** | Systeme T0-T3 mesurant la relation joueur-Merlin, determine ce que Merlin revele |
| **Merlin Direct** | Type de carte ou Merlin parle et propose 3 options sans minigame (effets a 100%) |
| **Multiplicateur direct** | Le score du minigame determine l'intensite des effets (x0.5 a x1.5) |
| **Ogham temporaire** | Ogham decouvert en run, utilisable ce run seulement, puis disponible a -50% dans l'arbre |

---

## 13. Regles detaillees, interactions & edge cases

> Cette section couvre TOUS les cas limites et interactions entre systemes. Chaque regle est une **decision finale** — pas de "a definir au playtest" sauf mention explicite.

### 13.1 Interactions entre systemes

#### Ogham Protection + effets multiples
- `luis` (Protection) bloque **1 seul effet negatif** — le premier dans l'ordre d'application. Les effets negatifs suivants passent normalement.
- `eadhadh` (Tremble) bloque **tous les negatifs** de la carte. Plus puissant mais cooldown 8.
- `gort` (Lierre) ne bloque pas — il **reduit** un gros degat (>10 → 5). Ne s'applique qu'aux degats PV, pas aux pertes de rep.

#### Cross-faction + promesse
- Les penalites s'empilent : une promesse brisee (-rep, -confiance) PLUS un choix cross-faction hostile dans la meme carte = double penalite. C'est **voulu** (les consequences comptent).
- Le MOS evite de generer des cartes cross-faction pendant le countdown d'une promesse pour ne pas pieger le joueur involontairement.

#### FastRoute + continuite narrative
- Chaque carte FastRoute est indexee avec des **tags de contexte** (biome, faction, champ lexical, tension).
- Quand une carte FR est utilisee, le code genere un **resume JSON** de cette carte et l'injecte dans le contexte du prochain appel LLM comme "evenement precedent".
- Les cartes FR ont des variantes par **tier de confiance** (T0/T1/T2/T3). Le code selectionne la variante appropriee.

#### Ogham Huath + Nuin (double activation)
- L'ordre est : **premier active = premier resolu**.
- Si Huath (regenere 3 options) est active d'abord → les 3 options sont nouvelles → Nuin n'a plus d'effet utile (les 3 sont deja "neuves").
- Si Nuin (remplace la pire) est active d'abord → 1 option est remplacee → Huath regenere les 3 → le remplacement de Nuin est ecrase.
- **Regle** : un seul Ogham peut etre active par carte. Le bouton Ogham se desactive apres usage.

#### Multiplicateur + bonus cumulatifs
- Tous les bonus de score sont **additifs** entre eux, puis appliques comme multiplicateur unique.
- Exemple : affinite biome (+10%) + talent tree (+5%) + buff 3D (+5%) = +20% → score final = score_brut x 1.20
- **Cap global** : x2.0. Au-dela, le score est plafonne.

#### Fin de run + marchand visible
- Le MOS ne declenche PAS la convergence narrative pendant une interaction marchand.
- Si le joueur est en ecran marchand, la convergence attend la carte suivante.
- En revanche, les evenements 3D (monnaie au sol, plantes) ne bloquent pas la convergence — le fondu peut couper une collecte en cours.

### 13.2 Edge cases — resolutions

#### E1. Vie = 0 pendant un minigame
Le minigame se termine toujours (le joueur joue jusqu'au bout). Ensuite, TOUS les effets de la carte sont appliques (y compris les soins eventuels). La verification vie = 0 se fait **apres** l'application complete des effets. Si la vie est toujours a 0 apres les soins, la fin de run se declenche.

#### E2. Formule mort — cap a 100%
```
Anam final = Anam calcule x min(cartes_jouees / 30, 1.0)
```
Le ratio est **plafonne a 1.0** (100%). Jouer plus de 30 cartes ne donne pas plus que le maximum. La formule recompense la survie, pas la longueur.

#### E3. Promesse expire pendant une carte Merlin Direct
Si une promesse expire pile pendant une carte Merlin Direct :
- Le MOS **insere une carte de resolution de promesse** comme prochaine carte (type "Promesse", avec minigame).
- La carte Merlin Direct se deroule normalement (effets a 100%).
- A la carte suivante, le joueur doit tenir ou briser la promesse.

#### E4. 0 Ogham equipable
Impossible en conditions normales (3 starters gratuits des le depart). En cas de bug/corruption de profil, le systeme **force beith** comme Ogham par defaut. Un profil sans les 3 starters = profil corrompu → reset automatique des starters.

#### E5. Faction a 80 + choix hostile
La verification du seuil de fin se fait **en fin de run** (pas en temps reel). Si le joueur est a 80 et fait un choix hostile (-5 rep → 75), la fin de faction n'est **plus disponible** pour ce run. Il devra remonter a 80 dans un run futur (la rep ne decay pas, donc c'est faisable).

#### E6. Ogham deja possede trouve en run
Le joueur gagne **+5 Anam** a la place (bonus de familiarite). Le message affiche : "Cet Ogham vous est deja familier. Vous percevez son essence. (+5 Anam)".

#### E7. Max 2 promesses actives + 3eme proposee
Le MOS a un **guardrail** : il ne genere PAS de carte de type "Promesse" tant que 2 promesses sont actives. Si une carte FastRoute avec tag `promise` est selectionnee, le code **degrade** le type en "narrative" (les effets restent, mais sans countdown ni engagement).

#### E8. Fondu enchaine + inputs
Les inputs joueur sont **desactives** pendant toute la duree du fondu (1-2 secondes). Pas de clic possible sur la monnaie au sol ou les evenements 3D. Le fondu est un moment de transition, pas de gameplay.

#### E9. Muin (inverse effets) + echec critique
Oui : Muin inverse positifs et negatifs. Sur un echec critique (negatifs x1.5), ils deviennent **positifs x1.5**. C'est le risque/recompense de Muin — l'Ogham est puissant en cas d'echec mais dangereux en cas de succes. Avec un cooldown de 7 et une activation avant le choix, le joueur prend un pari.

#### E10. Changement de tier confiance mid-run
Le tier de confiance est recalcule **a chaque carte**. Si la confiance passe de 74 a 76 (T2 → T3) mid-run, Merlin change immediatement de comportement pour les cartes suivantes. Pas de transition graduelle — le tier est binaire.

#### E11. Abandon vs Mort (recompenses)
| Scenario | Formule Anam | Bonus victoire |
|----------|:---:|:---:|
| Victoire (fin narrative) | 100% | +15 |
| Mort (vie = 0) | cartes/30 (cap 100%) | 0 |
| Abandon (menu pause) | cartes/30 (cap 100%) | 0 |

L'abandon et la mort donnent les memes recompenses. Le joueur n'est pas penalise pour abandonner (c'est un choix narratif en soi).

#### E12. Ogham narratif + LLM timeout
Si Nuin/Huath/Ioho est active et necessite un appel LLM pour generer de nouvelles options/carte :
- Si le LLM repond dans les 3 secondes → options generees normalement
- Si timeout → le code utilise une **carte FastRoute** correspondant au contexte actuel
- Le joueur ne percoit pas de difference (les deux sources produisent des options valides)

#### E13. Mort au drain initial (vie = 1, drain -1)
Si la vie est a 1 au debut d'une carte, le drain -1 met la vie a 0. La carte s'affiche quand meme (le joueur choisit et joue le minigame). Les effets sont appliques. Si un soin ramene la vie > 0, le run continue. Sinon, fin de run.

#### E14. Score minigame = 0 exactement
Score 0 = echec critique (tranche 0-20). Effets negatifs x1.5. C'est le pire resultat possible mais reste jouable.

#### E15. Confiance Merlin a 100 (max)
A confiance 100, Merlin est T3 maximum. Les gains supplementaires (+10 promesse tenue) sont ignores (cap a 100). Le joueur ne peut pas "gaspiller" de confiance.

### 13.3 Ordre d'application des effets (pipeline)

```
1. DRAIN VIE : -1 PV (debut de carte)
2. AFFICHAGE CARTE : texte + 3 options
3. ACTIVATION OGHAM (optionnel) : le joueur clique sur l'Ogham actif
4. CHOIX OPTION : le joueur choisit 1 des 3 options
5. MINIGAME : le joueur joue le minigame (sauf Merlin Direct)
6. SCORE : 0-100, multiplicateur calcule
7. APPLICATION EFFETS : les effets de l'option choisie, multiplies par le score
8. OGHAM POST-EFFECT : les Oghams de protection (luis, gort, eadhadh) filtrent les effets negatifs APRES le calcul
9. VERIFICATION VIE : si vie = 0, fin de run
10. VERIFICATION PROMESSES : countdown -1, si expire → carte de resolution inseree comme prochaine
11. COOLDOWN : -1 sur l'Ogham actif
12. RETOUR 3D : fondu, marche reprend
```

> Ce pipeline est la **reference absolue** pour le code. Toute implementation doit suivre cet ordre exact.

### 13.4 Structure de donnees — Profil joueur

```json
{
  "version": "1.0.0",
  "meta": {
    "anam": 0,
    "faction_rep": {
      "druides": 0.0, "anciens": 0.0, "korrigans": 0.0,
      "niamh": 0.0, "ankou": 0.0
    },
    "trust_merlin": 0,
    "oghams_unlocked": ["beith", "luis", "quert"],
    "oghams_equipped": "beith",
    "talent_tree": { "unlocked": [] },
    "total_runs": 0,
    "endings_seen": [],
    "biomes_unlocked": ["foret_broceliande"],
    "tutorial_flags": {},
    "arc_tags": [],
    "biome_runs": {
      "foret_broceliande": 0, "landes_bruyere": 0, "cotes_sauvages": 0,
      "villages_celtes": 0, "cercles_pierres": 0, "marais_korrigans": 0,
      "collines_dolmens": 0, "iles_mystiques": 0
    },
    "ogham_discounts": {},
    "stats": {
      "total_play_time_seconds": 0,
      "total_minigames_played": 0,
      "total_cards_played": 0,
      "total_deaths": 0,
      "oghams_discovered_in_run": []
    }
  },
  "run_state": null
}
```

`run_state` est `null` si pas de run en cours. Si un run est interrompu :
```json
{
  "run_state": {
    "biome": "foret_broceliande",
    "card_index": 12,
    "life": 67,
    "biome_currency": 14,
    "oghams_active": "beith",
    "oghams_found": ["duir"],
    "cooldowns": {"beith": 0, "duir": 3},
    "tags": ["rencontre_gwenn", "chene_trouve"],
    "promises": [
      {"id": "promesse_druides", "countdown": 4, "faction": "druides"}
    ],
    "narrative_summary": "Le joueur a aide Gwenn a trouver des herbes...",
    "faction_rep_delta": {"druides": 12.0},
    "cards_played": 12,
    "minigames_won": 8,
    "oghams_used": 3,
    "buffs": []
  }
}
```

### 13.5 Formules de calcul — reference

| Formule | Expression | Notes |
|---------|-----------|-------|
| **Anam fin de run** | `base(10) + victoire(15) + minigames(n×2) + oghams(n×1) + factions(n×5) + collecte` | Victoire = 0 si mort/abandon |
| **Anam mort/abandon** | `anam_calcule × min(cartes/30, 1.0)` | Cap a 100% |
| **Score maturite** | `runs×2 + fins×5 + oghams×3 + max_rep×1` | Poids ajustables playtest |
| **Multiplicateur minigame** | `table(score)` : 0-20=neg×1.5, 21-50=neg×1.0, 51-79=pos×0.5, 80-100=pos×1.0, 95-100=pos×1.5 | |
| **Bonus score cumule** | `min(1 + sum(bonus%), 2.0)` | Additifs, cap x2.0 |
| **Drain vie** | `-1 par carte` (modifiable par talents : drain_reduction) | |
| **Confiance Merlin** | `clamp(confiance + delta, 0, 100)` | Promesse tenue +10, brisee -15, choix +/-3-5 |
| **Discount Ogham post-run** | `cout_normal × 0.5` | Si decouvert en run, arrondi inferieur |

---

## 14. Ecarts code vs design (inventaire)

> Liste des systemes presents dans le code qui ne correspondent plus a ce design. A nettoyer.

| Systeme dans le code | Fichiers | Action |
|---------------------|----------|--------|
| 4 Gauges (ADD_GAUGE, REMOVE_GAUGE, SET_GAUGE) | merlin_store.gd, merlin_effect_engine.gd, merlin_card_system.gd | Supprimer, remplacer par HEAL_LIFE/DAMAGE_LIFE |
| Bestiole (bond, needs, skills, awen) | merlin_constants.gd (BOND_TIERS, OGHAM_STARTER_SKILLS), merlin_store.gd | Supprimer entierement |
| aspect_bias (Corps/Ame/Monde) dans biomes | merlin_biome_system.gd | Remplacer par faction_bias |
| D20 / DC system | merlin_constants.gd (DC_BASE, DC_DIFFICULTY_LABELS, ARCHETYPE_DC_BONUS) | Remplacer par minigame difficulty |
| Souffle refs | merlin_constants.gd (REWARD_TYPES), merlin_effect_engine.gd | Supprimer |
| TRIADE_LLM_PARAMS, TRIADE_GRAMMAR_PATH | merlin_llm_adapter.gd | Renommer |
| Flux system (terre/esprit/lien) | merlin_constants.gd (FLUX_*) | **SUPPRIMER** entierement |
| Run Typologies (5 types) | merlin_constants.gd (RUN_TYPOLOGIES) | **SUPPRIMER** entierement |
| ~~Awen references~~ | ~~merlin_constants.gd~~ | ✅ Nettoye (awen_cost supprime) |
| ~~bond_required dans Oghams~~ | ~~merlin_constants.gd~~ | ✅ Nettoye (bond_required supprime) |
| left/center/right options | merlin_constants.gd (CardOption enum, FLUX_CHOICE_DELTA) | Remplacer par 3 options fixes (toujours 3) |
| 3 slots save → profils | merlin_save_system.gd | Refactorer en systeme de profils |
| ~~Champs lexicaux manquants~~ | ~~minigame_registry.gd~~ | ✅ Ajoute : vigueur (3), esprit (3), perception (3) — 9 minigames |
| ~~TALENT_NODES (Corps/Ame/Monde)~~ | ~~merlin_constants.gd~~ | ✅ Redesign 34 noeuds, 5 branches factions + central, Anam-only |
| ~~3 slots save → profils~~ | ~~merlin_save_system.gd~~ | ✅ Profil unique + auto-continue (Hades-style) |
| ~~Souffle refs~~ | ~~merlin_game_controller.gd~~ | ✅ Nettoye (souffle shield, souffle bonus, souffle signal) |
| ~~Triade aspects refs~~ | ~~merlin_game_controller.gd~~ | ✅ Nettoye (tutorial triggers, dialogue context) |
| ~~Gauges in card_system~~ | ~~merlin_card_system.gd~~ | ✅ Nettoye (get_next_triade_card, gauges state) |

---

*Ce document est la source de verite unique pour le game design de M.E.R.L.I.N. v2.4.*
*Toute divergence entre ce document et le code doit etre resolue en faveur de ce document.*
*Co-ecrit entre l'utilisateur (vision) et Claude Code (structuration).*
