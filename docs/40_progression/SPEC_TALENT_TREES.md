# Cahier des charges : Arbres de talents Voyageur et Bestiole

> **Document de reference** — M.E.R.L.I.N. : Le Jeu des Oghams
> Version 1.0 — Fevrier 2026
> Statut : SPECIFICATION COMPLETE

---

## 1. Contexte et objectifs

### 1.1 Resume du jeu

M.E.R.L.I.N. est un jeu de cartes narratif roguelite construit avec Godot 4. Le joueur incarne un voyageur dans un univers celtique, guide par Merlin et accompagne d'une Bestiole (compagnon mystique).

**Systeme Triade** — 3 Aspects x 3 etats discrets :

| Aspect | Animal | BAS (-1) | EQUILIBRE (0) | HAUT (+1) |
|--------|--------|----------|---------------|-----------|
| **Corps** | Sanglier | Epuise | Robuste | Surmene |
| **Ame** | Corbeau | Perdue | Centree | Possedee |
| **Monde** | Cerf | Exile | Integre | Tyran |

**Boucle de jeu** : Chaque carte propose 3 options (Gauche/Centre/Droite). Les choix deplacent les aspects. Si 2 aspects atteignent un extreme, la run se termine par une "chute" (12 fins). L'objectif est d'accomplir une mission tout en maintenant l'equilibre.

**Ressources run** : Vigueur, Concentration, Materiel, Faveur, Nourriture.

**Ressources meta** (persistantes entre les runs) :
- **14 essences elementaires** : NATURE, FEU, EAU, TERRE, AIR, FOUDRE, GLACE, POISON, METAL, BETE, ESPRIT, OMBRE, LUMIERE, ARCANE
- **Fragments d'ogham** : monnaie rare (1-3 par run selon Awen depensee)
- **Liens** : 2-7 par run (2 base + 5 si victoire)
- **Gloire** : score/50 + bonus premiere fin

**Souffle d'Ogham** : Max 1, single-use (Phase 43). Les options Centre sont gratuites. Les talents du Voyageur peuvent modifier et etendre le Souffle (voir section 3.9).

**Bestiole** : Compagnon permanent avec 18 Oghams (competences), systeme de lien (bond), Awen (max 5, start 2, regen toutes les 5 cartes).

### 1.2 Objectif du systeme de talents

Ce cahier des charges definit deux arbres de talents complementaires :

1. **Arbre du Voyageur** — inspire du Sphere Grid de Final Fantasy X et du Passive Skill Tree de Path of Exile. Un grand graphe de noeuds connectes, achetables avec des essences et des fragments. ~129 noeuds repartis en trois branches (Corps/Ame/Monde) avec des noeuds-ponts inter-aspects.

2. **Arbre de la Bestiole** — structure composite basee sur le niveau de lien (5 paliers), la Roue d'Oghams (18 competences en 6 categories), le systeme de Mastery (5 niveaux par Ogham) et l'Evolution (3 stades, 3 voies).

### 1.3 Philosophie

- **Non-frustration** : Chaque run apporte un gain. Pas de punitions irreversibles.
- **Profondeur cachee** : Lisible en surface, synergies cachees pour la rejouabilite.
- **Theme celtique** : Noeuds, spirales, triskells, glyphes ogham lies au lore.


---

## 2. Principes de design

### 2.1 Esthetique celtique

Chaque noeud porte un nom inspire de la mythologie celtique et un texte de lore. Les icones utilisent des motifs d'entrelacs, de spirales et de glyphes oghamiques. Les trois branches sont associees aux animaux totems : Sanglier (Corps), Corbeau (Ame), Cerf (Monde).

### 2.2 Clarte et profondeur

L'arbre doit etre lisible : un joueur debutant identifie rapidement les noeuds de sa branche preferee. Des synergies cachees (ponts, combos, interactions Oghams) recompensent les experimentes.

### 2.3 Progression reguliere

- Run reussie = 1-2 noeuds mineurs achetables
- Notable = 3-5 runs
- Majeur = 10-15 runs + conditions
- Arbre complet = 80-120 runs
- Les talents ne sont jamais perdus

### 2.4 Equilibrage

- Variations tactiques, jamais d'immunites totales
- Aucune combo ne permet un "run infini"
- Le pity system prend en compte les talents actifs
- Les majeurs ont des conditions de deblocage (runs, victoires, bond)

### 2.5 Souffle comme recompense de progression

Le Souffle commence a 1 (single-use). **Les talents debloquent progressivement son potentiel** :
- Sans talents : Souffle max 1, single-use, Centre gratuit
- Avec talents Corps : Souffle max +1/+2, possibilite de regeneration
- Avec talents Ame : amelioration regen, interaction Awen

L'arbre de talents est le veritable "unlock" de la mecanique Souffle.


---

## 3. Arbre du Voyageur

### 3.1 Structure generale

**Layout** : Graphe connecte style PoE / FFX. Noeud de depart central, trois branches rayonnantes vers Corps (bas-gauche), Ame (haut) et Monde (bas-droite). Noeuds-ponts entre branches.

**Types de noeuds** :

| Type | Quantite | Cout typique | Description |
|------|----------|-------------|-------------|
| **Mineur** | ~30/branche (~90) | 5-30 essences | Bonus passifs : +1 ressource, -10% cout, reduction shifts |
| **Notable** | ~6/branche (~18) | 35-70 essences + 2-3 fragments | Bonus solides : actifs, modifications significatives |
| **Majeur** | ~3/branche (~9) | 80-180 essences + 7-15 fragments + conditions | Changements gameplay : nouvelles options, fins secretes |
| **Pont** | ~12 total | 20-50 essences hybrides | Connecteurs inter-aspects, synergies |

**Total** : ~129 noeuds (90 mineurs + 18 notables + 9 majeurs + 12 ponts)

### 3.2 Couts et mapping des essences

