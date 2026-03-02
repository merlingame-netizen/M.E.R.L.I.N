# Style Reference — Low-Poly Isometric Character Generator

> Ce document decrit les regles de construction, couleur et style pour chaque
> type de personnage genere par le systeme parametrique. C'est la reference
> que Claude utilise pour specifier un CharacterSpec JSON coherent.

---

## 1. Principes Fondamentaux (TOUS les personnages)

### 1.1 Construction Low-Poly

- **Canvas** : 256x256 px, rendu final 128x128 (LANCZOS downscale)
- **Facettes** : 35-50 polygones plats par personnage (pas de contours)
- **Eclairage** : Source UPPER-RIGHT, cote droit = lumineux, cote gauche = ombre
- **Z-order** : body(0-2) < shoulders(3-5) < hood(6-9) < face(10-11) < frame(13) < eyes(14) < accessories(15)
- **Animation** : 12 frames, sin/cos breathing + sway, 6 FPS
- **Visibilite facettes** : Le style vient de GRANDES facettes plates avec FORT CONTRASTE entre voisines, PAS de nombreux petits triangles

### 1.2 Structure Hood/Head (4 facettes par cote)

Chaque cote du hood/head suit la meme structure :
```
Facet 1 : Upper Outer — pente raide du pic vers le milieu (pentagon, 5 pts)
Facet 2 : Lower Outer — pente plus douce du milieu vers le bas (pentagon, 5 pts)
Facet 3 : Inner — face vers le centre/viewer, recesse (pentagon, 5 pts)
Facet 4 : Drape — ombre profonde en bas (quad, 4 pts)
```

Plus : 3 facettes peak (ridge, highlight, cap) + 2-3 facettes highlight + 2 drape extensions.

### 1.3 Structure Shoulders (5 facettes par cote)

```
Side    — plaque laterale externe (ombre/lumiere selon cote)
Top     — plaque superieure (capture la lumiere)
Front   — plaque frontale visible (zone principale)
Bevel   — bande de biseau brillante sur le dessus
Bottom  — plaque inferieure sombre
```

### 1.4 Eclairage par Cote

| Position | Cote Gauche (ombre) | Cote Droit (lumiere) |
|----------|--------------------|--------------------|
| Upper outer | dark3 | mid2 |
| Lower outer | dark2 | mid1 |
| Inner | dark2 | mid1 |
| Drape | dark1 | dark3 |
| Shoulder side | dark2 | mid2 |
| Shoulder top | mid1 | mid3 |
| Shoulder front | dark3 | mid1 |
| Shoulder bevel | mid2 | light1 |
| Highlight (right only) | - | bright / light2 |

---

## 2. M.E.R.L.I.N. — Druide Tech Sombre

### 2.1 Identite Visuelle

> Personnage principal. Figure a capuche sombre avec yeux ambre lumineux
> et glyphes tech sur l'armure. Silhouette en cloche (bell curve).

### 2.2 Palette

