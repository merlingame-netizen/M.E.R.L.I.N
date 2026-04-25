# M.E.R.L.I.N. — Visual Direction v3 (CANONIQUE)

> **Source de vérité unique** pour toute la direction artistique du jeu.
> Tout doc visuel antérieur est archivé en `docs/70_graphic/legacy/`.
> Décidé : 2026-04-25 — Auteur : Maxime + Claude (askuserquestion session)

---

## 0. Pitch d'une ligne

**"Une cassette PS1 perdue d'un grimoire druidique — contemplative au quotidien, cauchemar folklorique aux moments clés."**

**North star** : `Lunacid` (KIRA, 2023) — FPS PS1-like, dithering hardcore, brume colorée, low-poly détaillé, ambiance occulte celtique-victorienne.

**Voisinage de référence** : Sable (Shedworks), Citizen Sleeper (Jump Over The Age), Inscryption Act 2 (Daniel Mullins), Hyper Light Drifter (Heart Machine).

---

## 1. Les 16 décisions cardinales

| # | Dimension | Décision |
|---|-----------|----------|
| 1 | **Socle visuel** | Low-poly stylisé unifié, full stack PS1 (dithering Bayer + vertex jitter + affine textures + scanlines CRT subtiles) |
| 2 | **Tonalité émotionnelle** | Onirique sur-réel contemplatif. Bascule cauchemar folklorique sur événements forts (max 1/run) |
| 3 | **Rendu 3D du rail** | Rétro PS1/N64 — vertex jitter, low-res ~320×240, dithering, fog dense pour cacher le clip |
| 4 | **Cohérence inter-espaces** | Bridge fort par ornements celtiques partagés. Aucune scène sans signature commune |
| 5 | **Densité ornementale** | **Diégétique** — entrelacs/runes/triskells UNIQUEMENT sur les objets celtiques du monde |
| 6 | **Palettes** | Une palette par biome (8 biomes = 8 palettes distinctes). Parchemin canonique survit sur minigames |
| 7 | **Oghams (18 signes)** | Glyphes animés vivants — chaque Ogham se dessine, pulse, tourne quand activé |
| 8 | **Factions (5)** | Totem animal + couleur (corbeau, cerf, loup, saumon, ours) |
| 9 | **Personnages** | Présences sans corps — halos, voix, pierres pulsantes. Aucun modèle 3D incarné |
| 10 | **Cartes 2D** | Typographiques + sigil de faction (style Citizen Sleeper celtique). Pas d'illustration |
| 11 | **Minigames overlay** | Parchemin scriptural — mots-verbes qui s'écrivent à l'encre |
| 12 | **Feel animation** | PS1 pur choppy — 30fps locked, anim step, vertex jitter accentué |
| 13 | **Post-processing** | Stack complet : dithering + vertex jitter + brume volumétrique colorée + scanlines CRT |
| 14 | **Typographie** | Hybride : capitales Book of Kells (titres/Oghams/sacré) + bitmap mono PS1 (corps texte) |
| 15 | **HUD gameplay** | Classique en surimpression assumé (lisibilité prioritaire) |
| 16 | **Différentiation biomes** | 4 leviers : architecture végétale + brume variable + créatures/totems + signature audio |

---

## 2. Spécifications techniques

### 2.1 Pipeline post-processing (Godot 4.5)

Stack à appliquer dans cet ordre (CanvasLayer ou Compositor) :

```
1. Render scene 3D à résolution low-res (320×240 ou 480×360, viewport scaling)
2. Affine texture mapping (custom shader, désactiver perspective correction)
3. Vertex jitter (vertex shader, snap à grille pixel)
4. Fog volumétrique coloré par biome (WorldEnvironment, exponential, far-dense)
5. Upscale au final res (nearest-neighbor, conserver pixels)
6. Dithering Bayer 4×4 (post-process shader)
7. Scanlines CRT subtiles (opacité 10-15%, fréquence 2px)
8. Légère courbure CRT (barrel distortion 0.02-0.05)
9. Tone mapping désactivé ou ACES low contrast
```

**Réglages clés** :
- Target FPS : **30 locked** (Engine.max_fps = 30)
- Animations : `Tween.TRANS_LINEAR` + `step()` côté shader, pas de `LERP`
- Vertex jitter intensity : 0.5-1.0 px (à doser, trop = nausée)

### 2.2 Palette canonique parchemin (relique sur minigames)

Conservée du système actuel `MerlinVisual.PALETTE` :

```gdscript
"paper":        Color(0.965, 0.945, 0.905)  # Ivoire ancien
"ink":          Color(0.22, 0.18, 0.14)     # Encre brune profonde
"accent":       Color(0.58, 0.44, 0.26)     # Bronze ancien
"celtic_gold":  Color(0.68, 0.55, 0.32)     # Or celtique
"celtic_brown": Color(0.45, 0.36, 0.28)     # Brun enluminure
```

