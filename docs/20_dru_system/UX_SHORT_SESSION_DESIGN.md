# UX Research Report: Parties Courtes (<10 minutes) pour DRU

**Agent:** UX Research
**Date:** 2026-02-08
**Version:** 1.0
**Contexte:** DRU - "JDR Parlant" style Reigns avec LLM

---

## Executive Summary

Ce rapport analyse comment creer une experience de partie courte (<10 minutes) engageante pour DRU, en se differenciant de Reigns tout en capitalisant sur ses forces. L'objectif est de transformer chaque session de 10 minutes en une experience narrative complete et satisfaisante.

**Recommandations cles:**
- **25-35 cartes par session** (vs 50-100 dans la spec actuelle)
- **15-20 secondes par decision** en moyenne
- **Arc narratif complet** en 3 actes meme en partie courte
- **Feedback immediat** + progression persistante visible
- **Interface minimaliste** avec information "at a glance"

---

## PARTIE 1: Tempo et Pacing

### 1.1 Analyse Comparative

| Jeu | Duree Session | Cartes/Session | Temps/Carte | Satisfaction |
|-----|---------------|----------------|-------------|--------------|
| Reigns | 3-15 min | 30-80 | 10-15s | Moderee |
| Gnosia | 15-30 min | N/A | Variable | Haute |
| Slay the Spire | 30-60 min | N/A | 20-60s | Tres haute |
| **DRU (propose)** | **8-10 min** | **25-35** | **15-20s** | **Haute** |

### 1.2 Calcul du Tempo Optimal

**Budget temps pour 10 minutes:**
```
Total: 600 secondes

- Intro/Context:        30s (animation entree, biome reveal)
- Cartes narratives:    420s (25-30 cartes x 14-17s)
- Transitions:          60s (entre cartes, effets visuels)
- Fin de run:           60s (resolution, score, unlock)
- Temps mort/pause:     30s (hesitation naturelle)

= 600s / 10 minutes exact
```

### 1.3 Structure de Decision Optimale

**Temps par carte decompte:**
| Phase | Duree | Description |
|-------|-------|-------------|
| Apparition carte | 1.5s | Animation slide-in |
| Lecture texte | 5-8s | 40-60 mots max |
| Ecoute voix Merlin | 3-5s | Synthese vocale acceleree |
| Reflexion choix | 3-5s | Comparaison options |
| Geste swipe | 0.5s | Input joueur |
| Feedback effets | 1.5s | Animation jauges |
| **TOTAL** | **15-22s** | Moyenne: 17s |

### 1.4 Rythme Narratif en 3 Actes

Pour creer tension en 10 minutes, structurer chaque run en **micro-arcs**:

```
ACTE 1: ETABLISSEMENT (Cartes 1-8, ~2.5 min)
├── Carte 1-2: Introduction biome, contexte
├── Carte 3-5: Rencontres quotidiennes, choix simples
└── Carte 6-8: Premier dilemme, tension monte

ACTE 2: CONFRONTATION (Cartes 9-22, ~5 min)
├── Carte 9-12: Consequences des choix initiaux
├── Carte 13-17: Climax, decisions difficiles
└── Carte 18-22: Resolution ou escalade

ACTE 3: RESOLUTION (Cartes 23-30, ~2.5 min)
├── Carte 23-26: Denouement
├── Carte 27-28: Derniere chance
└── Carte 29-30: Fin inevitable ou survie
```

### 1.5 Gestion du "Flow" Narratif

**Probleme:** 10 min = trop court pour arc classique
**Solution:** Arcs modulaires imbriques

```
Arc Principal (toute la run):     =====================================
Arc Secondaire (5-8 cartes):            =========    =========
Micro-arcs (2-3 cartes):           ==  ==  ==  ==  ==  ==  ==  ==
```

**Implementation:**
- Chaque carte contribue a 1-3 arcs simultanement
- Flags LLM pour coherence inter-cartes
- "Callbacks" aux decisions precedentes (meme session)

### 1.6 Recommandations Tempo

