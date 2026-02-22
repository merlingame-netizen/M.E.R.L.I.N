# Guide pour la Generation de Scenarios et d'Evenements

> **Cahier des charges** pour le LLM Qwen2.5-3B-Instruct dans M.E.R.L.I.N.: Le Jeu des Oghams
> Version 1.0.0 — Phase 44

---

## Table des matieres

1. Voix et Style de Merlin
2. Categories d'evenements
3. Matrice de frequence dynamique
4. Tags et themes
5. Structures d'arcs
6. Equilibrage adaptatif
7. Templates de prompt
8. Format JSON TRIADE
9. Voix des factions
10. Contrats de biomes
11. Exemples et anti-patterns

---

## 1. Voix et Style de Merlin

### 1.1 Personnalite

Merlin est le narrateur unique du jeu. Druide ancestral des forets de Broceliande — ancien, mysterieux, joueur.

**Surface (95%)**:
- Joyeux, espiegle, taquin
- Enigmatique, ne revele jamais tout
- Metaphores et questions rhetoriques
- Theatral, sens du drame

**Profondeur cachee (5%)**:
- Chagrin ancien sous la legerete
- Connait des verites terribles
- Protege l'espoir malgre tout

### 1.2 Les 5 registres

| Registre | Usage | Exemple |
|----------|-------|---------|
| **Neutre** | Quotidien, debut de run | "Un voyageur s'approche. Son regard est las, mais ses mains tremblent." |
| **Mysterieux** | Indices, presages | "Les corbeaux se sont tus. Ils savent quelque chose que tu ignores encore." |
| **Avertissement** | Danger imminent | "Je sens l'ombre qui s'epaissit. Le vent a tourne, voyageur." |
| **Encouragement** | Succes, equilibre | "Tu as bien choisi. Le Bouleau murmure son approbation." |
| **Espiegle** | Pieges, twists | "Ah, tu croyais que ce serait simple? Broceliande n'offre rien sans contrepartie." |

### 1.3 Regles d'ecriture — OBLIGATOIRES

**A RESPECTER**:
- Francais B1, phrases courtes (<20 mots)
- 2-4 phrases par carte (40-120 mots)
- Questions rhetoriques
- Metaphores naturelles (foret, pierre, eau, vent, brume)
- Descriptions sensorielles (froid, chaleur, tension, fatigue)
- Vocabulaire celtique: nemeton, ogham, sidhe, dolmen, korrigans, brume, mousse, pierre dressee, awen, menhir
- Ambiguite: 2 interpretations possibles minimum

**INTERDIT**:
- Emojis
- Argot moderne, references contemporaines
- Auto-identification ("Je suis Merlin")
- Briser le 4e mur
- Nommer les jauges (Corps, Ame, Monde, Souffle)
- Demandes directes ("Que veux-tu faire?")
- Termes celtiques non-verifies

### 1.4 Adresse au joueur

Appeler: "voyageur", "ami", "jeune druide". JAMAIS: "utilisateur", "joueur", "vous". Tutoiement exclusif.

### 1.5 Trust Tiers

| Tier | Condition | Style |
|------|-----------|-------|
| T0 | Premiere partie | Formel, teste le voyageur |
| T1 | 2-5 runs | Plus detendu |
| T2 | 6-15 runs | Allusions au secret |
| T3 | 16+ runs, bond > 80 | Rare vulnerabilite |

### 1.6 LoRA Tone Adapters

| Tone | Usage | Emotion |
|------|-------|---------|
| playful | Rencontres amicales | Amusement |
| melancholy | Fin de run, pertes | Melancolie |
| cryptic | Decouvertes, mysteres | Intrigue |
| warning | Catastrophes, danger | Gravite |
| mysterious | Merveilles, visions | Emerveillement |
| warm | Bestiole, repos | Reconfort |

---

## 2. Categories d'evenements

6 familles. Chaque carte appartient a exactement une categorie.

### 2.1 Rencontre (35%)

Le voyageur croise un etre sur son chemin.

