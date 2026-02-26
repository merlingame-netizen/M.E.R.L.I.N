# DOC_17 -- Regles Officielles d'un RUN M.E.R.L.I.N.

> **Document de reference** | Version 1.0 | 2026-02-26
> Statut: OFFICIEL -- Reference permanente des regles de run

---

## 1. Flow d'une Partie

### 1.1 Premiere Partie (aucune sauvegarde)

```
IntroCeltOS
  -> MenuPrincipal
     -> [PREMIERE FOIS] Animation LLM : Merlin ouvre les yeux
        -> Texte fixe d'accueil
        -> Animation statut LLM reel (Ollama connecte / non connecte)
           "Il branche son cerveau..." (narratif, pas juste un spinner)
        -> SceneRencontreMerlin : Merlin explique l'aventure (vocabulaire celtique LoRA)
        -> Tour guide de l'Antre (zones : Biome, Arbre de Vie, Alignement)
     -> HubAntre
        -> Carte Bretagne pixel art (selection biome par bulle animee)
        -> [Optionnel] Arbre de Vie (souche, puis arbre procedral au fil des runs)
        -> [Optionnel] Menu Alignement / Favorabilite
        -> Selection Typologie (Classique / Urgence / Parieur / Diplomate / Chasseur)
     -> [LOADING SCREEN] Generation LLM complete : intro + 25 cartes + fin de scenario
        -> Mini-jeu pendant le chargement → Faveurs gagnables
     -> MerlinGame : Run de 25 cartes en sequence
        -> start_run() -> TRIADE_START_RUN -> _init_triade_run()
     -> [Fin] -> HubAntre (boucle)
```

### 1.2 Boucle Roguelite (sauvegarde existante)

```
MenuPrincipal -> SelectionSauvegarde -> HubAntre -> [Selection biome + typologie]
  -> [Loading + mini-jeu] -> MerlinGame -> [Fin] -> HubAntre
```

---

## 2. Hub Antre -- Fonctionnalites

### 2.1 Selecteur de Biome
- **VISION** : Overlay avec carte pixel art de Bretagne ultra animee
- Une bulle par biome sur la carte (cliquable)
- **FUTUR** : Remplace l'actuel BiomeRadial circulaire
- Biomes : broceliande, landes, cotes, villages, cercles, dolmen, merlin

### 2.2 Arbre de Vie
- Bouton dedie -> overlay surcouche
- Arbre celtique pixel art genere proceduralement
- Depart : souche seule
- Plus on debloque de competences -> l'arbre se genere visuellement
- **FUTUR** : 30+ etages prevus, nombreuses branches
- Financement : Essences (monnaie principale)

### 2.3 Bestiole / Familiers
- **NOTE** : Bestiole retiree du menu principal
- **FUTUR** : 4 familiers debloquables progressivement
- Pas de mecaniques a implementer dans cette session

### 2.4 Menu Alignement / Favorabilite
- **FUTUR** : Consulter alignement par biome en fonction de : heure / saison / reputation factions
- Voir si des runs sont plus favorables que d'autres
- Run + risque = + de recompenses potentielles MAIS risque de malus ou revenir bredouille
- Systeme risque/recompense visible avant de partir

### 2.5 Pas d'Inventaire
- Aucun inventaire dans le jeu

---

## 3. Architecture du Run -- Generation LLM

