# BK N64 Asset Construction Bible

> Source de vérité pour la génération d'assets style Banjo-Kazooie dans M.E.R.L.I.N.
> Basé sur l'analyse de la ROM BK/BT, la décompilation n64decomp/banjo-kazooie, et la documentation N64 SDK.

---

## 1. Principes Fondamentaux (Constraints = Creativity)

### La Hiérarchie Visuelle BK
```
1. VERTEX COLORS (80% de la qualité visuelle)
   └─ Couleurs baked, AO, gradients, éclairage directionnel simulé
2. FORME (15%)
   └─ Silhouettes rondes, proportions exagérées, Gouraud shading
3. TEXTURES (5%)
   └─ Petits tiles 32x32 modulés par vertex colors : TEXEL0 × SHADE
```

**Règle d'or** : Un asset sans texture mais avec bon vertex painting > Un asset texturé sans vertex colors.

---

## 2. Budgets Polygones (données ROM)

| Type Asset | Budget Triangles | Référence BK |
|-----------|-----------------|-------------|
| Arbre complet (3D) | 40-60 | Spiral Mountain trees |
| Arbre billboard (distant) | 2 | Quad + texture alpha |
| Buisson (cross-billboard) | 4-8 | 2 quads en X |
| Touffe d'herbe | 4 | 2 quads en X, 16x16 CI4 |
| Rocher petit | 12-20 | BK generic rocks |
| Rocher moyen | 30-50 | Boulder cluster |
| Champignon | 8-16 | BK oversized mushrooms |
| Souche/tronc coupé | 16-30 | CCW stumps |
| Tronc tombé | 20-40 | Forest floor log |
| Fougère | 4-8 | Cross-billboard |
| Menhir | 24-40 | Simple tapered cylinder |
| Structure (hutte) | 80-150 | Mumbo's Hut ~120 |
| Pont | 60-100 | BK bridges |
| Collectible | 10-30 | Jiggy ~20, note ~10 |
| Créature petite | 100-200 | Ant = 276 |
| Créature moyenne | 200-400 | Jinjo ~250 |
| Panneau/poteau | 8-12 | Signpost |
| Clôture section | 8-16 | Fence posts |
| Scène totale visible | 3000-5000 | Spiral Mountain = 3,354 |

**IMPORTANT** : Nos assets actuels (200-600 tris) sont 3-10× trop lourds pour une forêt dense. Il faut des assets BEAUCOUP plus légers avec vertex painting comme compensation.

---

## 3. Vertex Coloring — La Technique Signature Rare

### 3.1 Mode Non-Éclairé (Environnements)
- `G_LIGHTING` désactivé → vertex RGBA lus directement
- Formule RDP : `output = TEXEL0 * SHADE` (texture × vertex color)
- Sans texture : `output = SHADE` (vertex color pur)

### 3.2 Composantes du Vertex Paint
| Composante | Technique | Effet |
|-----------|----------|-------|
| **Base color** | Couleur de surface assignée | Définit le matériau (herbe, pierre, bois) |
| **AO baked** | Vertices sombres aux contacts/crevasses | Profondeur, ancrage au sol |
| **Gradient hauteur** | Sombre en bas → clair en haut | Simule lumière ambiante |
| **Directionnel** | Faces orientées soleil = plus claires | Simule lumière directionnelle |
| **Température** | Soleil = chaud (jaune), ombre = froid (bleu) | Richesse chromatique |
| **Mousse/lichen** | Vert sur faces orientées haut + base | Organic weathering |
| **Jitter** | ±3-5% variation par vertex | Aspect peint à la main |
| **Alpha** | Blend entre 2 textures (Rare signature) | Herbe→terre transition |

### 3.3 Subdivision pour Résolution Couleur
- Les surfaces plates sont subdivisées 4×4 ou 8×8 **uniquement pour porter plus de vertex colors**
- Bords de loop supplémentaires là où les gradients changent
- **Compromis** : Plus de vertices = plus de résolution couleur mais plus de géométrie à transformer

---

## 4. Palette de Couleurs BK