| Branche | Essences principales | Essences secondaires |
|---------|---------------------|---------------------|
| **Corps** (Sanglier) | TERRE, FEU | METAL, GLACE |
| **Ame** (Corbeau) | ESPRIT, LUMIERE | ARCANE, FOUDRE |
| **Monde** (Cerf) | EAU, AIR | NATURE, BETE |
| **Ponts** | OMBRE, POISON | Multi-types |

**Economie par run** (ref. `merlin_constants.gd:506-512`) :

| Condition | Essences gagnees |
|-----------|-----------------|
| Base (toujours) | TERRE 5, NATURE 3 |
| Victoire | +LUMIERE 8, +FOUDRE 5 |
| Chute | +OMBRE 5, +GLACE 3 |
| 3 aspects equilibres | +LUMIERE 10 |
| Bond > 70 | +BETE 5, +NATURE 3 |
| 5+ mini-jeux | +AIR 4 |
| 3+ Oghams utilises | +ARCANE 5 |
| Flux Terre >= 70 | +NATURE 5, +EAU 3 |
| Flux Terre <= 30 | +METAL 5, +POISON 3 |
| Flux Esprit >= 70 | +ESPRIT 8, +ARCANE 5 |
| Flux Lien >= 70 | +FEU 5, +FOUDRE 3 |
| Fragments | 1 + floor(awen_spent/3), max 3 |
| Liens | 2 + (5 si victoire) |

**Simulation** : Run victorieuse complete : ~53 essences. Run chute : ~16 essences. Moyenne : ~25-35/run + 1-3 fragments.


### 3.3 Branche Corps — Sanglier (Force et Resilience)

Thematique : endurance physique, Vigueur, protection shifts Corps, **deblocage du Souffle d'Ogham**.

#### Noeuds Mineurs (30)

| ID | Nom | Cout | Prerequis | Effet | Lore |
|----|-----|------|-----------|-------|------|
| corps_m01 | Souffle Fortifie | TERRE 8 | - | +1 Souffle max au depart | Les racines du Sanglier nourrissent le souffle de la terre. |
| corps_m02 | Vigueur du Druide | TERRE 10 | - | +1 Vigueur max | Le corps du druide se renforce par la marche. |
| corps_m03 | Peau de Chene | FEU 8 | - | -10% degats Essence de Vie sur echec critique | L'ecorce du chene protege ceux qui la meritent. |
| corps_m04 | Posture du Sanglier I | TERRE 6 | corps_m01 | Shifts negatifs Corps : 8% chance de reduction | Le Sanglier se campe, inebranlable. |
| corps_m05 | Endurance Naturelle | FEU 10 | corps_m02 | Annule le 1er shift Corps BAS par run | La chair ne flanche pas au premier choc. |
| corps_m06 | Tenacite | METAL 8 | corps_m03 | +1 benediction au depart | Les os se renforcent sous la pression. |
| corps_m07 | Reserve de Vigueur | TERRE 12 | corps_m04 | +1 Vigueur max (palier 2) | Les reserves profondes du Sanglier. |
| corps_m08 | Reflexe Instinctif | FEU 12 | corps_m05 | +5% reussite mini-jeux reflexes | Le corps reagit avant l'esprit. |
| corps_m09 | Muscles d'Acier | METAL 10 | corps_m06 | Cartes combat : +1 bonus score | La force brute du metal forge. |
| corps_m10 | Souffle Persistant | TERRE 15 | corps_m07 | Souffle multi-usage (ne se consomme plus) | Le souffle s'enracine et persiste. |
| corps_m11 | Posture du Sanglier II | FEU 15 | corps_m08 | Shifts negatifs Corps : 15% chance reduction | Le Sanglier se plante, immobile comme roc. |
| corps_m12 | Armure de Givre | GLACE 10 | corps_m09 | -5% degats Essence de Vie (passif) | Le givre durcit ce qu'il touche. |
| corps_m13 | Racines Profondes | TERRE 15, NATURE 5 | corps_m10 | Equilibre : +1 Souffle (regen) | L'equilibre nourrit les racines les plus profondes. |
| corps_m14 | Resistance au Feu | FEU 15 | corps_m11 | Shifts Corps HAUT reduits 50% (1er/run) | Le feu ne brule pas ceux qui le maitrisent. |
| corps_m15 | Forge Interieure | METAL 15, FEU 5 | corps_m12 | Materiel +2 au depart | La forge interieure produit sans cesse. |
| corps_m16 | Souffle du Sanglier | TERRE 18 | corps_m13 | +1 Souffle max (total +2) | Le souffle du Sanglier est inepuisable. |
| corps_m17 | Cuir Tanne | GLACE 12, METAL 5 | corps_m14 | Nourriture -1 cout quand soin | La peau du Sanglier ne se dechire plus. |
| corps_m18 | Force Brute | FEU 18 | corps_m15 | Combat : option Gauche +15% bonus | La force brute ecrase les obstacles. |
| corps_m19 | Regeneration Souffle | TERRE 20, NATURE 8 | corps_m16 | Souffle regen : +1 toutes les 5 cartes | Le souffle de la terre pulse sans fin. |
| corps_m20 | Posture du Sanglier III | FEU 18, TERRE 5 | corps_m17 | Shifts negatifs Corps : 20% chance reduction | Le Sanglier defie meme les dieux. |
| corps_m21 | Os de la Terre | METAL 18, GLACE 8 | corps_m18 | Survit a 1 game over/run (consomme benediction) | Les os de la terre ne se brisent qu'une fois. |
| corps_m22 | Vigueur Legendaire | TERRE 20 | corps_m19 | +1 Vigueur max (palier 3, total +3) | La vigueur du heros depasse les mortels. |
| corps_m23 | Peau de Dragon | GLACE 15, FEU 10 | corps_m20 | -10% degats Essence de Vie (cumule) | La peau du dragon est impenetrable. |
| corps_m24 | Marteau de Thor | METAL 20, FOUDRE 5 | corps_m21 | Combat : score critique +25% | Le marteau frappe avec la foudre. |
| corps_m25 | Source Vitale | TERRE 22, EAU 5 | corps_m22 | Souffle regen amelioree : toutes les 4 cartes | La source vitale jaillit sans tarir. |
| corps_m26 | Indomptable | FEU 22, METAL 8 | corps_m23 | Corps BAS : +2 Souffle bonus | Plus il tombe, plus le Sanglier puise. |
| corps_m27 | Mur de Pierre | GLACE 18, TERRE 10 | corps_m24 | 1x/run : annule 1 shift negatif (tout aspect) | Un mur de pierre entre le druide et le danger. |
| corps_m28 | Vigueur Eternelle | TERRE 25, NATURE 10 | corps_m25 | +2 Vigueur max (palier 4, total +5) | La vigueur eternelle du Sanglier Ancestral. |
| corps_m29 | Resistance Absolue | FEU 25, GLACE 10 | corps_m26 | Shifts negatifs Corps : 25% chance annulation | Le corps du druide est une forteresse. |
| corps_m30 | Dernier Rempart | METAL 25, TERRE 15 | corps_m27 | Si Essence de Vie < 25 : +2 Souffle + bouclier 1 carte | Le dernier rempart du Sanglier. |