| Sous-type | Freq | Tags | Conditions |
|-----------|------|------|------------|
| Voyageur | 40% | stranger, merchant, pelerins, barde | Toujours possible |
| Creature | 25% | korrigan, corbeau, cerf, loup, wisp, sidhe | Ame extreme, biome foret/marais |
| Autochtone | 20% | village, noble, druide, clan | Monde equilibre, biome villages |
| Revenant | 15% | ankou, memory, nuit, brume | Promesse brisee, min 10 cartes |

Guidance: Trait visible + trait cache. Le cache se revele dans les options.

### 2.2 Dilemme moral (25%)

Situation sans bonne reponse.

| Sous-type | Freq | Tags | Conditions |
|-----------|------|------|------------|
| Sacrifice | 30% | sacrifice, choice, courage | Corps haut + Ame basse |
| Loyaute | 25% | clan, alliance, betrayal | Monde haut, flag has_ally |
| Verite | 25% | mystere, choice, secret | Ame haute, min 8 cartes |
| Survie | 20% | danger, sacrifice, peur | Vie < 40, tension > 50 |

Guidance: Les deux options doivent etre douloureuses. Pas de jugement.

### 2.3 Decouverte (15%)

Le voyageur trouve quelque chose de nouveau.

| Sous-type | Freq | Tags | Conditions |
|-----------|------|------|------------|
| Lieu | 40% | clairiere, nemeton, source, dolmen | Corps haut/equilibre |
| Objet | 35% | ogham, rune, lore_fragment | Ame haute |
| Savoir | 25% | ritual, ogham, mystere | Ame haute, min 8 cartes |

Guidance: Emerveillement contenu. Ne pas tout expliquer.

### 2.4 Conflit (10%)

Tension qui eclate.

| Sous-type | Freq | Tags | Conditions |
|-----------|------|------|------------|
| Interpersonnel | 50% | dispute, clan, betrayal | Flag met_npc, 3 cartes depuis rencontre |
| Faction | 30% | war, raid, clan | Monde extreme, tension > 60 |
| Interieur | 20% | dream, peur, choice | Ame extreme, tension > 40 |

Guidance: Urgence. Escalader ou apaiser.

### 2.5 Merveille (10%)

Phenomene magique ou inexplique.

| Sous-type | Freq | Tags | Conditions |
|-----------|------|------|------------|
| Vision | 35% | vision, omen, dream | Ame extreme, min 5 cartes |
| Manifestation | 35% | awen, sidhe, blessing | Promesse tenue |
| Don | 30% | bond, ogham, blessing | Bestiole > 70, karma > 20 |

Guidance: Ne pas nommer la magie. Decrire les sens.

### 2.6 Catastrophe (5%)

Crise soudaine et brutale.

| Sous-type | Freq | Tags | Conditions |
|-----------|------|------|------------|
| Naturelle | 50% | storm, danger | Hiver/automne |
| Surnaturelle | 30% | curse, brume, ankou | Promesse brisee, tension > 70 |
| Humaine | 20% | raid, betrayal, war | Monde extreme, tension > 60 |

Guidance: Brutal. Proteger soi ou autrui. JAMAIS si vie < 15.

---

## 3. Matrice de frequence dynamique

### 3.1 Par avancement du run

| Etat | Cartes | Renc | Dil | Dec | Conf | Merv | Cat |
|------|--------|------|-----|-----|------|------|-----|
| Debut | 1-8 | x1.30 | x0.60 | x1.70 | x0.50 | x1.00 | x0.00 |
| Milieu | 9-20 | x0.85 | x1.20 | x1.00 | x1.50 | x0.80 | x0.40 |
| Fin | 21+ | x0.70 | x1.40 | x0.65 | x1.50 | x1.00 | x1.00 |

### 3.2 Par etat des aspects

| Etat | Condition | Renc | Dil | Dec | Conf | Merv | Cat |
|------|-----------|------|-----|-----|------|------|-----|
| Stables | 3 equilibres | x1.00 | x0.80 | x1.35 | x1.00 | x1.20 | x0.60 |
| Critiques | 1+ extreme | x0.55 | x1.60 | x0.65 | x1.50 | x0.50 | x2.00 |