### 4.1 Palette Forêt de Brocéliande (Green-Gold-Brown)
```python
BK_FOREST_PALETTE = {
    # Canopy & Herbe
    "canopy_bright":  (0.40, 0.62, 0.25),  # Vert vif feuillage soleil
    "canopy_shadow":  (0.18, 0.35, 0.12),  # Vert profond ombre couronne
    "grass_sun":      (0.42, 0.58, 0.22),  # Herbe ensoleillée
    "grass_shade":    (0.22, 0.38, 0.14),  # Herbe à l'ombre
    
    # Bois & Terre
    "bark_light":     (0.52, 0.36, 0.22),  # Écorce face soleil
    "bark_dark":      (0.22, 0.15, 0.08),  # Écorce crevasses
    "bark_root":      (0.35, 0.24, 0.14),  # Racines exposées
    "path_center":    (0.58, 0.42, 0.26),  # Chemin de terre centre
    "path_edge":      (0.48, 0.38, 0.22),  # Chemin bords
    
    # Pierre & Roche
    "stone_sun":      (0.55, 0.52, 0.48),  # Pierre face soleil (warm gray)
    "stone_shade":    (0.32, 0.30, 0.28),  # Pierre ombre
    "stone_moss":     (0.28, 0.40, 0.18),  # Pierre avec mousse
    "stone_lichen":   (0.50, 0.52, 0.40),  # Pierre avec lichen jaune-vert
    
    # Mousse & Végétation Basse
    "moss_dark":      (0.15, 0.30, 0.10),  # Mousse épaisse
    "moss_light":     (0.30, 0.45, 0.18),  # Mousse légère
    "fern_green":     (0.25, 0.50, 0.18),  # Fougère verte
    
    # Atmosphère
    "sky_zenith":     (0.28, 0.52, 0.85),  # Bleu ciel zénith
    "sky_horizon":    (0.70, 0.82, 0.68),  # Horizon vert-jaune brume
    "fog_forest":     (0.45, 0.55, 0.35),  # Brouillard forêt
    "water_surface":  (0.15, 0.30, 0.42),  # Eau ruisseau
    "water_shallow":  (0.22, 0.40, 0.35),  # Eau peu profonde
    
    # Accents
    "gold_collect":   (0.90, 0.78, 0.25),  # Collectibles dorés
    "magic_blue":     (0.30, 0.65, 1.00),  # Effet magique
    "cream_highlight":(0.94, 0.91, 0.82),  # Points lumineux
    "shadow_deep":    (0.12, 0.10, 0.08),  # Ombres profondes (JAMAIS noir pur)
    "mushroom_cap":   (0.72, 0.22, 0.15),  # Chapeau champignon (rouge BK)
    "mushroom_stem":  (0.85, 0.82, 0.72),  # Pied champignon (crème)
}
```

### 4.2 Règles Chromatiques
- **JAMAIS** de noir pur (0,0,0) → ombres = brun foncé (0.12, 0.10, 0.08)
- **JAMAIS** de blanc pur (1,1,1) → highlights = crème chaud (0.94, 0.91, 0.82)
- **Toujours** warm bias : gris → gris-brun chaud, ombres → brun-violet
- **Température** : soleil = +0.05 jaune/orange, ombre = +0.03 bleu/violet
- **Saturation** : poussée, jamais désaturée (sauf structures man-made = légèrement moins saturé)

---

## 5. Shape Language — Le Vocabulaire Formel BK

### 5.1 Règles de Forme
| Principe | Règle | Raison |
|----------|-------|--------|
| **Arrondi** | Pas d'arêtes vives sur organique | Gouraud shading sublime les ronds |
| **Exagéré** | Proportions 30-40% plus larges/courtes | Lisibilité à 320×240 |
| **Silhouette** | Forme lisible de n'importe quel angle | Camera fixe BK |
| **Épais** | Planches épaisses, troncs larges, pieds gros | Cartoon substantiel |
| **Penché** | Structures légèrement penchées/irrégulières | "Hand-built" feel |
| **Segmenté** | Membres = cylindres séparés (gaps visibles) | N64 pas de smooth skinning |

