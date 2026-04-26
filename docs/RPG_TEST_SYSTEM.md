# Systeme RPG M.E.R.L.I.N. — Tests narratifs guides par le LLM

> Source de verite pour le system de tests aux carrefours.
> Remplace le "pile ou face" + 3 boutons neutres par un vrai system tactique narre.

---

## Vision

> Le test ne s'AFFICHE pas — il SE RACONTE.

Le joueur ne lit jamais "Tu lances 1d20 + 2 contre DC 12, tu as 14, c'est un succes". Le joueur lit : "Tu poses ta paume sur la pierre. Elle est tiede. Une vibration remonte ton bras et un visage se dessine dans ton esprit — un visage qui te ressemble." → c'est ca le succes critique sur un test d'Esprit DC 12 avec un Ogham de Beith equipe.

Le LLM est l'arbitre + le narrateur. Le joueur prend des decisions tactiques sans voir les chiffres.

---

## Trois axes (stats)

Chaque axe : valeur de **0 a 10**, point de depart **5**.

| Axe | Domaine | Mots-cles | Exemple de test |
|-----|---------|-----------|-----------------|
| **Souffle** | Corps, instinct, fuite, peur, vitesse, vigueur | bondir, fuir, courir, lutter, retenir, pousser | Sauter par-dessus un ravin / fuir un loup / pousser une pierre |
| **Esprit** | Lucidite, sagesse, memoire, doute, dechiffrage | dechiffrer, comprendre, mediter, observer, chercher | Lire des runes / resoudre une enigme / se souvenir d'un nom |
| **Coeur** | Lien, empathie, persuasion, resonance, parole | parler, apaiser, charmer, prier, partager, ecouter | Negocier avec un korrigan / consoler un esprit / chanter avec une fontaine |

Une carte invoque **toujours UN axe principal**. Le joueur peut souvent CHOISIR un axe alternatif au prix d'un DC plus eleve (cf. Choix tactiques).

---

## Mecanique du test

### Roll formula

```
roll  = stat_courante           # 0 a 10
      + ogham_modifier           # -1 a +3 (selon Ogham equipe + affinite)
      + narrative_modifier       # -2 a +2 (selon faction reputation, profil joueur)
      + d10                      # 1 a 10 (RNG, lisse mais perceptible)

result = compare(roll, dc)

dc varie de 6 (facile) a 18 (legendaire). Defaut carte tuto = 10.
```

### Quatre niveaux de resultat

| Resultat | Condition | Effet narratif | Effet mecanique |
|----------|-----------|----------------|-----------------|
| **CRITICAL** | roll >= dc + 5 | Le LLM raconte un succes plus grand qu'attendu, debloquage de detail | +stat axe (+1), +faction prefere, no damage |
| **SUCCESS** | roll >= dc | Action accomplie, narration complete | +0.5 stat axe, effet positif standard |
| **FAILURE** | roll >= dc - 4 | Action echoue mais consequence supportable | -1 a -3 vie, narration tendue |
| **CRITICAL FAILURE** | roll < dc - 4 | Catastrophe, narration choquante | -5 a -10 vie, malus stat, faction rep negative |

### Le LLM raconte les 4 issues

Chaque carte LLM genere AVANT le test :
- `text_intro` : presentation de la situation (avant choix)
- `choices` : 3 options tactiques (cf. ci-dessous)
- `resolutions` : objet JSON avec 4 cles `critical`, `success`, `failure`, `critical_failure` — narration de chaque issue, avant que le joueur choisisse

Le card system roule, choisit la cle de resolution, affiche le texte. **Le joueur ne voit jamais le D10**, juste la phrase qui correspond.

---

## Choix tactiques (3 par carte)

Chaque choix expose au joueur :
- Un **verbe** (action concrete)
- Implicitement, **un axe** (le LLM le devine du verbe — l'UI ne l'affiche pas en chiffres)
- **Un risque** (perceptible au texte : "Tu pourrais te griffer la main" = DC moyen + small damage on fail)

### Pattern recommande

Pour CHAQUE carte, generer 3 choix qui couvrent **3 axes differents** (un par stat) :

