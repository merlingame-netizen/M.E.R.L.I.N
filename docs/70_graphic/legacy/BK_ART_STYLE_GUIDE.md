# Banjo-Kazooie Art Style Guide — M.E.R.L.I.N.

> Source de verite pour la generation d'assets 3D. Style: Banjo-Kazooie / Banjo-Tooie (Rare, N64 1998-2000).
> Adapte au theme celtique/Broceliande du jeu.

---

## 1. Polygon Budgets

| Type asset | Triangles | Reference BK |
|-----------|----------|-------------|
| Personnage principal | 500-800 | Banjo = 783 tris |
| PNJ / allies | 200-400 | Bottles, Mumbo |
| Ennemis (petits) | 100-300 | Ant = 276 tris |
| Boss | 500-1000 | Nipper = ~600 tris |
| Collectibles | 10-50 | Jiggy, notes, honeycombs |
| Props petits (cailloux, panneaux) | 20-80 | |
| Props moyens (arbres, huttes, ponts) | 80-200 | |
| Structures larges (batiments, tours) | 200-500 | |
| Terrain chunk | 500-2000 | |
| Scene totale visible | 3000-5000 | Spiral Mountain = 3,354 |

**Regle d'or** : si un asset depasse son budget, Decimate Modifier jusqu'a conformite.

---

## 2. Vertex Coloring — Technique Signature

Le vertex coloring represente **80% de la qualite visuelle** d'un asset BK.

### RGB = Couleur + Eclairage Bake
- **Couleur de surface** : vert herbe, brun bois, gris pierre
- **Ambient Occlusion** : assombrir les concavites, bases, dessous
- **Ombres directionnelles** : faces orientees nord/bas = plus sombres
- **Gradients** : transition douce herbe→terre, mousse→pierre

### Alpha = Blend Factor (terrain uniquement)
- `0.0` = texture A seulement (ex: herbe)
- `1.0` = texture B seulement (ex: chemin de terre)
- Valeurs intermediaires = blend doux entre les deux

### Techniques specifiques
1. **Baked AO** : vertex color sombre dans les creux et a la base des objets
2. **Shadow carving** : subdiviser la geometrie aux zones d'ombre, peindre ces vertex en sombre
3. **Color gradients** : une texture 32x32 + vertex colors = terrain visuellement riche et varie
4. **Moss/weathering** : vertex color vert sur le sommet des rochers, brun sombre a la base

---

## 3. Textures

### Specifications
- **32x32 pixels** : taille primaire (herbe, pierre, bois, terre)
- **64x64 pixels** : maximum (visages, details critiques)
- **Format** : PNG RGBA, hand-painted style
- **Filtrage** : Nearest Neighbor (pixelise, PAS bilineaire)
- **Tiling** : les textures tilent dans toutes les directions

### Types de textures
| Texture | Taille | Usage |
|---------|--------|-------|
| grass_noise.png | 32x32 | Herbe — noise vert, colore par vertex |
| stone_tile.png | 32x32 | Pierre — noise gris, variations subtiles |
| wood_plank.png | 32x32 | Bois — lignes horizontales brunes |
| dirt_path.png | 32x32 | Terre — brun chaud avec cailloux |
| bark_tree.png | 32x32 | Ecorce — lignes verticales brun fonce |
| water_surface.png | 32x32 | Eau — bleu avec highlights |
| face_detail.png | 64x64 | Visage personnage — yeux, bouche |
| rune_ogham.png | 32x32 | Inscriptions oghams sur pierre |

### Pipeline texture
```
1. Creer en 32x32 dans un editeur pixel art
2. Style hand-painted : couleurs pas uniformes, variations subtiles
3. Pas de details fins — juste des patterns de noise/grain
4. La richesse visuelle vient du vertex coloring, pas de la texture
```

---

## 4. Palette de Couleurs