| Parametre | Valeur Recommandee | Rationale |
|-----------|--------------------|-----------|
| Mots par carte | 40-60 max | 5-8s lecture |
| Options label | 2-4 mots | Decision rapide |
| Cartes sans voix | 20% | Accelerer pace |
| Twist timing | Carte 12-18 | Milieu de run |
| Pity trigger | 3 cartes sans jauge 0/100 | Eviter frustration |

---

## PARTIE 2: Feedback et Satisfaction

### 2.1 Le Probleme des Morts Rapides

**Constat:** Une mort a la carte 5 = frustration maximale
**Cause:** Pas assez de temps pour s'investir + pas de progression visible

**Solutions proposees:**

#### A. Grace Period (Cartes 1-5)
```gdscript
# Pendant les 5 premieres cartes:
- Jauges ne peuvent pas atteindre 0 ou 100
- Effets negatifs reduits de 50%
- Premier "near death" = Merlin intervient (Deus Ex gratuit)
```

#### B. Pity System Ameliore
```gdscript
# Si joueur a perdu 3 runs d'affilee en < 10 cartes:
- Prochaine run: jauges commencent a 55 (au lieu de 50)
- Cartes "stabilisantes" plus frequentes
- Bestiole skill "quert" (recovery) disponible immediatement
```

#### C. Mort = Apprentissage, pas Punition
```gdscript
# A chaque mort, afficher:
- "Cause de ta chute": Quelle jauge, pourquoi
- "Ce que tu as appris": Flags decouvertes, lore pieces
- "Prochaine fois": Conseil specifique de Merlin
```

### 2.2 Metriques de Progression a Afficher

**Pendant la partie (discret):**
| Metrique | Affichage | Position |
|----------|-----------|----------|
| Cartes jouees | "Jour 12" | Coin superieur |
| Streak positive | Etoiles discretes | Sous le titre |
| Bestiole mood | Icone emoticone | Panel Bestiole |

**Fin de partie (celebratoire):**
| Metrique | Description |
|----------|-------------|
| Duree survie | "Tu as regne X jours" |
| Score total | Points = jours x multiplicateur |
| Fragments trouves | Pieces de lore debloquees |
| Unlocks | Nouveaux Oghams, biomes |
| Comparaison | "Ton record: Y jours" |

### 2.3 Sentiment de Fin Souhaite

**Objectif:** Le joueur doit ressentir **completion**, pas **interruption**

| Type de fin | Sentiment vise | Comment l'atteindre |
|-------------|----------------|---------------------|
| Mort prematuree (<10 cartes) | "J'ai appris" | Montrer ce qui a mal tourne + conseil |
| Mort moyenne (10-25 cartes) | "Bon essai" | Celebrer les succes + montrer progression |
| Mort tardive (25+ cartes) | "Belle partie" | Score eleve + unlock + lore piece |
| Survie complete | "Victoire!" | Ending cinematique + secret tease |

### 2.4 Feedback Immediat par Choix

**Chaque swipe doit avoir un feedback triple:**

1. **Visuel:**
   - Animation de la carte (sort du cadre)
   - Flash couleur sur jauge impactee (vert/rouge)
   - Particules de renforcement

2. **Audio:**
   - Son de swipe satisfaisant
   - Son de jauge (montee = chime, descente = thud)
   - Commentaire vocal court de Merlin (optionnel)

3. **Haptique (mobile):**
   - Vibration legere sur swipe
   - Vibration forte si jauge critique
   - Pattern distinct par type d'effet

### 2.5 Micro-recompenses

**Toutes les 5 cartes:**
- Petit bonus aleatoire (unlock fragment, skill recharge)
- Commentaire encourageant de Merlin
- Progression barre meta visible

**Toutes les 10 cartes:**
- Checkpoint narratif ("Fin du Chapitre 1")
- Bonus jauge modere
- Option speciale revelee

---

## PARTIE 3: Rejouabilite

### 3.1 Pourquoi Rejouer Immediatement?

**Facteurs psychologiques:**
| Facteur | Mecanisme DRU | Impact |
|---------|---------------|--------|
| "Near miss" | Montrer a 2 cartes de la victoire | TRES FORT |
| Curiosite | "Tu as manque 3 secrets..." | FORT |
| Progression | "Encore 50 points pour unlock" | MODERE |
| Defi | "Battras-tu ton record de 18 jours?" | MODERE |
| Lore | "Tu approches de la verite..." | FORT (long terme) |