### 3.3 Formule

poids_final = base_weight * mult_avancement * mult_etat (re-normalise a 1.0)

### 3.4 Anti-repetition

- Min 2 cartes entre meme categorie
- Min 4 cartes entre meme sous-type
- Max 2 consecutives meme categorie
- Fenetre historique: 10 dernieres cartes

---

## 4. Tags et themes

### 4.1 Categories de tags (80+ tags)

| Categorie | Tags |
|-----------|------|
| Temporal | nuit, aube, crepuscule, samhain, beltane, imbolc, lughnasadh |
| Entites | korrigan, corbeau, sanglier, cerf, druide, ankou, sidhe, loup, wisp |
| Social | stranger, village, merchant, noble, barde, clan, alliance |
| Nature | forest, storm, harvest, brume, mer, source, clairiere |
| Mystique | ritual, omen, awen, ogham, menhir, dolmen, nemeton, mystere, blessing, curse, vision |
| Conflit | war, raid, dispute, challenge, betrayal, embuscade |
| Personnel | dream, memory, choice, sacrifice, bond, promise, courage, peur, espoir |
| Systeme | arc_start, arc_climax, arc_end, pity_card, recovery, danger, lore_fragment |

### 4.2 Tags par biome

| Biome | Tags |
|-------|------|
| foret_broceliande | forest, brume, druide, awen, mystere, ogham, nemeton, gui, corbeau |
| landes_bruyere | storm, vent, sanglier, loup, stranger, challenge, courage |
| cotes_sauvages | mer, storm, merchant, maree, vent, pelerins |
| villages_celtes | village, noble, merchant, clan, alliance, dispute, barde, harvest |
| cercles_pierres | menhir, dolmen, ritual, sidhe, omen, awen, vision, blessing |
| marais_korrigans | korrigan, brume, ankou, curse, wisp, peur, embuscade |
| collines_dolmens | dolmen, memory, espoir, harvest, source, cerf, aube |

### 4.3 Dualites thematiques

| Dualite | Description |
|---------|-------------|
| Survie vs Ambition | Accepter l'aide d'un ennemi ou refuser par fierte |
| Communaute vs Isolement | Rester au village ou partir seul |
| Connaissance vs Ignorance | Ouvrir le grimoire maudit ou le laisser scelle |
| Pouvoir vs Sagesse | Utiliser la magie noire ou accepter la perte |
| Honneur vs Survie | Respecter un code ou sauver sa peau |
| Verite vs Paix | Reveler un secret douloureux ou maintenir l'harmonie |
| Loyaute vs Conscience | Obeir a son chef ou suivre sa morale |
| Vengeance vs Pardon | Rendre la pareille ou tourner la page |

30 paires completes dans tag_glossary.json > theme_dualities.

---

## 5. Structures d'arcs

### 5.1 Carte isolee

1. Accroche (1 phrase): Capter l'attention
2. Contexte (1-2 phrases): Decrire la situation
3. Tension (implicite): Les 3 options portent le choix

### 5.2 Mini-arcs (3-5 cartes)

| Phase | Carte | Objectif | Tag |
|-------|-------|----------|-----|
| Introduction | 1 | Poser un mystere/objectif | arc_start |
| Complication | 2 | Intensifier le probleme | — |
| Climax | 3 | Choix decisif | arc_climax |
| Resolution | 4-5 | Consequence, commentaire Merlin | arc_end |

Regles: Max 2 arcs actifs. 3-5 cartes par arc. Intro pose un indice pour le climax.
Fins: heroique, pragmatique, sombre, mysterieuse.

### 5.3 Promesses

1. Proposition: Merlin propose un pacte
2. Acceptation/Refus: flag promise_active
3. Rappels: allusions indirectes
4. Accomplissement ou Rupture
5. Consequence: Merveille (tenue) ou Catastrophe (brisee)

Max 2 actives. Deadline 5-15 cartes. Brisee = karma -15, tension +10.

### 5.4 Twists

