# DOC 13 — Systeme de Profondeur Cachee

*Document cree: 2026-02-08*
*Status: DESIGN VALIDE - En attente implementation*

---

## Vision

Le jeu est **simple a jouer** (3 boutons, symboles clairs) mais **profond a maitriser**. Des mecaniques invisibles influencent le jeu sans que le joueur ait a les comprendre pour s'amuser.

**Philosophie:** "Easy to learn, impossible to master"

**Revelation progressive:**
- Runs 1-5: Aucun indice, le joueur decouvre
- Runs 6-10: Merlin fait des allusions
- Runs 11+: Indices plus clairs, patterns reveles

---

## PARTIE 1: Resonances entre Aspects

### 1.1 Concept

Quand 2 ou 3 aspects sont dans le **meme etat**, une **resonance** se produit. Ces effets ne sont jamais expliques — le joueur doit les decouvrir.

### 1.2 Resonances Positives (Equilibre)

| Aspects | Nom | Effet Invisible |
|---------|-----|-----------------|
| Corps + Ame | **Harmonie Interieure** | +1 Souffle gratuit |
| Corps + Monde | **Ancrage Terrestre** | Prochaine transition Corps annulee |
| Ame + Monde | **Influence Subtile** | Option Centre gratuite 1x |
| Corps + Ame + Monde | **Triade Parfaite** | Revele la prochaine carte + mission progress |

### 1.3 Resonances de Tension (Etats Extremes)

| Aspects | Nom | Effet Invisible |
|---------|-----|-----------------|
| Corps Haut + Ame Haute | **Fievre Mystique** | Tous les effets x2 (risque!) |
| Corps Bas + Ame Basse | **Epuisement Total** | Prochaine carte = derniere chance |
| Monde Haut + Corps Haut | **Domination** | Cartes de conflit forcees |
| Monde Bas + Ame Basse | **Isolement Absolu** | Mission bloquee 3 cartes |
| Corps Bas + Monde Haut | **Le Tyran Fragile** | +20% chance retournement |
| Ame Haute + Monde Bas | **Le Prophete Exile** | Visions prophetiques (hints) |

### 1.4 Merlin Commente (apres 5+ runs)

```
[Harmonie Interieure detectee]
MERLIN: "Tiens... tu sembles... aligne aujourd'hui. C'est rare."

[Fievre Mystique detectee]
MERLIN: "Tu brules de l'interieur. C'est... dangereux. Et beau."

[Triade Parfaite detectee]
MERLIN: "Trois. Comme les rayons du triskell. Tu comprends, n'est-ce pas?"
```

---

## PARTIE 2: Memoire du Style de Jeu

### 2.1 Les 3 Axes de Personnalite

Le jeu track secretement le style du joueur:

```gdscript
var player_profile := {
    "audace": 0.0,      # -1.0 (prudent) a +1.0 (audacieux)
    "altruisme": 0.0,   # -1.0 (egoiste) a +1.0 (altruiste)
    "spirituel": 0.0,   # -1.0 (materiel) a +1.0 (spirituel)
}
```

### 2.2 Calcul des Axes

| Axe | Augmente si | Diminue si |
|-----|-------------|------------|
| **Audace** | Choix Droite (risque) | Choix Centre ou Gauche |
| **Altruisme** | Monde monte, sacrifices | Monde descend, egoisme |
| **Spirituel** | Ame prioritaire | Corps prioritaire |

### 2.3 Effets sur le Jeu

| Profil | Effet Invisible |
|--------|-----------------|
| Tres Prudent (<-0.7) | Cartes "safe" plus frequentes |
| Tres Audacieux (>0.7) | Cartes a haut risque/recompense |
| Tres Altruiste (>0.7) | PNJ offrent de l'aide |
| Tres Egoiste (<-0.7) | PNJ mefients, prix plus eleves |
| Tres Spirituel (>0.7) | Plus de visions, Oghams boostes |
| Tres Materiel (<-0.7) | Plus de ressources, moins de magie |

### 2.4 Merlin Commente (apres 5+ runs)

```
[Profil audacieux detecte]
MERLIN: "Tu fonces toujours tete baissee, n'est-ce pas? Ca me rappelle... quelqu'un."

[Profil altruiste detecte]
MERLIN: "Le monde t'importe plus que toi-meme. C'est noble. Et dangereux."

[Profil spirituel detecte]
MERLIN: "Tu cherches l'Ame avant le Corps. Les anciens druides auraient approuve."

[Changement de profil detecte]
MERLIN: "Tiens... tu changes. Je ne suis pas sur d'aimer ca. Ou peut-etre que si."
```