### 5.2 Catalogue des Formes par Type
```
ARBRE = Tronc cylindrique (6-8 côtés) + Couronne sphérique (ico subdiv 1-2)
        Tronc évasé à la base (racines = demi-sphères)
        Couronne aplatie Z × 0.5-0.7 (pas une sphère parfaite)
        
ROCHER = Icosphère subdiv 1-2, déformée noise, aplatie Z × 0.5-0.8
         Toujours posé à plat (vertices négatifs Z = 0)
         Bosselures secondaires (petites ico soudées)
         
BUISSON = Cross-billboard (2 quads en X, 90°), texture alpha
          OU 3-4 sphères aplaties soudées pour version 3D

CHAMPIGNON = Cylindre fin (6 côtés) + demi-sphère aplatie dessus
             Chapeau : rouge BK + pois blancs OU brun + beige
             Taille exagérée (50-80% hauteur Banjo)

SOUCHE = Cylindre court (8 côtés), top irrégulier, racines
         Cernes simulés par vertex paint concentrique

TRONC TOMBÉ = Cylindre horizontal + branches cassées (cones)
              Mousse sur face supérieure, AO en dessous

FOUGÈRE = Cross-billboard (4 tris), texture alpha verte
          OU fan de quads depuis centre (8-12 tris pour 3D)

MENHIR = Cylindre effilé (12 côtés), top arrondi
         Mousse progressive bas→haut, crevasses verticales

HUTTE = Cylindre 14 côtés + cône toit + cheminée
        Portes = rectangles sombres, fenêtres = cercles

PONT = Planches (cubes subdivisés) + poteaux + cordes
       Gaps entre planches, affaissement au centre

PANNEAU = Planche + poteau, texte simulé par vertex paint sombre

CLÔTURE = Poteaux + traverses, irrégulier, penché
```

---

## 6. Techniques Manquantes dans le Générateur Actuel

### 6.1 Cross-Billboards (CRITIQUE pour densité)
BK utilise massivement les cross-billboards pour le remplissage :
- **2 quads en X** (4 tris) pour herbe, fougères, fleurs
- **Pas de rotation caméra** (contrairement aux billboards purs)
- Texture alpha CI4 16×16 ou 32×32
- En Godot : 2 QuadMesh à 90° avec texture alpha + cull_disabled

### 6.2 Assets ULTRA Low-Poly Manquants
La forêt BK utilise ~30-60 meshes uniques à 10-60 tris chacun.
Notre générateur produit des assets à 200-600 tris → il en faut à **10-60 tris**.

### 6.3 Variation sans Nouveaux Meshes
BK réutilise 2-3 meshes par type avec :
- Rotation aléatoire Y
- Scale ±20%
- Vertex colors différents selon biome (palette swap via vertex paint)

### 6.4 Densité de Placement
| Zone | Assets/m² | Technique |
|------|----------|----------|
| Sol forêt | 0.5-1.0 | Grass billboards + fougères |
| Sous-bois | 0.3-0.5 | Champignons, souches, rochers |
| Canopée | 0.1-0.2 | Arbres 3D |
| Sentier | 0.05-0.1 | Rochers bord, signaux |
| Clairière | 0.02-0.05 | Structures + collectibles |

---

## 7. Éclairage — Tout Baked, Zéro Runtime

### Règles Matériau Godot (GL Compatibility)
```gdscript
mat.vertex_color_use_as_albedo = true
mat.roughness = 1.0        # Aucun specular
mat.metallic = 0.0         # Aucun metallic
mat.metallic_specular = 0.0 # Aucun specular IOR
mat.shading_mode = SHADING_MODE_PER_VERTEX  # Gouraud, pas per-pixel
# PAS de normal maps, PAS de emission, PAS de AO map
```

### Vertex Paint = Éclairage
- Direction soleil : upper-left (XZ = (-0.7, 0, -0.7))
- Faces orientées soleil : +15% luminosité, +warm tint
- Faces opposées : -20% luminosité, +cool tint
- Contact sol : -30% (AO quadratique)
- Crevasses : -40% (inward normal detection)

---

## 8. Catalogue d'Assets Dense Forest

### 8.1 Arbres (4 sous-types × 3 variantes = 12)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `oak_broad` | 40-60 | Chêne large, couronne aplatie, tronc épais |
| `pine_tall` | 30-50 | Pin conique, tronc fin, étages de branches |
| `willow_droop` | 50-70 | Saule pleureur, lobes pendants |
| `birch_slim` | 25-40 | Bouleau fin, couronne ovoïde étroite |

### 8.2 Végétation Basse (6 sous-types × 2 = 12)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `bush_round` | 12-20 | Buisson rond (3 sphères aplaties) |
| `fern_cross` | 4-8 | Fougère cross-billboard |
| `grass_tuft` | 4 | Touffe d'herbe cross-billboard |
| `mushroom_red` | 12-16 | Champignon rouge BK (gros chapeau) |
| `mushroom_brown` | 10-14 | Champignon brun (cluster petit) |
| `flower_cross` | 4-6 | Fleur cross-billboard |