```json
{
  "title": "Le Cercle des Anciens",
  "text_intro": "Sept menhirs se dressent en cercle. Un vent leger fait chanter les pierres. Une presence, peut-etre, t'observe entre les troncs.",
  "test_stat_default": "esprit",
  "dc": 11,
  "choices": [
    {
      "label": "Dechiffrer les runes (lentement)",
      "axis": "esprit",
      "dc_offset": 0,
      "risk_hint": "Le doute peut t'engluer."
    },
    {
      "label": "Toucher la pierre maitresse (vif)",
      "axis": "souffle",
      "dc_offset": 1,
      "risk_hint": "L'instinct ne lit pas tout."
    },
    {
      "label": "Saluer le cercle (ouvert)",
      "axis": "coeur",
      "dc_offset": -1,
      "risk_hint": "Les vieilles pierres jugent l'orgueil."
    }
  ],
  "resolutions": {
    "critical": "Les runes s'illuminent en cascade. Tu lis non un mot mais une LIGNEE. Pendant un instant tu es l'aieul. Tu repars en sachant ton vrai nom druidique. (+1 Esprit, +5 reputation Druides)",
    "success": "Trois runes se reveillent : NAISSANCE, FEU, RIVIERE. Le sentier que tu suis est ancien. Tu n'es pas le premier. (+0.5 Esprit)",
    "failure": "Les signes s'embrouillent dans ta tete. Tu repars avec un mal de crane et la sensation d'avoir manque quelque chose. (-2 vie)",
    "critical_failure": "Tu offenses sans le savoir. Le vent tombe d'un coup. Une sensation glaciale glisse sur ta nuque. Quelque chose te suivra desormais. (-7 vie, -10 Druides, marque \"Suivi\")"
  }
}
```

---

## Modificateurs narratifs

Le LLM ne roule pas le D10 — c'est le card_system qui le fait. Mais **le LLM choisit les modificateurs narratifs** en lisant l'etat du joueur :

| Source | Modificateur | Exemple |
|--------|--------------|---------|
| Faction reputation **>= 50** dans la faction concernee | +1 a +2 | "Druides 60" → +1 sur tests Esprit |
| Faction reputation **<= 0** dans la faction concernee | -1 a -2 | "Druides -20" → -1 sur tests Esprit |
| Ogham equipe **affin** au test | +1 a +3 | Ogham Beith (commencement) sur test premier feu |
| Trait debloque **applicable** | +1 fixe | Trait "Marche silencieuse" → +1 sur test furtif |
| Vie **< 30%** | -1 (epuisement) | Mecanique : panique reduit la lucidite |

Le `narrative_modifier` final est cap a +/- 4.

---

## Progression

### XP narrative

Chaque resultat genere de la **XP** (visible dans une statistique cachee, surfacee aux paliers) :
- CRITICAL : +20 XP dans l'axe teste
- SUCCESS : +10 XP
- FAILURE : +5 XP (echouer apprend aussi)
- CRITICAL FAILURE : +2 XP