#### Noeuds Notables (6)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| corps_n01 | Maitre Endurance | TERRE 35, METAL 15, 2 frag | corps_m10, corps_m11 | Oghams "protection" : cooldown -1 |
| corps_n02 | Fury | FEU 40, GLACE 10, 2 frag | corps_m14, corps_m15 | Actif 1x/run : permute resultat risque en neutre |
| corps_n03 | Coeur de Pierre | METAL 40, TERRE 20, 3 frag | corps_m21, corps_m20 | Degats Essence de Vie -20% permanent |
| corps_n04 | Souffle Etendu | TERRE 45, NATURE 20, 3 frag | corps_m19, corps_m16 | Souffle max +1 ET regen toutes les 3 cartes si equilibre |
| corps_n05 | Berserker | FEU 50, METAL 15, 2 frag | corps_m26, corps_m24 | Corps BAS : +3 Souffle + combat bonus x2 |
| corps_n06 | Gardien du Seuil | GLACE 40, TERRE 25, 3 frag | corps_m29, corps_m30 | 2x/run : aspect extreme -> +1 shift vers equilibre |

#### Noeuds Majeurs (3)

| ID | Nom | Cout | Prerequis | Conditions | Effet |
|----|-----|------|-----------|-----------|-------|
| corps_M01 | Avatar du Corps | TERRE 100, FEU 50, 8 frag | corps_n01, corps_n02 | 10 runs | 4e option "Puissance" aux cartes combat |
| corps_M02 | Regen Berserker | FEU 80, METAL 40, GLACE 30, 7 frag | corps_n03, corps_n05 | 5 victoires | Corps Epuise : shift auto vers Equilibre + 2 Vigueur, 1x/run |
| corps_M03 | Sanglier Ancestral | TERRE 120, NATURE 60, 10 frag | corps_n04, corps_n06 | 15 runs, bond >= 50 | Corps HAUT positif (+1 Souffle, pas game over). Fin "Sanglier Eternal". |


### 3.4 Branche Ame — Corbeau (Magie et Intuition)

Thematique : perception, revelation, Awen, Concentration, interaction avec Oghams.

#### Noeuds Mineurs (30)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| ame_m01 | Clarte Interieure | ESPRIT 8 | - | Revele 1 effet de choix par carte |
| ame_m02 | Flamme Spirituelle | LUMIERE 10 | - | +1 Awen au depart de run |
| ame_m03 | Echo des Runes | ARCANE 8 | - | Voir le type de mini-jeu avant de jouer |
| ame_m04 | Concentration I | ESPRIT 6 | ame_m01 | +1 Concentration max |
| ame_m05 | Intuition Celeste | LUMIERE 10 | ame_m02 | +5% chance hint Merlin |
| ame_m06 | Memoire Oghamique | ARCANE 10 | ame_m03 | Oghams "reveal" : -1 cooldown |
| ame_m07 | Concentration II | ESPRIT 12 | ame_m04 | +1 Concentration max (palier 2) |
| ame_m08 | Lueur de Verite | LUMIERE 12 | ame_m05 | Revele si option est "risquee" |
| ame_m09 | Resonance Arcanique | ARCANE 12 | ame_m06 | Oghams "boost" : +10% efficacite |
| ame_m10 | Maitrise d'Awen | ESPRIT 15, FOUDRE 5 | ame_m07 | Awen regen toutes les 4 cartes (au lieu de 5) |
| ame_m11 | Troisieme Oeil | LUMIERE 15 | ame_m08 | Predit theme prochaine carte |
| ame_m12 | Savoir Ancestral | ARCANE 15, ESPRIT 5 | ame_m09 | +10% reussite mini-jeux logique |
| ame_m13 | Flux d'Awen | ESPRIT 18 | ame_m10 | +1 Awen max (de 5 a 6) |
| ame_m14 | Premonition | LUMIERE 18, FOUDRE 5 | ame_m11 | 1x/run : voir 3 prochaines cartes (themes) |
| ame_m15 | Grimoire Vivant | ARCANE 18 | ame_m12 | Connaitre 1 condition de fin au debut de run |
| ame_m16 | Awen Perpetuel | ESPRIT 20, LUMIERE 5 | ame_m13 | Awen regen +1 bonus si Ame Centree |
| ame_m17 | Vision Etherique | LUMIERE 20 | ame_m14 | Revele shifts caches des options Centre |
| ame_m18 | Echos du Passe | ARCANE 20, OMBRE 5 | ame_m15 | Mini-jeux memoire : +15% bonus |
| ame_m19 | Source d'Awen | ESPRIT 22 | ame_m16 | +1 Awen depart (total +2) |
| ame_m20 | Omniscience Partielle | LUMIERE 22, ESPRIT 8 | ame_m17 | Oghams "reveal" : -1 Awen cout |
| ame_m21 | Rune de Pouvoir | ARCANE 22, FOUDRE 8 | ame_m18 | Oghams "special" : -1 cooldown |
| ame_m22 | Awen Stellaire | ESPRIT 25 | ame_m19 | Awen regen toutes les 3 cartes |
| ame_m23 | Revelation Complete | LUMIERE 25, ARCANE 8 | ame_m20 | 2x/run : revele TOUS effets d'une carte |
| ame_m24 | Briseur de Voile | ARCANE 25, OMBRE 10 | ame_m21 | Voir Karma + Flux pendant la run |
| ame_m25 | Concentration III | ESPRIT 25 | ame_m22 | +1 Concentration max (palier 3, total +3) |
| ame_m26 | Prophete | LUMIERE 28, FOUDRE 10 | ame_m23 | Connaitre type prochaine carte |
| ame_m27 | Archiviste | ARCANE 28, ESPRIT 10 | ame_m24 | +3 ARCANE bonus si 3+ Oghams utilises |
| ame_m28 | Ame Luminescente | ESPRIT 30, LUMIERE 10 | ame_m25 | Awen max +1 (total +2, max 7) |
| ame_m29 | Oracle du Corbeau | LUMIERE 30, ARCANE 10 | ame_m26 | Oghams "narrative" : +1 option bonus |
| ame_m30 | Transcendance Mentale | ARCANE 30, ESPRIT 15 | ame_m27 | Mini-jeux tous types : +10% permanent |

