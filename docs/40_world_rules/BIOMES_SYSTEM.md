# Systeme de Biomes — DRU: Le JDR Parlant

*Document cree: 2026-02-08*
*Status: IMPLEMENTED — 8 biomes actifs (Broceliande, Landes, Cotes, Villages, Cercles, Marais, Collines, Iles Mystiques)*

---

## But

Definir les 8 biomes/environnements de la Bretagne celtique mystique, leurs specificites de gameplay, et les systemes de ressources cachees, retournements de situation, et rejouabilite qui transforment DRU en un veritable "JDR Parlant" avec une profondeur quasi-illimitee.

---

## Vision: Le JDR Parlant

DRU n'est pas un simple jeu de cartes — c'est un **JDR oral** ou Merlin narre des histoires uniques a chaque run. Le joueur ne voit que la surface (4 jauges), mais des **ressources invisibles** influencent secretement le recit. Les **retournements de situation** emergent naturellement de ces mecaniques cachees, creant des moments "ah-ha!" memorables.

**Principes cles:**
- Gameplay ultra-simple (swipe gauche/droite)
- Profondeur cachee (ressources invisibles, reputation, karma)
- Retournements narratifs emergents
- Rejouabilite quasi-illimitee via combinatoire

---

## PARTIE 1: Les 7 Biomes de Bretagne

### 1.1 Foret de Broceliande

**Theme:** Mystere, Magie Ancienne, Danger Cache

**Atmosphere:**
La foret primordiale ou le voile entre les mondes est mince. Arbres millenaires, brume perpetuelle, echos de voix anciennes. C'est ici que Merlin a ete emprisonne par Viviane.