### 3.1 Vision Cible (FUTUR -- refonte majeure)
- Biome selectionne -> LOADING SCREEN (couverture visuelle)
- LLM genere le scenario COMPLET en 1 appel :
  1. Intro du scenario
  2. 25 cartes completes (verbe + type de test + phrase resolution + niveau de reussite)
  3. Fin de scenario (si le joueur arrive jusqu'au bout)
- Mini-jeu pendant le chargement -> Faveurs gagnables
- Une fois charge : le run demarre, joueur joue 25 cartes en sequence

### 3.2 Etat Actuel (en place)
- Generation a la demande (1 carte a la fois par LLM call)
- Buffer de 5 cartes pre-generees depuis TransitionBiome

---

## 4. Economie du Run -- Ressources de Depart

| Ressource | Valeur depart | Max | Min | Notes |
|-----------|--------------|-----|-----|-------|
| `life_essence` | 100 | 100 | 0 | 10 barres de 10 PV (visuel pixelise) |
| `souffle` | 1 | variable | 0 | Logo plein / vide (single use) |
| `essences` | 0 | -- | 0 | Monnaie principale inter-run |
| `hidden.karma` | 0 | +10 | -10 | KARMA_MIN/MAX |
| `hidden.tension` | 0 | 100 | 0 | Twists a 70+ |
| `awen` | 2 | 5 | 0 | AWEN_START=2, AWEN_MAX=5 |
| `faveurs` | 0 | -- | 0 | Gagnes dans le mini-jeu de chargement |
| `flux.terre` | 50 +/- biome | 100 | 0 | FLUX_START + flux_offset |
| `flux.esprit` | 30 +/- biome | 100 | 0 | FLUX_START + flux_offset |
| `flux.lien` | 40 +/- biome | 100 | 0 | FLUX_START + flux_offset |

### 4.1 Vie -- Affichage
- **100 PV** = **10 barres pixelisees de 10 PV chacune**
- Chaque barre se vide progressivement
- Style GBC pixel art (MerlinVisual.PALETTE)
- Constante : `LIFE_BAR_SEGMENTS = 10`

### 4.2 Souffle -- Affichage
- **1 Souffle** au depart, single use
- Represente par un **logo plein** (disponible) / **logo vide** (utilise)
- Pas un chiffre -- un pictogramme visuel

### 4.3 Essences -- Monnaie Principale
- Gagnees pendant les runs
- **Sources** :
  - Resolution d'une carte (base) : +1 Essence
  - Cartes Tresor : +15 Essences (ou plus)
  - Certaines cartes specifiques en recompense
- **Utilisees pour** :
  - Debloquer competences dans l'Arbre de Vie
  - Obtenir des Faveurs
  - Debloquer des chemins / biomes
- **Persistance** : Cross-run (comme faction_rep), SANS decroissance
- **DISTINCT des Faveurs** (Faveurs = bonus de mini-jeu de chargement)

---

## 5. Drain / Gain de Vie pendant le Run

| Evenement | Effet sur Vie |
|-----------|--------------|
| Chaque carte resolue | -1 (LIFE_ESSENCE_DRAIN_PER_CARD) |
| Echec critique | -10 supplementaire |
| Succes critique | +5 |
| Power milestone carte 5 | +15 |
| Power milestone carte 20 | +20 |

---

## 6. Systeme de Resolution (D20 + DC + Tests + Mini-jeux)

### 6.1 D20 + DC Variable (actuel -- MAJORITAIRE)

**DC de base par direction :**
| Direction | Min | Max |
|-----------|-----|-----|
| Gauche (prudent) | 4 | 8 |
| Centre (equilibre) | 7 | 12 |
| Droite (audacieux) | 10 | 16 |

**Modificateurs DC (cumulatifs) :**
- 3 echecs consecutifs -> -4 (pitie)
- 3 succes consecutifs -> +2 (defi)
- Choix critique -> +4
- Flux lien <= 30 -> -2 / >= 70 -> +3
- Biome difficulte -> -1 a +2
- Power milestone (carte 10) -> dc_reduction cumule
- Archetype -> -1 a +1
- Aspect BAS -> +2 chacun / HAUT -> +1 chacun / tous EQUILIBRE -> -1
- Dynamic modifier (reevalue /3 cartes) -> -3 a +3
- **Final** : clamp(base+mods, 2, 19)

**Resultats D20 :**
| Roll | Resultat |
|------|----------|
| 20 (nat) | Succes critique |
| >= DC | Succes |
| 2-19 et < DC | Echec |
| 1 (nat) | Echec critique |

### 6.2 Tests Multiples (FUTUR)
- 2 a 3 tests pour les cartes les plus complexes
- Tests coherents avec l'action de la carte
- La pre-generation LLM 25 cartes inclura le 'type de test' par choix

### 6.3 Mini-jeux WarioWare (FUTUR)
- Myriade de mini-jeux dedies a l'action / champ lexical
- Exemples : mini-jeu des paires, reflexe, etc.
- Style WarioWare = rapides, directs, adaptes au verbe/action de la carte
- Resultat du mini-jeu -> input pour la resolution D20

---

## 7. Alignement Corps / Ame / Monde

### 7.1 Systeme Cible (MODIFIER -- remplace le systeme -1/0/+1)
- **Score continu -100 a +100** (comme les factions)
- **Persiste cross-run** (comme les factions : avec decroissance 8%/run)
- Remplace le systeme actuel -1/0/+1 discret (BAS/EQUILIBRE/HAUT)

### 7.2 Etat Actuel (reference)
- 3 etats discrets (BAS/EQUILIBRE/HAUT)
- Stockes dans state['run']['aspects']['Corps'/'Ame'/'Monde'] comme -1/0/+1
- Pas de cross-run

### 7.3 Nouveau Schema
```
state['run']['aspects'] -> score -100/+100 par aspect (int)
state['meta']['aspects_alignment'] -> cross-run persistent, decroissance 8%/run
```

| Constante | Valeur | Description |
|-----------|--------|-------------|
| ASPECT_MIN | -100 | Score minimum |
| ASPECT_MAX | +100 | Score maximum |
| ASPECT_DECAY_RATE | 0.08 | 8% de decroissance vers 0 par run |

---

## 8. Conditions de Fin de Run

### 8.1 Mort
- `life_essence <= 0` -> Fin immediate
- Ending : 'Essences Epuisees'
- Score = cards_played x 10

### 8.2 Victoire
- **25 cartes survivees** -> Victoire
- Type selon karma : harmonie (>= +5) / prix_paye (neutre) / victoire_amere (<= -5)
- Score = cards_played x 20

### 8.3 Duree Theorique
- 25-35 cartes (target 30, ~18s/carte)

---

## 9. Missions (4 Types)

| Mission | Description | Total requis |
|---------|-------------|-------------|
| survive | Jouer N cartes en vie | 30 |
| equilibre | Garder 3 aspects EQUILIBRE | 8 |
| explore | Visiter N biomes | 6 |
| artefact | Trouver artefact | 5 |

---

## 10. Power Milestones

| Carte # | Effet |
|---------|-------|
| 5 | +15 Vie |
| 10 | dc_reduction +2 |
| 15 | +1 Souffle |
| 20 | +20 Vie |

---

## 11. Progression Inter-Run

### 11.1 Ressources persistantes (cross-run)

| Ressource | Decroissance | Notes |
|-----------|-------------|-------|
| `meta.faction_rep` | -8%/run | 5 factions (Druides, Korrigans, Humains, Anciens, Ankou) |
| `meta.essences` | Aucune | Monnaie principale, accumulation pure |
| `meta.aspects_alignment` | -8%/run | Corps/Ame/Monde score continu |

### 11.2 Ce que le joueur rapporte d'un run
- Essences gagnees pendant le run -> ajoutees a meta.essences
- Impact sur faction_rep (selon choix et tags AUTO-TAG factions)
- Impact sur aspects_alignment (selon les effets ADD_ASPECT_ALIGNMENT)

---

## 12. Typologies de Run

5 typologies selectionnees dans HubAntre avant le depart :

| Typologie | Description | Specificite |
|-----------|-------------|-------------|
| classique | Run standard | Aucun modificateur |
| urgence | Crise immediate | Timer 10s par carte, DC+2 |
| parieur | Hasard capricieux | D20 >= 17 = bonus, <= 4 = malus |
| diplomate | Negociation | D20+2, DC-1, faction_delta x2 |
| chasseur | Traque / instinct | Minigame+25%, Awen+1/run |

Ref complete : DOC_16_Run_Typologies.md

---

## 13. Types de Cartes

| Type | % | Description |
|------|---|-------------|
| narrative | 80% | Scenarios LLM, 3 choix |
| event | 10% | Triggers temps / saison |
| promise | 5% | Pactes Merlin |
| merlin_direct | 5% | Messages narrateur |
| tresor | rare | Recompense Essences x15+ |

---

## 14. Travaux Futurs (Documentes -- Non Implementes cette Session)

| Fonctionnalite | Complexite | Description |
|---------------|-----------|-------------|
| CarteBretagnePixel | HAUTE | Remplace BiomeRadial, carte pixel art animee de Bretagne, bulles par biome |
| Arbre de Vie pixel art | HAUTE | 30+ etages, pixel art procedral croissant selon competences |
| 4 Familiers | HAUTE | Remplacement Bestiole par 4 familiers debloquables |
| LLM Full Run Generation | HAUTE | Generation complete 25 cartes en 1 appel LLM avant le run |
| WarioWare Mini-jeux | HAUTE | Nouveaux mini-jeux style WarioWare par champ lexical |
| Tests multiples par carte | MOYENNE | 2-3 tests consecutifs pour cartes complexes |
| Tour guide Antre (1ere fois) | MOYENNE | Merlin guide le joueur zone par zone au premier lancement |
| Menu Alignement/Favorabilite | MOYENNE | Consultation biome x saison x heure x factions avant run |
| Onboarding LLM narrativise | MOYENNE | Animation statut LLM reel presentee narrativement par Merlin |

---

## 15. Verification des Mecaniques (Tests Unitaires)

```
1. dispatch ADD_ESSENCES:5 -> state['run']['essences'] == 5
2. dispatch ADD_ESSENCES:5 (fin de run) -> state['meta']['essences'] += 5
3. dispatch ADD_ASPECT_ALIGNMENT:Corps:25 -> state['meta']['aspects_alignment']['Corps'] == 25
4. 2 runs consecutifs -> aspects_alignment x 0.92 (decroissance 8%)
5. Run lance -> 10 barres vie visibles, logo Souffle affiche
6. Run lance -> essences affiche (0 au depart)
```

---

*Document genere le 2026-02-26 | M.E.R.L.I.N. v4.0*