#### Noeuds Notables (6)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| ame_n01 | Vision Meditative | ESPRIT 40, FOUDRE 15, 2 frag | ame_m10, ame_m11 | Actif : revele impact 1 option, cooldown 3 cartes |
| ame_n02 | Onguent Mental | LUMIERE 35, ESPRIT 20, 2 frag | ame_m13, ame_m14 | Souffle regen +1 si 3 aspects equilibres |
| ame_n03 | Corbeau Omniscient | LUMIERE 45, ESPRIT 20, 3 frag | ame_m20, ame_m19 | Oghams "reveal" : -1 Awen ET -1 cooldown |
| ame_n04 | Memoire des Boucles | ARCANE 50, FOUDRE 20, 3 frag | ame_m24, ame_m21 | 2 conditions de fin visibles + Karma visible |
| ame_n05 | Flux Divin | ESPRIT 45, LUMIERE 25, 3 frag | ame_m28, ame_m22 | Awen regen toutes les 2 cartes si Ame Centree |
| ame_n06 | Maitre des Runes | ARCANE 50, ESPRIT 25, 3 frag | ame_m29, ame_m30 | Tous Oghams : -1 cooldown global |

#### Noeuds Majeurs (3)

| ID | Nom | Cout | Prerequis | Conditions | Effet |
|----|-----|------|-----------|-----------|-------|
| ame_M01 | Deuxieme Souffle | ESPRIT 80, LUMIERE 50, 8 frag | ame_n02, ame_n03 | 10 runs | Souffle max +2, regen +1/3 cartes. Ame Centree : regen x2. |
| ame_M02 | Pacte Mystique | ESPRIT 100, ARCANE 50, 8 frag | ame_n04, ame_n06 | Bond >= 50, 8 victoires | +1 slot Ogham equipe (4 au lieu de 3). +1 Mastery gratuit. |
| ame_M03 | Fusion Ame-Bestiole | ESPRIT 120, LUMIERE 60, 10 frag | ame_n05, ame_M01 ou M02 | 20 runs, bond >= 60 | Bond demarre a 60. +1 Awen depart. Fin "Ame Eternelle". |


### 3.5 Branche Monde — Cerf (Relations et Social)

Thematique : diplomatie, Faveur, liens sociaux, adaptation biome, options narratives.

#### Noeuds Mineurs (30)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| monde_m01 | Diplomatie Innee | EAU 8 | - | Annule 1er shift Monde HAUT par run |
| monde_m02 | Flux Harmonieux | AIR 10 | - | 1 Centre gratuit par run |
| monde_m03 | Instinct Animal | NATURE 8 | - | +5% score mini-jeux champ lexical |
| monde_m04 | Charme du Cerf I | EAU 6 | monde_m01 | +5% chance option sociale bonus |
| monde_m05 | Faveur Divine | AIR 10 | monde_m02 | -1 cout Faveur pour reroll/influence |
| monde_m06 | Adaptabilite | NATURE 10, BETE 5 | monde_m03 | Changement biome : +1 Souffle |
| monde_m07 | Charme du Cerf II | EAU 12 | monde_m04 | +8% chance option sociale |
| monde_m08 | Faveur des Anciens | AIR 12 | monde_m05 | Faveur max +2 |
| monde_m09 | Pisteur | NATURE 12, BETE 5 | monde_m06 | Biome : revele 1 carte bonus specifique |
| monde_m10 | Ruse du Renard | EAU 15, POISON 5 | monde_m07 | Choix critique : DC +2 (au lieu de +4) |
| monde_m11 | Souplesse du Vent | AIR 15 | monde_m08 | 1 Centre gratuit supplementaire (total 2) |
| monde_m12 | Herboriste | NATURE 15, EAU 5 | monde_m09 | Nourriture +2 au depart |
| monde_m13 | Negociateur | EAU 18, AIR 5 | monde_m10 | Cartes promesse : -1 cout Faveur |
| monde_m14 | Voyageur Aguerri | AIR 18, NATURE 5 | monde_m11 | Changement biome : +2 Souffle |
| monde_m15 | Ami des Betes | BETE 15, NATURE 8 | monde_m12 | Bond +5 au depart de run |
| monde_m16 | Langue d'Argent | EAU 20 | monde_m13 | 1x/run : option Droite -> "Bargain" |
| monde_m17 | Marcheur de Biomes | AIR 20, BETE 5 | monde_m14 | +1 Souffle toutes les 5 cartes |
| monde_m18 | Guerisseur | NATURE 20, EAU 8 | monde_m15 | Nourriture soigne +5 Essence de Vie |
| monde_m19 | Ambassadeur I | EAU 22 | monde_m16 | Cartes narratives : +10% option sociale |
| monde_m20 | Souffle du Cerf | AIR 22, NATURE 5 | monde_m17 | 1 Centre gratuit supplementaire (total 3) |
| monde_m21 | Lien Sauvage | BETE 20, NATURE 10 | monde_m18 | Bond +3 par victoire mini-jeu |
| monde_m22 | Charme du Cerf III | EAU 25 | monde_m19 | +15% chance option sociale |
| monde_m23 | Vent Favorable | AIR 25, FOUDRE 5 | monde_m20 | Changement biome : +1 Awen |
| monde_m24 | Passeur de Legendes | NATURE 25, EAU 10 | monde_m21 | Arc complete : +2 essences aleatoires |
| monde_m25 | Eloquence | EAU 25, AIR 8 | monde_m22 | Faveur max +3 (total +5) |
| monde_m26 | Libre comme l'Air | AIR 28, EAU 5 | monde_m23 | Shifts Monde : 15% chance annulation |
| monde_m27 | Druide Nourricier | NATURE 28, BETE 10 | monde_m24 | Nourriture +3 depart (total +5) |
| monde_m28 | Orateur Sacre | EAU 30, AIR 10 | monde_m25 | Cartes promesse : +1 option (4 choix) |
| monde_m29 | Maitre des Vents | AIR 30, FOUDRE 10 | monde_m26 | 1x/run : choisir biome suivant |
| monde_m30 | Gardien de la Terre | NATURE 30, BETE 15 | monde_m27 | Bond plancher = 30 (jamais en dessous) |