### 3.2 Differenciation des Parties Courtes

**Comment eviter la repetition?**

#### A. Variabilite de Depart
```
Chaque run commence avec:
- Biome aleatoire (7 possibilites)
- Saison courante (reelle ou override)
- Bestiole mood variable
- 1-2 flags herites de la run precedente
```

#### B. Cartes Jamais Identiques
```
LLM genere en fonction de:
- Contexte actuel (jauges, biome, flags)
- Historique recent (eviter repetition)
- Karma cache (oriente le ton)
- Tension narrative (ajuste difficulte)
```

#### C. Twists Proceduraux
```
Probabilite de twist par run:
- Run 1-5:   10% (decouverte)
- Run 6-15:  20% (familiarisation)
- Run 16+:   30% (surprise attendue)
```

### 3.3 Equilibre Repetition/Surprise

| Element | Repetition (Confort) | Surprise (Excitation) |
|---------|---------------------|----------------------|
| Jauges | Toujours les memes 4 | Effets variables |
| Bestiole | Meme compagnon | Mood/skills variables |
| Merlin | Meme narrateur | Ton variable |
| Cartes | Types previsibles | Contenu genere |
| Fins | 8 fins connues | 1 fin secrete |
| Biomes | Structure similaire | Visuels/ambiance uniques |

### 3.4 Hooks de Rejouabilite

**Court terme (meme session):**
- "Encore une partie?" bouton prominent
- Temps de relancement < 3 secondes
- Pas de pub/interruption entre runs

**Moyen terme (meme jour):**
- "Challenge du jour" avec bonus
- Streak de runs (3 runs = bonus special)
- Event saisonnier actif

**Long terme (multi-jours):**
- Login streak recompenses
- Deblocages progressifs (18 Oghams)
- Verite cachee fragmentee

---

## PARTIE 4: UI/UX pour Parties Courtes

### 4.1 Interface Minimaliste vs Informationnelle

**Recommandation:** MINIMALISTE avec details on-demand

```
+------------------------------------------+
|  ▓▓▓▓░  ▓▓▓░░  ▓▓░░░  ▓▓▓▓▓  [≡]  [?]   |  <- Jauges simples + menus
+------------------------------------------+
|                                          |
|           ┌─────────────────┐            |
|           │                 │            |
|           │   [Portrait]    │            |
|           │                 │            |
|           │  Texte court    │            |  <- Zone principale
|           │  40-60 mots     │            |
|           │                 │            |
|           │   — MERLIN      │            |
|           └─────────────────┘            |
|                                          |
|  ← Refuser             Accepter →        |  <- Labels clairs, 2-4 mots
|                                          |
+------------------------------------------+
|  [🐾 Bestiole]              Jour 12      |  <- Status minimal
+------------------------------------------+
```

**Details on-demand (tap/hold):**
- Jauge → affiche nom + valeur exacte + historique
- Bestiole → affiche mood + skills disponibles + cooldowns
- Carte → affiche hints d'effets (si Bestiole skill actif)

### 4.2 Temps de Lecture des Textes

**Contraintes Merlin voice:**
- ACVoicebox speed: 0.65
- Moyenne: 8-10 caracteres/seconde
- 60 mots = ~300 caracteres = ~30-35 secondes TROP LONG

**Solution: Voix selective**
```gdscript
# Regles de voix:
if card.importance == "high" or card.type == "merlin_direct":
    play_voice(full_text)
elif card.importance == "medium":
    play_voice(first_sentence_only)
else:
    play_voice(None)  # Texte silencieux
```

**Recommandations texte:**
| Type carte | Mots max | Voix |
|------------|----------|------|
| Narrative (normale) | 50 | Premiere phrase |
| Narrative (importante) | 60 | Complete |
| Event | 40 | Complete |
| Promise | 50 | Complete |
| Merlin Direct | 40 | Complete |
| Twist | 60 | Complete + pause dramatique |

### 4.3 Transitions Entre Etats

