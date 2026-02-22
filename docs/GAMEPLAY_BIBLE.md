# GAMEPLAY BIBLE â€” M.E.R.L.I.N.: Le Jeu des Oghams

> **Version:** 1.0.0 â€” Phase 42 Audit
> **Date:** 2026-02-11
> **Statut:** Reference absolue pour tout developpement futur
> **Auteur:** Audit automatise (Claude Code) sur la base de 41 phases d'implementation

---

## Table des Matieres

1. [Vue d'Ensemble â€” La Boucle Principale](#1-vue-densemble)
2. [Systeme TRIADE â€” Coeur du Gameplay](#2-systeme-triade)
3. [Systeme de Cartes](#3-systeme-de-cartes)
4. [Systeme D20 et Mini-Jeux](#4-systeme-d20-et-mini-jeux)
5. [Scenes et Menus â€” Flux Complet](#5-scenes-et-menus)
6. [Meta-Progression](#6-meta-progression)
7. [IA et LLM](#7-ia-et-llm)
8. [Relations Inter-Systemes](#8-relations-inter-systemes)
9. [Audit de Coherence](#9-audit-de-coherence)
10. [Recommandations Priorisees](#10-recommandations)

---

# 1. VUE D'ENSEMBLE

## 1.1 Pitch

M.E.R.L.I.N. est un **jeu de cartes narratif roguelite** ou le joueur explore la Bretagne celtique
en equilibrant 3 Aspects (Corps, Ame, Monde). Chaque carte offre 3 choix. Un LLM local (Qwen 2.5-3B-Instruct)
genere le contenu narratif en temps reel. Merlin est le narrateur et guide.

**Boucle fondamentale :** Choisir â†’ Risquer (D20/Mini-jeu) â†’ Subir les effets â†’ Survivre ou triompher.

## 1.2 Boucle de Gameplay Principale

```
MENU PRINCIPAL
  |
  +---> [Nouvelle Partie]
  |       |
  |       v
  |     QUIZ PERSONNALITE (4 questions â†’ archetype)
  |       |
  |       v
  |     RENCONTRE MERLIN (7 phases : contexte, bestiole, mission, biome)
  |       |
  |       v
  +---> [Continuer] ---> SELECTION SAUVEGARDE (3 slots)
  |       |                    |
  |       v                    v
  |     HUB â€” ANTRE DE MERLIN  <-----------------------------------+
  |       |                                                         |
  |       +---> Carte du Monde (7 biomes)                          |
  |       +---> Arbre de Vie (talents, 28 noeuds)                  |
  |       +---> Collection (compendium)                            |
  |       +---> Sauvegarde                                         |
  |       |                                                         |
  |       +---> [PARTIR EN EXPEDITION]                             |
  |               |                                                 |
  |               v                                                 |
  |             PREPARATION                                        |
  |             (1. Destination  2. Outil  3. Conditions depart)   |
  |               |                                                 |
  |               v                                                 |
  |             TRANSITION BIOME                                   |
  |             (paysage pixel-art, brouillard, narration)         |
  |               |                                                 |
  |               v                                                 |
  |          +--> BOUCLE DE CARTES TRIADE  <----+                  |
  |          |     |                             |                  |
  |          |     v                             |                  |
  |          |   Afficher Carte (typewriter)     |                  |
  |          |     |                             |                  |
  |          |     v                             |                  |
  |          |   3 Options (Gauche/Centre/Droit) |                  |
  |          |     |                             |                  |
  |          |     v                             |                  |
  |          |   D20 ou Mini-jeu (15 types)      |                  |
  |          |     |                             |                  |
  |          |     v                             |                  |
  |          |   Effets appliques sur Aspects    |                  |
  |          |     |                             |                  |
  |          |     v                             |                  |
  |          |   Reaction narrative              |                  |
  |          |     |                             |                  |
  |          |     v                             |                  |
  |          |   Verif fin de run                |                  |
  |          |     |                             |                  |
  |          |     +--[Continuer]----------------+                  |
  |          |     |                                                |
  |          |     +--[CHUTE] (2 aspects extremes) -----> Hub      |
  |          |     |                                                |
  |          |     +--[VICTOIRE] (mission + equilibre) --> Hub -----+
  |          |
  |          +--- 25-35 cartes par run (~8-10 min)
  |
  +---> [Options]
  +---> [Quitter]
```

## 1.3 Parametres de Session

| Parametre | Valeur | Source |
|-----------|--------|--------|
| Cartes par run (cible) | **30** (min 25, max 35) | `merlin_constants.gd:286` |
| Temps moyen par carte | **18 secondes** | `merlin_constants.gd:287` |
| Duree totale estimee | **8-10 minutes** par run | Calcul : 30 x 18s |
| Revelation mission | Carte **4** | `merlin_constants.gd:288` |
| Zone de climax | Cartes **20-25** | `merlin_constants.gd:289` |

---

# 2. SYSTEME TRIADE

## 2.1 Les 3 Aspects

Le joueur gere 3 Aspects, chacun avec **3 etats discrets** (pas de jauge continue).

| Aspect | Animal | Symbole | BAS (-1) | EQUILIBRE (0) | HAUT (+1) |
|--------|--------|---------|----------|----------------|-----------|
| **Corps** | Sanglier | Spirale | Epuise | Robuste | Surmene |
| **Ame** | Corbeau | Triskell | Perdue | Centree | Possedee |
| **Monde** | Cerf | Croix celtique | Exile | Integre | Tyran |

- **Source :** `merlin_constants.gd:121-156`
- **Etat initial :** Tous a EQUILIBRE (0)
- **Transition :** Un aspect se deplace de +-1 par effet (BASâ†’EQUILIBRE ou EQUILIBREâ†’HAUT)
- **Pas de saut :** Le design indique qu'un aspect ne peut PAS sauter un etat (BASâ†’HAUT directement)

> **BUG IDENTIFIE :** Le code `_apply_shift_aspect` dans `merlin_effect_engine.gd:152-153` ne valide PAS cette regle.
> Un effet `SET_ASPECT` peut forcer n'importe quel etat directement.

## 2.2 Souffle d'Ogham

Ressource visible pour l'option Centre.

| Parametre | Valeur | Source |
|-----------|--------|--------|
| Maximum | **7** | `merlin_constants.gd:159` |
| Depart | **3** | `merlin_constants.gd:160` |
| Cout Centre | **1** par utilisation | `merlin_constants.gd:161` |
| Regeneration | **+1** si 3 aspects equilibres apres carte | Store logic |
| Regen avec talent | **+2** (talent `racines_5`) | `merlin_constants.gd:619-621` |

**Risque si Souffle = 0 et choix Centre :**

| Probabilite | Evenement | Source |
|-------------|-----------|--------|
| 50% | Effet normal | `merlin_constants.gd:165` |
| 25% | Aspect aleatoire descend | `merlin_constants.gd:166` |
| 25% | Aspect aleatoire monte | `merlin_constants.gd:167` |

## 2.3 Souffle d'Awen (Bestiole)

Ressource separee pour activer les competences Ogham de la Bestiole.

| Parametre | Valeur | Source |
|-----------|--------|--------|
| Maximum | **5** | `merlin_constants.gd:308` |
| Depart | **2** | `merlin_constants.gd:309` |
| Intervalle regen | **5 cartes** â†’ +1 Awen | `merlin_constants.gd:310` |
| Bonus equilibre | **+1 extra** si 3 aspects equilibres lors de la regen | `merlin_constants.gd:311` |

> **CONFUSION NOMMAGE :** "Souffle d'Ogham" (pour Centre) et "Souffle d'Awen" (pour competences) portent des noms similaires. Risque de confusion joueur.

## 2.4 Ressources Cachees

| Ressource | Plage | Depart | Visible ? | Usage |
|-----------|-------|--------|-----------|-------|
| **Karma** | -10 a +10 | 0 | Non | Modifie probabilite choix critiques, qualite des fins |
| **Tension** | 0 a 100 | 0 | Non | Devrait declencher des Twists narratifs |
| **Flux Terre** | 0 a 100 | 50 | Non | Influence fins + LLM context |
| **Flux Esprit** | 0 a 100 | **30** | Non | Influence narrative intensity |
| **Flux Lien** | 0 a 100 | **40** | Non | Influence difficulte (dc_mod) |

**Source :** `merlin_constants.gd:477`, `merlin_store.gd:201-207`

> **ANOMALIE FLUX :** Les Flux ne demarrent pas a 50/50/50 (Esprit=30, Lien=40). Cette asymetrie n'est pas documentee. Le talent `tronc_1` corrige cela en forcant 50/50/50.

### Flux â€” Impact par Choix

| Choix | Terre | Esprit | Lien |
|-------|-------|--------|------|
| Gauche | +5 | +2 | -3 |
| Centre | +3 | +8 | -2 |
| Droite | -5 | +3 | +8 |

**Source :** `merlin_constants.gd:482-486`

### Flux â€” Modificateurs de DC

Seul le Flux Lien modifie actuellement le DC :

| Tier Lien | Plage | DC Mod | Label |
|-----------|-------|--------|-------|
| Calme | 0-30 | **-2** | Facilite |
| Modere | 31-69 | 0 | Normal |
| Brutal | 70-100 | **+3** | Difficulte accrue |

**Source :** `merlin_constants.gd:507-511`

> **NOTE :** Les Flux Terre et Esprit ont `dc_mod: 0` pour tous les tiers â€” ils n'impactent donc PAS la difficulte.

## 2.5 Conditions de Fin de Run

### 12 Chutes (Defaites)

Declencheur : **2 aspects atteignent un etat extreme** (BAS ou HAUT) simultanement.

| Cle | Titre | Corps | Ame | Monde |
|-----|-------|-------|-----|-------|
| `corps_bas_ame_basse` | La Mort Oubliee | BAS | BAS | - |
| `corps_bas_ame_haute` | Le Sacrifice Vain | BAS | HAUT | - |
| `corps_bas_monde_bas` | L'Abandon Total | BAS | - | BAS |
| `corps_bas_monde_haut` | L'Usurpation | BAS | - | HAUT |
| `corps_haut_ame_basse` | La Bete Sauvage | HAUT | BAS | - |
| `corps_haut_ame_haute` | L'Ascension Folle | HAUT | HAUT | - |
| `corps_haut_monde_bas` | Le Solitaire | HAUT | - | BAS |
| `corps_haut_monde_haut` | Le Conquerant | HAUT | - | HAUT |
| `ame_basse_monde_bas` | L'Errance Eternelle | - | BAS | BAS |
| `ame_basse_monde_haut` | Le Pantin | - | BAS | HAUT |
| `ame_haute_monde_bas` | Le Prophete Exile | - | HAUT | BAS |
| `ame_haute_monde_haut` | La Possession Divine | - | HAUT | HAUT |

**Source :** `merlin_constants.gd:195-258`

> **PROBLEME 3 EXTREMES :** Si les 3 aspects sont extremes simultanement, le systeme detecte la premiere paire trouvee. L'ordre de priorite n'est pas defini.

### 4 Victoires

| Cle | Titre | Condition |
|-----|-------|-----------|
| `harmonie` | L'Harmonie | Mission accomplie + 3 aspects EQUILIBRE |
| `prix_paye` | Le Prix Paye | Mission accomplie + 1 aspect extreme |
| `victoire_amere` | La Victoire Amere | Mission accomplie + karma negatif |
| `tyran_juste` | Le Tyran Juste | Mission accomplie + Monde=HAUT, Corps=EQUILIBRE, Ame=EQUILIBRE |

**Source :** `merlin_constants.gd:262-279`

### Qualite des Fins (Flux)

| Categorie | Condition | Resultat |
|-----------|-----------|----------|
| Harmonie parfaite | Terre+Esprit+Lien >= 225 | Meilleure narration de fin |
| Prix paye | Terre < 30 OU Esprit < 30 | Victoire avec sacrifice |
| Victoire amere | Lien < 30 | Victoire isolee |

---

# 3. SYSTEME DE CARTES

## 3.1 Types de Cartes

| Type | Poids | Description | Frequence |
|------|-------|-------------|-----------|
| **narrative** | 80% | Scenarios generes par LLM, 3 options | ~24/run |
| **event** | 10% | Declencheurs saisonniers/contextuels | ~3/run |
| **promise** | 5% | Pactes avec Merlin (2 phases) | ~1-2/run |
| **merlin_direct** | 5% | Merlin brise le 4e mur | ~1-2/run |

**Source :** `merlin_constants.gd:858-863`

### Contraintes de Distribution

| Parametre | Valeur | Source |
|-----------|--------|--------|
| Min cartes avant event | **3** | `merlin_constants.gd:866` |
| Min cartes avant promise | **5** | `merlin_constants.gd:867` |
| Max promises actives | **2** | `merlin_constants.gd:868` |

## 3.2 Structure d'une Carte

```json
{
  "id": "card_012",
  "text": "La brume se leve sur le sentier...",
  "speaker": "Merlin",
  "type": "narrative",
  "options": [
    {
      "direction": "left",
      "label": "Suivre la lumiere",
      "effects": [
        {"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"}
      ],
      "preview": "Curiosite"
    },
    {
      "direction": "center",
      "label": "Mediter en silence",
      "effects": [
        {"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}
      ],
      "preview": "Patience"
    },
    {
      "direction": "right",
      "label": "Courir vers le bruit",
      "effects": [
        {"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"},
        {"type": "ADD_KARMA", "amount": 2}
      ],
      "preview": "Action"
    }
  ],
  "tags": ["forest", "exploration"]
}
```

## 3.3 Les 3 Options

| Position | Nom | Type | Cout | DC | Philosophie |
|----------|-----|------|------|----|-------------|
| **Gauche** | left | direct | 0 | 6 (facile) | Prudence, consequences claires |
| **Centre** | center | wise | 1 Souffle | 10 (moyen) | Sagesse, souvent neutre |
| **Droite** | right | risky | 0 | 14 (dur) | Audace, consequences extremes |

**Source :** `merlin_constants.gd:173-192`, `triade_game_controller.gd:31-33`

## 3.4 Types d'Effets TRIADE (Whitelist)

9 effets autorises pour le systeme TRIADE actuel :

| Code Effet | Format | Description |
|-----------|--------|-------------|
| `SHIFT_ASPECT` | `SHIFT_ASPECT:Corps:up` | Deplace un aspect de +-1 |
| `SET_ASPECT` | `SET_ASPECT:Monde:0` | Force un aspect a un etat precis |
| `USE_SOUFFLE` | `USE_SOUFFLE:1` | Consomme du Souffle |
| `ADD_SOUFFLE` | `ADD_SOUFFLE:2` | Ajoute du Souffle |
| `PROGRESS_MISSION` | `PROGRESS_MISSION:1` | Avance la mission |
| `ADD_KARMA` | `ADD_KARMA:3` | Modifie le karma cache |
| `ADD_TENSION` | `ADD_TENSION:15` | Modifie la tension narrative cachee |
| `ADD_NARRATIVE_DEBT` | `ADD_NARRATIVE_DEBT:type:desc` | Cree une dette narrative |
| `MODIFY_BOND` | `MODIFY_BOND:5` | Modifie le lien avec la Bestiole |

**Source :** `merlin_effect_engine.gd:11-23`

> **NOTE LEGACY :** L'Effect Engine contient aussi **~55 effets legacy/deprecated** (HP_DELTA, BUFF_STAT, ADD_GAUGE, etc.) qui ne sont PAS utilises par le systeme TRIADE mais restent dans le code.

## 3.5 Pipeline de Generation

```
Demande de carte
       |
       v
[1] Verifier prefetch cache
       |
       +--[HIT] --> Valider + afficher
       |
       +--[MISS]--> [2] MerlinOmniscient (Narrateur + Game Master en parallele)
                          |
                          +--[OK] --> Guardrails â†’ Valider â†’ Afficher
                          |
                          +--[TIMEOUT 15s] --> [3] LLM direct (merlin_ai)
                                                    |
                                                    +--[OK] --> Afficher
                                                    |
                                                    +--[FAIL] --> [4] Carte Fallback Emergency
```

**Cartes fallback emergency :** `triade_game_controller.gd:311-330` â€” une seule carte generique "La brume s'epaissit..." avec 3 options simples (1 par aspect).

---

# 4. SYSTEME D20 ET MINI-JEUX

## 4.1 Systeme D20

Apres chaque choix du joueur, un **test de resolution** determine l'issue.

| Resultat | Condition | Effet |
|----------|-----------|-------|
| **Succes Critique** | Roll >= DC + 5 | Effets x2 positifs |
| **Succes** | Roll >= DC | Effets normaux |
| **Echec** | Roll < DC | Effets reduits/inverses |
| **Echec Critique** | Roll <= DC - 5 | Effets x2 negatifs |

### Modificateurs du D20

| Modificateur | Plage | Source |
|-------------|-------|--------|
| Karma | -10 a +10 | `triade_game_controller.gd:36-37` |
| Benedictions | 0 a 2 max | `triade_game_controller.gd:38` |
| Outil d'expedition | -3 DC (si champ correspond) | `merlin_constants.gd:897-926` |
| Flux Lien | -2 a +3 DC | `merlin_constants.gd:508-511` |
| Talents | Variables | Arbre de Vie |
| Passif biome | Variable | Non implemente |

### Difficulte Adaptive (Pity/Challenge)

| Condition | Effet |
|-----------|-------|
| 3 echecs consecutifs | DC temporairement -4 |
| 3 succes consecutifs | DC temporairement +2 |

**Source :** `merlin_constants.gd (PITY_CAP := 3)`

## 4.2 Mini-Jeux (15 Types)

**Probabilite :** 70% mini-jeu, 30% D20 pur (`triade_game_controller.gd:39`)

Les mini-jeux sont repartis par **champs lexicaux** detectes dans le texte de la carte.

| # | Type | Champ Lexical | Mecanisme |
|---|------|---------------|-----------|
| 1 | Rythme | Musique, danse | Timing au beat |
| 2 | QTE | Combat, urgence | Quick-Time Events |
| 3 | Pattern | Runes, magie | Memorisation de motifs |
| 4 | Viser | Arc, lancer | Precision de visee |
| 5 | Equilibre | Balance, marche | Gyroscope/slider |
| 6 | Memoire | Connaissance | Memory/matching |
| 7 | Reflexe | Piege, surprise | Reaction rapide |
| 8 | Puzzle | Enigme, verrou | Combinaison logique |
| 9 | Survie | Froid, faim | Gestion de timer |
| 10 | Negociation | Marchand, PNJ | Choix rapides |
| 11 | Furtivite | Ombre, eviter | Esquive de patterns |
| 12 | Herboristerie | Plante, potion | Tri/combinaison |
| 13 | Navigation | Chemin, carte | Labyrinthe rapide |
| 14 | Invocation | Rituel, esprit | Sequence precise |
| 15 | Observation | Regard, detail | Spot-the-difference |

Le **score du mini-jeu** est converti en equivalent D20 pour determiner succes/echec.

**Bonus outil :** Si l'outil equipe correspond au `bonus_field` du mini-jeu, le DC est reduit de 3.

---

# 5. SCENES ET MENUS

## 5.1 Menu Principal

**Fichier :** `scripts/MenuPrincipalMerlin.gd`

### Elements UI
- Titre "M  E  R  L  I  N" avec ornements celtiques
- 4 options : Nouvelle Partie / Continuer / Options / Quitter
- Horloge temps reel (noms bretons : jours + mois)
- Effets saisonniers (neige/feuilles/fleurs/rayons)
- Indicateur IA discret (bas-droite) : "IA: 2 cerveaux"
- Bouton Calendrier (bas-gauche), bouton Collections (bas-droite)

### Palette : "Parchemin Mystique Breton"
- Papier : `#F6F0E7` (ivoire ancien)
- Encre : `#382E24` (brun profond)
- Accent : `#947038` (bronze ancien)
- Shader : `merlin_paper.gdshader` (grain + vignette)

### Transitions
- **Nouvelle Partie** â†’ `IntroPersonalityQuiz.tscn` + lancement LLM warmup
- **Continuer** â†’ `SelectionSauvegarde.tscn`
- **Options** â†’ `MenuOptions.tscn`
- **Quitter** â†’ `get_tree().quit()`

## 5.2 Quiz de Personnalite

**Scene :** `scenes/IntroPersonalityQuiz.tscn`

4 questions determinent l'archetype du joueur :

| # | Question | Reponses |
|---|----------|----------|
| 1 | Element favori | Feu / Eau / Terre / Air |
| 2 | Style de decision | Instinct / Logique / Coeur / Tradition |
| 3 | Resolution de conflit | Combattre / Negocier / Fuir / Observer |
| 4 | Relation a la nature | Dominer / Harmoniser / Observer / Craindre |

### Archetypes resultants

| Archetype | Biome suggere | Profil |
|-----------|---------------|--------|
| **Druide** | `cercles_pierres` | Spirituel, equilibre |
| **Guerrier** | `villages_celtes` | Force, confrontation |
| **Barde** | `cotes_sauvages` | Creativite, emotion |
| **Eclaireur** | `foret_broceliande` | Exploration, prudence |

**Stocke :** `GameManager.player_class`
**Transite vers :** `SceneRencontreMerlin.tscn`

## 5.3 Rencontre Merlin (Onboarding)

**Fichier :** `scripts/SceneRencontreMerlin.gd`

Machine a etats en **7 phases** fusionnant l'ancien SceneEveil + SceneAntreMerlin :

### Phase 1 : INTRO_CONTEXT
- Merlin presente le monde et le systeme Triade
- Texte LLM (ou fallback script) avec typewriter + blips
- Portrait pixel Merlin (cascade de pixels)
- 3 choix interactifs de reponse
- Badge source (LLM / Fallback / Static)

### Phase 2 : BESTIOLE_REVEAL
- Animation d'apparition de la Bestiole
- Revelation des 3 Oghams de depart :
  - **Beith** (Bouleau) â€” Revelation : revele 1 option
  - **Luis** (Sorbier) â€” Protection : empeche 1 shift negatif
  - **Quert** (Pommier) â€” Guerison : ramene l'aspect le plus extreme vers Equilibre
- Panneau Ogham avec glyphes celtiques

### Phase 3 : MISSION_BRIEFING
- Explication de la mission (7 sanctuaires, equilibrer les 3 aspects)
- Tour du Hub (Carte, Inventaire, Sauvegardes)
- Texte LLM ou fallback

### Phase 4 : BIOME_SELECTION
- Portrait cache, carte reduite en haut
- 7 boutons biomes affiches
- Biome suggere pulse (correspond a l'archetype)
- Le joueur clique â†’ `selected_biome` stocke

**Donnees stockees :** `eveil_seen = true`, `selected_biome`, Oghams initiaux
**Transite vers :** `HubAntre.tscn`

## 5.4 Hub â€” Antre de Merlin

**Fichier :** `scripts/HubAntre.gd`
**Flow canonique onboarding/pre-run :** `docs/30_scenes/CANONICAL_ONBOARDING_FLOW.md`

Centre nevralgique entre les runs. Le joueur prepare son expedition.

### Pages/Onglets
1. **Antre** - Vue principale, preparation expedition
2. **Compagnons** - Bestiole, Oghams equipes, bond level

### Actions laterales (pas des tabs)
- **Collection** - ecran satellite
- **Arbre de Vie** - overlay dedie
- **Calendrier**, **Sauvegarde**, **Options**, **Menu**

### Systeme d'Expedition (3 etapes)

**Etape 1 : Destination** â€” Choix du biome via la carte

**Etape 2 : Outil** â€” 4 outils disponibles :

| Outil | Bonus | Effet Initial |
|-------|-------|---------------|
| Baton de Marche | Combat DC -3 | Aucun |
| Besace du Druide | â€” | +1 Souffle au depart |
| Lanterne d'Ogham | Exploration DC -3 | Aucun |
| Talisman Ancien | Mysticisme DC -3 | Aucun |

**Etape 3 : Conditions de depart** â€” 4 conditions :

| Condition | Effet |
|-----------|-------|
| Partir de jour | Normal |
| Partir de nuit | +3 Karma, DCs +2 |
| Avec compagnon | Monde shift UP |
| Voyager leger | -2 cartes mission |

**Source :** `merlin_constants.gd:890-958`

Mode assiste de condition:
- **ON**: condition auto (jour/nuit), visible et explicite
- **OFF**: choix manuel obligatoire de la condition

Le bouton "Partir" est grise tant que les 3 etapes ne sont pas completees.

**Condition d'entree :** `eveil_seen = true`
**Transite vers :** `TransitionBiome.tscn`

## 5.5 Transition Biome

**Fichier :** `scripts/TransitionBiome.gd`

Animation en **6 phases** introduisant le biome choisi :

| Phase | Nom | Description | Duree |
|-------|-----|-------------|-------|
| 1 | BRUME | Pixels scouts dans la brume | ~2s |
| 2 | EMERGENCE | Cascade de pixels assemblant le paysage 32x16 | ~3s |
| 3 | REVELATION | Nom du biome + sous-titre fade-in, zoom 1.0â†’1.4x | ~2s |
| 4 | SENTIER | Ligne d'encre trace le chemin + marqueurs | ~2s |
| 5 | VOIX | Texte LLM d'arrivee + commentaire Merlin | Variable |
| 6 | DISSOLUTION | Pixels tombent avec gravite, transition | ~1.5s |

### 7 Biomes et leurs Paysages Proceduraux

| Cle | Nom | Paysage |
|-----|-----|---------|
| `foret_broceliande` | Foret de Broceliande | Coniferes denses + mousse |
| `landes_bruyere` | Landes de Bruyere | Bruyere + menhir solitaire |
| `cotes_sauvages` | Cotes Sauvages | Falaises + vagues |
| `villages_celtes` | Villages Celtes | 2 huttes rondes + fumee |
| `cercles_pierres` | Cercles de Pierres | Cercle megalithique sous les etoiles |
| `marais_korrigans` | Marais des Korrigans | Marecage sombre + arbres tordus |
| `collines_dolmens` | Collines des Dolmens | Dolmen sur collines vertes |

**Brouillard volumetrique :** 3 couches GPU particles + shader Perlin, tinte par biome.

**LLM :** Texte d'arrivee genere par LLM (ou fallback JSON avec 140 variantes : 7 biomes x 4 categories x 5 textes).

**Source donnees :** `data/post_intro_dialogues.json`
**Transite vers :** `MerlinGame.tscn`

## 5.6 Triade Game (Gameplay Principal)

**Fichiers :** `scripts/ui/triade_game_controller.gd`, `scripts/ui/triade_game_ui.gd`

### Layout UI (haut en bas)

```
+--------------------------------------------------+
| [Sanglier] Corps  [Corbeau] Ame  [Cerf] Monde   |  <- 3 aspects + etats
| [o o o . . . .]  Souffle d'Ogham                 |  <- 7 spirales
| Biome: Foret de Broceliande                       |
+--------------------------------------------------+
| Outil: Baton | Jour 3 | Mission: 2/5             |  <- Barre ressources
+--------------------------------------------------+
|                                                    |
|    +--------------------------------------+        |
|    |  [Portrait Pixel]                     |        |
|    |                                       |        |  <- Carte parcheminee
|    |  "La brume se leve sur le sentier     |        |     460x360px
|    |   et trois chemins s'offrent a toi..."  |      |     avec ombres empilees
|    |                                       |        |
|    |  [LLM] badge source                   |        |
|    +--------------------------------------+        |
|                                                    |
|  [Gauche: DC6]  [Centre: DC10]  [Droite: DC14]  |  <- 3 boutons options
|                                                    |
|  Tooltip: "Corps â†‘ (Robuste â†’ Surmene)"         |  <- Preview au hover
|                                                    |
|  Mission: Sanctuaire 2/5    Cartes: 12/30         |
|                                                    |
|                          [Roue Bestiole]           |  <- Competences Ogham
+--------------------------------------------------+
```

### Flux de Resolution d'un Choix

```
1. Joueur choisit LEFT / CENTER / RIGHT
   |
   +--[CENTER] --> Verifier Souffle (>0 ? consommer : risque vide)
   |
   v
2. Detecter choix critique (tags carte)
   |
   v
3. Mini-jeu (70%) ou D20 (30%)
   |
   v
4. Resultat: CRIT_SUCCESS / SUCCESS / FAILURE / CRIT_FAILURE
   |
   v
5. Moduler les effets par le resultat
   +--[CRIT_SUCCESS] --> Effets positifs x2
   +--[SUCCESS] -------> Effets normaux
   +--[FAILURE] -------> Effets reduits ou inverses
   +--[CRIT_FAILURE] --> Effets negatifs x2
   |
   v
6. Appliquer talents (boucliers, annulations, bonus)
   |
   v
7. Appliquer benedictions (si disponibles)
   |
   v
8. Store.dispatch("TRIADE_RESOLVE_CHOICE")
   +---> Effets appliques aux aspects
   +---> Verification fin de run (2 extremes ? mission complete ?)
   |
   v
9. Reaction narrative (4 pools x 4 messages)
   |
   v
10. Animation resultat carte (shake/glow/fade)
    |
    v
11. Animation voyage + texte saveur
    |
    v
12. Ecriture contexte RAG (derniers 5 evenements)
    |
    v
13. Prefetch prochaine carte --> BOUCLE
```

## 5.7 Carte du Monde

**Fichier :** `scripts/ui/map_ui.gd`

Carte geographique interactive des 7 biomes bretons.

### Systeme de Deverrouillage
- **Par defaut :** Seul `foret_broceliande` est deverrouille
- **Deverrouillage :** Via meta-progression (victoires, quetes)
- **Marqueurs :** Boutons positionnes avec symboles celtiques
- **Effet glow :** Biomes deverrouilles pulsent en couleur
- **Biomes verrouilles :** Gris, non-cliquables

### Signaux
- `node_selected(biome_key)` â†’ Stocke la selection, ouvre TransitionBiome
- `close_requested` â†’ Retour au Hub

## 5.8 Resume des Transitions

```
MenuPrincipal
  +---> IntroPersonalityQuiz ---> SceneRencontreMerlin ---> HubAntre
  +---> SelectionSauvegarde ---> HubAntre
  +---> Calendar (temporaire, retour MenuPrincipal)
  +---> Collection (temporaire, retour MenuPrincipal)

HubAntre
  +---> MapMonde (selection biome)
  +---> ArbreDeVie (meta-progression) [BACKEND SEUL]
  +---> Collection (compendium)
  +---> SelectionSauvegarde (save/load)
  +---> [Partir] ---> TransitionBiome ---> MerlinGame
                                             +---> [Fin] ---> HubAntre
```

### Exigences de Donnees par Scene

| Scene | Condition d'Entree | Donnees Requises | Donnees Stockees |
|-------|-------------------|------------------|------------------|
| MenuPrincipal | Demarrage app | Aucune | Aucune |
| IntroPersonalityQuiz | Premier lancement | Aucune | `player_class` |
| SceneRencontreMerlin | Apres quiz | `player_class` | `eveil_seen`, oghams, biome |
| HubAntre | Apres Rencontre / Continuer | `eveil_seen=true` | run config |
| TransitionBiome | Apres selection biome | `run.current_biome` | Aucune |
| MerlinGame | Apres transition | Biome + aspects + souffle | Tout l'etat gameplay |
| MapMonde | Depuis HubAntre | Etat deverrouillage | `selected_biome` |

---

# 6. META-PROGRESSION

## 6.1 Arbre de Vie (28 Talents)

**Source :** `merlin_constants.gd:576-833`

### Structure

4 branches, 4 tiers (Germe â†’ Pousse â†’ Branche â†’ Cime) :

| Branche | Aspect | Animal | Noeuds | Theme |
|---------|--------|--------|--------|-------|
| **Racines** | Corps | Sanglier | 8 | Souffle, endurance, survie |
| **Ramures** | Ame | Corbeau | 8 | Revelation, Awen, prevision |
| **Feuillage** | Monde | Cerf | 8 | Diplomatie, DC, adaptation |
| **Tronc** | Universel | â€” | 4 | Flux, equilibre, New Game+ |

### Talents Notables

| ID | Nom | Tier | Effet |
|----|-----|------|-------|
| `racines_1` | Souffle Fortifie | 1 | +1 Souffle au depart |
| `racines_5` | Racines Profondes | 2 | Regen Souffle x2 si equilibre |
| `racines_7` | Os de la Terre | 3 | Survit a 1 game over/run |
| `racines_8` | Sanglier Ancestral | 4 | Corps HAUT = positif |
| `ramures_2` | Flamme Spirituelle | 1 | +1 Awen au depart |
| `ramures_4` | Maitrise d'Awen | 2 | Regen Awen toutes les 4 cartes |
| `ramures_8` | Fusion Ame-Bestiole | 4 | Bond demarre a 60 |
| `feuillage_2` | Flux Harmonieux | 1 | 1 Centre gratuit/run |
| `feuillage_8` | Roi sans Couronne | 4 | Debloque fin "Tyran Juste" |
| `tronc_1` | Equilibre des Feux | 2 | Flux demarre a 50/50/50 |
| `tronc_2` | Voile Perce | 3 | Voir Karma + Flux (indices) |
| `tronc_4` | Boucle Eternelle | 4 | New Game+ : essences x1.5 |

### Couts (exemples)

| Tier | Cout typique | Prerequis |
|------|-------------|-----------|
| 1 (Germe) | 15-20 essences + 1 fragment | Aucun |
| 2 (Pousse) | 40-50 essences + 3 fragments | 2 noeuds tier 1 |
| 3 (Branche) | 60-80 essences + 5-6 fragments | 1 noeud tier 2 |
| 4 (Cime) | 120-150 essences + 10-20 fragments | 2 noeuds tier 3 |

> **PROBLEME CRITIQUE :** L'Arbre de Vie a son **backend complet** (structures, couts, prerequis, effets) mais **AUCUNE UI** n'existe. Le joueur ne peut PAS debloquer de talents. Toutes les essences collectees sont inutilisables.

## 6.2 Bestiole (18 Oghams)

La Bestiole est un compagnon permanent qui fournit des competences passives/actives.

### Bond (Lien)

| Tier | Plage | Skills Actifs | Modificateur |
|------|-------|---------------|-------------|
| Distant | 0-30 | 0 | +0% |
| Friendly | 31-50 | 1 | +5% |
| Close | 51-70 | 2 | +10% |
| Bonded | 71-90 | 3 | +15% |
| Soulmate | 91-100 | Tous | +20% |

**Retention inter-runs :** 40% du bond conserve (`merlin_constants.gd:569`)

### Les 18 Oghams â€” Catalogue Complet

#### Revelation (3)
| Ogham | Arbre | Cout Awen | Cooldown | Bond Requis | Effet |
|-------|-------|-----------|----------|-------------|-------|
| **Beith** | Bouleau | 1 | 3 | 0 (starter) | Revele l'effet d'1 option |
| **Coll** | Noisetier | 2 | 5 | 21 | Revele tous les effets |
| **Ailm** | Sapin | 2 | 4 | 41 | Predit le theme prochain |

#### Protection (3)
| Ogham | Arbre | Cout Awen | Cooldown | Bond Requis | Effet |
|-------|-------|-----------|----------|-------------|-------|
| **Luis** | Sorbier | 1 | 4 | 0 (starter) | Empeche 1 shift negatif |
| **Gort** | Lierre | 2 | 6 | 41 | Ramene extreme â†’ equilibre |
| **Eadhadh** | Tremble | 3 | 8 | 61 | Annule tous effets negatifs |

#### Force (3)
| Ogham | Arbre | Cout Awen | Cooldown | Bond Requis | Effet |
|-------|-------|-----------|----------|-------------|-------|
| **Duir** | Chene | 2 | 4 | 21 | Force 1 aspect â†’ Equilibre |
| **Tinne** | Houx | 2 | 5 | 41 | Double effets positifs prochaine carte |
| **Onn** | Ajonc | 3 | 7 | 61 | +2 Souffle d'Ogham |

#### Recit (3)
| Ogham | Arbre | Cout Awen | Cooldown | Bond Requis | Effet |
|-------|-------|-----------|----------|-------------|-------|
| **Nuin** | Frene | 2 | 6 | 41 | Ajoute 4e option a la carte |
| **Huath** | Aubepine | 2 | 5 | 21 | Remplace la carte actuelle |
| **Straif** | Prunellier | 3 | 10 | 81 | Force un retournement |

#### Guerison (3)
| Ogham | Arbre | Cout Awen | Cooldown | Bond Requis | Effet |
|-------|-------|-----------|----------|-------------|-------|
| **Quert** | Pommier | 1 | 4 | 0 (starter) | Ramene aspect extreme â†’ Equilibre |
| **Ruis** | Sureau | 3 | 8 | 61 | Ramene TOUS les aspects â†’ Equilibre |
| **Saille** | Saule | 2 | 6 | 41 | Regenere 2 Awen |

#### Secret (3)
| Ogham | Arbre | Cout Awen | Cooldown | Bond Requis | Effet |
|-------|-------|-----------|----------|-------------|-------|
| **Muin** | Vigne | 2 | 7 | 41 | Inverse positif/negatif de la carte |
| **Ioho** | If | 3 | 12 | 81 | Regenere carte completement nouvelle |
| **Ur** | Bruyere | 3 | 10 | 61 | Sacrifie 1 extreme pour booster 2 autres |

### Evolution Bestiole

3 stades, 3 voies :

| Stade | Nom | Bond Base | Awen Bonus | Runs Requis | Cout |
|-------|-----|-----------|-----------|-------------|------|
| 1 | Enfant | 10 | 0 | 0 | â€” |
| 2 | Compagnon | 30 | +1 | 15 | â€” |
| 3 | Gardien | 50 | +2 | 40 | 200 BETE |

| Voie | Nom | Aspect | Runs Focalises | Cout | Bonus |
|------|-----|--------|----------------|------|-------|
| A | Protecteur | Corps | 25 | 150 BETE + 80 TERRE | -15% effets negatifs |
| B | Oracle | Ame | 25 | 150 BETE + 80 ESPRIT | Preview 1 carte |
| C | Diplomate | Monde | 25 | 150 BETE + 80 EAU | +5 Liens |

> **ETAT :** Backend implemente (`merlin_constants.gd:557-567`, `merlin_store.gd:246-249`). **Evolution trigger logic et UI manquants.**

## 6.3 Essences (14 Types)

Collectees en fin de run, utilisees pour l'Arbre de Vie.

| Categorie | Essences |
|-----------|----------|
| Elements | NATURE, FEU, EAU, TERRE, AIR |
| Mystiques | FOUDRE, GLACE, POISON, METAL |
| Abstraits | BETE, ESPRIT, OMBRE, LUMIERE, ARCANE |

### Recompenses de Fin de Run

| Condition | Recompense |
|-----------|-----------|
| Toujours | TERRE 5, NATURE 3 |
| Victoire | LUMIERE 8, FOUDRE 5 |
| Chute | OMBRE 5, GLACE 3 |
| 3 aspects equilibres | LUMIERE 10 |
| Bond > 70 | BETE 5, NATURE 3 |
| 5+ mini-jeux gagnes | AIR 4 |
| 3+ Oghams utilises | ARCANE 5 |
| Flux Terre >= 70 | NATURE 5, EAU 3 |
| Flux Esprit >= 70 | ESPRIT 8, ARCANE 5 |
| Flux Lien >= 70 | FEU 5, FOUDRE 3 |

**Source :** `merlin_constants.gd:544-551`

## 6.4 Fins Vues et Progression

| Donnee Meta | Description |
|-------------|-------------|
| `total_runs` | Nombre total de runs |
| `total_cards_played` | Cartes jouees au total |
| `endings_seen` | Liste des fins rencontrees |
| `gloire_points` | Points de gloire accumules |
| `talent_tree.unlocked` | Talents debloques |
| `bestiole_evolution.stage` | Stade evolution (1-3) |
| `bestiole_evolution.path` | Voie choisie |

---

# 7. IA ET LLM

## 7.1 Architecture Multi-Brain

**Fichier :** `addons/merlin_ai/merlin_ai.gd`

| Plateforme | Cerveaux | RAM Estimee |
|-----------|----------|-------------|
| Web | 1 (Narrateur) | 2.0 GB |
| Mobile (< 4.5 GB RAM) | 1 | 2.0 GB |
| Mobile (>= 4.5 GB RAM) | 2 (Narrateur + GM) | 4.0 GB |
| Desktop | 2-4 (Narrateur + GM + Workers) | 4.0-8.0 GB |

**Modele :** Qwen 2.5-3B-Instruct Q4_K_M (2.0 GB par cerveau)

### Roles des Cerveaux

| Cerveau | Role | Temperature | top_p | max_tokens |
|---------|------|------------|-------|------------|
| **Narrateur** (toujours) | Texte creatif, dialogues | 0.6 | 0.85 | 200 |
| **Game Master** (desktop+) | Effets JSON structurees | 0.2 | 0.80 | 150 |
| **Workers** (3-4, desktop) | Prefetch, voix, analyse | Herite du role | â€” | â€” |

## 7.2 Pipeline Omniscient

**Fichier :** `addons/merlin_ai/merlin_omniscient.gd`

```
Demande de carte
       |
       v
[Verifier prefetch cache]
       |
       +--[HIT valide] --> Retourner carte cacher
       |
       +--[MISS] --> Lancer generation parallele
                      |
                      +---> [Narrateur] : scenario creatif
                      +---> [Game Master] : effets JSON (GBNF)
                      |
                      v
                    Fusion scenario + effets
                      |
                      v
                    Guardrails (validation)
                      |
                      v
                    Carte validee --> Retourner
```

### Prefetch

- **Hash de contexte :** MD5(aspects + mission_stage) â€” invalide si aspects changent
- **Lancement :** Pendant que le joueur lit la carte actuelle
- **Timeout :** 3s supplementaires max pour consommer le prefetch

## 7.3 RAG v2.0

**Fichier :** `addons/merlin_ai/rag_manager.gd`

| Parametre | Valeur |
|-----------|--------|
| Budget tokens | **180** |
| Chars/token | **4** |
| Niveaux de priorite | 4 (CRITICAL=4, HIGH=3, MEDIUM=2, LOW=1, OPTIONAL=0) |
| Registres journal | Max **50** entrees |
| Memoire cross-run | Max **20** resumes |

### Contexte Injecte (par priorite)

1. **CRITICAL :** Crise aspects + souffle
2. **HIGH :** Dernieres 3 decisions
3. **MEDIUM :** Arcs narratifs actifs
4. **LOW :** Contexte biome
5. **OPTIONAL :** Pattern joueur, bond bestiole

> **MANQUANT DANS LE RAG :** Karma, Factions, Dette Merlin, Tension, Memoire Monde, Resonances. Ces systemes caches ne sont PAS envoyes au LLM, rendant la generation de contenu deconnectee de l'etat profond du jeu.

## 7.4 Guardrails

| Verification | Critere | Action si echec |
|-------------|---------|-----------------|
| Longueur min | >= 10 caracteres | Rejet |
| Longueur max | <= 300 caracteres (transition), <= 500 (carte) | Rejet |
| Langue francaise | >= 2 mots-cles FR (le, la, de, un, etc.) | Rejet |
| Mots anglais | Detection (the, and, you, are...) | Rejet |
| Repetition | Similarite Jaccard >= 0.7 vs 10 dernieres cartes | Rejet |
| Whitelist effets | 9 types TRIADE autorises | Filtrage silencieux |
| Reparation JSON | 4 etapes (braces â†’ corrections â†’ agressif â†’ regex) | Fallback |

---

# 8. RELATIONS INTER-SYSTEMES

## 8.1 Diagramme d'Architecture

```
                    +-------------------+
                    |   MerlinAI        |
                    |  (Multi-Brain)    |
                    +--------+----------+
                             |
                             | genere texte + effets
                             v
+----------------+  +------------------+  +-------------------+
| RAG Manager    |->| MerlinOmniscient |->| MerlinLlmAdapter  |
| (contexte)     |  | (orchestrateur)  |  | (validation)      |
+----------------+  +--------+---------+  +--------+----------+
                             |                      |
                             | carte validee        | effets filtres
                             v                      v
                    +------------------+   +-------------------+
                    | MerlinCardSystem |   | MerlinEffectEngine|
                    | (selection type) |   | (application)     |
                    +--------+---------+   +--------+----------+
                             |                      |
                             | carte choisie        | effets appliques
                             v                      v
                    +-------------------------------------------+
                    |           MerlinStore (Redux)              |
                    |  aspects, souffle, karma, flux, mission    |
                    +---+-------+-------+-------+-------+-------+
                        |       |       |       |       |
                   signals  signals signals signals signals
                        |       |       |       |       |
                        v       v       v       v       v
                    +------+ +----+ +------+ +-----+ +-------+
                    |  UI  | |Save| | RAG  | |Biome| |Events |
                    +------+ +----+ +------+ +-----+ +-------+
                        ^
                        |
                +-------+--------+
                | MerlinGame     |
                | Controller     |
                | (bridge)       |
                +-------+--------+
                        ^
                        |
                   [Player Input]
```

## 8.2 Signaux du Store

| Signal | Parametres | Emis quand |
|--------|-----------|------------|
| `state_changed` | `state: Dictionary` | Tout changement d'etat |
| `phase_changed` | `phase: String` | Phase du jeu change |
| `aspect_shifted` | `aspect, old_state, new_state` | Un aspect change d'etat |
| `souffle_changed` | `old_value, new_value` | Souffle modifie |
| `run_ended` | `ending: Dictionary` | Run terminee (chute ou victoire) |
| `card_resolved` | `card_id, option` | Choix du joueur traite |
| `mission_progress` | `step, total` | Mission avance |
| `awen_changed` | `old_value, new_value` | Awen modifie |
| `ogham_activated` | `skill_id, effect` | Ogham utilise |
| `bond_tier_changed` | `old_tier, new_tier` | Tier de bond change |

**Source :** `merlin_store.gd:11-21`

## 8.3 Actions du Store (Dispatch)

| Action | Description | Sous-systeme |
|--------|-------------|-------------|
| `SET_PHASE` | Change la phase du jeu | Core |
| `SET_SEED` | Initialise le RNG | Core |
| `TRIADE_START_RUN` | Demarre une run (biome, seed, flux) | Triade |
| `TRIADE_GET_CARD` | Obtient prochaine carte (LLM/fallback) | Triade |
| `TRIADE_RESOLVE_CHOICE` | Applique les effets du choix | Triade |
| `SHIFT_ASPECT` | Deplace un aspect | Triade |
| `USE_SOUFFLE` / `ADD_SOUFFLE` | Gestion Souffle | Triade |
| `PROGRESS_MISSION` | Avance la mission | Triade |
| `ADD_KARMA` / `ADD_TENSION` | Compteurs caches | Hidden |
| `MODIFY_BOND` | Modifie lien Bestiole | Bestiole |
| `SET_FLAG` / `ADD_TAG` | Flags narratifs | Narrative |
| `CREATE_PROMISE` / `FULFILL` / `BREAK` | Promesses Merlin | Promise |

## 8.4 Flux de Donnees Cle

### Demarrage d'une Run
```
GameManager.run â†’ biome_key â†’ TriadeController.start_run()
  â†’ Store.dispatch(TRIADE_START_RUN) â†’ _init_triade_run()
    â†’ Aspects = EQUILIBRE x3
    â†’ Souffle = SOUFFLE_START (3) + talents
    â†’ Flux = FLUX_START + biome_offset + talents
    â†’ Mission = {} (stub vide)
    â†’ MerlinOmniscient.on_run_start()
```

### Choix du Joueur
```
UI.option_chosen(index) â†’ Controller._on_option_chosen(index)
  â†’ Determiner DC (6/10/14) + modificateurs
  â†’ Mini-jeu (70%) ou D20 (30%)
  â†’ Moduler effets par resultat
  â†’ Store.dispatch(TRIADE_RESOLVE_CHOICE)
    â†’ EffectEngine.apply_effects()
      â†’ SHIFT_ASPECT, ADD_KARMA, etc.
    â†’ _check_run_end()
      â†’ 2 extremes ? â†’ run_ended signal
      â†’ Mission complete + equilibre ? â†’ victoire
    â†’ Souffle regen check
    â†’ Awen regen check
  â†’ UI.show_reaction()
  â†’ UI.travel_animation()
  â†’ RAG.write_context()
  â†’ Prefetch next card
```

---

# 9. AUDIT DE COHERENCE

## 9.1 Problemes Game-Breaking (P0)

### P0-1 : Systeme de Mission NON-FONCTIONNEL

**Localisation :** `merlin_store.gd:187-193`

```gdscript
"mission": {
    "type": "",       # Toujours vide
    "target": "",     # Toujours vide
    "progress": 0,
    "total": 0,
    "revealed": false,
},
```

**Impact :** Le joueur ne peut PAS gagner. La seule fin possible est la CHUTE (2 aspects extremes). Les 4 conditions de victoire (`harmonie`, `prix_paye`, `victoire_amere`, `tyran_juste`) requierent toutes "Mission accomplie", mais la mission n'est jamais generee ni revele.

**Correction requise :** Implementer un generateur de missions (types : collecte, equilibre, exploration, alliance) avec progression et detection de completion.

---

### P0-2 : Arbre de Vie SANS UI

**Localisation :** `HubAntre.gd` (page 4 absente)

**Backend existant :**
- 28 noeuds completement definis (`merlin_constants.gd:576-833`)
- Structures de donnees dans le store (`meta.talent_tree.unlocked`)
- 14 types d'essences comme monnaie

**Manquant :** Toute l'interface utilisateur. Le joueur accumule des essences mais ne peut pas les depenser.

**Correction requise :** Page 4 dans HubAntre avec visualisation de l'arbre, tooltips, deblocage.

---

### P0-3 : Buffer de Cartes Insuffisant en Production

**Localisation :** `triade_game_controller.gd:92-93`

Le buffer de 3 cartes est declare (`_card_buffer: Array[Dictionary]`, `BUFFER_SIZE := 3`) mais le code `_request_next_card()` ne l'utilise pas â€” il fait un dispatch synchrone avec timeout de 15s.

**Impact :** Gel de 1-3 secondes entre chaque carte sur systemes CPU. Sur le timeout de 15s, le joueur voit un ecran de chargement.

**Correction requise :** Implementer le remplissage continu du buffer (pre-generer 3 cartes en avance).

---

### P0-4 : Systeme de Twists ABSENT

**Localisation :** Aucun code

La tension narrative est trackee (`merlin_store.gd:203`, effet `ADD_TENSION`) mais **jamais consommee**. Le design (BIOMES_SYSTEM.md, MASTER_DOCUMENT) prevoit 5 types de Twists :
- Revelation (15%)
- Trahison (20%)
- Miracle (10%)
- Catastrophe (25%)
- Deus Ex (5%)

**Impact :** L'arc narratif reste plat. Pas de climax, pas de retournement de situation.

**Correction requise :** Detecteur de tension dans `merlin_omniscient.gd`, declenchant un Twist quand tension >= 70.

---

### P0-5 : Fin Secrete IMPOSSIBLE a Atteindre

**Localisation :** Aucun code de detection

Le design prevoit une fin secrete ("L'Echo Eternel") accessible apres 100+ runs, Bond 95+, Trust T3, toutes les fins vues. Aucune logique de detection n'existe dans le store ou le controller.

**Impact :** La recompense ultime du jeu est inexistante.

**Correction requise :** Ajouter detection dans `_check_triade_run_end()` basee sur `meta.total_runs`, `bestiole.bond`, `meta.endings_seen.size()`.

---

## 9.2 Problemes d'Equilibrage (P1)

### P1-1 : Economie Souffle trop Restrictive

| Facteur | Valeur | Probleme |
|---------|--------|----------|
| Max | 7 | Limite basse pour 30 cartes |
| Depart | 3 | Seulement 3 choix Centre en debut |
| Regen | +1 si 3 equilibres | Condition rare, ~1 regen toutes les 5 cartes |
| Sans talent | 3 + ~6 regens max = ~9 Centres / run | Sur 30 cartes, seulement 30% de Centres possibles |

**Recommendation :** Augmenter max a 10, OU regen toutes les 3 cartes equilibrees, OU reduire cout Centre a 0 pour les 5 premieres cartes (tutoriel).

---

### P1-2 : Karma trop Volatile

| Facteur | Valeur | Probleme |
|---------|--------|----------|
| Plage | -10 a +10 | Etroite |
| Delta par carte | +-1 a +-3 | Agressif |
| Saturation | ~4 cartes pour atteindre le cap | Le karma se stabilise a un extreme tres vite |

**Recommendation :** Reduire delta max a +-1 par carte, OU elargir la plage a -20/+20.

---

### P1-3 : DC Droite trop Dur

| Option | DC | Probabilite succes (D20 pur) | Avec Karma +10 |
|--------|----|-----------------------------|-----------------|
| Gauche | 6 | **75%** | 100% (trivial) |
| Centre | 10 | **55%** | 75% |
| Droite | 14 | **35%** | 55% |

Sans modificateurs, la Droite echoue **65% du temps**. C'est punitif pour un jeu de cartes casual.

**Recommendation :** DC adaptatif selon la progression (DC 14 en debut, DC 12 en milieu, DC 10 en climax).

---

### P1-4 : Awen Regen trop Lent

Pour utiliser les 18 Oghams (cout 1-3 Awen), le joueur dispose de 2 Awen de depart et regenere +1 toutes les 5 cartes. Sur une run de 30 cartes, il obtient ~8 Awen total. Les Oghams coutent en moyenne 2 Awen â†’ **seulement 4 utilisations par run**.

**Recommendation :** Reduire intervalle a 3 cartes, OU ajouter +1 Awen sur succes critique.

---

### P1-5 : Shift Aspect sans Validation de Saut

Le design (DOC_12) stipule qu'un aspect ne peut pas sauter un etat (BAS â†’ HAUT directement). Mais `SET_ASPECT` dans l'Effect Engine permet de forcer n'importe quel etat.

**Recommendation :** Ajouter validation dans `_apply_set_aspect` : si ecart > 1, forcer passage par EQUILIBRE.

---

### P1-6 : Save Scumming Possible

L'autosave se declenche apres chaque carte resolue. Le joueur peut quitter et recharger pour annuler un mauvais D20.

**Recommendation :** Sauvegarder AVANT le choix (pas apres), OU implementer un systeme de "roguelite save" (1 seule sauvegarde ecrasee a chaque action).

---

## 9.3 Systemes Caches Non-Implantes

Tout le contenu de `docs/20_card_system/DOC_13_Hidden_Depth_System.md` est **en attente d'implementation** :

| # | Systeme | Description | Design | Code | Priorite |
|---|---------|-------------|--------|------|----------|
| 1 | **Resonances** | 6 positives + 6 tension, bonus quand 2-3 aspects meme etat | DOC_13 Partie 1 | Aucun | P1 |
| 2 | **Profil Joueur** | 3 axes (audace/altruisme/spirituel) â†’ modifie cartes | DOC_13 Partie 2 | Stub (valeurs 0) | P1 |
| 3 | **Echos Inter-Runs** | Actions laissent traces dans la run suivante | DOC_13 Partie 3 | Aucun | P1 |
| 4 | **Synergies Oghams** | 8 combos secretes de 3 Oghams | DOC_13 Partie 4 | Aucun | P2 |
| 5 | **Quetes Cachees** | 10 objectifs secrets avec recompenses | DOC_13 Partie 5 | Aucun | P2 |
| 6 | **Cycles Lunaires** | 4 phases de lune affectent le gameplay | DOC_13 Partie 6 | Aucun | P2 |
| 7 | **Personnalite Bestiole** | 5 personnalites selon style joueur | DOC_13 Partie 7 | Aucun | P1 |
| 8 | **Dette Narrative** | Callbacks narratifs 5-15 cartes plus tard | DOC_13 Partie 8 | Structure (`ADD_NARRATIVE_DEBT` existe) | P1 |
| 9 | **5 Factions** | Druides/Villageois/Guerriers/Creatures/Marchands | MASTER_DOC | Aucun | P1 |
| 10 | **Memoire Monde** | Flags cross-run permanents | MASTER_DOC | Aucun | P1 |

---

## 9.4 Incoherences Design / Code

### INC-1 : DOC_11 vs DOC_12 (Conflit de Systemes)

`DOC_11_Card_System.md` decrit 4 jauges continues (Vigueur/Esprit/Faveur/Ressources, 0-100).
`DOC_12_Triade_Gameplay_System.md` decrit 3 aspects discrets (Corps/Ame/Monde, -1/0/+1).

**Le code implemente DOC_12.** DOC_11 est **obsolete** mais toujours present, creant de la confusion.

Les constantes `REIGNS_GAUGES`, `REIGNS_GAUGE_*`, `REIGNS_ENDINGS` dans `merlin_constants.gd:51-69` sont des vestiges de ce systeme abandonne.

---

### INC-2 : D20 + Mini-Jeux Non Documentes

Le systeme D20 (DC 6/10/14) et les 15 mini-jeux ont ete implementes en Phases 37-40 mais **ne figurent dans aucun document de design original**. DOC_12 ne les mentionne pas.

---

### INC-3 : Confusion Souffle d'Ogham / Souffle d'Awen

Deux ressources avec "Souffle" dans le nom :
- **Souffle d'Ogham** : pour l'option Centre (visible, max 7)
- **Souffle d'Awen** : pour les competences Bestiole (visible, max 5)

L'UI doit les distinguer clairement. Le nom "Awen" est utilise dans le code (`bestiole.awen`) mais pas dans le design original.

---

### INC-4 : Flux Asymetrique Non Documente

Les Flux demarrent a `terre:50, esprit:30, lien:40` (`merlin_constants.gd:477`). Cette asymetrie favorise Esprit bas (stagnant) et Lien bas (calme = DC-2) en debut de run. Aucun document n'explique ce choix.

Le talent `tronc_1` ("Equilibre des Feux") corrige cela en forcant 50/50/50, suggerant que l'asymetrie est intentionnellement un desavantage.

---

### INC-5 : TUNING_SHEET et KNOWN_RISKS Desalignes

`docs/40_world_rules/TUNING_SHEET.md` concerne l'ancien systeme "World Rules" (spawn rates, mystery rates, conflict). Ces multiplicateurs **ne s'appliquent pas** au systeme TRIADE actuel.

`docs/40_world_rules/KNOWN_RISKS.md` liste des risques pour un "permanent world" (FOMO, timezone, seasons), pas pour un roguelite a sessions courtes.

---

### INC-6 : Code Legacy (46+ Lignes Inutilisees)

`merlin_constants.gd:1-46` contient des constantes Legacy (VERBS, RUN_RESOURCES, NEEDS, POSTURES, ELEMENTS, STATUS_IDS, NODE_TYPES) qui ne sont plus utilisees par le systeme TRIADE.

`merlin_effect_engine.gd:26-94` contient ~50 codes d'effets Legacy qui ne sont jamais appeles.

---

## 9.5 Resume des Risques d'Equilibrage

```
CRITIQUE (jeu casse)
  |
  â”œâ”€â”€ Mission = stub vide â†’ PAS DE VICTOIRE
  â”œâ”€â”€ Arbre de Vie sans UI â†’ ESSENCES INUTILISABLES
  â”œâ”€â”€ Buffer cartes absent â†’ GEL 1-3s
  â”œâ”€â”€ Twists absents â†’ ARC PLAT
  â””â”€â”€ Fin secrete absente â†’ RECOMPENSE ULTIME MANQUANTE

HAUT (experience degradee)
  |
  â”œâ”€â”€ Souffle trop restrictif â†’ FRUSTRATION
  â”œâ”€â”€ Karma volatile â†’ SATURATION RAPIDE
  â”œâ”€â”€ DC Droite punitif â†’ EVITEMENT CHOIX AUDACIEUX
  â”œâ”€â”€ Awen lent â†’ OGHAMS SOUS-UTILISES
  â”œâ”€â”€ Saut d'aspect â†’ GAME OVER INATTENDU
  â””â”€â”€ Save scumming â†’ PAS DE TENSION

MOYEN (profondeur manquante)
  |
  â”œâ”€â”€ 10 systemes caches non-implantes â†’ DEPTH LAYER ABSENT
  â”œâ”€â”€ Flux dormant (Terre/Esprit) â†’ COMPLEXITY SANS IMPACT
  â”œâ”€â”€ Resonances absentes â†’ BONUS INVISIBLES MANQUANTS
  â””â”€â”€ RAG incomplet â†’ LLM DECONNECTE DE L'ETAT PROFOND
```

---

# 10. RECOMMANDATIONS PRIORISEES

## Phase A â€” "Rendre le jeu jouable" (P0)

| # | Action | Fichier(s) | Effort |
|---|--------|-----------|--------|
| A1 | Implementer systeme de Mission (generation, progression, detection victoire) | `merlin_store.gd`, `merlin_omniscient.gd`, `merlin_constants.gd` | LOURD |
| A2 | Implementer buffer de cartes (3 pre-generees) | `triade_game_controller.gd` | MOYEN |
| A3 | Ajouter validation saut d'aspect (pas BASâ†’HAUT direct) | `merlin_effect_engine.gd` | LEGER |
| A4 | Cabler Twists (tension >= 70 â†’ carte speciale) | `merlin_omniscient.gd`, `merlin_card_system.gd` | MOYEN |

## Phase B â€” "Rendre le jeu profond" (P1)

| # | Action | Fichier(s) | Effort |
|---|--------|-----------|--------|
| B1 | UI Arbre de Vie (page 4 HubAntre) | `HubAntre.gd` | LOURD |
| B2 | Resonances entre aspects | `merlin_store.gd`, `merlin_constants.gd` | MOYEN |
| B3 | Profil joueur â†’ contexte LLM | `rag_manager.gd`, `merlin_store.gd` | MOYEN |
| B4 | Echos inter-runs | `merlin_save_system.gd`, `merlin_store.gd` | MOYEN |
| B5 | Reequilibrage Souffle (max 10 ou regen plus frequent) | `merlin_constants.gd` | LEGER |
| B6 | Reequilibrage Karma (plage -20/+20 ou delta +-1) | `merlin_constants.gd`, `triade_game_controller.gd` | LEGER |
| B7 | DC adaptatif (selon progression run) | `triade_game_controller.gd` | MOYEN |
| B8 | Integrer hidden resources dans RAG | `rag_manager.gd` | MOYEN |

## Phase C â€” "Rendre le jeu memorable" (P2)

| # | Action | Fichier(s) | Effort |
|---|--------|-----------|--------|
| C1 | Fin secrete (detection + narration) | `merlin_store.gd`, `merlin_constants.gd` | MOYEN |
| C2 | Synergies Oghams (8 trios) | `merlin_constants.gd`, `triade_game_controller.gd` | MOYEN |
| C3 | Evolution Bestiole (triggers + UI) | `HubAntre.gd`, `merlin_store.gd` | LOURD |
| C4 | Quetes cachees (10) | `merlin_store.gd`, `merlin_constants.gd` | MOYEN |
| C5 | Personnalite Bestiole | `merlin_store.gd` | MOYEN |
| C6 | Dette narrative (callbacks) | `merlin_omniscient.gd`, `merlin_card_system.gd` | MOYEN |

## Phase D â€” "Nettoyage" (P3)

| # | Action | Fichier(s) | Effort |
|---|--------|-----------|--------|
| D1 | Supprimer constantes Legacy (lignes 1-46) | `merlin_constants.gd` | LEGER |
| D2 | Supprimer constantes Reigns (lignes 47-69) | `merlin_constants.gd` | LEGER |
| D3 | Supprimer effets Legacy (lignes 26-94) | `merlin_effect_engine.gd` | LEGER |
| D4 | Deprecier DOC_11 ou le marquer obsolete | `docs/20_card_system/DOC_11_Card_System.md` | LEGER |
| D5 | Mettre a jour DOC_12 avec D20 + mini-jeux | `docs/20_card_system/DOC_12_Triade_Gameplay_System.md` | MOYEN |
| D6 | Mettre a jour TUNING_SHEET pour TRIADE | `docs/40_world_rules/TUNING_SHEET.md` | MOYEN |
| D7 | Documenter choix Flux asymetrique | `merlin_constants.gd` (commentaire) | LEGER |

---

## Annexe A â€” Fichiers de Reference

| Fichier | Contenu | Lignes |
|---------|---------|--------|
| `scripts/merlin/merlin_constants.gd` | Toutes les constantes du jeu | ~970 |
| `scripts/merlin/merlin_store.gd` | Store Redux, etat central | ~500+ |
| `scripts/merlin/merlin_effect_engine.gd` | Application des effets | ~400+ |
| `scripts/merlin/merlin_card_system.gd` | Generation de cartes | ~300+ |
| `scripts/merlin/merlin_llm_adapter.gd` | Validation LLM | ~300+ |
| `scripts/merlin/merlin_save_system.gd` | Persistance JSON | ~200+ |
| `scripts/ui/triade_game_controller.gd` | Bridge Store-UI, D20, mini-jeux | ~800+ |
| `scripts/ui/triade_game_ui.gd` | Interface TRIADE | ~600+ |
| `scripts/MenuPrincipalMerlin.gd` | Menu principal | ~400+ |
| `scripts/SceneRencontreMerlin.gd` | Onboarding 7 phases | ~500+ |
| `scripts/HubAntre.gd` | Hub central | ~1000+ |
| `scripts/TransitionBiome.gd` | Transition biome | ~500+ |
| `scripts/ui/map_ui.gd` | Carte du monde | ~200+ |
| `addons/merlin_ai/merlin_ai.gd` | Multi-Brain LLM | ~400+ |
| `addons/merlin_ai/merlin_omniscient.gd` | Orchestrateur IA | ~500+ |
| `addons/merlin_ai/rag_manager.gd` | RAG v2.0 | ~465 |

## Annexe B â€” Documents de Design

| Document | Statut |
|----------|--------|
| `docs/20_card_system/DOC_12_Triade_Gameplay_System.md` | **ACTIF** â€” Reference pour TRIADE |
| `docs/20_card_system/DOC_13_Hidden_Depth_System.md` | **DESIGN VALIDE** â€” Non implemente |
| `docs/40_world_rules/BIOMES_SYSTEM.md` | **ACTIF** â€” 7 biomes + Twists |
| `docs/20_card_system/DOC_11_Card_System.md` | **OBSOLETE** â€” Remplace par DOC_12 |
| `docs/40_world_rules/TUNING_SHEET.md` | **DESALIGNE** â€” Concerne ancien systeme |
| `docs/40_world_rules/KNOWN_RISKS.md` | **DESALIGNE** â€” Concerne permanent world |
| `docs/50_lore/LORE_BIBLE_MERLIN.md` | **ACTIF** â€” Lore reference |
| `docs/60_companion/BESTIOLE_*.md` | **ACTIF** â€” 12 docs Bestiole |

---

*Fin de la Bible de Gameplay â€” M.E.R.L.I.N. v1.0.0*