#### Noeuds Notables (6)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| monde_n01 | Ambassadeur | EAU 40, AIR 15, 2 frag | monde_m16, monde_m13 | 1x/run : option "Bargain" (reduit 2 aspects vs Faveur) |
| monde_n02 | Courant Adaptable | AIR 35, BETE 20, 2 frag | monde_m14, monde_m12 | Changement biome : +2 Souffle ET +1 Awen |
| monde_n03 | Alliance Sauvage | BETE 45, NATURE 20, 3 frag | monde_m21, monde_m24 | Bond +10 depart. Option cachee 20% (bond >= 71) |
| monde_n04 | Cerf Communaute | EAU 50, AIR 20, 3 frag | monde_m25, monde_m22 | Debloque missions "Alliance" (haute recompense) |
| monde_n05 | Venin Bienveillant | POISON 40, BETE 25, 3 frag | monde_m29, monde_m26 | Effets negatifs -30% |
| monde_n06 | Tisserand du Destin | NATURE 50, EAU 25, 3 frag | monde_m28, monde_m30 | 2x/run : forcer type de carte specifique |

#### Noeuds Majeurs (3)

| ID | Nom | Cout | Prerequis | Conditions | Effet |
|----|-----|------|-----------|-----------|-------|
| monde_M01 | Illustre | EAU 100, AIR 50, 8 frag | monde_n01, monde_n04 | 10 runs | 4 choix cartes promesse. Faveur max +3. |
| monde_M02 | Pacte d'Alliance | NATURE 80, BETE 50, EAU 30, 7 frag | monde_n03, monde_n05 | Bond >= 60, 5 victoires | Bestiole liee a PNJ (mecanique "allie") |
| monde_M03 | Roi sans Couronne | EAU 120, AIR 60, 10 frag | monde_n06, monde_n04 | 15 runs, equilibre 3x | Monde HAUT = fin "Tyran Juste". +5 liens/run. |


### 3.6 Noeuds-Ponts (Inter-Aspects)

#### Ponts Corps-Ame (3)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| pont_ca01 | Endurance Spirituelle | TERRE 20, ESPRIT 20 | corps_m07, ame_m04 | +1 Vigueur ET +1 Concentration depart |
| pont_ca02 | Souffle-Awen | TERRE 30, ESPRIT 30, 2 frag | corps_m13, ame_m10 | Quand Souffle regen : +1 Awen aussi |
| pont_ca03 | Guerrier-Mage | FEU 35, ARCANE 35, 3 frag | corps_n02, ame_n01 | Combat : revele shifts ET +10% bonus |

#### Ponts Ame-Monde (3)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| pont_am01 | Empathie | ESPRIT 20, EAU 20 | ame_m05, monde_m04 | Options sociales : -1 cout Souffle |
| pont_am02 | Prophete Social | LUMIERE 30, AIR 30, 2 frag | ame_m14, monde_m13 | Narratives : revele consequences sociales |
| pont_am03 | Lien Mystique | ARCANE 35, BETE 35, 3 frag | ame_n04, monde_n03 | Bond +5/run. Oghams "narrative" : +1 option |

#### Ponts Corps-Monde (3)

| ID | Nom | Cout | Prerequis | Effet |
|----|-----|------|-----------|-------|
| pont_cm01 | Resilience Sociale | METAL 20, EAU 20 | corps_m06, monde_m01 | 1er shift extreme annule, 1x/run |
| pont_cm02 | Nourrir et Proteger | NATURE 30, GLACE 30, 2 frag | corps_m15, monde_m12 | Nourriture soigne aussi bond +10 |
| pont_cm03 | Champion du Peuple | FEU 35, EAU 35, 3 frag | corps_n01, monde_n01 | Combat : option "Defendre" (Faveur + Vigueur) |

#### Ponts Centraux — ancien Tronc (3)

| ID | Nom | Cout | Prerequis | Conditions | Effet |
|----|-----|------|-----------|-----------|-------|
| pont_c01 | Equilibre des Feux | OMBRE 30, FEU 20, 3 frag | corps_m01, ame_m01, monde_m01 | - | Flux demarre 50/50/50 |
| pont_c02 | Triade Parfaite | OMBRE 50, POISON 30, 5 frag | pont_c01 + 1 notable/branche | - | 3 equilibres : +3 Souffle + ignore shift negatif |
| pont_c03 | Boucle Eternelle | OMBRE 100, FEU 80, 15 frag | pont_c02 + 1 majeur/branche | 20 runs, 10 victoires | New Game+ : essences x1.5. Fin secrete ultime. |