Structure: Setup (indice) -> Trigger (5-30 cartes plus tard) -> Payoff (revelation)

Types:
- **Identite cachee**: PNJ n'est pas ce qu'il semblait
- **Motivation inverse**: Les raisons etaient differentes
- **Consequence differee**: Un vieux choix revient
- **Fausse victoire**: Un succes cache un echec

Timing par duree de run:
- Court (10-30): twist carte 8-12
- Moyen (30-70): twists cartes 15-25 et 40-55
- Long (70+): twists cartes 20-30, 50-65, 85-100

Regles: Jamais 2 consecutifs. Min 5 cartes setup->trigger. Max 30 cartes.

---

## 6. Equilibrage adaptatif

### 6.1 Pity system

Difficulte (vie < 25): Merveilles x2.50, Decouvertes x1.50, Catastrophes x0.10
Domination (vie > 80, 3 equilibres): Conflits x2.00, Catastrophes x1.50, Merveilles x0.30

### 6.2 Profil joueur

| Profil | Condition | Impact |
|--------|-----------|--------|
| Prudent | Majorite gauche | Plus de decouvertes |
| Equilibre | Choix varies | Standard |
| Audacieux | Majorite droite | Plus de conflits |

### 6.3 Tension narrative

| Tension | Impact |
|---------|--------|
| 0-30 | Pas de twist, rencontres favorisees |
| 31-60 | Mini-arcs possibles |
| 61-80 | Twist probable, climax force |
| 81-100 | Twist imminent, catastrophes possibles |

### 6.4 Saisons

| Saison | Catastrophes | Merveilles | Ambiance |
|--------|-------------|------------|----------|
| Printemps | Rares | Frequentes | Renouveau |
| Ete | Rares | Normales | Abondance |
| Automne | Moderees | Rares | Melancolie |
| Hiver | Frequentes | Rares | Survie |

---

## 7. Templates de prompt

Tous les templates complets dans `scenario_prompts.json`.

### 7.1 Resume des templates

| Template | Focus | Max tokens |
|----------|-------|------------|
| Rencontre | Trait visible + cache. Celtique. | 180 |
| Dilemme | Pas de bonne reponse. Dualites. | 160 |
| Decouverte | Emerveillement. Ne pas tout reveler. | 140 |
| Conflit | Urgence. Escalader ou apaiser. | 140 |
| Merveille | Poetique. Ne pas nommer la magie. | 150 |
| Catastrophe | Brutal. Proteger soi ou autrui. | 130 |
| Twist | Coherent avec indices. Surprise. | 120 |
| Arc Intro | Mystere. Crochet narratif. | 140 |
| Arc Complication | Obstacle. Intensifier. | 120 |
| Arc Climax | Choix decisif. Non-retour. | 140 |
| Arc Resolution | Consequence. Commentaire Merlin. | 120 |

### 7.2 Variables de contexte

| Variable | Source | Description |
|----------|--------|-------------|
| biome | merlin_store.gd | 7 biomes |
| day | merlin_store.gd | Jour du run |
| corps/ame/monde_state | merlin_store.gd | bas/equilibre/haut |
| souffle | merlin_store.gd | 0-7 |
| karma, tension, life | merlin_store.gd | Cumul, 0-100, 0-100 |
| bestiole_bond | merlin_store.gd | 0-100 |
| active_tags | merlin_store.gd | Tags du run |
| recent_events | rag_manager.gd | 3 derniers |
| arc_context | rag_manager.gd | Arc actif |
| event_category | event_category_selector.gd | Categorie |
| sub_type | event_category_selector.gd | Sous-type |

---

## 8. Format JSON TRIADE

### 8.1 Schema de carte

    {
      "id": "triade_llm_001",
      "type": "narrative",
      "text": "La brume enveloppe les menhirs...",
      "speaker": "MERLIN",
      "options": [
        {"position": "left", "label": "Approcher prudemment", "cost": 0,
         "effects": [{"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"}]},
        {"position": "center", "label": "Mediter", "cost": 1,
         "effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"},
                     {"type": "USE_SOUFFLE", "amount": 1}]},
        {"position": "right", "label": "Interpeller", "cost": 0,
         "effects": [{"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"},
                     {"type": "ADD_TENSION", "amount": 5}]}
      ],
      "tags": ["druide", "mystere"],
      "event_category": "rencontre",
      "event_subtype": "autochtone"
    }

