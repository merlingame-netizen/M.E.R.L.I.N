# Plan Assets 3D — Foret de Broceliande (FPS Path)

> Version aboutie du prototype archive `SceneBroceliandeFPS.gd`.
> Objectif : marche contemplative FPS sur un sentier sinueux a travers Broceliande.

---

## 1. Vision

**Experience** : Le joueur marche sur un sentier forestier (pas de libre exploration complete).
Le chemin serpente a travers la foret, avec des zones d'interet narratives (clearings).
L'atmosphere est mystique, brumeuse, avec des jeux de lumiere a travers la canopee.

**Style** : Low-poly faceted (flat shading), palette GBC Broceliande.
**Camera** : FPS classique (WASD + mouselook), vitesse lente/contemplative.
**Ameliorations vs prototype** :
- Sentier structure (pas d'errance libre dans un carre)
- Vegetation dense et variee (pas juste des cones/cylindres proceduraux)
- Eclairage volumetrique (rayons de soleil a travers les arbres)
- Particules atmospheriques (pollen, lucioles, brume au sol)
- Points d'interet narratifs le long du chemin
- Son spatialisc (oiseaux, ruisseau, vent dans les feuilles)

---

## 2. Inventaire assets existants (reutilisables)

### Modeles GLB deja disponibles (archive/)

| Asset | Fichier | Usage Broceliande |
|-------|---------|-------------------|
| Chene ancien | `08_OldOak_Merlin.glb` | **HERO TREE** — point central |
| Arbre dore | `09_GoldenTree_Sacred.glb` | Clearing sacre |
| Arbre spirale | `10_SpiralTree_Mystic.glb` | Zone mystique |
| Saule pleureur | `11_Willow_Enchanted.glb` | Bord de mare |
| Arbre argente | `12_SilverTree_Moon.glb` | Clairiere de lune |
| Arbre mort | `28_Tree_Dead.glb` | Zones sombres |
| Bouleau | `29_Birch.glb` | Lisiere |
| Petit/Moyen/Grand arbre | `01-03_Tree_*.glb` | Remplissage foret |
| Pin | `04_Pine.glb` | Coniferes en fond |
| Cypres | `05_Cypress.glb` | Sentinelles |
| Thuya | `06_Thuya.glb` | Bordure sentier |
| Buissons (3 types) | `07, 26, 27_Bush*.glb` | Bordure chemin |
| Fougeres | `16_Fern.glb` | Sous-bois dense |
| Herbe haute/courte | `17-18_Grass_*.glb` | Sol foret |
| Champignons | `19-20_Mushroom_*.glb` | Details sol |
| Rochers (3 types) | `21-23_Rock_*.glb` | Bordure/obstacles |
| Paquerettes | `25_Daisy.glb` | Clairiere |
| Nenuphars | `13-15_LilyPad_*.glb` | Mare enchantee |
| Quenouilles | `24_Cattail.glb` | Bord de mare |
| Tuiles herbe (5) | `Tile_01-05_Grass_*.glb` | Sol sentier |
| Tuiles terre (4) | `Tile_06-09_Dirt_*.glb` | Chemin principal |
| Tuiles boue (3) | `Tile_10-12_Mud_*.glb` | Zones humides |
| Tuiles mousse | `Tile_*_Moss_*.glb` | Sous-bois |
| Terrain vallon | `Terrain_Vallon_Complete.glb` | Base terrain |
| Falaise bretonne | `Falaise_Bretonne_Complete.glb` | Bords de carte |

**Total reutilisable : ~45 modeles GLB**

---

## 3. Assets manquants (a generer via TRELLIS.2)

### 3.1 Elements de sentier (P1 — critiques)

| Asset | Description | Source image a creer |
|-------|------------|---------------------|
| **Dolmen** | Trilithon megalithique, pierres moussues | Low-poly dolmen, moss-covered stones, white bg |
| **Menhir** | Pierre dressee 2-3m, gravures ogham | Standing stone with ogham carvings, low-poly |
| **Pont de bois** | Petit pont sur ruisseau, planches moussues | Wooden bridge, moss, low-poly forest |
| **Souche geante** | Tronc coupe ancien, champignons dessus | Giant tree stump with mushrooms, low-poly |
| **Arche de racines** | Racines entremelees formant arche naturelle | Natural root arch, twisted roots, low-poly |
| **Lanterne feerique** | Petite cage lumineuse suspendue | Fairy lantern, glowing, crystal cage, low-poly |

### 3.2 Points d'interet narratifs (P1)

| Asset | Description | Lien gameplay |
|-------|------------|--------------|
| **Fontaine de Barenton** | Source sacree, bassin de pierre, eau claire | Lieu de Viviane |
| **Tombeau de Merlin** | Cairn de pierres empilees sous un if | Point final |
| **Cercle de pierres** | 7 menhirs en cercle, mousse | Rituel ogham |
| **Chene de Merlin** | Variante du OldOak avec creux lumineux | Rencontre Merlin |
| **Autel druidique** | Pierre plate sureleve, offrandes | Choix narratif |

### 3.3 Creatures/PNJ (P2)

| Asset | Description | Lien Triade |
|-------|------------|-------------|
| **Korrigan** | Petit etre malicieux, chapeau, pieds nus | Ame |
| **Biche blanche** | Cervidee etheree, translucide | Monde |
| **Loup de brume** | Loup spectral, contours flous | Corps |
| **Feu follet** | Sphere lumineuse pulsante | Guide sentier |
| **Corbeau geant** | Corbeau surdimensionne, oeil intelligent | Ame (observateur) |

### 3.4 Decor atmospherique (P3)

| Asset | Description |
|-------|------------|
| **Tronc tombe** | Arbre tombe en travers, mousse |
| **Toile d'araignee** | Entre deux arbres, rosee |
| **Ruisseau** | Segment d'eau courante (mesh anime) |
| **Racines apparentes** | Reseau racinaire au sol |
| **Champignon geant** | Amanite surdimensionnee, lueur |

---

## 4. Structure du sentier

```
                    [Entree]
                       │
              ┌────────▼────────┐
              │ Lisiere — Bouleau│  Zone 1: Introduction
              │ + Brume legere   │  Assets: Birch, Fern, mist particles
              └────────┬────────┘
                       │ (sentier terre)
              ┌────────▼────────┐
              │ Foret dense     │  Zone 2: Immersion
              │ + Canopee fermee│  Assets: Tree_Large, Pine, OldOak, mousse
              └────────┬────────┘
                       │ (sentier + racines)
              ┌────────▼────────┐
              │ Dolmen Clearing │  Zone 3: Premier point d'interet
              │ + Menhirs       │  Assets: Dolmen, Menhir, Daisy, lumiere
              └────────┬────────┘
                       │ (descente)
              ┌────────▼────────┐
              │ Mare enchantee  │  Zone 4: Zone aquatique
              │ + Pont de bois  │  Assets: Willow, LilyPad, Bridge, Cattail
              └────────┬────────┘
                       │ (montee)
              ┌────────▼────────┐
              │ Foret profonde  │  Zone 5: Atmosphere sombre
              │ + Brume epaisse │  Assets: DeadTree, Mushroom_Giant, fog dense
              └────────┬────────┘
                       │ (arche de racines)
              ┌────────▼────────┐
              │ Fontaine de     │  Zone 6: Revelation
              │ Barenton        │  Assets: Fountain, SacredTree, light rays
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │ Cercle de       │  Zone 7: Climax
              │ pierres + Merlin│  Assets: StoneCircle, OakMerlin, glow
              └────────┬────────┘
                       │
                    [Sortie → Hub]
```

**Longueur totale** : ~200m de sentier sinueux
**Temps de parcours** : 3-5 minutes a vitesse contemplative (2.5 m/s)
**Largeur sentier** : 1.5-2m (assez etroit pour forcer la perspective)

---

## 5. Palette couleurs Broceliande 3D

```
# Sol
DIRT_PATH     = Color(0.28, 0.20, 0.12)   # Sentier terre
MOSS_GREEN    = Color(0.18, 0.30, 0.12)   # Mousse
DARK_EARTH    = Color(0.12, 0.08, 0.05)   # Sol foret

# Vegetation
LEAF_DARK     = Color(0.10, 0.24, 0.10)   # Feuillage sombre
LEAF_MID      = Color(0.18, 0.38, 0.12)   # Feuillage moyen
LEAF_BRIGHT   = Color(0.30, 0.50, 0.18)   # Feuillage eclaire
TRUNK_DARK    = Color(0.15, 0.10, 0.06)   # Ecorce sombre
TRUNK_LIGHT   = Color(0.30, 0.22, 0.14)   # Ecorce claire

# Pierres
STONE_DARK    = Color(0.20, 0.20, 0.18)   # Pierre sombre
STONE_LIGHT   = Color(0.42, 0.40, 0.36)   # Pierre claire
STONE_MOSS    = Color(0.22, 0.30, 0.18)   # Pierre moussue

# Eau
WATER_DEEP    = Color(0.08, 0.18, 0.22)   # Eau profonde
WATER_SURFACE = Color(0.15, 0.30, 0.28)   # Surface

# Atmosphere
FOG_COLOR     = Color(0.33, 0.43, 0.34)   # Brume verte
SKY_CANOPY    = Color(0.08, 0.11, 0.09)   # Ciel a travers canopee
LIGHT_RAY     = Color(0.90, 0.85, 0.60)   # Rayon de soleil

# Magie
GLOW_BLUE     = Color(0.34, 0.72, 1.00)   # Lueur feerique
GLOW_GOLD     = Color(0.85, 0.70, 0.30)   # Lueur sacree
FIREFLY       = Color(0.60, 0.90, 0.40)   # Luciole
```

---

## 6. Prompts TRELLIS.2 (concept art → 3D)

Style guide pour toutes les images source :
```
"low-poly 3D game asset, faceted flat-shading, celtic druidic style,
dark forest green and moss brown palette, isolated on pure white background,
game-ready prop, no textures, solid color faces"
```

### Exemples de prompts specifiques :

**Dolmen** :
```
"low-poly dolmen trilithon, three moss-covered ancient stones, celtic megalith,
dark gray with green moss patches, isolated on white background, game asset"
```

**Fontaine de Barenton** :
```
"low-poly sacred spring fountain, circular stone basin with clear water,
ancient celtic carved stones, moss and ferns, isolated on white background"
```

**Korrigan** :
```
"low-poly korrigan fairy creature, small mischievous humanoid, pointed ears,
red cap, bare feet, celtic folklore, isolated on white background, game character"
```

---

## 7. Pipeline de generation

```
1. Creer concept art (DALL-E / Midjourney / SD)
   → Images 1024x1024, fond blanc, objet isole

2. Post-process image si necessaire
   → Background removal (rembg)
   → Recadrage centre

3. TRELLIS.2 via Kaggle (trellis_generate_3d)
   → Resolution 512 pour props, 1024 pour hero assets
   → Output: GLB avec PBR materials

4. Post-process GLB (Blender optionnel)
   → Simplification mesh si trop de polygones
   → Ajustement couleurs pour matcher palette
   → Export GLB final

5. Import Godot
   → Placer dans assets/3d_models/broceliande/
   → Verifier import settings (flat shading, no compression)
   → Integrer dans scene
```

---

## 8. Structure fichiers cible

```
assets/3d_models/broceliande/
├── terrain/
│   ├── path_segment_straight.glb
│   ├── path_segment_curve.glb
│   ├── ground_forest_01.glb
│   └── ground_clearing_01.glb
├── vegetation/
│   ├── (reuse from archive/Assets/ — symlinks or copy)
├── megaliths/
│   ├── dolmen_01.glb
│   ├── menhir_01.glb
│   ├── menhir_02_ogham.glb
│   └── stone_circle.glb
├── structures/
│   ├── bridge_wood.glb
│   ├── root_arch.glb
│   ├── fairy_lantern.glb
│   └── druid_altar.glb
├── poi/           (points of interest)
│   ├── fountain_barenton.glb
│   ├── merlin_tomb.glb
│   └── merlin_oak.glb
├── creatures/
│   ├── korrigan.glb
│   ├── white_doe.glb
│   ├── mist_wolf.glb
│   └── giant_raven.glb
└── decor/
    ├── fallen_trunk.glb
    ├── giant_mushroom.glb
    ├── root_network.glb
    └── spider_web.glb
```

**Total assets a generer** : ~20 via TRELLIS.2
**Total assets reutilises** : ~45 depuis archive
**Grand total** : ~65 modeles pour la scene complete