**Palette visuelle:**
- Dominante: Verts sombres (#1a3a1a), bruns mousse (#4a3a2a)
- Accents: Lueurs bleues (#4a8ab8), or ancien (#c4a44a)
- Ambiance: Brume, rayons de lumiere filtres, lucioles

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Esprit | +15% gains, +20% pertes | La magie amplifie tout |
| Vigueur | -10% gains | La foret epuise les mortels |
| Faveur | Neutre | Les creatures observent |
| Ressources | -15% gains | Peu de provisions naturelles |

**Types de cartes specifiques:**
- Rencontres avec fees et korrigans
- Illusions et pieges magiques
- Quetes pour objets enchantes
- Visions prophetiques de Merlin
- Epreuves de sagesse druidique

**Oghams favorises:** ailm (Sapin), huath (Aubepine), ioho (If)

**Conditions d'acces:**
- Disponible des le debut
- Plus frequent en automne et printemps
- Declenche si `Esprit > 60` OU `flag:quete_merlin_active`

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| Le Chene Parlant | `cards_in_biome >= 5` | Revele un secret du passe du joueur |
| Viviane Apparait | `Esprit > 80 AND karma_cache < -20` | Proposition de pouvoir contre service |
| La Chasse Sauvage | Samhain OU `tension_narrative > 70` | Fuite ou affrontement epique |

---

### 1.2 Landes de Bruyere

**Theme:** Survie, Solitude, Endurance

**Atmosphere:**
Vastes etendues balayees par le vent, ciel immense, ajoncs et bruyeres a perte de vue. Ici, l'homme est seul face aux elements. Les tempetes arrivent sans prevenir.

**Palette visuelle:**
- Dominante: Pourpres (#6a4a6a), mauves (#8a6a8a), gris clair (#a0a0a0)
- Accents: Jaune ajonc (#d4b434), ciel orageux (#4a5a6a)
- Ambiance: Vent, nuages bas, horizons infinis

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Vigueur | -20% gains, +10% pertes | Conditions eprouvantes |
| Esprit | +10% gains | Clarte mentale dans le vide |
| Faveur | -15% gains | Peu de rencontres sociales |
| Ressources | +15% gains/pertes | Tout est amplifie |

**Types de cartes specifiques:**
- Survie contre les elements (tempete, froid)
- Rencontres avec voyageurs egarés
- Decouvertes archeologiques (menhirs isoles)
- Moments de reflexion et revelation
- Chasse et cueillette

**Oghams favorises:** ur (Bruyere), onn (Ajonc), saille (Saule)

**Conditions d'acces:**
- Plus frequent si `Vigueur < 40` (fuite vers isolement)
- Dominant en hiver et debut automne
- Evite si `Faveur > 80` (trop social pour les landes)

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| La Tempete Noire | Hiver OU `tension_narrative > 60` | -15 Vigueur OU trouver abri |
| L'Ermite | `cards_in_biome >= 3 AND Esprit > 50` | Enseignement secret |
| Le Cairn Oublie | Aleatoire 5% | Tresor OU malediction |

---

### 1.3 Cotes Sauvages

**Theme:** Commerce, Exploration, Danger Maritime

**Atmosphere:**
Falaises battues par les vagues, ports de peche, odeur de sel et d'algues. Les navires arrivent avec des nouvelles du monde — et parfois des ennuis. Les naufrages cachent des tresors... et des pieges.

**Palette visuelle:**
- Dominante: Bleus ocean (#2a4a6a), gris roche (#6a6a6a)
- Accents: Blanc ecume (#e0e0e0), orange coucher (#d4824a)
- Ambiance: Eclaboussures, cris de mouettes, vent sale

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Ressources | +25% gains, +15% pertes | Commerce actif mais risque |
| Faveur | +10% gains/pertes | Beaucoup de contacts sociaux |
| Vigueur | Neutre | Equilibre effort/repos |
| Esprit | -10% gains | L'agitation disperse |

**Types de cartes specifiques:**
- Negociations commerciales
- Naufrages et sauvetages
- Contrebande et choix moraux
- Rencontres avec etrangers (Vikings, marchands)
- Peche et recolte maritime
- Legendes de sirenes et creatures marines

**Oghams favorises:** muin (Vigne), nuin (Frene), tinne (Houx)

**Conditions d'acces:**
- Plus frequent si `Ressources < 30` (besoin de commerce)
- Dominant en ete (saison de navigation)
- Declenche par `flag:dette_marchande` OU `faction_marchands > 50`

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| Le Navire Noir | Samhain OU `karma_cache < -30` | Marche faustien propose |
| Maree Rouge | Beltaine | Recolte miraculeuse (+30 Ressources) |
| Le Passeur | `dette_merlin > 0` | Opportunite de rembourser |

---

### 1.4 Villages Celtes

**Theme:** Politique, Social, Intrigue

**Atmosphere:**
Huttes rondes, feux de camp, assemblees tribales. Les jeux de pouvoir entre chefs, druides et guerriers. Les rumeurs voyagent vite. Un mot peut faire ou defaire une reputation.

**Palette visuelle:**
- Dominante: Bruns chaleureux (#6a4a3a), oranges feu (#c47a3a)
- Accents: Or (#c4a44a), rouge sang (#8a3a3a)
- Ambiance: Fumee, voix multiples, lueurs de torches

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Faveur | +30% gains, +30% pertes | Jeux sociaux intenses |
| Ressources | +10% gains | Acces aux ressources tribales |
| Esprit | -15% gains | Bruit et distraction |
| Vigueur | +15% gains | Nourriture et repos disponibles |

**Types de cartes specifiques:**
- Assemblees et jugements
- Mariages et alliances
- Festins et celebrations
- Conflits entre clans
- Rumeurs et calomnies
- Commerce et troc local
- Requetes des villageois

**Oghams favorises:** duir (Chene), coll (Noisetier), beith (Bouleau)

**Conditions d'acces:**
- Plus frequent si `Faveur` entre 30-70 (equilibre social)
- Dominant au printemps et ete (saison sociale)
- Declenche par `flag:convocation_chef` OU `promesse_sociale_active`

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| Le Jugement | `reputation_druides < -20` | Proces public |
| L'Assemblee | Beltaine OU Lughnasadh | Vote sur une loi majeure |
| Le Mariage | `Faveur > 70 AND cards_total > 50` | Proposition d'alliance |

---

### 1.5 Cercles de Pierres

**Theme:** Magie, Spirituel, Liminal

**Atmosphere:**
Menhirs anciens, cromlechs sacres, energie palpable. Le temps semble suspendu. Les etoiles tournent differemment ici. C'est le territoire des druides et des rituels.

**Palette visuelle:**
- Dominante: Gris pierre (#5a5a5a), bleu nuit (#2a3a4a)
- Accents: Argent lune (#c0c0c0), violet mystique (#6a4a8a)
- Ambiance: Silence oppressant, ciel etoile, resonance

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Esprit | +40% gains, +25% pertes | Epicentre magique |
| Faveur | -20% gains | Eloigne de la societe |
| Vigueur | -10% pertes | Le temps ralentit |
| Ressources | Neutre | Ni gain ni perte |

**Types de cartes specifiques:**
- Rituels druidiques
- Visions et propheties
- Contact avec l'Autre Monde
- Sacrifices et offrandes
- Enigmes cosmiques
- Initiation aux mysteres
- Rencontre avec ancetres

**Oghams favorises:** ioho (If), straif (Prunellier), ruis (Sureau)

**Conditions d'acces:**
- Plus frequent lors des 8 festivals celtiques
- Declenche si `Esprit > 70` OU `reputation_druides > 50`
- Rare si `karma_cache < -40` (rejet spirituel)

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| Le Passage | Samhain exactement | Voyage dans l'Autre Monde |
| L'Initiation | `reputation_druides > 70` | Devenir druide |
| L'Eclipse | Aleatoire 2% | Tous les effets x2 pendant 5 cartes |

---

### 1.6 Marais des Korrigans

**Theme:** Danger, Mystere, Tentation

**Atmosphere:**
Eaux stagnantes, brumes epaisses, feux follets trompeurs. Les korrigans dansent la nuit autour de leurs tresors. Un faux pas et on disparait dans la tourbe. Mais les richesses sont reelles...

**Palette visuelle:**
- Dominante: Verts marecage (#3a4a3a), bruns boue (#4a3a2a)
- Accents: Jaune feu follet (#e4d44a), rouge danger (#8a2a2a)
- Ambiance: Bulles, cris lointains, lueurs mouvantes

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Vigueur | +25% pertes | Terrain treacherous |
| Ressources | +30% gains | Tresors caches |
| Esprit | +15% pertes | Les illusions perturbent |
| Faveur | Neutre | Les korrigans sont neutres |

**Types de cartes specifiques:**
- Pieges et embuscades
- Tresors et maledictions
- Marches avec les korrigans
- Sauvetage de victimes
- Navigation perilleuse
- Decouvertes archeologiques sombres
- Rencontres avec morts-vivants

**Oghams favorises:** gort (Lierre), eadhadh (Tremble), luis (Sorbier)

**Conditions d'acces:**
- Plus frequent si `Ressources < 20` (appat du gain)
- Declenche par `flag:tresor_indique` OU `karma_cache < -20`
- Dominant la nuit et en automne

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| La Danse | Minuit + nouvelle lune | Invitation korrigan: richesse ou perdition |
| Le Tresor | `cards_in_biome >= 4` | Decouverte majeure avec garde |
| L'Engloutissement | `Vigueur < 20 in biome` | Risque de mort definitive |

---

### 1.7 Collines aux Dolmens

**Theme:** Sagesse, Ancestral, Memoire

**Atmosphere:**
Douces collines parsemees de dolmens et tumulus. Ici reposent les anciens rois et sages. L'air est paisible mais charge de memoire. Les ancetres murmurent a ceux qui savent ecouter.

**Palette visuelle:**
- Dominante: Verts doux (#4a6a4a), bruns terre (#6a5a4a)
- Accents: Or pale (#d4c49a), blanc os (#e0d8d0)
- Ambiance: Vent leger, herbe haute, silence respectueux

**Modificateurs de jauges:**
| Jauge | Modificateur | Explication |
|-------|--------------|-------------|
| Esprit | +20% gains | Sagesse ancestrale |
| Vigueur | +10% gains | Repos paisible |
| Faveur | +5% gains | Respect des traditions |
| Ressources | -10% gains | Peu d'exploitation |

**Types de cartes specifiques:**
- Meditation et revelation
- Rencontre avec esprits ancestraux
- Decouvertes historiques
- Enseignements de sagesse
- Guerison spirituelle
- Interpretation de presages
- Hommages et rituels funeraires

**Oghams favorises:** quert (Pommier), ailm (Sapin), coll (Noisetier)

**Conditions d'acces:**
- Plus frequent si `Esprit < 40` (besoin de guerison)
- Declenche par `flag:ancetre_appelle` OU `reputation_druides > 30`
- Dominant au printemps et autour de Samhain

**Evenements uniques:**
| Evenement | Condition | Effet |
|-----------|-----------|-------|
| Le Reveil | `cards_in_biome >= 3 AND Esprit > 60` | Ancetre partage un secret |
| Le Tumulus Ouvert | Samhain | Tresor ancien OU malediction |
| La Guerison | `any_gauge < 20` | Restauration miraculeuse possible |

---

## PARTIE 2: Systeme de Ressources Cachees

### 2.1 Principe

Le joueur voit 4 jauges (Vigueur, Esprit, Faveur, Ressources). Mais en coulisses, **6 ressources invisibles** influencent secretement le recit. Ces ressources ne sont JAMAIS affichees — le joueur doit les deduire du comportement du monde.

### 2.2 Les 6 Ressources Invisibles

#### A) Karma Cache (karma_cache)

**Fourchette:** -100 a +100 (start: 0)

**Influence:**
- Decisions morales (aider/abandonner, voler/rendre)
- Chaque choix "bien/mal" impacte de +/-5 a +/-15

**Effets secrets:**
| Niveau | Effet |
|--------|-------|
| -100 a -60 | Les creatures malefiques s'interessent a vous |
| -59 a -20 | Rumeurs negatives, mefiance des PNJ |
| -19 a +19 | Neutre — comportement normal |
| +20 a +59 | Aide inattendue, rumeurs positives |
| +60 a +100 | Protection divine, opportunites rares |

**Exemples de modification:**
- Sauver un enfant: +10
- Voler un marchand: -8
- Sacrifier pour autrui: +15
- Mentir a Merlin: -12
- Tenir une promesse difficile: +5

---

#### B) Reputation par Faction (faction_X)

**5 factions suivies secretement:**

| Faction | Description | Influence principale |
|---------|-------------|----------------------|
| `faction_druides` | Ordre druidique | Acces aux cercles, magie |
| `faction_villageois` | Paysans et artisans | Ressources, abri, info |
| `faction_guerriers` | Clans et chefs | Protection, conflits |
| `faction_creatures` | Fees, korrigans, etc. | Magie, pieges, tresors |
| `faction_marchands` | Commercants, voyageurs | Ressources, nouvelles |

**Fourchette par faction:** -100 a +100 (start: 0)

**Seuils d'effet:**
| Niveau | Relation | Effet |
|--------|----------|-------|
| -100 a -50 | Hostile | Embuscades, refus d'aide |
| -49 a -20 | Mefiant | Prix majores, info partielle |
| -19 a +19 | Neutre | Comportement standard |
| +20 a +49 | Amical | Bonus mineurs, aide occasionnelle |
| +50 a +100 | Allie | Aide majeure, quetes exclusives |

---

#### C) Dette envers Merlin (dette_merlin)

**Fourchette:** 0 a 100 (start: 0)

**Accumulation:**
- Chaque fois que Merlin aide directement: +10-20
- Chaque promesse brisee: +15
- Chaque faveur demandee: +5-10

**Effets progressifs:**
| Dette | Effet |
|-------|-------|
| 0-20 | Merlin est bienveillant |
| 21-40 | Merlin rappelle ses services |
| 41-60 | Merlin demande des faveurs |
| 61-80 | Merlin impose des quetes |
| 81-100 | Merlin devient antagoniste |

**Remboursement:**
- Accomplir une quete de Merlin: -15-30
- Sacrifice personnel: -10-20
- Atteindre un objectif secret: -5-15

---

#### D) Tension Narrative (tension_narrative)

**Fourchette:** 0 a 100 (start: 10)

**Accumulation automatique:**
- +1 par carte jouee
- +5 si jauge critique (<20 ou >80)
- +10 si promesse proche de deadline
- +3 par arc narratif actif

**Declencheurs:**
| Tension | Effet |
|---------|-------|
| 0-30 | Cartes calmes, setup narratif |
| 31-50 | Complications mineures |
| 51-70 | Conflits majeurs possibles |
| 71-85 | Retournements probables |
| 86-100 | Climax garanti — puis reset a 20 |

---

#### E) Memoire du Monde (memoire_monde)

**Structure:** Dictionnaire de flags et compteurs

**Exemples:**
```gdscript
memoire_monde = {
    "druide_noir_rencontre": true,
    "villageois_sauves": 3,
    "promesses_tenues": 7,
    "promesses_brisees": 2,
    "mort_count": 4,  # meta-game
    "secret_broceliande_decouvert": false,
    "ancetre_contacte": "Brennus",
}
```

**Utilisation:**
- Le LLM recoit ces flags pour generer des callbacks
- Les PNJ "se souviennent" des actions passees
- Certaines cartes ne se declenchent qu'avec certains flags

---

#### F) Affinite Saisonniere (affinite_saison)

**4 compteurs:** affinite_printemps, affinite_ete, affinite_automne, affinite_hiver

**Accumulation:**
- Jouer pendant une saison: +1 par carte
- Respecter les festivals: +10
- Certains choix: +/-3

**Effets:**
| Affinite | Bonus |
|----------|-------|
| > 30 | +5% tous effets dans cette saison |
| > 60 | Cartes saisonnieres exclusives |
| > 90 | Maitre de saison (skill special) |

---

### 2.3 Revelation Progressive

Les ressources cachees ne sont JAMAIS affichees directement. Le joueur les deduit via:

**Indices narratifs:**
- "Les druides semblent mefiants a votre approche..." (faction_druides < -20)
- "Un sourire etrange joue sur les levres de Merlin..." (dette_merlin > 50)
- "Le korrigan vous salue comme un vieil ami..." (faction_creatures > 40)

**Skill Bestiole "ailm" (Sapin):**
- Revele UN indicateur cache choisi aleatoirement
- "Votre karma penche vers la lumiere..."
- "Merlin garde un compte..."

**Endings speciaux:**
- A la fin de run, revele les ressources cachees
- "Revue de votre karma: +47 (Vertueux)"
- "Merlin vous devait: rien. Vous lui deviez: 35"

---

## PARTIE 3: Systeme de Retournements de Situation

### 3.1 Philosophie

Les retournements ne sont pas scriptes — ils **emergent** de la combinaison des ressources cachees et de la tension narrative. Cela cree des moments "ah-ha!" authentiques et uniques.

### 3.2 Types de Retournements

#### A) Revelation

**Trigger:** `tension_narrative > 70 AND memoire_monde.secret_X == false`

**Mecanique:**
- Un secret du monde est revele
- Change la perception d'une situation anterieure
- Souvent lie au karma ou aux factions

**Exemples:**
- "Le villageois que vous avez aide... etait un druide noir deguise."
- "La foret de Broceliande vous a observe depuis le debut."
- "Votre ancetre a fait une promesse en votre nom."

**Effets:**
- Modifie retroactivement une ressource cachee
- Ouvre un nouvel arc narratif
- Peut changer un allie en ennemi (ou inverse)

---

#### B) Trahison

**Trigger:** `faction_X < -30 AND faction_X_was_ally AND tension > 60`

**Mecanique:**
- Une faction autrefois amicale se retourne
- Base sur des actions passees du joueur
- Toujours "justifiee" par les choix anterieurs

**Exemples:**
- "Les guerriers se rappellent votre refus de les aider... Ils n'oublient jamais."
- "Les korrigans ont patiemment accumule leurs griefs. Ce soir, ils encaissent."
- "Merlin a vu votre coeur. Il n'aime pas ce qu'il y voit."

**Effets:**
- Perte massive de Faveur (-30 a -50)
- Embuscade ou conflit force
- Opportunite de redemption (si karma > 0)

---

#### C) Miracle

**Trigger:** `karma_cache > 50 AND any_gauge < 15 AND tension > 50`

**Mecanique:**
- Intervention positive inattendue
- Recompense pour un bon karma accumule
- Toujours narrativement justifie

**Exemples:**
- "Un druide que vous aviez aide jadis apparait... avec un remede."
- "Les ancetres parlent en votre faveur. La mort recule."
- "Le korrigan rit: 'Tu m'as amuse. Je te dois une faveur.'"

**Effets:**
- Restauration de la jauge critique (+20 a +40)
- Reset de tension a 30
- Possible ouverture d'un arc de gratitude

---

#### D) Catastrophe

**Trigger:** `karma_cache < -40 AND tension > 80`

**Mecanique:**
- Evenement negatif majeur
- Consequence de mauvais choix accumules
- Peut etre evite si resources cachees le permettent

**Exemples:**
- "La Chasse Sauvage vous a trouve. Vos mensonges les ont attires."
- "La terre se souvient de vos vols. Elle prend son du."
- "Merlin ne protege plus ceux qui ont perdu leur voie."

**Effets:**
- Perte multiple de jauges
- Possible fin de run acceleree
- Opportunite de sacrifice heroique (redemption possible)

---

#### E) Deus Ex Machina (Rare)

**Trigger:** `tension_narrative >= 100 AND cards_total > 75`

**Mecanique:**
- Intervention directe de Merlin comme narrateur
- Brise le quatrieme mur subtilement
- Recompense les longues runs

**Exemples:**
- "Merlin soupire. 'Je ne devrais pas... mais je vais vous raconter quelque chose.'"
- "L'histoire hesite. Un chemin nouveau s'ouvre — un que je n'avais pas prevu."
- "Les anciens disent que parfois, le conteur s'attache a son heros..."

**Effets:**
- Choix exceptionnel a 3 options
- Revelation majeure de lore
- Possible ending secret

---

### 3.3 Frequence des Retournements

| Type | Frequence par run moyenne | Conditions |
|------|---------------------------|------------|
| Revelation | 1-2 | Tension > 70, secret non decouvert |
| Trahison | 0-1 | Faction retournee, tension > 60 |
| Miracle | 0-1 | Karma > 50, gauge critique |
| Catastrophe | 0-1 | Karma < -40, tension > 80 |
| Deus Ex | 0.1 | Tension max, longue run |

**Note:** Une run moyenne de 70 cartes verra 1-3 retournements. Les runs courtes (<30) n'en voient souvent aucun.

---

### 3.4 Prevention et Anticipation

**Bestiole peut avertir:**
- Skill "ailm" peut reveler "un retournement approche..."
- Mood de Bestiole baisse avant trahison (s'il a du bond)
- Hints subtils dans les cartes precedentes

**Le joueur peut prevenir:**
- Maintenir karma equilibre evite extremes
- Garder les factions > -30 evite trahisons
- Gerer la tension (skills de "reset")

---

## PARTIE 4: Systeme de Rejouabilite

### 4.1 Combinatoire des Elements

**Sources de variation:**
| Element | Variations | Calcul |
|---------|------------|--------|
| 7 Biomes | Sequence aleatoire | 7^10 pour 10 biomes = 282 millions |
| 6 Ressources cachees | Etats independants | ~10^6 combinaisons |
| 5 Factions | Relations croisees | 5^5 = 3125 configurations |
| 4 Saisons | Timing | 4 x 8 festivals |
| 18 Oghams | Builds differents | C(18,3) = 816 trios |
| Promesses | Actives/Brisees | Variable infini |

**Total theorique:** Trillions de combinaisons uniques

### 4.2 Arcs Narratifs Proceduraux

**Structure d'un arc:**
```
1. INTRODUCTION (1-2 cartes)
   - Setup situation et personnage
   - Enjeux etablis

2. DEVELOPPEMENT (3-5 cartes)
   - Complications progressives
   - Choix du joueur faconnent l'arc

3. CLIMAX (1 carte)
   - Choix decisif
   - Retournement possible

4. RESOLUTION (1-2 cartes)
   - Consequences revelees
   - Impact sur ressources cachees
```

**Arcs disponibles par biome:**
| Biome | Arcs possibles |
|-------|----------------|
| Broceliande | La Fee Captive, Le Chene Maudit, L'Eveil de Merlin |
| Landes | L'Ermite Fou, La Tempete Eternelle, Le Cairn Perdu |
| Cotes | Le Navire Fantome, La Sirene, Le Tresor Viking |
| Villages | Le Mariage Force, Le Jugement, La Revolte |
| Cercles | L'Initiation, L'Eclipse, Le Passage |
| Marais | La Danse Mortelle, Le Tresor Maudit, L'Engloutissement |
| Collines | Le Reveil Ancestral, La Prophetie, La Guerison |

**35 arcs x contexte variable = Centaines d'experiences**

### 4.3 Secrets a Decouvrir

**Secrets globaux (persistent entre runs):**

| Secret | Condition de decouverte | Unlock |
|--------|-------------------------|--------|
| Le Vrai Nom de Merlin | 10 runs, karma > 50 | Dialogue special |
| L'Origine de Bestiole | Bond > 90 cumule | Skin Bestiole |
| La Prophetie Complete | Tous les endings vus | Prologue secret |
| Le Huitieme Biome | Tous biomes maitrises | L'Avalon |
| La Dette Originelle | dette_merlin rembourse 3x | Ending True |

**Secrets de run (uniques a chaque partie):**

| Type | Generation | Effet |
|------|------------|-------|
| Tresor cache | Biome + flag | Bonus majeur une fois trouve |
| PNJ secret | Faction + karma | Allie/ennemi unique |
| Chemin alternatif | Choix specifiques | Skip de biome |
| Revelation lore | Tension + ancetre | Piece du puzzle global |

### 4.4 Meta-Progression

**Entre les runs:**

| Element | Persistence | Impact |
|---------|-------------|--------|
| Gloire | Points cumulatifs | Unlocks globaux |
| Oghams maitrises | Permanent | Plus de skills dispo |
| Secrets decouverts | Permanent | Nouvelles options narratives |
| Morts | Compteur | "Le monde se souvient..." |
| Endings vus | Collection | 8 + secrets a debloquer |

**Seuils de Gloire:**
| Gloire | Unlock |
|--------|--------|
| 50 | 4eme slot Ogham |
| 100 | Biome prefere au start |
| 200 | Ressource cachee visible |
| 500 | Mode Druide (difficulte+) |
| 1000 | Ending Ultime accessible |

### 4.5 Daily/Weekly Runs (Optionnel)

**Daily Challenge:**
- Seed fixe pour tous les joueurs
- Biome impose au depart
- Leaderboard par survie

**Weekly Quest:**
- Objectif specifique (ex: "Tenir 3 promesses")
- Recompense Gloire bonus

---

## PARTIE 5: Integration Technique

### 5.1 Structure de Donnees Biome

```gdscript
const BIOMES := {
    "broceliande": {
        "name_fr": "Foret de Broceliande",
        "theme": "mystique",
        "modifiers": {
            "Esprit": {"gain": 1.15, "loss": 1.20},
            "Vigueur": {"gain": 0.90, "loss": 1.0},
            "Faveur": {"gain": 1.0, "loss": 1.0},
            "Ressources": {"gain": 0.85, "loss": 1.0}
        },
        "oghams_boosted": ["ailm", "huath", "ioho"],
        "seasons_preferred": ["automne", "printemps"],
        "conditions": {
            "min_Esprit": 60,
            "flags_any": ["quete_merlin_active"]
        },
        "events": ["chene_parlant", "viviane_apparait", "chasse_sauvage"],
        "palette": {
            "primary": "#1a3a1a",
            "secondary": "#4a3a2a",
            "accent": "#4a8ab8"
        }
    },
    # ... autres biomes
}
```

### 5.2 Structure Ressources Cachees

```gdscript
var hidden_resources := {
    "karma_cache": 0,
    "faction_druides": 0,
    "faction_villageois": 0,
    "faction_guerriers": 0,
    "faction_creatures": 0,
    "faction_marchands": 0,
    "dette_merlin": 0,
    "tension_narrative": 10,
    "affinite_printemps": 0,
    "affinite_ete": 0,
    "affinite_automne": 0,
    "affinite_hiver": 0,
}

var memoire_monde := {}  # Flags dynamiques
```

### 5.3 Contexte LLM Etendu

```json
{
    "visible": {
        "gauges": {"Vigueur": 65, "Esprit": 40, "Faveur": 80, "Ressources": 30},
        "bestiole": {"mood": "happy", "bond": 72},
        "day": 15,
        "season": "automne"
    },
    "hidden": {
        "karma": 23,
        "factions": {"druides": 45, "creatures": -12},
        "dette_merlin": 35,
        "tension": 67
    },
    "biome": {
        "current": "broceliande",
        "cards_in_biome": 4,
        "modifiers_active": true
    },
    "narrative_state": {
        "active_arcs": ["fee_captive"],
        "pending_twists": ["revelation"],
        "memoire": {"druide_noir_rencontre": true}
    }
}
```

### 5.4 Hooks de Retournement

```gdscript
func check_twist_conditions() -> Dictionary:
    var twist := {}

    # Revelation
    if tension_narrative > 70 and has_undiscovered_secret():
        twist = {"type": "revelation", "secret": get_random_secret()}

    # Trahison
    elif has_betrayed_faction() and tension_narrative > 60:
        twist = {"type": "trahison", "faction": get_betrayed_faction()}

    # Miracle
    elif karma_cache > 50 and has_critical_gauge():
        twist = {"type": "miracle", "gauge": get_critical_gauge()}

    # Catastrophe
    elif karma_cache < -40 and tension_narrative > 80:
        twist = {"type": "catastrophe"}

    # Deus Ex
    elif tension_narrative >= 100 and cards_total > 75:
        twist = {"type": "deus_ex"}

    return twist
```

---

## PARTIE 6: Equilibrage et Tuning

### 6.1 Knobs Principaux

| Parametre | Defaut | Range | Impact |
|-----------|--------|-------|--------|
| Modifier biome max | 40% | 10-60% | Difficulte locale |
| Karma decay | 0 | -1 to +1/card | Neutralite forcee? |
| Tension growth | +1/card | 0.5-2 | Frequence twists |
| Faction threshold | +/-30 | +/-20-50 | Sensibilite sociale |
| Twist cooldown | 10 cards | 5-20 | Densite dramatique |

### 6.2 Metriques a Surveiller

| Metrique | Cible | Alerte si |
|----------|-------|-----------|
| Avg cards/run | 50-70 | < 30 ou > 100 |
| Twists/run | 1-3 | 0 ou > 5 |
| Biome variety/run | 3-5 | < 2 |
| Faction flip rate | 10% runs | > 25% |
| Miracle rate | 5% runs | > 15% |

### 6.3 Tests Recommandes

- [ ] Run complete sans biome (fallback fonctionne)
- [ ] Toutes les combinaisons karma extreme
- [ ] Chaque type de retournement au moins 3x
- [ ] Transitions entre tous les biomes
- [ ] 100 runs pour statistiques moyennes
- [ ] Stress test LLM avec hidden resources

---

## Annexe A: Tableau des 8 Festivals Celtiques

| Festival | Date | Biome favorise | Effet special |
|----------|------|----------------|---------------|
| Samhain | 1 Nov | Cercles | Passage Autre Monde |
| Yule | 21 Dec | Collines | Ancetres parlent |
| Imbolc | 1 Fev | Villages | Guerison boost |
| Ostara | 21 Mar | Broceliande | Magie printaniere |
| Beltaine | 1 Mai | Cotes | Fertilite, recolte |
| Litha | 21 Juin | Landes | Endurance max |
| Lughnasadh | 1 Aout | Villages | Assemblees, jeux |
| Mabon | 21 Sep | Collines | Equilibre, sagesse |

---

## Annexe B: Glossaire

| Terme | Definition |
|-------|------------|
| Biome | Zone geographique avec regles specifiques |
| Ressource cachee | Stat invisible influencant le recit |
| Retournement | Evenement narratif majeur emergent |
| Arc | Sequence de cartes formant une histoire |
| Tension | Compteur invisible menant aux climax |
| Karma | Cumul moral des decisions |
| Faction | Groupe avec relation trackee |
| Ogham | Skill Bestiole base sur alphabet ancien |

---

*Document version: 1.0*
*Auteur: Game Designer Agent*
*Status: DESIGN - Pret pour review Narrative Writer*