Cette palette n'apparaît plus que :
- Sur les minigames overlay (parchemin scriptural)
- Sur la typo Book of Kells (or celtique pour titres)
- Comme couleur d'ornement diégétique sur les pierres celtiques

### 2.3 Palettes biomes (8 — à finaliser)

Brief par biome (à détailler ultérieurement avec mood board) :

| Biome | Tonalité | Palette directrice | Brume |
|-------|----------|-------------------|-------|
| Landes | Mélancolique poétique | Gris-bleu, bruyère pourpre, vent visible | Basse, rasante |
| Côtes | Lumineux contemplatif | Bleu pâle, sable doré, blanc d'écume | Iodée, pulsante |
| Villages | Chaleur humaine voilée | Brun chaud, ocre, fumée bleue | Peu, par taches |
| Cercles (mégalithes) | Mystique sacré | Gris pierre, mousse vert sourd, lichen orange | Verdâtre rampante |
| Marais | Sombre étrange | Vert-noir, marron tourbe, lueurs verdâtres | Très épaisse, opaque |
| Collines | Onirique pastoral | Vert pomme, ciel rose voilé, blanc moutons | Vaporeuse, haute |
| Îles | Dépaysement irréel | Turquoise, basalte noir, magenta orchidée sauvage | Saline, irisée |
| Forêt (Brocéliande) | Cauchemar par moments | Vert profond, rouge sang ponctuel, or filtrant | Très dense, vibrante |

> ⚠️ **À valider via mood board** (nano-banana) avant production assets.

### 2.4 Glyphes Oghams animés (18 sorts vivants)

**Principe** : chaque Ogham n'est jamais affiché statiquement. Son icône s'anime selon une logique propre.

| Phase | Comportement |
|-------|--------------|
| **Disponible** (cooldown OK) | Glyphe pulse lent, lueur dorée subtle, traits visibles |
| **Survol** | Glyphe se redessine en trait progressif (1.5s loop), audio cristallin |
| **Activé** | Trait gravé en or vif, particules celtiques qui s'élèvent, son rituel |
| **En cooldown** | Glyphe terni, traits pointillés, compteur en chiffres celtiques |
| **Bonus biome** | Lueur supplémentaire couleur du biome autour du glyphe |

Les 18 Oghams gardent leur signature graphique authentique (traits sur ligne verticale) MAIS chaque trait est animé dans l'apparition — le joueur voit le sort se dessiner.

### 2.5 Refonte totale factions — 5 Clâns totémiques (DÉCIDÉ 2026-04-25)

**RUPTURE MAJEURE** : les 5 factions actuelles (`druides / anciens / korrigans / niamh / ankou`) sont **remplacées intégralement** par 5 Clâns totémiques. Migration code requise sur :
- `scripts/merlin/merlin_constants.gd` (FACTION_INFO, FACTION_KEYWORDS, FACTION_TIERS, FACTION_RUN_BONUSES)
- `scripts/merlin/merlin_reputation_system.gd` (FACTIONS array)
- Toutes les cartes FastRoute référençant les anciens noms
- Lore + dialogues Merlin

| Nouveau nom | Animal totem | Symbole celtique | Couleur signature | Hex |
|------------|-------------|------------------|-------------------|-----|
| **Clân du Corbeau** | Corbeau | Mort, prophétie, savoir caché | Noir + violet sombre | `#1A0F1F` + `#5B3A8C` |
| **Clân du Cerf** | Cerf | Royauté, renouveau, monde sauvage | Brun + or roux | `#6B4226` + `#C7882C` |
| **Clân du Loup** | Loup | Loyauté, instinct, chasse en meute | Gris + argent froid | `#5C5C66` + `#B8C0CC` |
| **Clân du Saumon** | Saumon | Sagesse ancestrale, mémoire, voyage | Bleu profond + nacre | `#1E3A5F` + `#E0E8F0` |
| **Clân de l'Ours** | Ours | Force, terre, protection des siens | Rouge brique + brun terre | `#8C2A1F` + `#5C3A28` |

**Représentation visuelle** : **pierres levées sculptées** (low-poly PS1, ~12 polys), une par Clân, plantées dans les biomes correspondants. Elles pulsent à la couleur signature du Clân selon la réputation actuelle :
- Hostile (≤ 5) : pulse rouge sang, vibration agressive
- Neutre (20-49) : pulse lent monochrome
- Content (≥ 50) : pulse couleur signature, halo doré subtil
- Endormi (≥ 80, fin débloquée) : éclat permanent, particules celtiques montantes

**À déterminer ultérieurement** (lore design pass) :
- Valeurs/philosophie de chaque Clân
- Verbes-actions favoris par Clân (cf. champs lexicaux)
- Type d'effets sur le joueur (heal/damage patterns)
- Affinité biome préférée par Clân

### 2.6 Typographie hybride (CHOIX FIGÉS)