### 2.5 Fins Secretes par Profil

| Profil | Fin Secrete Accessible |
|--------|------------------------|
| Max Audace + Max Altruisme | "Le Heros Tragique" |
| Max Prudence + Max Spirituel | "Le Sage Invisible" |
| Max Egoisme + Max Materiel | "Le Survivant" |
| Parfaitement Equilibre (0,0,0) | "L'Observateur" |

---

## PARTIE 3: Echos Inter-Runs

### 3.1 Concept

Les actions d'une run laissent des **traces** dans la suivante. Le monde "se souvient".

### 3.2 Types d'Echos

| Evenement Run N | Echo Run N+1 |
|-----------------|--------------|
| Mort par Corps Epuise | Carte speciale: "Une fatigue ancienne..." |
| Mort par Ame Possedee | Visions plus frequentes, +fragiles |
| Aide a un villageois | Ce villageois revient et t'aide |
| Promesse brisee | PNJ hostile: "Je t'ai deja vu..." |
| Victoire complete | Merlin: "Tu as deja reussi. Refais-le." |
| Utilise beaucoup un Ogham | Cet Ogham est "fatigue" (cooldown +1) |
| 3+ runs meme profil | Merlin commente le pattern |

### 3.3 Echos Narratifs (Exemples)

```
[Mort precedente par Ame Basse]
MERLIN: "Tu as l'air... hante. Comme si une partie de toi etait restee... ailleurs."

[Victoire precedente]
MERLIN: "Ah, te revoila. Tu as reussi avant. Le feras-tu encore?"

[Meme mort 3x consecutif]
MERLIN: "Encore? Tu retombes dans les memes pieges. Interessant."
```

### 3.4 Implementation Technique

```gdscript
# Sauvegarde meta (persistant)
var echo_data := {
    "last_death": "ame_basse",  # cause de la derniere mort
    "last_victory": false,
    "helped_npcs": ["villageois_01", "druide_noir"],
    "broken_promises": ["promesse_lune"],
    "run_count": 7,
    "profile_history": [0.3, 0.5, 0.2],  # derniers profils
}
```

---

## PARTIE 4: Synergies Oghams Cachees

### 4.1 Concept

Certaines combinaisons de 3 Oghams equipes creent des **synergies secretes**.

### 4.2 Tableau des Synergies

| Trio | Nom | Effet Secret |
|------|-----|--------------|
| Beith + Luis + Fearn | **L'Aube** | +1 Souffle au debut de run |
| Duir + Tinne + Coll | **Le Chene Sacre** | Corps ne descend jamais sous Equilibre |
| Saille + Nuin + Huath | **Les Liens** | Monde +1 a chaque choix altruiste |
| Quert + Muin + Gort | **La Recolte** | Mission progress 2x plus vite |
| Ngetal + Straif + Ruis | **Le Passage** | Transition = +1 Souffle |
| Ailm + Ioho + Onn | **La Vision** | Revele tous les impacts |
| Luis + Huath + Straif | **Les Ombres** | Cartes sombres bonus |
| Beith + Quert + Ioho | **Le Cycle** | Resonances 2x plus frequentes |

### 4.3 Decouverte Progressive

- Runs 1-10: Aucun indice
- Runs 11-20: Merlin: "Ces Oghams... ensemble... il y a quelque chose."
- Runs 21+: Bestiole reagit quand une synergie est active

### 4.4 Merlin Commente

```
[Synergie L'Aube detectee]
MERLIN: "Beith, Luis, Fearn... Le commencement, la memoire, la resistance. Tu as bien choisi."

[Synergie Les Ombres detectee]
MERLIN: "Ces Oghams... ils attirent les tenebres. Es-tu pret pour ce que tu vas voir?"
```

---

## PARTIE 5: Quetes Cachees

### 5.1 Concept

Des **objectifs secrets** existent en parallele de la mission principale. Le joueur ne sait pas qu'ils existent.

### 5.2 Liste des Quetes Cachees