Palier : **chaque 100 XP cumules dans un axe** = +1 stat permanent dans cet axe (jusqu'au cap 10).

### Traits debloques

A des paliers narratifs (pas en chiffres au joueur) :
- **3 critiques d'affilee dans Esprit** → trait "Lecteur de pierres" (+1 sur tests de dechiffrage)
- **Survivre a 3 critical failures sans mourir** → trait "Resistance a la nuit" (+1 vie max)
- **Reputation max dans une faction** → trait specifique (Druides : "Voix grave")

Les traits sont annonces au joueur par Merlin entre deux runs, jamais en chiffres. Liste de ~12 traits dans `data/traits/druidic_traits.json`.

### Memoire long-terme (LLM context)

Le card_system maintient un journal court (3-5 entrees max) que le LLM RECOIT en contexte pour les cartes suivantes :

```
[memoire] "Cercle des Anciens : critical, +Druides, Lecteur de pierres debloque"
[memoire] "Loup de Brume : success Coeur, lien tisse"
[memoire] "Fontaine de Barenton : critical_failure, marque Suivi"
```

Le LLM peut alors faire des callbacks ("La pierre que tu as dechiffree resonne avec celle-ci..."). Pas necessaire pour la mecanique, mais transforme le run en histoire.

---

## Tactique (decisions du joueur)

Le joueur a 4 leviers tactiques :

1. **Choix d'axe** parmi les 3 proposes — ses stats fortes l'avantagent.
2. **Equipement d'Ogham** avant le run — chaque Ogham bonifie un axe specifique.
3. **Reputation faction** cumulee — orienter ses choix pour grimper dans une faction = bonus permanents.
4. **Vie / risque** — accepter une approche avec DC plus eleve mais effet superieur, vs la voie sure.

C'est tactique parce qu'il y a des **trade-offs reels** : aller toujours sur ton axe fort ne fait pas progresser tes axes faibles.

---

## Format JSON LLM (a integrer dans `merlin_card_system.gd`)

Schema actuel (a etendre) :

```json
{
  "title": "...",
  "text": "...",
  "choices": [{"label": "..."}, ...],
  "effects": [[...], [...], [...]]
}
```

Schema cible :

```json
{
  "title": "...",
  "text_intro": "...",
  "test_stat_default": "esprit",
  "dc": 11,
  "choices": [
    {
      "label": "...",
      "axis": "esprit",
      "dc_offset": 0,
      "risk_hint": "..."
    }
  ],
  "resolutions": {
    "critical": "...",
    "success": "...",
    "failure": "...",
    "critical_failure": "..."
  },
  "memory_tag": "cercle_anciens"
}
```

Compatibilite : si le LLM retourne l'ancien format (sans `resolutions`), le card_system genere des resolutions de fallback ("Tu reussis." / "Tu echoues.") et applique les `effects` legacy.

---

## Implementation MVP (3 phases)

### Phase 1 — Mecanique core (ce commit, doc only)
- [x] Doc `RPG_TEST_SYSTEM.md` (ce fichier)
- [ ] Etendre `merlin_constants.gd` : `enum Axis { SOUFFLE, ESPRIT, COEUR }`
- [ ] Ajouter `state.player.stats: { souffle, esprit, coeur }` dans store
- [ ] Ajouter `state.player.xp: { souffle, esprit, coeur }` + `state.player.traits: []`

### Phase 2 — Roll system
- [ ] `merlin_test_engine.gd` : `roll_test(axis, dc, modifiers) -> { result, narration_key }`
- [ ] Tests unitaires sur les distributions (s'assurer que la difficulte progresse comme prevu)
- [ ] Wire dans `merlin_card_system` : a chaque choix, appeler `roll_test`, stocker la cle de resolution

### Phase 3 — Generation LLM
- [ ] Update `merlin_llm_adapter.gd` prompt : exiger les 4 resolutions par carte
- [ ] Validateur JSON : si `resolutions` manquantes, retomber sur fallback
- [ ] FastRoute : enrichir les ~500 cartes existantes avec `test_stat_default`, `dc`, `resolutions`

### Phase 4 — UI
- [ ] WalkEventOverlay : afficher `text_intro` + 3 choix avec `risk_hint`
- [ ] Apres choix : pause 0.5s, fade vers texte de resolution narratif (pas de "succes" affiche)
- [ ] Stat changes en pop discret en bas-droite ("Esprit +1")

### Phase 5 — Progression
- [ ] Trait registry `data/traits/druidic_traits.json`
- [ ] Ecran post-run : Merlin annonce les traits debloques en RP
- [ ] Memoire long-terme dans le LLM context (3-5 entries roulantes)

---

## Why pas D20 ?

Le D20 est emblematique mais a une distribution plate qui rend les criticals trop frequents (5%) et les echecs critiques trop dramatiques en cinematique. Le D10 + thresholds (+5, +0, -4) donne :
- ~10% critical
- ~50% success
- ~30% failure
- ~10% critical failure

Distribution narrative plus douce, moins de "1 nat" frustrants. Et 10 c'est plus facile a expliquer en interface si on l'expose un jour.

---

## Comparison : avant / apres

| Avant | Apres |
|-------|-------|
| 3 boutons "[A] Toucher [B] Dechiffrer [C] Contourner" | 3 choix avec verbe + risk_hint integre dans le ton |
| Pile-ou-face implicite (50/50) | Roll D10 + axis + modificateurs + DC, 4 resultats |
| Texte de resolution generique | 4 narrations distinctes par choix, ecrites par le LLM |
| Effets binaires (succes / echec) | Effets graduels (critical / success / failure / crit_fail) |
| Pas de progression entre runs | Stats cumulees, traits debloques, memoire LLM |
| Pas de tactique | Choix d'axe + Ogham + faction = 4 leviers tactiques |

---

## Mini-jeux dans la carte (90% texte, 10% overlay 2D, 0% 3D)

> Le mini-jeu est l'epreuve courte qui transforme un choix tactique en un MOMENT vecu.
> Il s'integre DANS la carte parchemin, jamais en scene separee. Apres le mini-jeu, le
> resultat est ramene dans le pipeline de roll (modificateur ou pre-decision du DC).

### Regle d'or

Le mini-jeu est un **modulateur** du roll, pas un remplacement. Sa performance applique :
- Performance excellente → `narrative_modifier += 2`
- Performance correcte → `narrative_modifier += 0`
- Performance mediocre → `narrative_modifier -= 2`
- Echec total / timeout → `narrative_modifier -= 4` + force min `failure`

Le LLM ecrit les 4 resolutions sans connaitre la performance — le card_system applique le modificateur a la fin.

### Archetypes textuels (6 — un par axe x 2)

| # | Archetype | Axe | Mecanique | Duree | Succes |
|---|-----------|-----|-----------|-------|--------|
| 1 | **Cadence** | Souffle | Texte se deroule mot par mot a 800ms ; appuyer SPACE/clic au bon moment sur les mots-cles surlignes (3-5 par phrase) | 8-12s | 4/5 timings dans la fenetre +/-200ms |
| 2 | **Souffle retenu** | Souffle | Maintenir le clic pendant N secondes (3-7s aleatoire) sans relacher ; un cercle se remplit ; relacher trop tot ou trop tard = echec | 3-7s | Relacher dans la fenetre +/- 0.3s du temps cible |
| 3 | **Memoire des runes** | Esprit | 4-6 oghams apparaissent 1.5s puis disparaissent ; retaper l'ordre via 6 boutons "candidat" | 4s reveal + 8s reponse | Sequence exacte |
| 4 | **Lecture** | Esprit | 3 indices integres dans la narration (en couleur) ; choisir parmi 4 conclusions celle qui les relie | pas de timer | Bonne conclusion |
| 5 | **Resonance** | Coeur | Maintenir le curseur dans une zone qui flotte doucement sur l'ecran (Lissajous lente) ; barre de "lien" se remplit si dedans | 6-10s | Barre >= 75% a la fin |
| 6 | **Echo** | Coeur | Une phrase est prononcee (texte qui apparait) ; choisir parmi 3 reponses celle dont le rythme + ton CORRESPONDENT (mots souples vs durs vs tranchants) | pas de timer | Match du registre |

### Spec UI commune

- **Bandeau dans la carte parchemin existante** (pas une nouvelle scene). Le bandeau remplace temporairement la zone des 3 boutons `_button_container`.
- **Hauteur fixe : ~120px** sur la carte 680x360.
- **Ton parchemin** : ink brown sur cream, polices identiques au reste de la carte.
- **Echec doux** : meme un timeout n'arrete pas le jeu — il enchaine sur la resolution `failure`/`critical_failure`. Pas de "vous avez perdu".

### Repartition par carte

Pas TOUTES les cartes ont un mini-jeu. Cible :
- 60% des cartes : 3 choix simples (resolution directe sur le roll, sans mini-jeu)
- 30% des cartes : 1 mini-jeu sur 1 des 3 choix (l'option "tactique forte")
- 10% des cartes : mini-jeu obligatoire pour TOUS les choix (moments-cles, ex: le Seuil de Merlin)

Le LLM declare la presence d'un mini-jeu via le champ optionnel :
```json
"choices": [
  {
    "label": "Toucher la pierre maitresse",
    "axis": "souffle",
    "minigame": "souffle_retenu",
    "minigame_difficulty": "medium",
    "dc_offset": 1,
    "risk_hint": "..."
  }
]
```

Si `minigame` absent → choix direct, pas de mini-jeu.

### Overlay 2D (les 10%)

Pour les moments-cles narratifs (~1 carte sur 10), un mini-jeu evolue legerement vers du 2D dans la zone parchemin :

- **Trace au doigt** : Line2D que le joueur trace par-dessus un chemin guide (rune a tracer correctement)
- **Drag d'Ogham** : icone d'Ogham a glisser-deposer dans un emplacement specifique (mecanique d'invocation)
- **Cercle a intercepter** : un cercle qui grossit dans le parchemin, cliquer quand sa taille match le contour cible

Toujours dans la carte. Pas de scene separee.

### Anti-patterns

- ❌ Mini-jeu de 30+ secondes (casse le rythme du run)
- ❌ Mini-jeu de plate-forme / combat / esquive (sortie de l'ADN narratif)
- ❌ Mini-jeu identique sur 2 cartes consecutives (variete = vie)
- ❌ Mini-jeu qui PUNIT en game-over (juste degrade le resultat narratif)
- ❌ Mini-jeu qui REVELE le DC ou le roll en chiffres

### Implementation MVP (Phase 4 du plan global)

1. `scripts/minigames/minigame_base.gd` — interface commune (`start(difficulty)`, signal `minigame_finished(performance: float)`)
2. 6 implementations : `minigame_cadence.gd`, `minigame_souffle_retenu.gd`, `minigame_memoire_runes.gd`, `minigame_lecture.gd`, `minigame_resonance.gd`, `minigame_echo.gd`
3. WalkEventOverlay : entre le clic du choix et l'affichage de la resolution, si `choice.minigame` set, instancier + await `minigame_finished` → calcule narrative_modifier → roll
4. Validateur LLM : si `minigame` non null mais inconnu, ignore (degrade gracieusement)

---

*Doc canonique : 2026-04-26 — Version 1.1 (ajout minigames hybrides)*