- **Titres / Oghams / Sacré** : **Uncial Antiqua** (Google Fonts, libre). Inspirée des manuscrits irlandais médiévaux. Or celtique (`celtic_gold` 0.68/0.55/0.32) sur fond sombre, taille généreuse (40-72px). Letter-spacing +5%.
- **Corps texte / Cartes / UI** : **m6x11** (Daniel Linssen, libre). Bitmap monospace 11px, lisibilité maximale en pixel art, support français complet. Encre noire (`ink` 0.22/0.18/0.14) sur parchemin pour le 2D, blanc cassé sur fond sombre pour le rail 3D.

**Téléchargement** :
- Uncial Antiqua : https://fonts.google.com/specimen/Uncial+Antiqua
- m6x11 : https://managore.itch.io/m6x11 (gratuit, CC0-like)

**Intégration Godot** : importer en `.ttf` dans `assets/fonts/`, créer FontFile resources, référencer dans `MerlinVisual` autoload.

### 2.7 HUD gameplay (lisibilité prioritaire)

- **Vie** : barre horizontale en haut centre, encre noire sur ivoire, pulse rouge sur dégât
- **5 jauges factions** : bottom row, chacune avec son totem animal en icône, couleur signature
- **Oghams disponibles** : barre verticale gauche, glyphes animés (cf. 2.4)
- **Multiplicateur score** : top right, chiffre celtique
- **Texte UI** : bitmap mono PS1 sauf titres en celtique

Bordure HUD : ornement celtique subtil sur les coins (entrelacs simplifié), opacité 30% pour ne pas surcharger.

---

## 3. Transitions et moments clés

### 3.1 Transitions inter-scènes (Hub ↔ Rail ↔ Carte ↔ Minigame)

**Effet "Scanline glitch celtique"** (300-500ms) :

1. CRT distorsion s'intensifie (chromatic aberration ×3, courbure ×2)
2. Oghams aléatoires flashent en or sur l'écran (3-5 glyphes)
3. Dithering pattern se réorganise visiblement (animation forcée)
4. Audio : crackle vinyle + cloche cristalline
5. Nouvelle scène apparaît sous le pattern qui se résorbe

### 3.2 Écran de mort — "Vision du corbeau"

Aucun "Game Over" texte. Séquence cinématique courte (4-6s) :

1. POV bascule vers un corbeau perché à proximité du joueur
2. Le corbeau s'envole, caméra le suit en POV (vol bas)
3. Le rail rétrécit en bas de l'écran à mesure que le corbeau monte
4. Au pic, fondu vers ciel d'orage gris-violet
5. Texte celtique apparaît : "Ton souffle a rejoint l'Awen"
6. Calcul Anam s'affiche en bas (chiffres celtiques)
7. Retour Hub avec page du grimoire qui se tourne

### 3.3 Bascule cauchemar folklorique

Déclencheurs :
- Mort imminente (vie ≤ 10)
- Faction à hostilité maximale (≤ 5)
- Promesse brisée majeure
- Esprit vexé en minigame raté

Effets cumulés (5-10s) :
- Brume devient rouge sombre
- Vertex jitter ×3 (déformation visible)
- Scanlines passent de subtiles à hardcore
- Présence : silhouette indistincte au loin (Sluagh, Banshee, Each-uisge)
- Audio : drone basse fréquence + chuchotements gaéliques

Cap : **1 séquence cauchemar maximum par run** (sinon dilue le ton contemplatif).

---

## 4. Différentiation biomes (4 axes)

Chaque biome se distingue sur **les 4 axes simultanément** :

### 4.1 Architecture végétale unique
Brief par biome (low-poly PS1, 6-20 polys par élément) :
- **Landes** : ajoncs cubiques, bruyère plate en quadrilatères, tertres en cône
- **Côtes** : roseaux verticaux, dunes en arches, rochers lissés
- **Villages** : maisons triangulaires couvertes de chaume, puits, palissades
- **Cercles** : monolithes verticaux, dolmens en U, cromlechs en cercle
- **Marais** : arbres morts tortueux, troncs immergés, joncs inclinés
- **Collines** : pommiers ronds, haies en murs verts, moulins à vent triangulaires
- **Îles** : palmiers stylisés (étrangers), basalte hexagonal, criques en arcs
- **Forêt** : chênes massifs polygonaux, racines visibles, sous-bois en facettes

### 4.2 Densité de brume variable
- **Marais** : brume opaque (90% visibilité 0)
- **Forêt** : brume dense (70%, vibrante)
- **Cercles** : brume rampante (50%, verdâtre)
- **Landes** : brume basse (30%, rasante)
- **Côtes** : brume iodée pulsante (20%, salée)
- **Collines** : brume haute (15%, vaporeuse)
- **Villages** : brume par taches (10%, par bouffées)
- **Îles** : brume saline irisée (40%, magique)