**Transitions actuelles: TROP LONGUES**

| Transition | Actuel (estime) | Recommande | Gain |
|------------|-----------------|------------|------|
| Carte → Carte | 1.5s | 0.8s | 47% |
| Choix → Effets | 1.0s | 0.5s | 50% |
| Effets → Next | 0.5s | 0.3s | 40% |
| Scene → Scene | 2.0s | 1.0s | 50% |

**Implementation:**
```gdscript
# Animations paralleles, pas sequentielles:
func _apply_choice(direction: String):
    # Lancer en parallele:
    card_tween.slide_out(direction)      # 0.3s
    await get_tree().create_timer(0.15)  # Overlap
    effects_tween.flash_gauges()         # 0.2s
    await get_tree().create_timer(0.1)
    next_card_tween.slide_in()           # 0.3s
    # Total percue: ~0.5s au lieu de 1.5s sequentiel
```

### 4.4 Information "At a Glance"

**Probleme:** Le joueur ne doit jamais se demander "ou en suis-je?"

**Solution: Visual language coherent**

| Information | Representation Visuelle | Position |
|-------------|------------------------|----------|
| Jauges | Barres de couleur (pas de nombres) | Top, horizontal |
| Jauge critique | Pulsation rouge + icone danger | Sur la barre |
| Biome | Couleur de fond + icone | Background subtle |
| Saison | Icone coin superieur droit | Fixe |
| Jour | Nombre discret | Coin inferieur droit |
| Bestiole | Icone emotionnelle | Panel bas |
| Skills dispo | Points lumineux | Sous Bestiole |

### 4.5 Palette Emotionnelle par Etat

| Etat | Couleur Dominante | Ambiance |
|------|-------------------|----------|
| Debut run | Bleu-vert calme | Espoir |
| Milieu safe | Vert equilibre | Controle |
| Tension monte | Jaune-orange | Attention |
| Danger (jauge <20 ou >80) | Rouge pulse | Urgence |
| Twist imminent | Violet flash | Mystere |
| Fin proche | Ambre sombre | Melancolie |

### 4.6 Mobile-First Considerations

**Touch targets:**
- Boutons: minimum 48x48px
- Zone swipe: 60% largeur ecran
- Marges: 16px minimum

**Gestes:**
| Geste | Action |
|-------|--------|
| Swipe gauche | Choix gauche |
| Swipe droite | Choix droite |
| Tap long | Details on-demand |
| Double tap | Activer skill Bestiole |
| Tap jauge | Afficher historique |

**Orientation:**
- Portrait prefere (mobile)
- Landscape supporte (tablette)
- UI s'adapte automatiquement

---

## PARTIE 5: Metriques de Succes a Mesurer

### 5.1 KPIs de Session

| Metrique | Cible | Pourquoi |
|----------|-------|----------|
| Duree session moyenne | 8-10 min | Objectif design |
| Cartes par session | 25-35 | Rythme optimal |
| Temps par carte | 15-20s | Flow maintenu |
| % sessions completees | >60% | Engagement |
| % morts <10 cartes | <20% | Pas frustrant |

### 5.2 KPIs de Rejouabilite

| Metrique | Cible | Pourquoi |
|----------|-------|----------|
| Sessions par jour | 2-3 | Engagement optimal |
| Taux "encore une" | >40% | Hook immediat |
| Retention D1 | >50% | Premiere impression |
| Retention D7 | >25% | Engagement moyen terme |
| Runs avant fin secrete | 80-120 | Longevite |

### 5.3 KPIs de Satisfaction

| Metrique | Mesure | Cible |
|----------|--------|-------|
| NPS | Sondage | >40 |
| Avis stores | Moyenne | >4.2/5 |
| Partage social | Captures/partages | >5% |
| Completion rate | % joueurs ayant vu 4+ fins | >30% |

### 5.4 Tests A/B Recommandes

| Test | Variante A | Variante B | Metrique |
|------|------------|------------|----------|
| Grace period | 3 cartes | 5 cartes | Retention D1 |
| Voix Merlin | Toujours | Selective | Temps session |
| Transitions | 1.5s | 0.8s | Cartes/session |
| Pity system | Subtil | Explicite | Frustration |
| Mots/carte | 60 max | 40 max | Temps/carte |