| Quete | Condition | Recompense |
|-------|-----------|------------|
| **Le Pacifiste** | 10 cartes sans choix Droite | +2 Souffles |
| **L'Equilibriste** | 3 Equilibres pendant 5 cartes | Fin secrete accessible |
| **Le Temeraire** | 5 choix Droite consecutifs | Carte legendaire |
| **L'Econome** | Finir run avec 7 Souffles | Ogham secret (Eadha) |
| **Le Curieux** | Visiter 4+ biomes en 1 run | Fragment de lore |
| **Le Fidele** | Tenir 3 promesses en 1 run | Merlin revele un secret |
| **Le Briseur** | Briser 2 promesses en 1 run | Fin sombre exclusive |
| **L'Ancien** | Survivre 50+ cartes | Dialogue meta de Merlin |
| **Le Silencieux** | 20 cartes sans utiliser d'Ogham | Bestiole parle |
| **Le Prodigue** | Utiliser 15+ Souffles en 1 run | Vision du passe |

### 5.3 Revelation (apres 5+ runs)

Quand une quete est presque accomplie, Merlin fait une allusion:

```
[Pacifiste a 8/10 cartes]
MERLIN: "Tu evites le conflit avec constance. C'est... inhabituel."

[Econome a 6/7 Souffles]
MERLIN: "Tu gardes tes Souffles precieusement. Pourquoi? Tu attends quelque chose?"
```

---

## PARTIE 6: Cycles Lunaires

### 6.1 Concept

La **phase de la lune** (calculee en temps reel OU simulee) modifie subtilement le jeu.

### 6.2 Les 4 Phases

| Phase | Effet sur Corps | Effet sur Ame | Effet sur Monde |
|-------|-----------------|---------------|-----------------|
| **Nouvelle Lune** | Normal | Volatile (+) | Stable |
| **Premier Quartier** | Monte facilement | Normal | Normal |
| **Pleine Lune** | Normal | Oghams +50% | Volatile |
| **Dernier Quartier** | Descend facilement | Normal | Stable |

### 6.3 Effets Additionnels

| Phase | Bonus Cache |
|-------|-------------|
| Nouvelle Lune | Cartes mystiques plus frequentes |
| Premier Quartier | Regeneration Souffle +1/run |
| Pleine Lune | Synergies Oghams 2x effet |
| Dernier Quartier | Echos inter-runs plus forts |

### 6.4 Merlin Commente (apres 10+ runs)

```
[Pleine Lune]
MERLIN: "La lune est pleine ce soir. Tu sens ca? La magie coule plus... librement."

[Nouvelle Lune]
MERLIN: "Pas de lune cette nuit. Les ombres sont plus... presentes."
```

---

## PARTIE 7: Personnalite de Bestiole

### 7.1 Concept

Bestiole developpe une **personnalite** basee sur le style de jeu du joueur.

### 7.2 Les 5 Personnalites

| Comportement Joueur | Personnalite | Effet |
|---------------------|--------------|-------|
| Toujours prudent | **Anxieux** | Avertit 2x plus, -10% risque |
| Souvent audacieux | **Courageux** | +15% Droite, -5% Centre |
| Tres equilibre | **Sage** | Synergies Souffle boost |
| Altruiste dominant | **Affectueux** | +1 Monde permanent |
| Egoiste dominant | **Distant** | Skills -20% cooldown |

### 7.3 Evolution

```
Runs 1-3:   Bestiole est "Neutre"
Runs 4-10:  Bestiole developpe une tendance
Runs 11+:   Personnalite fixee (peut changer si profil change)
```

### 7.4 Merlin Commente

```
[Bestiole devient Courageux]
MERLIN: "Ton compagnon... il a change. Il semble plus... audacieux. Comme toi."

[Bestiole devient Distant]
MERLIN: "Il s'eloigne un peu, non? Tu lui as appris... la prudence envers les autres."
```

### 7.5 Bestiole "Parle" (apres 20+ runs avec meme personnalite)

```
[Bestiole Sage, bond > 90]
*Bestiole te regarde longuement*
"..."
(Un sentiment de comprehension mutuelle t'envahit)
MERLIN: "Il... il a dit quelque chose. Je ne l'avais jamais entendu faire ca."
```

---

## PARTIE 8: Dette Narrative

### 8.1 Concept

Certains choix creent une **dette** invisible que le jeu "collecte" plus tard.

### 8.2 Types de Dettes