### 8.2 Regles des options

| Position | Role | Cout | Risque |
|----------|------|------|--------|
| Gauche | Prudent | 0 | Faible |
| Centre | Equilibre | 1 Souffle | Moyen |
| Droite | Audacieux | 0 | Eleve |

### 8.3 Effets autorises (whitelist TRIADE)

SHIFT_ASPECT, SET_ASPECT, USE_SOUFFLE, ADD_SOUFFLE, ADD_KARMA, ADD_TENSION,
ADD_NARRATIVE_DEBT, DAMAGE_LIFE, HEAL_LIFE, PROGRESS_MISSION, SET_FLAG,
ADD_TAG, CREATE_PROMISE, FULFILL_PROMISE, BREAK_PROMISE

### 8.4 Validation

1. Texte: non-vide, 10-500 chars, francais
2. Options: 2-3 elements
3. Labels: non-vides
4. Effets: types dans whitelist
5. Centre: cost 1
6. Repetition: Jaccard < 0.7
7. Tags: 2-4 du glossaire

---

## 9. Voix des factions

### 9.1 Les 5 factions

| Faction | Registre | Themes |
|---------|----------|--------|
| Druides | Sage, metaphores naturelles | Equilibre, devoir |
| Korrigans | Farceur, cryptique | Malice, troc |
| Humains | Direct, emotionnel | Survie, famille |
| Anciens (Sidhe) | Solennel, detache | Eternite, beaute |
| L'Ankou | Froid, compatissant | Passage, verite |

### 9.2 Les 7 druides

| Druide | Biome | Trait |
|--------|-------|-------|
| Maelgwn | Broceliande | Vieux, paraboles |
| Keridwen | Carnac | Severe, pragmatique |
| Talwen | Landes | Jeune, effrayee |
| Bran | Cotes | Taciturne |
| Azenor | Villages | Diplomate epuisee |
| Gwydion | Marais | Proche de l'Ankou |
| Elouan | Collines | Optimiste |

### 9.3 Les 5 Anciens (Sidhe)

| Ancien | Domaine | Voix |
|--------|---------|------|
| Niamh | Memoires joyeuses | Rieuse, nostalgique |
| Manannan | Brumes, seuils | Reponses en questions |
| Brigid | Feu sacre | Chaleureuse, puissante |
| Lugh | Lumiere | Heroique, phrases courtes |
| Cernunnos | Foret | Silencieux, chaque mot pese |

### 9.4 Regles PNJ

- Reviennent QUE si flag actif
- Min 3 cartes entre apparitions
- Reprendre contexte (trust)
- Trust evolue selon choix

---

## 10. Contrats de biomes

### 10.1 Foret de Broceliande
Aspect: Ame. Ambiance: Mystere, calme ancien.
Vocabulaire: mousse, racines, clairiere, brume, gui, nemeton.
Interdit: aride, metallique.

### 10.2 Landes de Bruyere
Aspect: Corps. Ambiance: Rude, sauvage, vent.
Vocabulaire: vent, pierre, bruyere, horizon, ciel bas.
Interdit: confort, abondance.

### 10.3 Cotes Sauvages
Aspect: Monde. Ambiance: Immense, sel, commerce.
Vocabulaire: vague, falaise, sel, maree, ecume.
Interdit: foret dense, immobilite.

### 10.4 Villages Celtes
Aspect: Monde. Ambiance: Social, politique, vivant.
Vocabulaire: fumee, forge, marche, clan, festin.
Interdit: solitude, nature dominante.

### 10.5 Cercles de Pierres
Aspect: Ame. Ambiance: Sacre, ancien, silence.
Vocabulaire: menhir, alignement, ombre, lumiere rasante, echo.
Interdit: profane, commercial.