### 4.3 Créatures / totems spécifiques
1-2 par biome, **présences sans corps** (cf. décision 9) :
- Landes : pierres levées qui chantent au vent
- Côtes : phoques pulsants en silhouette, mouettes
- Villages : fumée vivante, chiens-ombres
- Cercles : druides en halos blancs flottants
- Marais : feux follets, voix sous l'eau
- Collines : pommes lumineuses qui flottent, moutons-nuages
- Îles : sirènes en brume, méduses lumineuses
- Forêt : Cernunnos en silhouette, biches blanches, corbeaux

### 4.4 Signature audio (DIRECTION : PS1 lo-fi authentique)

Direction sonore globale : **PS1 lo-fi authentique** — compression 22kHz mono, grain analogique, MIDI samples celtiques, OST style Lunacid / King's Field.

Signatures audio par biome (à produire avec contraintes PS1) :
- **Landes** : vent rasant dans bruyère + cliquetis ajoncs + cris d'oiseaux distants compressés
- **Côtes** : vagues lentes + mouettes lo-fi + cliquetis galets + cor de brume distant
- **Villages** : feu de cheminée crépitant + chuchotements + chien qui aboie loin + cloche d'église
- **Cercles mégalithes** : bourdonnement basse fréquence + chant grave druide éthiopien-comme + craquements pierre
- **Marais** : glouglous d'eau noire + grenouilles lo-fi + crissements bois mort + ricanement folliet
- **Collines** : vent généreux + bla bla moutons compressé + clochettes lointaines + harpe MIDI éparse
- **Îles** : vagues sales + cris d'oiseaux marins exotiques + chant sirène lo-fi distant + craquements basalte
- **Forêt Brocéliande** : silence épais + bruissements feuilles soudain + corbeau distant + souffle indistinct (lien cauchemar)

Direction musicale (OST) :
- Instruments : harpe celtique MIDI samples, flûte irlandaise lo-fi, bodhrán compressé, voix gaeliques échantillonnées 22kHz
- Composition : drones évolutifs 1-3 minutes par biome, 0 mélodie chantable, focus atmosphérique
- Cauchemar bascule : drone basse + chuchotements gaeliques renversés + cliquetis horlogère distorsionné
- Référence absolue : Lunacid OST (ROCKET POW MUSIC, 2023)

---

## 4.5 Items collectibles 3D — Glyphes flottants brillants