### 8.3 Bois Mort (4 sous-types × 2 = 8)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `stump_short` | 16-24 | Souche basse, cernes vertex paint |
| `stump_tall` | 20-30 | Souche haute cassée irrégulière |
| `log_fallen` | 24-40 | Tronc tombé avec mousse |
| `branch_pile` | 12-20 | Tas de branches (cônes + cylindres) |

### 8.4 Rochers (3 sous-types × 3 = 9)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `rock_small` | 12-20 | Caillou (ico subdiv 1, noise) |
| `rock_medium` | 24-40 | Boulder (ico subdiv 2, bosses) |
| `rock_cluster` | 30-50 | Groupe de 3 petits rochers |

### 8.5 Mégalithes (2 sous-types × 3 = 6)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `menhir_tall` | 24-40 | Menhir classique |
| `dolmen_flat` | 40-60 | Dolmen (3 pierres + dalle) |

### 8.6 Structures (3 sous-types × 2 = 6)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `hut_round` | 80-120 | Hutte ronde celtique |
| `hut_long` | 100-150 | Longère |
| `shrine_stone` | 60-80 | Autel en pierre |

### 8.7 Props (5 sous-types × 2 = 10)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `bridge_plank` | 60-80 | Pont de bois |
| `fence_section` | 8-16 | Section de clôture |
| `signpost` | 10-16 | Panneau indicateur |
| `torch_stand` | 12-20 | Support torche |
| `well_stone` | 30-50 | Puits en pierre |

### 8.8 Collectibles (3 sous-types × 2 = 6)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `jiggy_star` | 20-30 | Étoile dorée |
| `ring_gold` | 16-24 | Anneau |
| `note_music` | 10-16 | Note musicale |

### 8.9 Créatures (3 sous-types × 2 = 6)
| Sous-type | Tris | Description |
|-----------|------|------------|
| `korrigan` | 150-200 | Lutin trapu |
| `doe` | 120-180 | Biche gracile |
| `wolf` | 140-200 | Loup forestier |

**TOTAL CATALOGUE : ~75 assets, budget moyen 30 tris → ~2,250 tris scène complète (dans budget 3,000-5,000)**

---

## 9. Composition de Niveau — Forêt Dense

### 9.1 Structure BK (Central Landmark + Loop Path + Branches)
```
                    [Outer Forest Wall — Dense trees]
                   /                                  \
      [Megalith   ]                                    [Creek + Bridge]
      [Hilltop    ]----[Path Branch]                  /
           |                                         /
    [Main Loop Path around Central Clearing]--------
           |                                         \
      [Hut Village]----[Path Branch]                  \
                   \                                  [Rock Outcrop]
                    [Outer Forest Wall — Dense trees]
```

### 9.2 Couches de Densité (intérieur → extérieur)
| Ring | Rayon | Assets | Densité |
|------|-------|--------|---------|
| Centre (clairière) | 0-15m | Structures, collectibles, 2-3 arbres | Basse |
| Intérieur | 15-25m | Arbres espacés, rochers, champignons | Moyenne |
| Milieu | 25-38m | Arbres denses, buissons, fougères | Haute |
| Extérieur | 38-55m | Mur d'arbres, cross-billboards | Très haute |

### 9.3 Règle des 3 Plans (BK signature)
Chaque vue de la forêt montre 3 plans de profondeur :
1. **Premier plan** : Assets 3D détaillés (arbres, rochers, champignons)
2. **Plan moyen** : Assets 3D simplifiés + cross-billboards
3. **Arrière-plan** : Fog + couleur ciel verte-brume

---

## 10. Références ROM

| Source | URL |
|--------|-----|
| Décompilation BK | github.com/n64decomp/banjo-kazooie |
| Vertex Data BT | hack64.net/wiki/doku.php?id=banjo_tooie:model_data |
| BK Texture Blending | forum.criajogo.com |
| N64 Poly Counts | oocities.org/zeldaadungeon2000/polygonchart.html |
| F3DEX3 Microcode | github.com/HackerN64/F3DEX3 |
| N64 TMEM | n64squid.com/homebrew/libdragon/graphics/hardware/textures |