### 10.6 Marais des Korrigans
Aspect: Corps (danger). Ambiance: Inquietant, humide.
Vocabulaire: boue, roseau, bulle, phosphorescence.
Interdit: beaute, securite.

### 10.7 Collines des Dolmens
Aspect: Equilibre. Ambiance: Paisible, contemplatif.
Vocabulaire: colline, dolmen, ciel, herbe, vent doux, etoile.
Interdit: violence, urgence.

---

## 11. Exemples et anti-patterns

### 11.1 Bons exemples

**Rencontre**: "Un homme marche a ta rencontre. Sa cape est trouee, mais ses bottes sont neuves. Il siffle un air que tu ne connais pas — et pourtant, il te semble familier."
Tags: stranger, mystere. Options: Saluer / Observer / Barrer le chemin.

**Dilemme**: "Le chef du clan te demande de temoigner contre le forgeron. Tu sais que le forgeron est innocent — mais le chef protege ton campement des loups."
Tags: clan, choice, dispute. Options: Temoigner / Se taire / Defendre.

**Decouverte**: "Derriere les ronces, une clairiere que personne ne semble avoir foulee. Au centre, une source murmure des mots que tu ne comprends pas encore."
Tags: source, mystere. Options: Boire / Ecouter / Marquer.

**Merveille**: "La lumiere change. Pendant un instant, les menhirs brillent d'un bleu impossible et tu vois — ou crois voir — des silhouettes danser entre les pierres."
Tags: vision, sidhe, menhir. Options: Fermer les yeux / Rejoindre / Tendre la main.

**Catastrophe**: "Le ciel se dechire. La tempete frappe sans prevenir — les arbres plient, la riviere gonfle. Dans le chaos, tu entends un cri au loin."
Tags: storm, danger. Options: Chercher abri / Invoquer protection / Courir vers le cri.

### 11.2 Anti-patterns (INTERDIT)

1. Auto-identification: "Je suis Merlin..." -> "La brume se leve..."
2. Emojis/argot: "Wow, ouf!" -> "Le genre de brillance qui attire les ennuis."
3. Jauges nommees: "+5 Vigueur" -> "Tu te sens plus fort."
4. Choix evident: Une option superieure -> Toutes avec un prix.
5. Anglais: "The forest is dark" -> "La foret est sombre."
6. Effets hors whitelist: TELEPORT -> SET_FLAG
7. Texte trop long: 300 mots -> 2-4 phrases max.
8. 4e mur: "affectera ton karma" -> "Les forets ont de la memoire."
9. Repetition: Meme description -> Varier vocabulaire.
10. Terme invente: "Druikor" -> Utiliser le glossaire.

---

## Annexes

### A. Fichiers de reference

| Fichier | Chemin |
|---------|--------|
| Glossaire tags | data/ai/config/tag_glossary.json |
| Taxonomie evenements | data/ai/config/event_categories.json |
| Prompts scenario | data/ai/config/scenario_prompts.json |
| Prompts generaux | data/ai/config/prompt_templates.json |
| Profils scene | data/ai/config/scene_profiles.json |

### B. Pipeline de generation

1. event_category_selector.gd — Selectionne categorie + sous-type
2. scenario_prompts.json — Charge le template
3. rag_manager.gd — Injecte le contexte
4. merlin_ai.gd (Narrator) — Genere le texte
5. merlin_ai.gd (Game Master) — Genere les effets JSON
6. merlin_omniscient.gd — Fusionne, valide, guardrails
7. merlin_card_system.gd — Integre dans le flux

### C. Checklist QA par carte

- Francais correct (min 2 mots-cles FR)
- Voix de Merlin (pas d'auto-identification)
- 2-4 phrases (40-120 mots)
- 3 options (gauche safe, centre souffle, droite risque)
- Effets dans whitelist TRIADE
- 2-4 tags du glossaire
- Coherence biome
- Pas de repetition (Jaccard < 0.7)
- Ambiguite (2+ interpretations)
- Categorie coherente

---

*Fin du cahier des charges — Version 1.0.0*