Pendant la marche 3D, les items de monnaie biome (1 toutes les 3-5s) apparaissent comme :
- **Petits glyphes Oghams flottants** (~10cm dans l'espace), suspendus à hauteur des yeux du joueur
- Pulse doré lent (1.2s cycle), particules dorées montantes subtiles
- Au survol/clic : flash blanc cristallin, glyphe absorbé en spirale, son cristallin
- Couleur : or celtique signature (`#C7882C`) — uniforme cross-biomes pour lisibilité

> Cohérent avec décision §2.4 (Oghams animés vivants) — l'univers est saturé d'Oghams qui dansent.

## 4.6 IntroCeltOS — retouche v3

L'intro actuelle "boot terminal sombre" est **conservée** mais retouchée pour aligner sur le stack v3 :
- Ajouter dithering Bayer 4×4 sur tout le terminal (déjà cohérent avec l'esthétique CRT)
- Ajouter scanlines CRT subtiles (cohérent avec le reste du jeu)
- Ajouter courbure CRT légère (cohérent)
- Conserver typo terminal monospace existante
- Conserver glyphes Oghams qui s'égrènent (déjà signature forte)

L'IntroCeltOS reste un boot druidique digital qui transitionne vers le monde parchemin/biome — rôle narratif inchangé.

## 4.7a Caméra du rail 3D — Première personne (POV)

**Décision** : caméra POV, le joueur EST un halo qui flotte. Cohérent avec "présences sans corps" généralisé.

Spécifications :
- FOV : 60° (PS1 typique, pas 90° moderne)
- Hauteur caméra : 1.5m (comme un humain debout)
- Bobbing léger (vertical sine 0.05m, période 1.2s) pour suggérer la flottaison
- Pas de modèle de mains/corps visible
- Quand le joueur "regarde" un Ogham flottant, léger zoom (FOV passe à 50° pendant 0.4s)
- Vertex jitter sur géométrie distante (non sur la caméra elle-même pour éviter la nausée)

⚠️ **Risque motion sickness** : le combo POV + vertex jitter est un risque. Doser avec extrême prudence en playtest. Si insupportable, fallback dynamique : passer à 3e personne (cf. §4.7c) lorsque le joueur signale un malaise — mais le `Stack PS1 non-négociable` interdit cet override automatique. À voir avec playtests réels.

## 4.7b Présentation de Merlin — Halo + pierre centrale qui parle

**Décision** : Merlin n'est pas un personnage baladeur. Il est ancré dans une **grande pierre levée centrale** au Hub 2D (l'Antre de Merlin / Hub).

- Cette pierre porte un halo doré pulsant (le "siège" de Merlin)
- Quand le joueur entre dans le Hub : la pierre s'éveille, halo s'intensifie, voix se manifeste
- Quand le joueur part en biome : la voix de Merlin **suit le joueur** dans le rail (audio 3D positionné au-dessus de l'avatar invisible) — mais aucun visuel ne suit, juste la voix
- En cas de dialogue critique mid-run, la voix peut s'accompagner d'un halo doré flottant transitoire qui apparaît à 2m devant le joueur, pulse, puis disparaît

Avantages :
- Anchor narratif fort (le Hub EST Merlin, on rentre chez lui)
- Évite tout modèle 3D de Merlin (cohérent §2.5)
- Permet à la voix d'être omniprésente sans surcharge visuelle

## 4.7c Menu principal — Grimoire ouvert plein écran

**Décision** : le menu principal n'est PAS un terminal ni une scène 3D. C'est un **grand grimoire celtique ouvert** qui occupe l'écran.

Specs :
- Page de gauche : illustration enluminée du titre "M.E.R.L.I.N. — Le Jeu des Oghams" (capitales Book of Kells / Uncial Antiqua, or sur parchemin)
- Page de droite : table des matières illuminée — entrées du menu sous forme de capitales celtiques numérotées
  - I. Nouvelle Partie
  - II. Reprendre
  - III. Sentier (progrès / arbre Anam)
  - IV. Réglages
  - V. Quitter
- Hover sur une entrée : un petit Ogham authentique s'illumine en or à côté
- Click : la page se tourne (animation, cf. §4.8)
- Background : fond noir profond avec scanlines + dithering subtil
- Coins : ornements celtiques diégétiques sur le grimoire lui-même

Transition depuis IntroCeltOS : le terminal se "résout" en grimoire (les caractères du terminal se métamorphosent en lettres enluminées, scanlines persistent).

## 4.7d Fin de run réussie — Inscription dans le grimoire

**Décision** : sur fin narrative débloquée (faction ≥ 80), le grimoire prend le centre.

Séquence (8-12s) :
1. Fondu vers le grimoire ouvert (même asset que menu principal)
2. Page de droite vide se présente, parchemin neuf
3. Une plume invisible commence à écrire :
   - Nom du Clân vainqueur (en capitales Uncial or)
   - Nom symbolique du run (généré par LLM ou semi-aléatoire)
   - Date celtique stylisée
   - Ornement final qui s'enroule autour
4. Apparition de l'icône totem du Clân, qui pulse à sa couleur signature
5. Bruit de plume + parchemin + cloche cristalline
6. Texte poétique court (1 ligne) : "Ainsi fut écrit le passage de [nom du joueur]"
7. Calcul Anam s'inscrit en chiffres celtiques en bas de page
8. Bouton "Tourner la page" pour retour Hub

Symétrie avec mort "Vision du corbeau" : la mort = fuite vers le ciel, la victoire = inscription dans la pierre/parchemin. Le joueur soit s'élève, soit reste.

## 4.8 Animation tournage de page — 3D facetté PS1

Le tournage de page est l'animation la plus utilisée du jeu (menu principal → jeu, fin de run, peut-être transitions). Elle doit être satisfaisante.

Specs :
- Page modélisée en plane low-poly (8-12 quads)
- Pliage progressif via vertex shader (courbure 0→180°)
- Durée : 250-350ms (snappy mais lisible)
- Vertex jitter assumé sur la page en mouvement (cohérent stack PS1)
- Texture parchemin appliquée (affine warping visible pendant le pli)
- Audio : papier compressé 22kHz, frottement bref, résolution finale en cloche cristalline

Variantes :
- Menu principal → Nouvelle Partie : 1 page
- Fin de run → Hub : 2-3 pages successives (plus solennel)
- Mort → Hub : 1 page qui se déchire (variante : pli inversé + crackle)

## 4.9 Apparition d'une carte — Déplié de page parchemin

Quand le joueur termine un segment de marche 3D et qu'une carte apparaît :

Séquence (500-700ms) :
1. La marche se fige (FOV bloqué, vertex jitter persiste, ambient continue)
2. Un petit parchemin enroulé apparaît à 1m devant le joueur, en bas de l'écran
3. Le parchemin se déplie en montant et grossissant (animation 3D PS1)
4. À la fin : carte plein écran 2D, fond rail dithéré en arrière-plan
5. Audio : déroulement papier, cloche cristalline, ambient du biome qui s'atténue

Quand le joueur fait son choix : la carte se réenroule rapidement (200ms) et disparaît, la marche reprend.

## 4.10 Feedback action — Floating numbers PS1

Quand un effet s'applique (faction +5, vie -3, gain monnaie, etc.) :

- Un petit chiffre apparaît au centre de l'écran (bitmap PS1 m6x11, 24-32px)
- Couleur selon le type :
  - Vert : gain
  - Rouge : perte
  - Or : monnaie / Anam
  - Couleur Clân : changement de réputation
- Anim : monte de 60-80px en 600ms, fade out sur les 200 derniers ms
- Trajectoire : vers la jauge cible du HUD (vie, faction, etc.)
- À l'arrivée : la jauge cible pulse brièvement
- Audio : son court tonalité selon type (cristallin pour gain, métal mat pour perte)

Multiple effets simultanés : staggered de 80-120ms entre chaque chiffre pour ne pas surcharger.

## 4.11 Pierres totem — 1 par Clân par biome

Chaque biome contient les **5 pierres-totems** (une pour chaque Clân), placées dans la même configuration relative (pour repère) :
- Disposition en quinconce ou cercle léger autour du chemin du rail
- Distance du chemin : 5-15m (visibles mais pas obstruantes)
- Polycount : 12 polys par pierre
- Hauteur : 2-4m (variable selon Clân : Ours plus trapu, Cerf plus élancé)
- Sculpture du totem animal en bas-relief sur la face avant
- Pulse selon réputation du Clân (cf. §2.5)

**Cohérence cross-biomes** : la pierre du Clân du Loup a la même silhouette dans tous les biomes (juste l'environnement change). Le joueur reconnaît instantanément ses Clâns.

## 4.12 Différenciation cartes par Clân — Sigil totem + bordure

**Décision** : carte universelle (même layout, même typo, même parchemin) + différenciation par 2 éléments :
1. **Sigil totem** : silhouette du totem du Clân associé en bas-centre (or sur parchemin)
2. **Bordure subtile** : bordure de la carte avec teinte 5-10% de la couleur signature du Clân

Cohérence : toutes les cartes restent immédiatement lisibles, mais le Clân se devine sans lire le texte.

## 4.13 Skybox biomes — Ciel animé lent

Le ciel occupe 30-50% de l'écran selon l'angle. Direction :
- Cubemap PS1 basse résolution (256×256 par face) avec dithering
- Mouvement : nuages low-poly qui défilent lentement (1-3 minutes par cycle complet)
- Soleil/lune visible selon le biome (présent mais flou, voile de brume)
- Gradients colorés du biome (cf. §2.3)

Variantes par biome :
- Marais : pas de soleil visible, ciel oppressant uniforme vert-noir
- Côtes : soleil voilé bas, mouettes silhouettes croisent l'écran
- Forêt Brocéliande : ciel à peine visible (canopée dense), juste des taches de lumière
- Cercles : ciel ouvert, étoiles visibles même de jour (signe sacré)

## 4.14 Menu de pause — Mini-grimoire flottant

Quand le joueur appuie sur Échap (ou pause) :
- Le rail/carte se fige et passe en flou + dithering plus fort en arrière-plan
- Un mini-grimoire ouvert apparaît au centre (1/3 de l'écran), version réduite du menu principal
- Page gauche : "Pause" en capitales Uncial + heure de jeu en chiffres celtiques
- Page droite : 4 options (Reprendre / Réglages / Hub / Quitter)
- Hover : Ogham qui s'illumine, identique au menu principal
- Audio : pause = son cristallin doux, reprise = page qui se tourne

Cohérence garantie avec menu principal et fin de run (même asset grimoire, échelle différente).

## 4.15 Choix fin multi-factions — Cercle de pierres totems

Cas spécial (2+ Clâns ≥ 80 en fin de run) : sequence dédiée 3D PS1.

Séquence (10-15s) :
1. Fondu vers une scène 3D dédiée : un cromlech ouvert circulaire, ciel violet-or au-dessus
2. Les 2-5 pierres-totems concernées (selon Clâns ≥ 80) apparaissent en cercle, équidistantes
3. Chaque pierre pulse à sa couleur signature, particules celtiques qui montent
4. Le joueur (POV) peut tourner sa caméra librement, mais ne peut que regarder
5. Au centre : un autel-pilier qui invite au choix
6. Le joueur clique sur la pierre choisie → cette pierre s'illumine intensément, les autres s'éteignent
7. Transition vers la fin du Clân choisi (inscription dans le grimoire, cf. §4.7d)
8. Audio : drone profond + une note par pierre, cristallin lors du choix

## 4.16 Manifestation de Merlin parle — Pierre vibre + boîte de dialogue

Quand Merlin prend la parole (Hub ou voix-off pendant le rail) :
- La pierre centrale du Hub vibre subtilement (sine wave 0.5px amplitude)
- Halo doré pulse au rythme de la voix (1-2 pulses/seconde max)
- **Boîte de dialogue** apparaît en bas de l'écran : parchemin enroulé qui se déplie, texte en typo Uncial Antiqua (or sur parchemin)
- Texte écrit progressivement (typewriter effect, 60-80 char/s, son de plume sur papier)
- Le joueur peut accélérer (clic) ou skip (Échap)
- Audio : voix synthétisée ou enregistrée, traitement PS1 lo-fi (compression 22kHz, mono)

Lisibilité prioritaire — bridge entre PNJ central et stack rétro. Subtitles auto-on (compliance).

## 4.17 Marchand — Pierre levée marchande

Rencontre rare (~1 par 2-3 runs), pendant le rail 3D POV :
- Une pierre levée différente apparaît sur le bord du chemin, beaucoup plus large que les pierres totems
- Glyphes commerciaux (Oghams stylisés) s'allument à l'approche
- Au clic : transition courte (scanline glitch celtique), arrivée sur scène 3D dédiée
- Scène : la pierre marchande au centre, 3-5 Oghams flottants disponibles à l'achat (glyphes + prix en chiffres celtiques)
- Le joueur navigue avec POV, regarde, achète ou refuse
- Sortie : retour au rail à la même position, marche reprend

Audio : carillon de cloches au moment de la rencontre, son de pierre vibrant pendant la transaction.

## 4.18 Inventaire Oghams — Page de grimoire détaillée

Accès à l'inventaire Oghams via le grimoire (à tout moment au Hub, ou en pause durant un run via mini-grimoire) :
- Ouvre une page dédiée du grimoire ("Le Bestiaire des Sorts")
- Layout : 3 colonnes × 6 lignes = 18 emplacements (max Oghams)
- Chaque emplacement :
  - Glyphe Ogham (animé même statique, pulse subtil)
  - Nom en Uncial (or)
  - Description courte 1-2 lignes en m6x11
  - Cooldown actuel (chiffres celtiques)
  - Coût d'activation (Anam)
  - Indicateur "starter" / "appris" / "trouvé en run"
- Survol : zoom subtil sur la case, lueur dorée
- Click : active l'Ogham (si possible) ou montre détail complet en page séparée

Fond : parchemin standard, ornements diégétiques sur les coins.

## 4.19 Lighting biomes — Ombres baked simples

**Décision** : pas de shadow map dynamique, pas de full PS1 sans ombres. Compromis :
- Lightmap baked sur le sol et les éléments statiques
- Une seule lumière directionnelle par biome (cohérent avec la couleur du ciel/biome)
- Pas d'ombres sur les objets dynamiques (le joueur, items collectibles, présences)
- Vertex coloring sur les éléments low-poly pour suggérer le volume sans calcul

Avantages : performance excellente (PS1-friendly), donne du volume aux scènes sans complexité, donne un caractère "diorama" cohérent low-poly.

## 4.20 Marche POV — Bobbing rythmé + sons de pas

Compromis assumé : "présence sans corps" + sons de pas pour feedback tactile.

Specs :
- Bobbing vertical : sine 0.08m amplitude, période 0.85s (cadence marche)
- Bobbing latéral : sine 0.04m amplitude, période 1.7s (déhanchement subtil)
- Sons de pas : selon matériau biome
  - Forêt : feuilles sèches + craquement bois
  - Marais : succion vase + bulles
  - Côtes : sable craquant + cailloux
  - Cercles : pierre + mousse
  - Landes : herbe rase + cailloux
  - Villages : chemin de terre + pavés
  - Collines : herbe haute + insectes
  - Îles : sable mouillé + algues
- Cadence : 2 pas/seconde (constant, pas accélérable)
- Vitesse de déplacement : ~3.5 m/s (pas trop lent — sinon ennui — pas trop rapide — sinon perte du contemplatif)

## 4.21 L'Antre de Merlin — Pierre centrale + 5 totems autour

Hub 2D principal, vue de face symbolique :
- Centre : la pierre de Merlin (grande, 60% de la hauteur), halo doré
- Périphérie : 5 pierres-totems disposées en arc autour (de gauche à droite : Corbeau, Cerf, Loup, Saumon, Ours), tailles plus petites
- Arrière-plan : calendrier celtique stylisé en watermark (cycle des saisons en cercle, runes des mois)
- Sol : motif de pavage celtique (entrelacs subtils, encre sur parchemin)
- Ciel : noir profond avec étoiles + scanlines + dithering
- Ornements diégétiques : sur les pierres uniquement (entrelacs sculptés)

Cliquer sur :
- Pierre Merlin → dialogue avec Merlin
- Pierre totem → consulter détail Clân (réputation, cartes, fin débloquée?)
- Calendrier → progrès saison/festival
- Bouton "Partir" en bas centre → sélection biome → run

## 4.22 Esprits vexés — Glyphes Oghams en colère

Trigger cauchemar (esprit vexé suite à minigame raté) :
- Apparition immédiate de 5-8 glyphes Oghams ROUGES tordus autour du joueur (POV ou carte)
- Glyphes vibrent en haute fréquence, distordus (warping shader)
- Trajectoires erratiques : ils se rapprochent du joueur en spirale
- Particules rouges + sang-or qui s'égrènent
- Les glyphes se brisent en éclats au contact (audio : verre brisé + cris compressés)
- Effet de jeu : -X PV ou -Y rep faction (selon le minigame raté)
- Durée : 1.5-2.5s, intense, non-skippable

Si esprit vexé déclenche le mode cauchemar : enchaîner immédiatement sur §3.3 (Bascule cauchemar folklorique).

## 4.23 Onboarding — Sans tutoriel, par pratique

**Décision assumée** : pas de tutoriel explicite, pas de "Press X to attack", pas de pages d'intro. Le joueur découvre par essai-erreur.

Mitigations pour éviter le rejet :
- Premier run : Merlin parle plus que d'habitude (mais sans expliquer, juste contextualiser)
- HUD reste visible et lisible : le joueur déduit les jauges
- Première carte : choix simples (3 options claires, aucun terme jargon)
- Onbording silencieux : les premiers Oghams disponibles sont les 3 starters bien introduits dans le grimoire
- Si mort première run : le récapitulatif "Vision du corbeau" + page grimoire montre ce qu'il a appris
- Aucun panneau pédagogique, aucune popup explicative

Public cible assumé : exigeant, type Lunacid / Hyper Light Drifter / Pathologic. Argument marketing : "Discover the way of the Oghams. No hand-holding, no compromise."

## 4.7 Accessibilité — Stack PS1 NON-NÉGOCIABLE

**Décision assumée** : pas d'options pour désactiver vertex jitter / dithering / scanlines / 30fps lock. Le PS1 retro est l'âme du jeu, public cible niché (fans Lunacid, retro horror, indie occult).

**Implications** :
- Pas de menu accessibilité visuelle
- Risque assumé : perte de joueurs sensibles (nausée, photosensibilité)
- Vertex jitter intensité dosée à 0.5 px max (le minimum pour la signature, pas de surcharge)
- Pas de flashs > 3Hz (compliance épilepsie minimale, requis légalement)
- Subtitles obligatoires (compliance audio)

**Communication marketing** : assumer "Authentic PS1 experience, not for the faint of heart" comme argument d'identité.

---

## 5. À faire (next steps)

- [ ] Mood board nano-banana : 4-6 images de référence
- [ ] Mapping totems → 5 factions (cohérence lore)
- [ ] Palettes biomes finalisées (RGB précis x 8)
- [ ] Sélection police Book of Kells custom + bitmap PS1
- [ ] Shader vertex jitter Godot 4.5 implémenté
- [ ] Shader dithering Bayer 4×4 + scanlines compositor
- [ ] Refactor `MerlinVisual.gd` → support multi-palette biome
- [ ] Asset pipeline : 8 biomes × architecture végétale unique
- [ ] Animation pipeline : 18 Oghams animés (états disponible/survol/activé/cooldown/bonus)
- [ ] Animation pipeline : 5 totems pierres pulsantes
- [ ] Cinématique mort "Vision du corbeau"
- [ ] Effet "Scanline glitch celtique" (transitions)
- [ ] Effet "Bascule cauchemar folklorique"

---

## 6. Tensions assumées (à surveiller en playtest)

1. **HUD classique vs immersion onirique** — rupture justifiée par la densité mécanique (5 jauges, 18 Oghams). À retester en playtest.
2. **PS1 rétro vs accessibilité typo** — bitmap mono fatigue sur longs textes. Mitigé par les capitales Book of Kells dans les titres.
3. **Cauchemar par moments vs contemplatif** — cap strict à 1/run. Si le joueur déclenche plusieurs triggers, n'afficher qu'une seule séquence.
4. **8 palettes biomes vs cohérence visuelle** — risque de "8 jeux différents". Compensé par les ornements celtiques partagés et le stack post-process commun.
5. **Vertex jitter intensité** — peut provoquer nausée. Doser à 0.5-1.0 px max et offrir option d'accessibilité.

---

## 7. Références visuelles obligatoires

À consulter avant tout asset :

- **Lunacid** (KIRA, 2023) — north star, PS1 occulte
- **Sable** (Shedworks, 2021) — low-poly cel-shaded contemplatif
- **Citizen Sleeper** (Jump Over The Age, 2022) — cartes typo + sigils
- **Inscryption** (Daniel Mullins, 2021) — minigames rituels Act 2
- **Hyper Light Drifter** (Heart Machine, 2016) — silhouettes glow
- **Hylics** (Mason Lindroth, 2015) — dérangement onirique digestible
- **Book of Kells** (manuscrit, ~800 AD) — capitales celtiques, ornement
- **Sluagh / Banshee / Each-uisge** (folklore celtique) — pour bascule cauchemar

---

*Document v3 — 2026-04-25 — Vision graphique consolidée par dialogue Maxime+Claude (8 questions × 4 = 32 décisions raffinées).*