---

## PARTIE 6: Differenciation de Reigns

### 6.1 Ce que DRU fait mieux

| Aspect | Reigns | DRU | Avantage DRU |
|--------|--------|-----|--------------|
| Narration | Pre-ecrite | LLM generee | Infinie variete |
| Personnalite narrateur | Neutre | Merlin joyeux/sombre | Attachement |
| Compagnon | Aucun | Bestiole | Lien emotionnel |
| Profondeur cachee | Faible | 6 ressources invisibles | Rejouabilite |
| Lore | Minimal | Mythologie celtique | Immersion |
| Verite secrete | Aucune | Apocalypse cachee | Long terme |
| Audio | Sons basiques | Voix Merlin | Personnalite |

### 6.2 Ce que DRU doit eviter

| Piege Reigns | Solution DRU |
|--------------|--------------|
| Repetition lassante | LLM + contexte = cartes uniques |
| Mort arbitraire | Pity system + grace period |
| Manque de but | Verite cachee a decouvrir |
| Personnages oubliables | Merlin + Bestiole memorables |
| Fin abrupte | Resolution narrative meme en mort |

### 6.3 Innovation DRU: Le "JDR Parlant"

**Concept unique:**
> Chaque partie est une micro-session de JDR ou Merlin est le MJ
> Le joueur ne controle pas un personnage, IL EST le joueur de JDR
> Les choix sont narratifs, pas mecaniques

**Implementation:**
- Merlin s'adresse directement au joueur ("Tu vois...")
- Les choix sont formules a la premiere personne ("Je refuse")
- Le ton est conversationnel, pas litteraire
- Les effets sont presentes comme consequences narratives

---

## PARTIE 7: Plan d'Implementation

### 7.1 Priorites Immediates (Sprint 1)

| Task | Effort | Impact |
|------|--------|--------|
| Reduire mots/carte (60→45 avg) | Faible | Haut |
| Accelerer transitions (1.5s→0.8s) | Moyen | Haut |
| Implementer grace period (5 cartes) | Moyen | Haut |
| Ajouter "encore une?" bouton | Faible | Moyen |

### 7.2 Priorites Court Terme (Sprint 2-3)

| Task | Effort | Impact |
|------|--------|--------|
| Voix selective Merlin | Moyen | Haut |
| Feedback visuel jauges ameliore | Moyen | Moyen |
| Ecran fin de run informatif | Moyen | Haut |
| Pity system implementation | Moyen | Haut |

### 7.3 Priorites Moyen Terme (Sprint 4-6)

| Task | Effort | Impact |
|------|--------|--------|
| Analytics tracking | Haut | Critique |
| A/B testing framework | Haut | Critique |
| Optimisation mobile | Moyen | Haut |
| Polish animations | Moyen | Moyen |

---

## Annexes

### A. Checklist Validation UX

Avant release, verifier:

- [ ] Session moyenne < 10 minutes
- [ ] Mort <10 cartes = <20% des runs
- [ ] Texte lisible (16px minimum)
- [ ] Touch targets >= 48px
- [ ] Transitions fluides (<1s)
- [ ] Feedback sur chaque action
- [ ] "Encore une?" accessible
- [ ] Voix ne ralentit pas le pace
- [ ] Jauges comprehensibles sans tutoriel
- [ ] Progression visible meme en mort

### B. Questions Ouvertes

1. Faut-il un mode "Partie Rapide" (5 min) en plus?
2. Le joueur peut-il accelerer/skipper la voix?
3. Notifications de "streak" entre sessions?
4. Leaderboard sessions courtes?
5. Achievements specifiques aux parties courtes?

### C. References Recherche

- Reigns session design (TouchArcade, SteamSpy)
- Mobile game UX trends 2025 (Red Apple Technologies, Game-Ace)
- Roguelite run length psychology (Medium, Gamasutra)
- Card narrative pacing (Emily Short, Larksuite)

---

*Document cree: 2026-02-08*
*Agent: UX Research*
*Status: COMPLETE - En attente validation*