### Couleurs principales (hex)
```python
BK_PALETTE = {
    "kazooie_red":    "#CE4127",  # Rouge-orange chaud (accents, danger)
    "sky_cyan":       "#59BFC7",  # Cyan brillant (ciel, eau, glace)
    "banjo_brown":    "#9D6749",  # Brun chaud (bois, fourrure, terre)
    "foliage_sage":   "#60836D",  # Vert sauge sourd (feuillage ombre)
    "shadow_brown":   "#493C2F",  # Brun chocolat (ombres profondes)
    "gold_accent":    "#E8C840",  # Jaune dore (collectibles, magie)
    "cream_light":    "#F0E8D0",  # Creme chaud (highlights, lumiere)
    "grass_green":    "#5A8A3A",  # Vert herbe sature (vegetation)
    "stone_gray":     "#7A7A7E",  # Gris pierre chaud (megalithes)
    "water_blue":     "#4090C0",  # Bleu eau lumineux (lacs, rivieres)
    "moss_green":     "#3A6A2A",  # Vert mousse fonce (rochers, troncs)
    "bark_dark":      "#3A2A1A",  # Brun ecorce fonce (troncs, ombres)
    "magic_glow":     "#57B8FF",  # Bleu magique (oghams, sortileges)
    "druid_purple":   "#5A3080",  # Violet druide (Merlin, mystere)
}
```

### Regles palette
- **Chaud et sature** : jamais froid ou desature
- **Pas de noir pur** (#000000) : le plus sombre = `shadow_brown` (#493C2F)
- **Pas de blanc pur** (#FFFFFF) : le plus clair = `cream_light` (#F0E8D0)
- **Fog** = couleur du ciel (cyan ou jaune chaud, jamais gris)
- **Accents pop** : rouges, cyans, jaune dore pour les objets importants
- **Dominante par biome** :
  - Foret Broceliande = verts + bruns
  - Cotes sauvages = cyans + sable
  - Landes de bruyere = violets + verts sages
  - Marais des korrigans = verts fonces + bleus sombres
  - Cercles de pierres = gris + mousse

---

## 5. Shape Language

### Regles de forme
- **TOUT est arrondi** : pas d'aretes vives sur les formes organiques
- **Proportions exagerees** : grosses tetes (30-40% de la hauteur), gros yeux, membres courts
- **Googly eyes** sur les creatures/personnages (signature Rare)
- **Batiments penchent** : rien n'est parfaitement droit
- **Chemins courbent** : pas de lignes droites dans la nature
- **Segments separes** aux articulations : pas de smooth skinning, gaps visibles aux joints

### Par type d'asset
| Type | Shape rules |
|------|------------|
| Arbres | Tronc epais cylindrique, couronne spherique/ovale volumineuse |
| Rochers | Icosphere deformee, formes bulbeuses, arrondis |
| Structures | Murs penchent legerement, toits courbes, planches irregulières |
| Personnages | Gros yeux, tete surdimensionnee, corps trapu |
| Collectibles | Formes geometriques simples, brillantes, visibles de loin |
| Megalithes | Pierres arrondies par l'erosion, jamais de faces planes |
| Ponts | Planches irregulières avec gaps, garde-corps penchees |

---

## 6. Eclairage

- **ZERO specular** / metallic / normal maps
- **Tout l'eclairage** est bake dans les vertex colors
- **Ambient** : ~40% luminosite de base dans les vertex colors
- **Directionnel doux** : simule par vertex painting (faces haut = clair, faces bas = sombre)
- **Resultat** : look mat, chaud, cartoon — comme un livre pop-up anime

---

## 7. Export GLB

### Settings Blender
- Format : glTF Binary (.glb)
- Vertex Colors : **ACTIF** (critique)
- Flat Shading : **NON** (smooth shading pour l'aspect BK arrondi)
- Textures : embarquees dans le GLB
- Animation : non (assets statiques)
- Scale : 1.0 (unites Blender = unites Godot)

### Validation post-export
- [ ] Triangle count dans le budget
- [ ] Vertex colors preserves (pas perdus a l'export)
- [ ] Pas de faces degenerees (tris a aire zero)
- [ ] Bounding box raisonnable (pas de vertex a l'infini)
- [ ] Taille fichier < 500KB pour props, < 2MB pour structures

---

## 8. Adaptations Celtiques

Le style BK est adapte au theme M.E.R.L.I.N. (Broceliande, druides, oghams) :

| BK Original | Adaptation M.E.R.L.I.N. |
|------------|------------------------|
| Jiggy (puzzle piece dore) | Ogham runique dore |
| Notes musicales | Feuilles de gui lumineux |
| Honeycomb | Pomme d'Avalon |
| Mumbo's hut | Dolmen habite |
| Treasure Trove Cove | Cotes sauvages bretonnes |
| Freezeezy Peak | Landes de bruyere givre |
| Gobi's Valley | Collines aux dolmens |
| Gruntilda's Lair | Antre de Morgane |

---

*v1.0 — 2026-04-06 — Base sur recherche technique BK/BT (polygon counts, vertex coloring, palette)*