### 3.7 Prerequis et graphe

Les prerequis forment un **DAG (graphe acyclique dirige)** :
- Mineur : 0-1 mineur adjacent
- Notable : 2 mineurs specifiques
- Majeur : 2 notables + conditions de run
- Pont : 1 noeud de chaque branche connectee
- Pont central : noeuds des 3 branches

### 3.8 Rythme de progression

| Phase | Runs | Mineurs | Notables | Majeurs | Ponts |
|-------|------|---------|----------|---------|-------|
| Debutant | 1-5 | 5-10 | 0 | 0 | 0-1 |
| Intermediaire | 6-20 | 15-30 | 2-4 | 0 | 2-4 |
| Avance | 21-50 | 40-60 | 6-12 | 1-3 | 5-8 |
| Expert | 51-80 | 70-80 | 14-17 | 4-7 | 9-11 |
| Maitre | 81-120+ | 85-90 | 18 | 8-9 | 12 |

### 3.9 Souffle dans l'arbre — Innovation cle

| Talent | Branche | Effet sur Souffle |
|--------|---------|-------------------|
| corps_m01 | Corps | +1 Souffle max depart |
| corps_m10 | Corps | Multi-usage (ne se consomme plus) |
| corps_m13 | Corps | Regen +1 si equilibre |
| corps_m16 | Corps | +1 max (total +2) |
| corps_m19 | Corps | Regen +1 toutes les 5 cartes |
| corps_m25 | Corps | Regen toutes les 4 cartes |
| corps_n04 | Corps | +1 max ET regen/3 cartes si equilibre |
| ame_n02 | Ame | Regen acceleree si equilibre |
| ame_M01 | Ame | +2 max ET regen/3 cartes |
| pont_c02 | Centre | 3 equilibres = +3 Souffle instant |

**Progression Souffle** :
- Run 1-5 : max 1, single-use
- Run 6-15 : max 2-3, multi-usage, debut regen
- Run 16-40 : max 4-5, regen reguliere
- Run 41+ : max 6-8, regen acceleree

### 3.10 Interface graphique

**Layout** : Parchemin celtique navigable (zoom 50%-200%, pan).

**Noeuds** :
- Mineur : cercle 24px, spirale simple
- Notable : cercle 40px, noeud celtique complexe, bordure doree
- Majeur : cercle 56px, glyphe ogham, aura lumineuse
- Pont : losange 32px, entrelacs bicolore

**Etats** : Verrouille (gris, cadenas) | Disponible (couleur branche, glow ambre) | Debloque (plein, coche verte)

**Couleurs** : Corps = brun `Color(0.55, 0.40, 0.25)` | Ame = bleu `Color(0.40, 0.45, 0.70)` | Monde = vert `Color(0.35, 0.55, 0.35)` | Ponts = ambre `Color(0.65, 0.45, 0.20)`

**Navigation** : Molette zoom, glisser pan, clic selection, filtres par branche, indicateur progression %.

**Palette** : Parchemin Mystique Breton (paper/ink/celtic_gold/accent). Font : Morris Roman Black. Shader : `merlin_paper.gdshader`.

### 3.11 Audio

- Achat noeud : harpe cristalline (0.5s)
- Decouverte : murmure du vent (0.3s)
- Achat majeur : accord majestueux + tintement (1s)
- Navigation : bruissement parchemin


---

## 4. Arbre de la Bestiole

Systeme composite a 4 dimensions : Roue d'Oghams, Paliers de lien, Mastery, Evolution.

### 4.1 La Roue d'Oghams

6 secteurs de 60 degres, 3 Oghams par categorie. Centre = portrait Bestiole + mood.
- Rayon : 160px (desktop), 140px (mobile)
- Anneau interieur : 3 starters
- Anneaux moyen/exterieur : Oghams avances

### 4.2 Catalogue des 18 Oghams

> Source : `merlin_constants.gd:19-44`

#### Revelation

| ID | Nom | Cout Awen | CD | Bond | Effet |
|----|-----|-----------|-----|------|-------|
| beith | Bouleau (starter) | 1 | 3 | 0 | Revele 1 option |
| coll | Noisetier | 2 | 5 | 21 | Revele TOUTES les options |
| ailm | Sapin | 2 | 4 | 41 | Predit theme prochaine carte |

#### Protection

| ID | Nom | Cout Awen | CD | Bond | Effet |
|----|-----|-----------|-----|------|-------|
| luis | Sorbier (starter) | 1 | 4 | 0 | 50% empeche 1 shift negatif |
| gort | Lierre | 2 | 6 | 41 | Ramene extreme -> Equilibre |
| eadhadh | Tremble | 3 | 8 | 61 | Annule TOUS effets negatifs |

#### Force

| ID | Nom | Cout Awen | CD | Bond | Effet |
|----|-----|-----------|-----|------|-------|
| duir | Chene | 2 | 4 | 21 | Bloque tous shifts negatifs ce tour |
| tinne | Houx | 2 | 5 | 41 | Double effets positifs prochaine carte |
| onn | Ajonc | 3 | 7 | 61 | Redirige vers Equilibre 3 tours |

#### Recit

| ID | Nom | Cout Awen | CD | Bond | Effet |
|----|-----|-----------|-----|------|-------|
| huath | Aubepine | 2 | 5 | 21 | Remplace carte (meme theme) |
| nuin | Frene | 2 | 6 | 41 | Ajoute 4e option |
| straif | Prunellier | 3 | 10 | 81 | Force retournement narratif |

#### Guerison

| ID | Nom | Cout Awen | CD | Bond | Effet |
|----|-----|-----------|-----|------|-------|
| quert | Pommier (starter) | 1 | 4 | 0 | Ramene 1 extreme -> Equilibre |
| saille | Saule | 2 | 6 | 41 | Regenere +2 Awen |
| ruis | Sureau | 3 | 8 | 61 | Ramene TOUS aspects -> Equilibre |