**Rampe grayscale de reference** (11 nuances, extraites de l'image source) :
```
void:   #000000   (noir pur — void facial, ombres profondes)
deep:   #0a0a12   (quasi-noir bleuatre)
dark1:  #151520   (gris tres sombre)
dark2:  #222230   (charbon sombre)
dark3:  #2a3038   (charbon — ombre capuche)
mid1:   #3a4048   (gris moyen-sombre — armure)
mid2:   #4a5058   (gris moyen — faces eclairees)
mid3:   #586068   (gris moyen-clair)
light1: #687078   (gris — reflets capuche)
light2: #8a9098   (gris clair — highlights)
bright: #a8b0b8   (highlight brillant — bord eclaire)
```

**Accent** : Ambre `#FFFC68` (bright), `#BBA830` (dim), `#FFFC6838` (halo)

### 2.3 Parametres CharacterSpec

```json
{
  "name": "merlin",
  "template": "hooded_figure",
  "silhouette": "bell",
  "proportions": {
    "head_ratio": 0.57,
    "shoulder_width": 0.92,
    "body_width": 0.65
  },
  "grayscale_warmth": 0.0,
  "accent": { "bright": "#FFFC68" },
  "face": {
    "width_top": 0.14,
    "width_bottom": 0.22,
    "height": 0.23,
    "vertical_position": 0.34,
    "has_chin_band": true
  },
  "eyes": {
    "style": "slit",
    "glow_radius": 4.0,
    "halo_radius": 22.0,
    "vertical_position": 0.40,
    "spacing": 0.55
  },
  "accessories": [
    { "slot": "tech_cable", "side": "both" },
    { "slot": "glyph", "side": "both", "glow": true }
  ]
}
```

### 2.4 Regles Specifiques

- **SEUL personnage** avec la rampe grayscale neutre de reference
- Yeux en FENTE (slit) = identite visuelle iconique
- Cables tech + glyphes lumineux sur les epaules
- Highlight BRIGHT sur le haut droit de la capuche = signature
- Warmth TOUJOURS a 0.0 (palette exacte de reference)

---

## 3. BESTIOLE — Renard Violet Compagnon

### 3.1 Identite Visuelle

> Creature compagnon. Petit renard violet avec oreilles pointues
> et yeux cyan lumineux. Silhouette a cornes (oreilles de renard).

### 3.2 Palette

**Rampe violette** (generee par `generate_colored_ramp(hue=275, saturation=0.35)`) :

Les 11 nuances suivent la MEME structure de luminosite que la reference
mais teintees en violet. Les zones sombres restent quasi-noires,
les zones mid/light deviennent violet visible.

```
void:   #000000   (noir pur)
deep:   ~#0e0a14  (quasi-noir violet)
dark1:  ~#1a1524  (violet tres sombre)
dark2:  ~#282238  (violet sombre)
dark3:  ~#332a44  (violet charbon)
mid1:   ~#483a58  (violet moyen-sombre)
mid2:   ~#584a68  (violet moyen)
mid3:   ~#685878  (violet moyen-clair)
light1: ~#786888  (violet gris)
light2: ~#988aa8  (violet clair)
bright: ~#b8a8c8  (violet brillant)
```

**Accent** : Cyan `#1DFDFF` (bright, auto-derive dim/halo)

### 3.3 Parametres CharacterSpec

```json
{
  "name": "bestiole",
  "template": "creature",
  "silhouette": "horned",
  "proportions": {
    "head_ratio": 0.52,
    "shoulder_width": 0.68,
    "body_width": 0.60
  },
  "accent": { "bright": "#1DFDFF" },
  "face": {
    "width_top": 0.12,
    "width_bottom": 0.16,
    "height": 0.18,
    "vertical_position": 0.36,
    "has_chin_band": false
  },
  "eyes": {
    "style": "round",
    "glow_radius": 5.0,
    "halo_radius": 18.0,
    "vertical_position": 0.42,
    "spacing": 0.50
  },
  "color_overrides": "<output of generate_colored_ramp(275, 0.35)>"
}
```

### 3.4 Regles Specifiques

- Silhouette HORNED = les "cornes" sont les oreilles de renard
- Palette VIOLETTE (hue=275, saturation=0.35) — JAMAIS grayscale
- Pas de chin band (visage ouvert, plus animal)
- Yeux RONDS (round) — plus doux que les fentes de Merlin
- Accent CYAN — contraste fort avec le violet
- Epaules plus etroites (0.68 vs 0.92) — silhouette plus compacte
- Pas d'accessoires cables/glyphes (creature naturelle)

---

## 4. SHADOW KNIGHT — Chevalier Ennemi

### 4.1 Identite Visuelle

> Ennemi. Chevalier en armure sombre avec casque a sommet plat
> et visiere rouge sang. Silhouette flat-top (casque militaire).

### 4.2 Palette

**Rampe acier bleu** (generee par `generate_colored_ramp(hue=215, saturation=0.18)`) :

Teinte subtile bleu-acier. Plus froide que M.E.R.L.I.N., plus metallique.

```
void:   #000000   (noir pur)
deep:   ~#0a0c14  (quasi-noir bleu)
dark1:  ~#141822  (bleu-acier tres sombre)
dark2:  ~#202832  (bleu-acier sombre)
dark3:  ~#28303c  (bleu charbon)
mid1:   ~#38424e  (acier moyen-sombre)
mid2:   ~#485260  (acier moyen)
mid3:   ~#586270  (acier moyen-clair)
light1: ~#687280  (acier gris)
light2: ~#8a94a0  (acier clair)
bright: ~#a8b2c0  (acier brillant)
```

**Accent** : Rouge sang `#FF3344` (bright, auto-derive dim/halo)

### 4.3 Parametres CharacterSpec

```json
{
  "name": "shadow_knight",
  "template": "hooded_figure",
  "silhouette": "flat_top",
  "proportions": {
    "head_ratio": 0.50,
    "shoulder_width": 0.95,
    "body_width": 0.70
  },
  "accent": { "bright": "#FF3344" },
  "face": {
    "width_top": 0.16,
    "width_bottom": 0.20,
    "height": 0.18,
    "vertical_position": 0.36,
    "has_chin_band": true
  },
  "eyes": {
    "style": "visor",
    "glow_radius": 4.0,
    "halo_radius": 16.0
  },
  "color_overrides": "<output of generate_colored_ramp(215, 0.18)>"
}
```

### 4.4 Regles Specifiques

- Silhouette FLAT_TOP = casque a sommet plat, militaire
- Palette ACIER BLEU (hue=215, saturation=0.18) — froide, metallique
- Yeux VISOR — barre horizontale rouge sang (menacant)
- Epaules LARGES (0.95) — imposant, guerrier
- Chin band present (casque ferme)
- Accent ROUGE SANG — contraste avec l'acier bleu
- Cables tech comme Merlin (meme technologie, camp oppose)

---

## 5. Guide de Creation de Nouveaux Personnages

### 5.1 Workflow Claude

1. **Choisir un template** : `hooded_figure`, `creature`, ou `object`
2. **Choisir une silhouette** : `bell`, `angular`, `rounded`, `horned`, `spiky`, `flat_top`, `tapered`
3. **Definir la palette** : `generate_colored_ramp(hue, saturation)` OU grayscale avec warmth
4. **Specifier le visage** : taille, position, chin band
5. **Choisir les yeux** : `slit`, `round`, `single`, `multi`, `visor`, `none`
6. **Ajouter des accessoires** : cables, glyphes, cornes

### 5.2 Palettes Recommandees par Archetype

| Archetype | Hue | Saturation | Accent | Exemple |
|-----------|-----|-----------|--------|---------|
| Druide/Mage | 0 (gray) | 0.0 | Ambre #FFFC68 | M.E.R.L.I.N. |
| Creature nature | 120-160 | 0.25-0.40 | Vert #22FF88 | Forest Guardian |
| Creature feu | 15-30 | 0.30-0.45 | Orange #FF8844 | Fire Imp |
| Creature eau | 190-210 | 0.25-0.35 | Bleu clair #44CCFF | Water Sprite |
| Creature ombre | 270-290 | 0.30-0.40 | Cyan #1DFDFF | Bestiole |
| Chevalier | 210-220 | 0.15-0.25 | Rouge #FF3344 | Shadow Knight |
| Undead | 45-60 | 0.10-0.20 | Vert toxique #88FF44 | Revenant |
| Celestial | 0 (gray) | 0.0 | Blanc #FFFFFF | Angel |
| Demon | 0-10 | 0.25-0.40 | Orange #FF6600 | Pit Fiend |

### 5.3 Silhouettes par Archetype

| Silhouette | Forme | Usage |
|-----------|-------|-------|
| `bell` | Cloche/dome avec pic | Robes, capuches, mages |
| `angular` | Cristal/pyramide | Constructs, golems, geodes |
| `rounded` | Dome/oeuf | Creatures douces, blobs |
| `horned` | Deux pics (oreilles) | Creatures a oreilles, demons |
| `spiky` | Multi-pics irreguliers | Eldritch, cristaux, herissons |
| `flat_top` | Sommet plat/tronque | Casques, couronnes, robots |
| `tapered` | Cone/fantome | Spectres, robes longues |

### 5.4 Regles de Differentiation

**OBLIGATOIRE** — chaque personnage doit differer sur AU MOINS 2 des 3 axes :

1. **Silhouette** : forme differente (bell ≠ horned ≠ flat_top)
2. **Palette** : hue differente (gray ≠ purple ≠ steel blue)
3. **Yeux** : style different (slit ≠ round ≠ visor)

**INTERDIT** :
- Deux personnages avec la meme rampe grayscale neutre (reserve a M.E.R.L.I.N.)
- Yeux slit ambre sur un personnage autre que M.E.R.L.I.N.
- Copier les proportions exactes de M.E.R.L.I.N. (head_ratio=0.57, shoulder_width=0.92)

---

## 6. Fichiers Cles

| Fichier | Role |
|---------|------|
| `character_spec.py` | Schema CharacterSpec (interface Claude) |
| `color_engine.py` | Rampes couleur, `generate_colored_ramp()` |
| `silhouette.py` | 7 courbes parametriques |
| `geometry.py` | Moteur de tuilage (4 facettes/cote) |
| `templates.py` | 3 templates de base |
| `validator.py` | Validation avant rendu |
| `__init__.py` | API: `generate_character()`, `animate_character()`, `export_character()` |
| `STYLE_LOWPOLY.md` | Guide de style general (canvas, eclairage, animation) |
| `merlin_lowpoly.py` | Gold standard hardcode M.E.R.L.I.N. v15 |