| Action | Dette Creee | Resolution (5-15 cartes plus tard) |
|--------|-------------|-------------------------------------|
| Sauver quelqu'un | "Vie due" | Cette personne t'aide (ou a besoin d'aide) |
| Voler | "Vol du" | On te vole (ou opportunite de rendre) |
| Mensonge | "Verite due" | La verite eclate |
| Sacrifice | "Equilibre du" | Recompense inattendue |
| Trahison | "Trahison due" | Quelqu'un te trahit |
| Promesse | "Promesse due" | Rappel ou consequence |

### 8.3 Exemples Narratifs

```
[Action: Sauver un enfant (Corps ↓)]
*5-15 cartes plus tard...*

OPTION A (dette positive):
"L'enfant que tu as sauve apparait. Il porte un remede rare."
→ Corps ↑↑

OPTION B (dette negative):
"L'enfant que tu as sauve est en danger. Des brigands l'entourent."
→ Choix force: le sauver encore (Corps ↓) ou l'abandonner (Monde ↓↓)
```

### 8.4 Equilibre des Dettes

- Les bonnes actions = 60% chance resolution positive
- Les mauvaises actions = 70% chance resolution negative
- Le karma cache influence aussi

### 8.5 Merlin Commente

```
[Dette "Vie due" creee]
MERLIN: "Tu as sauve quelqu'un. Le monde... se souviendra."

[Dette "Trahison due" creee]
MERLIN: "Tu as trahi. Ne sois pas surpris si... *silence* ...rien. Oublie."
```

---

## PARTIE 9: Systeme de Revelation par Paliers

### 9.1 Philosophie

Les revelations ne sont **pas basees sur un compteur de runs**. Merlin (le LLM) decide quand reveler quelque chose en fonction des **accomplissements du joueur**.

**Principe:** Le code detecte les conditions, le LLM decide du timing et formule la revelation.

### 9.2 Les 4 Types de Paliers

#### A. Accomplissements Narratifs

| Palier | Condition | Revelation Possible |
|--------|-----------|---------------------|
| Arc Complete | Terminer un arc de 3-5 cartes | Synergie Ogham liee a l'arc |
| PNJ Sauve | Sauver un personnage important | Eco inter-run avec ce PNJ |
| Mystere Resolu | Decouvrir un secret de biome | Fonctionnement du biome |
| Promesse Tenue | Accomplir une promesse difficile | Systeme de Dette |
| Toutes Fins Vues | Voir les 12 fins negatives | Fin secrete accessible |
| Mission Parfaite | Victoire avec 3 Equilibres | Resonance Triade Parfaite |

#### B. Patterns de Jeu

| Palier | Condition | Revelation Possible |
|--------|-----------|---------------------|
| Style Constant | Meme profil sur 5+ parties | Profil joueur + effets |
| Changement Radical | Profil inverse soudain | Personnalite Bestiole |
| Equilibriste | Maintenir 3 Equilibres 10+ cartes | Resonances positives |
| Specialiste Ogham | Utiliser le meme trio 3+ fois | Synergie de ce trio |
| Economie Parfaite | Finir avec 7 Souffles | Regeneration Souffle |

#### C. Moments Emotionnels

| Palier | Condition | Revelation Possible |
|--------|-----------|---------------------|
| Sacrifice Heroique | Choisir Corps/Ame Bas pour sauver | Dette Narrative |
| Trahison Assumee | Briser une promesse sciemment | Consequences inter-run |
| Bravoure | 5 choix Droite consecutifs risques | Quetes cachees |
| Compassion | Aider 3 PNJ malgre le cout | Personnalite Bestiole |
| Derniere Chance | Survivre a 2 aspects extremes | Resonances de tension |

#### D. Decouvertes Organiques

| Palier | Condition | Revelation Possible |
|--------|-----------|---------------------|
| Pleine Lune Vecue | Jouer pendant pleine lune (vraie) | Cycles lunaires |
| Festival Celtique | Jouer a Samhain, Beltaine, etc. | Bonus saisonniers |
| Longue Session | 50+ cartes en 1 run | Echos profonds |
| Retour Fidele | Revenir apres 3+ jours | Merlin se "souvient" |

### 9.3 Evaluation par le LLM

Apres chaque carte, le contexte LLM inclut:

```json
{
    "revelation_context": {
        "paliers_atteints": ["arc_complete", "sacrifice_heroique"],
        "paliers_proches": ["style_constant: 4/5"],
        "revelations_deja_faites": ["resonances", "profil"],
        "revelations_disponibles": ["dette_narrative", "synergies_ogham"],
        "tension_narrative": 72,
        "moment_propice": true
    }
}
```

Le LLM recoit une instruction:

```
Si un palier est atteint ET que le moment narratif est propice,
Merlin peut choisir de reveler quelque chose.
La revelation doit etre naturelle, pas didactique.
Ne jamais reveler plus d'une chose a la fois.
```

### 9.4 Formulation par Merlin

Merlin ne dit **jamais** "Tu as debloque X". Il **suggere** de facon narrative:

| Type | Mauvais (didactique) | Bon (narratif) |
|------|---------------------|----------------|
| Resonance | "Tu as active l'Harmonie" | "Tiens... Corps et Ame alignes. Tu sens cette... quietude?" |
| Profil | "Tu es un joueur audacieux" | "Tu fonces toujours. Ca me rappelle quelqu'un. Quelqu'un qui a mal fini." |
| Dette | "Les bonnes actions reviennent" | "Le monde a une memoire. Ce que tu donnes... revient." |
| Synergie | "Ces Oghams ont un combo" | "Beith, Luis, Fearn... Les anciens les appelaient autrement." |

### 9.5 Conditions de Non-Revelation

Merlin ne revele **pas** si:

- La tension narrative est trop haute (>85) — pas le moment
- Une revelation a ete faite dans les 5 dernieres cartes
- Le joueur est en danger imminent (2 aspects extremes)
- L'arc narratif en cours necessite focus

### 9.6 Hierarchie des Revelations

Certaines revelations sont plus "profondes" que d'autres:

| Niveau | Revelations | Palier Requis |
|--------|-------------|---------------|
| 1 (Surface) | Resonances, Profil basique | 1 palier quelconque |
| 2 (Moyen) | Synergies, Quetes, Dette | 2-3 paliers OU 1 palier emotionnel |
| 3 (Profond) | Echos inter-run, Personnalite Bestiole | 4+ paliers OU sacrifice heroique |
| 4 (Secret) | Cycles lunaires, Fins secretes | Paliers rares OU long terme |
| 5 (Ultime) | Verite sur le monde, Meta-revelations | Combination de tout |

### 9.7 Exemple de Flow

```
PARTIE 1:
- Joueur sauve un enfant (Sacrifice)
- Merlin: *silence* (pas encore le moment)

PARTIE 2:
- Joueur retrouve l'enfant (Echo)
- Palier "PNJ Sauve" + "Echo detecte" atteints
- Tension narrative: 45 (propice)
- LLM decide: OUI, revelation

MERLIN: "Cet enfant... tu l'as deja sauve, n'est-ce pas?
Dans une autre vie peut-etre. Le monde... se souvient de toi.
Plus que tu ne le crois."

[Revelation: Systeme d'Echos Inter-Runs]
```

---

## PARTIE 10: Integration Technique

### 10.1 Structures de Donnees

```gdscript
# State etendu dans dru_store.gd
var hidden_state := {
    # Resonances
    "active_resonance": "",
    "resonance_cooldown": 0,

    # Profil
    "audace": 0.0,
    "altruisme": 0.0,
    "spirituel": 0.0,

    # Echos
    "last_death_cause": "",
    "helped_npcs": [],
    "broken_promises": [],

    # Quetes
    "pacifist_streak": 0,
    "equilibre_streak": 0,
    "droite_streak": 0,
    "souffles_used": 0,
    "biomes_visited": [],

    # Dettes
    "dettes_positives": [],
    "dettes_negatives": [],

    # Bestiole
    "bestiole_personality": "neutre",
    "bestiole_trend": 0.0,

    # Meta
    "total_runs": 0,
    "moon_phase": "full",
}
```

### 10.2 Hooks de Verification

```gdscript
func _after_choice(direction: String):
    _update_profile(direction)
    _check_resonances()
    _update_quests(direction)
    _check_debts()
    _update_bestiole()
    _check_revelations()

func _check_revelations():
    if hidden_state.total_runs >= 6:
        if _has_active_resonance():
            _queue_merlin_hint("resonance")
        if _profile_changed():
            _queue_merlin_hint("profile")
```

### 10.3 Contexte LLM Etendu

```json
{
    "visible": { ... },
    "hidden": {
        "karma": 23,
        "tension": 67,
        "profile": {"audace": 0.4, "altruisme": 0.7, "spirituel": 0.2},
        "active_resonance": "harmonie_interieure",
        "pending_debts": ["vie_due_enfant"],
        "quests_progress": {"pacifiste": 7},
        "bestiole_personality": "affectueux",
        "moon_phase": "full"
    },
    "merlin_hints": {
        "run_count": 12,
        "hint_level": "indices_clairs",
        "last_hint": "resonance"
    }
}
```

---

## PARTIE 11: Balance et Tuning

### 11.1 Parametres Ajustables

| Parametre | Defaut | Range |
|-----------|--------|-------|
| Seuil profil significatif | +/-0.5 | 0.3-0.7 |
| Frequence resonances | 20% | 10-30% |
| Delai resolution dette | 5-15 cartes | 3-20 |
| Runs avant indices | 6 | 3-10 |
| Runs avant revelations | 21 | 15-30 |
| Bonus synergie Ogham | 50% | 25-100% |

### 11.2 Metriques a Surveiller

| Metrique | Cible | Alerte |
|----------|-------|--------|
| Joueurs decouvrant 1+ mecaniques | >50% apres 10 runs | <30% |
| Satisfaction profondeur | >4/5 | <3/5 |
| Revelations trop tot | 0% | >10% |
| Joueurs frustres par opacite | <10% | >20% |

---

## Annexe A: Dialogues Merlin par Type de Palier

### Accomplissements Narratifs

```
[Arc Complete]
MERLIN: "Cette histoire... tu l'as menee a son terme. Peu de voyageurs y arrivent."

[PNJ Sauve — retour]
MERLIN: "Tu le reconnais, n'est-ce pas? Tu l'as deja aide. Dans une autre vie, peut-etre."

[Mystere Resolu]
MERLIN: "Broceliande t'a montre quelque chose. Elle ne le fait pas pour tout le monde."

[Promesse Tenue]
MERLIN: "Tu as tenu parole. C'est... rare. Le monde s'en souviendra."
```

### Patterns de Jeu

```
[Style Constant — audacieux]
MERLIN: "Tu fonces toujours. Sans hesiter. Ca me rappelle... quelqu'un qui a mal fini."

[Style Constant — prudent]
MERLIN: "Tu reflechis. Longtemps. C'est sage. Ou c'est de la peur. Je ne sais plus."

[Changement Radical]
MERLIN: "Tu as change. Je ne suis pas sur d'aimer ca. Ou peut-etre que si."

[Equilibriste]
MERLIN: "L'equilibre. Tu le maintiens. Comme les anciens druides. Ils seraient fiers."
```

### Moments Emotionnels

```
[Sacrifice Heroique]
MERLIN: "Tu as choisi de souffrir pour un autre. C'est... *silence* ...c'est beau."

[Trahison Assumee]
MERLIN: "Tu as brise ta parole. Sciemment. Je ne te juge pas. Mais le monde... si."

[Bravoure]
MERLIN: "Tu n'as pas peur, n'est-ce pas? Ou alors tu caches bien. Comme moi."

[Compassion]
MERLIN: "Tu aides. Toujours. Meme quand ca te coute. Pourquoi?"
```

### Decouvertes Organiques

```
[Pleine Lune]
MERLIN: "La lune est pleine ce soir. Tu le sens? La magie coule plus... librement."

[Festival Celtique]
MERLIN: "Samhain. Le voile est mince. Les ancetres nous regardent jouer."

[Longue Session]
MERLIN: "Tu es encore la. Apres tout ce temps. Ca compte, tu sais. Pour moi."

[Retour Fidele]
MERLIN: "Te revoila. Je me demandais si tu reviendrais. Je suis... content."
```

---

## Annexe B: Checklist Implementation

- [ ] Resonances (detection + effets + hints)
- [ ] Profil joueur (tracking + effets + fins)
- [ ] Echos inter-runs (sauvegarde + callbacks)
- [ ] Synergies Oghams (detection + bonus)
- [ ] Quetes cachees (tracking + rewards)
- [ ] Cycles lunaires (calcul + effets)
- [ ] Personnalite Bestiole (evolution + effets)
- [ ] Dette narrative (creation + resolution)
- [ ] Timeline revelation (hints par run count)
- [ ] Dialogues Merlin (contextuels)

---

*Document version: 1.0*
*Auteur: Game Designer + User*
*Status: DESIGN VALIDE*