#### Secret

| ID | Nom | Cout Awen | CD | Bond | Effet |
|----|-----|-----------|-----|------|-------|
| muin | Vigne | 2 | 7 | 41 | Inverse positif/negatif |
| ur | Bruyere | 3 | 10 | 61 | Sacrifie 1 extreme, boost 2 autres |
| ioho | If | 3 | 12 | 81 | Full reroll carte |

### 4.3 Paliers de lien (Bond)

> Source : `merlin_constants.gd:52-58`

| Tier | Nom | Plage | Slots | Modificateur |
|------|-----|-------|-------|-------------|
| 1 | Distant | 0-30 | 0 | +0% |
| 2 | Friendly | 31-50 | +1 | +5% effets positifs |
| 3 | Close | 51-70 | +2 | +10% |
| 4 | Bonded | 71-90 | +3 | +15% + hints Merlin |
| 5 | Soulmate | 91-100 | Tous | +20% + options speciales |

**Gains** : +1/carte, +2/Ogham active, +5/promesse tenue, +3/carte narrative Bestiole.
**Pertes** : -5 promesse brisee, -2 si 2 extremes, -1 hint ignore.
**Retention** : 40%. Formule : `Next = min(Prev, 50) + 10` (+5 victoire).
**Pas de punition d'absence** : 3+ jours -> stabilise a 30.

### 4.4 Mastery (5 niveaux par Ogham)

> Source : `BESTIOLE_BIBLE_COMPLETE.md:294-376`

Progression **persistante cross-run** basee sur activations totales.

| Niveau | Activations | Bonus | Icone |
|--------|------------|-------|-------|
| 0 | 0 | Aucun | - |
| 1 | 3 | Cooldown -1 | 1 etoile |
| 2 | 8 | Feedback visuel ameliore | 2 etoiles |
| 3 | 15 | Cout Awen -1 (min 1) | 3 etoiles |
| 4 | 25 | Effet renforce | 4 etoiles |
| 5 | 40 | **Transcendance** (1x/run, bond >= 60) | Etoile doree |

**Mastery 4 exemples** :
- beith : revele 2 options au lieu de 1
- luis : 65% shield au lieu de 50%
- quert : soigne + 1 Souffle d'Ogham
- duir : bloque negatifs + 1 Souffle
- tinne : double positif + securite absolue

**Mastery 5 Transcendance exemples** :
- beith : revele TOUTE la carte + narration cachee
- luis : protection 100% automatique
- quert : soigne TOUS aspects a Equilibre
- ioho : reroll + carte garantie positive

### 4.5 Evolution de la Bestiole

> Source : `merlin_constants.gd:518-530`

#### Stades

| Stade | Nom | Bond Base | Awen Bonus | Runs | Cout |
|-------|-----|-----------|-----------|------|------|
| 1 | Enfant | 10 | +0 | 0 | - |
| 2 | Compagnon | 30 | +1 | 15 | - |
| 3 | Gardien | 50 | +2 | 40 | 200 BETE |

#### Voies (stade 3)

| Voie | Nom | Aspect | Cout | Bonus |
|------|-----|--------|------|-------|
| A | Protecteur | Corps | 150 BETE + 80 TERRE | -15% effets negatifs |
| B | Oracle | Ame | 150 BETE + 80 ESPRIT | Preview 1 carte |
| C | Diplomate | Monde | 150 BETE + 80 EAU | +5 liens/run |

Choix irreversible (nouveau slot de sauvegarde pour essayer une autre voie).

### 4.6 Deblocage et equipement

- Passage de palier : 3 Oghams proposes (categories differentes), en choisir 1
- Conditions supplementaires : coll (3 runs), gort (20 cartes survecues), straif (5 fins vues), ioho (bond >= 80)
- 3 starters toujours equipes + slots tier-dependants
- Loadout fixe entre runs

### 4.7 Synergies cachees

| Ogham | Condition | Synergie |
|-------|-----------|----------|
| beith | 3 consecutifs | Revele TOUT |
| luis | Ame Possedee | Shield 100% |
| quert | 3 Equilibre | +2 Awen |
| duir | Corps Robuste | +1 Souffle |
| onn | Biome Landes | 5 tours (au lieu de 3) |
| saille | Biome aquatique | 5 tours (au lieu de 3) |
| gort+luis | Consecutifs | Protection absolue 1 carte |

Diminishing returns : 4-5 uses = 80%, 6+ = 60%. Synergies repetees : 2e = 50%, 3e+ = 0%.

### 4.8 Anti-abus

- 1 Ogham/carte, cooldown min 3, Awen cap 5, cout min 1
- ioho/straif : 1x/run. Cooldown reset puissants inter-run.

### 4.9 Interface Bestiole

**Roue** : Long-press 250ms ou tap bouton (56x56px, coin bas-droit). Expansion `TRANS_BACK, EASE_OUT` (0.3s). Items en cascade 20ms.

**Couleurs** : Reveal=bleu `(0.294, 0.706, 0.902)` | Protection=vert `(0.314, 0.745, 0.529)` | Boost=or `(1.0, 0.824, 0.0)` | Narrative=violet `(0.659, 0.529, 0.847)` | Recovery=rose `(1.0, 0.706, 0.902)` | Special=rouge `(0.733, 0.290, 0.251)`

**Mastery** : 0-4 etoiles sous chaque icone, etoile doree pour niv 5.
**Evolution** : Scene cinematique au passage de stade. Interface 3 cartes pour choix de voie.
**Bond** : Barre horizontale avec 5 marqueurs de palier, couleur gris -> dore.


---

## 5. Integration au gameplay

### 5.1 Impact controle

Les talents offrent des **variations tactiques**, jamais des immunites :
- "+1 Vigueur" ameliore la marge, ne supprime pas le risque
- "25% annulation shift" est un filet, pas un bouclier
- "Revele 1 option" informe, ne choisit pas

### 5.2 Synergie Voyageur-Bestiole

- **Voyageur -> Bestiole** : ame_M02 donne +1 slot Ogham, ame_M03 demarre bond a 60
- **Bestiole -> Voyageur** : Bond >= 50 prerequis certains talents, essences BETE bonus
- **pont_cm02** : Nourriture soigne aussi bond +10
- **pont_am03** : Bond +5/run + Oghams "narrative" ameliores

### 5.3 Scaling de difficulte

Le pity system prend en compte :
- Nombre de talents (modifier +1% par 10 talents)
- Souffle max (si > 3, cartes plus exigeantes)
- Bond moyen (stabilite -> complexite)
- Mastery average

### 5.4 Multi-plateforme

| Plateforme | Arbre | Roue |
|------------|-------|------|
| Clavier | Fleches + ZQSD, Tab branches | Tab ouvre, Escape ferme |
| Souris | Glisser, molette zoom | Clic bouton, hover+clic |
| Tactile | Pinch zoom, swipe pan | Long-press 250ms |
| Manette | Stick droit, LB/RB, A | X ouvre, B ferme |

---

## 6. Implementation technique

### 6.1 Donnees

Remplacer `TALENT_NODES` dans `merlin_constants.gd` (lignes 537-794) par ~129 noeuds :

```gdscript
const TALENT_NODES := {
    "corps_m01": {
        "branch": "Corps", "tier": 1, "type": "mineur",
        "name": "Souffle Fortifie",
        "cost": {"TERRE": 8},
        "prerequisites": [],
        "conditions": {},
        "effect": {"type": "modify_start", "target": "souffle", "value": 1},
        "description": "...", "lore": "...",
    },
}
```

Nouveaux champs : `"type"` (mineur/notable/majeur/pont), `"conditions"` (runs_min, victories_min, bond_min).

Ajouter constantes Mastery :
```gdscript
const OGHAM_MASTERY_THRESHOLDS := [0, 3, 8, 15, 25, 40]
```

### 6.2 MerlinStore

- Etendre `_apply_talent_effects_for_run()` (lignes 617-692) pour nouveaux effets (souffle_multi_use, souffle_regen, reveal_option)
- Ajouter verification conditions dans `can_unlock_talent()`
- Ajouter `get_ogham_mastery(skill_id)`, `increment_ogham_mastery(skill_id)`
- Modifier `activate_ogham()` pour bonus Mastery

### 6.3 Scenes UI

**Voyageur** : Refonte `arbre_de_vie_ui.gd` — vertical list -> graph navigable (Camera2D/SubViewport + panning/zoom). Noeuds = Controls positionnes en 2D. Connexions via `_draw()` ou Line2D.

**Bestiole** : Etendre `bestiole_wheel_system.gd` — indicateurs Mastery, panel detail, UI evolution.

### 6.4 LLM

Contexte RAG enrichi avec : talents actifs, Oghams equipes + Mastery, stade/voie evolution, bond.

### 6.5 Sauvegarde

Etendre `merlin_save_system.gd` :
```gdscript
"meta": {
    "talent_tree": {"unlocked": [...]},
    "ogham_mastery": {"beith": 12, "luis": 8, ...},
    "bestiole_evolution": {"stage": 2, "path": ""},
}
```

### 6.6 Tests

- **Unitaires** : achat, couts, prerequis, conditions, effets, mastery, evolution
- **Integration** : Souffle unlock progressif, synergie Voyageur-Bestiole, scaling
- **Equilibrage** : 100 runs simulees, pas de run infini, couts calibres

---

## 7. Annexes

### 7.1 Mapping essences

| Essence | Branche | Sources par run |
|---------|---------|----------------|
| NATURE | Monde | Base 3, Bond>70 +3, Flux Terre high +5 |
| FEU | Corps | Flux Lien high +5 |
| EAU | Monde | Flux Terre high +3 |
| TERRE | Corps | Base 5 |
| AIR | Monde | 5+ mini-jeux +4 |
| FOUDRE | Ame | Victoire +5, Flux Lien high +3 |
| GLACE | Corps | Chute +3 |
| POISON | Monde | Flux Terre low +3 |
| METAL | Corps | Flux Terre low +5 |
| BETE | Evolution | Bond>70 +5 |
| ESPRIT | Ame | Flux Esprit high +8 |
| OMBRE | Ponts | Chute +5 |
| LUMIERE | Ame | Victoire +8, Equilibre +10 |
| ARCANE | Ame | 3+ Oghams +5, Flux Esprit high +5 |

### 7.2 Simulation economique

| Type | Cout moyen | Runs (standard) | Runs (bonne) |
|------|-----------|----------------|-------------|
| Mineur debut | 8-12 | 1 | < 1 |
| Mineur avance | 20-30 | 2 | 1 |
| Notable | 40-70 + 2-3 frag | 3-5 | 2-3 |
| Majeur | 100-180 + 7-15 frag | 8-12 | 4-6 |
| Pont | 20-50 hybrides | 2-3 | 1-2 |

**Total arbre** : ~4020 essences + ~145 fragments = **~115 runs**

### 7.3 Graphe DAG (schema par branche)

```
BRANCHE :  m01 - m04 - m07 - m10 - m13 - m16 - m19 - m22 - m25 - m28
           m02 - m05 - m08 - m11 - m14 - m17 - m20 - m23 - m26 - m29
           m03 - m06 - m09 - m12 - m15 - m18 - m21 - m24 - m27 - m30
                n01 (m10+m11)   n02 (m14+m15)   n03 (m21+m20)
                n04 (m19+m16)   n05 (m26+m24)   n06 (m29+m30)
                M01 (n01+n02)   M02 (n03+n05)   M03 (n04+n06)
```

---

> **Fin du cahier des charges** — Version 1.0
> Ce document definit les deux arbres de talents du jeu M.E.R.L.I.N.
> Reference pour l'implementation dans Godot 4.
