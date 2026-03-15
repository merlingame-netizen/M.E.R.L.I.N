# CRT_PALETTE — Systeme de Couleurs Terminal Druido-Tech

**Dernière mise à jour** : 2026-03-15
**Source** : `scripts/autoload/merlin_visual.gd` (autoload singleton)
**Statut** : Actif (palette principale, PALETTE legacy en rollback)

---

## Vue d'ensemble

### Philosophie du design

M.E.R.L.I.N est une IA du futur. Le joueur voit à travers un **écran CRT monochrome phosphore**, comme dans les années 1980-90 : fonds très sombres, texte vert brillant, accents ambres, surbrillances cyan mystiques. Les couleurs émanent d'une émission phosphore virtuelle, avec un effet de scintillement (scanlines) et une persistance visuelle (afterglow CRT).

### Principes fondamentaux

| Principe | Détail |
|----------|--------|
| **Sombre primaire** | Fonds très noirs (0.02-0.08 en RGB) = espace physique du terminal |
| **Phosphor vert** | Texte primaire (0.20, 1.00, 0.40) = émission phosphore classique |
| **Amber accent** | Secondaire (1.00, 0.75, 0.20) = chaleur, warning, interaction |
| **Cyan mystic** | Tertiaire (0.30, 0.85, 0.80) = magie, spécial, feedback Celtic |
| **Hiérarchie d'opacité** | Les couleurs avec alpha <1.0 superposent sur le scanline du CRT |

### Hiérarchie colorée

```
1. FONDS SOMBRES        ← bg_deep / bg_dark / bg_panel (très sombres)
2. TEXTE PRIMAIRE       ← phosphor (vert brillant, lisible)
3. ACCENTS & WARNINGS   ← amber (chaud, attire l'œil)
4. SPÉCIAL/MAGIE        ← cyan (otherworldly, Celtic)
5. ÉTATS (status)       ← danger/success/warning (rouge/vert/or)
6. STRUCTURES           ← borders / shadow / scanline / mist (discrets)
```

---

## CRT_PALETTE — Dictionnaire complet

### 1. FONDS TERMINAUX (Terminal backgrounds)

Dégradé très sombre avec teinte verte subtile, simulant la persistance CRT.

| Clé | Hex | Color() | Visibilité | Usage |
|-----|-----|---------|-----------|-------|
| **bg_deep** | #050A05 | Color(0.02, 0.04, 0.02) | Noir profond | Fonds extrêmement sombres, panels intérieurs |
| **bg_dark** | #0A1A0A | Color(0.04, 0.08, 0.04) | Noir 0.5 | Panneaux standard, zones neutres |
| **bg_panel** | #0F1F0F | Color(0.06, 0.12, 0.06) | Noir 0.3 | Panneaux surélevés, emphasis léger |
| **bg_highlight** | #151F15 | Color(0.08, 0.16, 0.08) | Noir 0.2 | Panneaux actifs, hover zones |

**Utilisation** :
- `bg_deep` : overlays sombres, couches de fond
- `bg_dark` : boutons, panneaux de status, interface standard
- `bg_panel` : panneaux flottants, menus secondaires
- `bg_highlight` : focus visual, zone active

---

### 2. TEXTE PHOSPHOR (Phosphor text — vert primaire)

Teinte vert phosphore classique CRT, avec variantes d'intensité.

| Clé | Hex | Color() | Visibilité | Usage |
|-----|-----|---------|-----------|-------|
| **phosphor** | #33FF66 | Color(0.20, 1.00, 0.40) | Brillant | Texte primaire, labels, élements actifs |
| **phosphor_dim** | #1F9A3D | Color(0.12, 0.60, 0.24) | Moyen | Texte désactivé, hints, secondaire |
| **phosphor_bright** | #66FF99 | Color(0.40, 1.00, 0.60) | Très brillant | Accents, highlights, feedback |
| **phosphor_glow** | #33FF661F | Color(0.20, 1.00, 0.40, 0.15) | Faible + alpha | Aura/glow, effeits de luminescence |

**Variantes intentionnelles** :
- `phosphor` : Écran normal (vert standard)
- `phosphor_dim` : Texte faible / désactivé (réduit brillance & saturation)
- `phosphor_bright` : Emphase sur certains mots ou actions critiques
- `phosphor_glow` : Aura douce autour d'éléments flottants (texte, badges)

**Utilisation** :
```gdscript
# Texte standard
label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])

# Avec glow (shader ou compositing)
label.modulate = MerlinVisual.CRT_PALETTE["phosphor_glow"]
```

---

### 3. ACCENTS AMBRES (Amber accent)

Teinte or-orange chaude, rappelle les anciens écrans monochrome ambres (années 80-90).

| Clé | Hex | Color() | Visibilité | Usage |
|-----|-----|---------|-----------|-------|
| **amber** | #FFBF33 | Color(1.00, 0.75, 0.20) | Chaud brillant | Boutons hover, accents forts, warnings |
| **amber_dim** | #994D1F | Color(0.60, 0.45, 0.12) | Moyen | Bordures, boutons normaux, traces |
| **amber_bright** | #FFDD66 | Color(1.00, 0.85, 0.40) | Très chaud | Buttons pressed, danger sérieux, focus |

**Rôle principal** : Attirer l'attention sans être agressif (moins rouge pur). Contraste fort sur noir phosphore.

**Utilisation** :
```gdscript
# Bordure ambre sur panneau card
style.border_color = MerlinVisual.CRT_PALETTE["amber"]

# Bouton enfoncé = amber_bright
button.add_theme_color_override("font_pressed_color", MerlinVisual.CRT_PALETTE["amber"])
```

---

### 4. CYAN MYSTIQUE (Celtic mystic / Cyan)

Teinte cyan froide = magie, éléments surnaturels, feedback Celtic.

| Clé | Hex | Color() | Visibilité | Usage |
|-----|-----|---------|-----------|-------|
| **cyan** | #4DD9CC | Color(0.30, 0.85, 0.80) | Cyan vif | Éléments magiques, Oghams, spécial |
| **cyan_bright** | #80FFFB | Color(0.50, 1.00, 0.95) | Très brillant | Emphasis magique, glow intense |
| **cyan_dim** | #2A6A66 | Color(0.15, 0.42, 0.40) | Moyen | Texte désactivé, traces magiques |

**Utilisation** :
- Surbrillance Ogham au survol
- Éléments surnaturels, promesses
- Feedback visuel pour actions magiques
- Triade "Ame" (aspect mystique)

---

### 5. COULEURS DE STATUT (Status colors)

Codes universels : rouge = danger, vert = succès, or = warning.

| Clé | Hex | Color() | Statut | Exemple |
|-----|-----|---------|--------|---------|
| **danger** | #FF3328 | Color(1.00, 0.20, 0.15) | Critique | Perte de santé, erreur |
| **success** | #33FF66 | Color(0.20, 1.00, 0.40) | Positif | Gain de rep, heal |
| **warning** | #FFBF33 | Color(1.00, 0.75, 0.20) | Attention | Cooldown, attention |
| **inactive** | #333433 | Color(0.20, 0.25, 0.20) | Désactivé | Boutons grisés, options bloquées |
| **inactive_dark** | #1F1F1F | Color(0.12, 0.15, 0.12) | Très inactif | Shadow, traces de désactivation |

**Hiérarchie sémantique** :
- `danger` = **couleur alerte**, utilisée très spasmément
- `success` = phosphor_bright (déjà vert, même teinte)
- `warning` = amber (déjà warm, alerte sans panique)
- `inactive` = version grisée, peu visible = "n'existe pas maintenant"

---

### 6. STRUCTURES (Bordures, ombres, lignes)

Éléments discrets qui définissent les zones sans attirer l'attention.

| Clé | Hex | Color() | Alpha | Usage |
|-----|-----|---------|-------|-------|
| **border** | #1F4D23 | Color(0.12, 0.30, 0.14) | 1.0 | Bordures normales, panels |
| **border_bright** | #338038 | Color(0.20, 0.50, 0.24) | 1.0 | Bordures active, focus |
| **shadow** | #00000066 | Color(0.00, 0.00, 0.00, 0.40) | 0.40 | Ombre sous panels (discrets) |
| **scanline** | #00000026 | Color(0.00, 0.00, 0.00, 0.15) | 0.15 | Simulation scanline CRT |
| **line** | #1F4D2340 | Color(0.12, 0.30, 0.14, 0.25) | 0.25 | Lignes séparatrices fines |
| **mist** | #192A10** | Color(0.10, 0.20, 0.10, 0.20) | 0.20 | Brume/fog overlay subtil |

**Contexte utilisation** :
- `border` : StandardButton, Card panel frame
- `border_bright` : Focus / active state
- `shadow` : Drop shadow très subtil (0.40 alpha max)
- `scanline` : Overlay shader CRT simulé
- `line` : Séparations discrétes (vs border épais)
- `mist` : Fog ambient, blur effect background

---

### 7. GAMEPLAY UI (Spécial game systems)

Couleurs dédiées aux systèmes de jeu majeurs.

| Clé | Hex | Color() | Système | Détail |
|-----|-----|---------|---------|--------|
| **ogham_glow** | #4DD9CC | Color(0.30, 0.85, 0.80) | Oghams | Surbriggle au survol des cartes Ogham |
| **bestiole** | #4DB3E6 | Color(0.30, 0.70, 0.90) | Bestiole (legacy) | Icon color, feedback visuel |
| **souffle** | #4DD9CC | Color(0.30, 0.85, 0.80) | Souffle d'Ogham | Même cyan (identité visuelle) |
| **souffle_full** | #FFD966 | Color(1.00, 0.85, 0.40) | Souffle (highlight) | Activation complète |

**Note** : `souffle` et `ogham_glow` = même teinte cyan = cohérence visuelle pour Oghams.

---

### 8. CELTOS INTRO — Boot Sequence Eye Animation

Séquence d'introduction CeltOS (écran de démarrage avec oeil animé).

| Clé | Hex | Color() | Partie | Contexte |
|-----|-----|---------|--------|----------|
| **block** | #33FF66 | Color(0.20, 1.00, 0.40) | Logo block | Carré primaire (phosphor) |
| **block_alt** | #26BF4D | Color(0.15, 0.75, 0.30) | Logo block alt | Carré alternant |
| **eye_cyan** | #4DD9CC | Color(0.30, 0.85, 0.80) | Œil iris | Couleur iris principale |
| **eye_white** | #99FF99 | Color(0.60, 1.00, 0.70) | Œil blanc | Reflexe blanc |
| **eye_deep** | #050F0A | Color(0.02, 0.06, 0.04) | Œil profond | Pupille très sombre |
| **eye_outer** | #1A4D33 | Color(0.10, 0.30, 0.20) | Œil outer iris | Contour iris |
| **eye_bright** | #66FF99 | Color(0.40, 1.00, 0.60) | Œil bright | Accent cyab brillant |
| **slit_glow** | #FFD966 | Color(1.00, 0.85, 0.40) | Pupille slit | Fente pupillaire ambre |

**Composition de l'œil** (du centre au bord) :
```
1. eye_deep (noir pupille)
2. slit_glow (fente ambre)
3. eye_cyan (iris cyan)
4. eye_white (reflexe blanc)
5. eye_outer (contour sombre)
```

---

### 9. CHOIX / OPTIONS BUTTONS (Quiz, dialogues)

Boutons interactifs pour sélections du joueur.

| Clé | Hex | Color() | État | Contexte |
|-----|-----|---------|------|----------|
| **choice_normal** | #1F9A3D | Color(0.12, 0.60, 0.24) | Normal | Bouton désactivé / normal |
| **choice_hover** | #33FF66 | Color(0.20, 1.00, 0.40) | Hover | Survol (phosphor complet) |
| **choice_selected** | #FFBF33 | Color(1.00, 0.75, 0.20) | Sélectionné | Choix validé |

**Transition d'état** :
```
Normal (phosphor_dim)
  ↓ (hover)
Hover (phosphor complet) ← "click me!"
  ↓ (click)
Selected (amber) ← "validé!"
```

---

### 10. CALENDRIER / ÉVÉNEMENTS (Calendar UI)

Couleurs pour interface calendrier du jeu.

| Clé | Hex | Color() | Type | Utilisation |
|-----|-----|---------|------|------------|
| **event_today** | #FFBF33 | Color(1.00, 0.75, 0.20) | Événement courant | Date actuelle |
| **event_past** | #333433 | Color(0.20, 0.25, 0.20) | Événement passé | Dates historiques, grisées |

---

### 11. MAP UI (Interface de sélection biomes)

Couleurs pour la map 2D de sélection biomes.

| Clé | Hex | Color() | État | Exemple |
|-----|-----|---------|------|---------|
| **locked** | #262619BF | Color(0.15, 0.20, 0.15, 0.50) | Verrouillé | Biome non accessible, semi-transparent |

---

### 12. REWARD BADGE TOOLTIP (Carte hover — infobulles rewards)

Badge affichant les récompenses au survol d'une carte.

| Clé | Hex | Color() | Partie | Utilisation |
|-----|-----|---------|--------|------------|
| **reward_bg** | #0A1A0ABF | Color(0.04, 0.08, 0.04, 0.92) | Background | Fond du badge (très transparent) |
| **reward_border** | #33FF66BF | Color(0.20, 1.00, 0.40, 0.75) | Bordure | Bordure phosphor du badge |

**Comportement** : Badge qui apparaît au survol, disparaît au départ souris.

---

### 13. LLM STATUS BAR (Barre de statut IA)

Affichage du statut de l'IA / génération de cartes LLM.

| Clé | Hex | Color() | État | Contexte |
|-----|-----|---------|------|----------|
| **llm_bg** | #050A0AD9 | Color(0.02, 0.04, 0.02, 0.85) | Normal | Fond barre LLM |
| **llm_bg_hover** | #0A1A0AF2 | Color(0.04, 0.08, 0.04, 0.95) | Hover | Fond barre (plus opaque) |
| **llm_text** | #33FF66 | Color(0.20, 1.00, 0.40) | Texte | Texte statut normal |
| **llm_success** | #33FF66 | Color(0.20, 1.00, 0.40) | Succès | Génération réussie |
| **llm_warning** | #FFBF33 | Color(1.00, 0.75, 0.20) | Warning | Attente, cooldown LLM |
| **llm_error** | #FF3328 | Color(1.00, 0.20, 0.15) | Erreur | Erreur génération |

**Affichage** : Barre en bas à gauche montrant "Generating..." + timer, couleur change à succès/erreur.

---

## PALETTE Legacy — Migration Graduelle

### État actuel

La **PALETTE** historique (Parchemin Mystique Breton) est **maintenue pour rollback** uniquement. Les scènes migreront une par une vers CRT_PALETTE.

| Composant | Statut | Notes |
|-----------|--------|-------|
| CeltOS Intro | ✓ Migré | Utilise CRT_PALETTE (eye animation, blocks) |
| Menu Principal | ⚠ En cours | Parchemin legacy + CRT overlay |
| Card System | ✓ Migré | CRT_PALETTE exclusive |
| LLM Status Bar | ✓ Migré | CRT colors |
| Biomes 3D | ⚠ En cours | Pixel art + biome-specific palettes |

**Pour revert d'urgence** :
```gdscript
# Au lieu de :
var color = MerlinVisual.CRT_PALETTE["phosphor"]

# Rollback rapide :
var color = MerlinVisual.PALETTE["ink"]  # Noir parchemin
```

---

## GBC PALETTE — Game Boy Color (Référence biomes pixel art)

### Vue d'ensemble

La **GBC palette** duplique les couleurs emblématiques Game Boy Color pour cohérence visuelle avec les biomes (pixel art sprite animations). Séparée de CRT_PALETTE pour flexibilité.

### Structure (19 couleurs + 6 grises)

#### Grises (Base)

| Clé | Hex | Usage |
|-----|-----|-------|
| white | #E8E8E8 | Highlights, très clairs |
| cream | #F8F0D8 | Tons neutres chauds |
| light_gray | #B8B0A0 | Demi-teintes |
| gray | #787870 | Tons moyens |
| dark_gray | #484840 | Ombres légères |
| black | #181810 | Blacks profonds |

#### Éléments Naturels (12 couleurs)

| Catégorie | Couleurs | Usage |
|-----------|----------|-------|
| **Herbe** | grass_light, grass, grass_dark | Biome nature, verdure |
| **Eau** | water_light, water, water_dark | Cotes, marais, animations |
| **Feu** | fire_light, fire, fire_dark | Chaleur, énergie, danger |
| **Terre** | earth_light, earth, earth_dark | Collines, dolmens, stabil |
| **Mystic** | mystic_light, mystic, mystic_dark | Magie, Ame aspect |
| **Glace** | ice_light, ice, ice_dark | Froid, éléments glaçants |
| **Tonnerre** | thunder_light, thunder, thunder_dark | Électricité, énergie |
| **Poison** | poison_light, poison, poison_dark | Venin, toxine |
| **Métal** | metal_light, metal, metal_dark | Mécanismes, durabilité |
| **Shadow** | shadow_light, shadow, shadow_dark | Ombre, noir magie |
| **Lumière** | light_light, light, light_dark | Luminescence, clarté |

#### UI Bars (5 couleurs)

| Clé | Hex | Usage |
|-----|-----|-------|
| hp_green | #48A028 | Barre HP (santé) |
| hp_yellow | #E8C030 | Barre déplétée (warning) |
| hp_red | #D03028 | Barre critique (danger) |
| hunger_orange | #E08028 | (Legacy — supprimé) |
| energy_blue | #4898D0 | Énergie mana |

### Utilisation GBC dans le code

```gdscript
# Coloriser un sprite pixel art par biome
sprite.modulate = MerlinVisual.GBC["grass"]  # Biome vert

# Barre HP (GBC + CRT blending possible)
hp_bar.modulate = MerlinVisual.GBC["hp_green"]
```

---

## ASPECT COLORS — Triade (Corps/Ame/Monde)

### Vue d'ensemble

La **Triade** = système à 3 aspects du jeu. Chaque aspect a 3 variantes de couleurs (normal, light, dark) + version CRT phosphore.

### Système standard PALETTE (legacy)

| Aspect | Normal | Hex | Light | Dark |
|--------|--------|-----|-------|------|
| **Corps** | (0.55, 0.40, 0.25) | Brownish | (0.72, 0.58, 0.38) | (0.40, 0.30, 0.18) |
| **Ame** | (0.40, 0.45, 0.70) | Purplish | (0.62, 0.58, 0.82) | (0.30, 0.25, 0.47) |
| **Monde** | (0.35, 0.55, 0.35) | Greenish | (0.50, 0.72, 0.50) | (0.22, 0.38, 0.22) |

### Système CRT (actif)

Même logique, mais phosphore CRT-style.

| Aspect | Normal (Hex) | Light (Hex) | Dark (Hex) |
|--------|------|------|------|
| **Corps** | #FF6633 (0.80, 0.40, 0.20) | #FF9966 (1.00, 0.60, 0.40) | #993D1F (0.60, 0.24, 0.12) |
| **Ame** | #8066FF (0.50, 0.40, 1.00) | #B399FF (0.70, 0.60, 1.00) | #4D3D99 (0.30, 0.24, 0.60) |
| **Monde** | #33FF66 (0.20, 1.00, 0.40) | #66FF99 (0.40, 1.00, 0.60) | #1F9A3D (0.12, 0.60, 0.24) |

**Utilisation** :
```gdscript
# Afficher récompense Triade
var aspect = "Corps"  # ou "Ame", "Monde"
var color = MerlinVisual.CRT_ASPECT_COLORS[aspect]
reward_label.add_theme_color_override("font_color", color)
```

---

## BIOME_CRT_PALETTES — Palettes spécifiques par biome

### Vue d'ensemble

Chaque **biome** a une palette CRT unique de 8 couleurs (index 0=sombre, 7=brillant), utilisée pour :
- Teinte phosphore du CRT local
- Palette swap des sprites biome-spécifiques
- Ambiance visuelle distincte

### Structure générale

```
Index 0: #000000 (noir pur)
Index 1-6: Dégradé per-biome
Index 7: #FFFFFF (blanc/phosphor pur)
```

### Les 8 biomes et leurs palettes

#### Broceliande (Forêt ancestrale — vert profond)

```gdscript
[
  Color(0.02, 0.06, 0.02),  # 0: Noir profond
  Color(0.04, 0.12, 0.06),  # 1: Vert très sombre
  Color(0.08, 0.22, 0.10),  # 2: Vert sombre
  Color(0.12, 0.35, 0.16),  # 3: Vert moyen
  Color(0.20, 0.50, 0.24),  # 4: Vert actif
  Color(0.30, 0.65, 0.30),  # 5: Vert phosphor actif
  Color(0.50, 0.80, 0.40),  # 6: Vert clair
  Color(0.70, 1.00, 0.50),  # 7: Vert très clair
]
```
**Caractère** : Forêt ancestrale, bioluminescence verte profonde, écosystème ancien.

#### Landes (Brande pourprée — violet/magenta)

```gdscript
[
  Color(0.06, 0.02, 0.06),  # 0: Violet profond
  Color(0.12, 0.06, 0.14),  # 1: Violet très sombre
  Color(0.20, 0.10, 0.24),  # 2-4: Dégradé violet
  Color(0.35, 0.18, 0.40),
  Color(0.50, 0.28, 0.55),
  Color(0.65, 0.40, 0.70),  # 5: Violet phosphor
  Color(0.80, 0.55, 0.85),  # 6-7: Violet clair
  Color(0.95, 0.70, 1.00),
]
```
**Caractère** : Landes sauvages, bruyères mauves, teinte mystique.

#### Côtes (Côtes sauvages — cyan/bleu mer)

```gdscript
[
  Color(0.02, 0.04, 0.08),  # 0: Bleu profond
  Color(0.04, 0.08, 0.16),  # 1: Bleu très sombre
  Color(0.08, 0.16, 0.28),  # 2-3: Dégradé bleu
  Color(0.14, 0.28, 0.42),
  Color(0.22, 0.42, 0.58),  # 4-5: Bleu phosphor
  Color(0.35, 0.58, 0.72),
  Color(0.55, 0.75, 0.85),  # 6-7: Bleu/cyan clair
  Color(0.75, 0.90, 1.00),
]
```
**Caractère** : Océan breton, vagues, horizon marin, embruns.

#### Villages (Villages Celtes — or/terre chaude)

```gdscript
[
  Color(0.06, 0.04, 0.02),  # 0: Brun profond
  Color(0.14, 0.08, 0.04),  # 1: Brun très sombre
  Color(0.24, 0.14, 0.06),  # 2-3: Dégradé brun
  Color(0.40, 0.24, 0.10),
  Color(0.58, 0.36, 0.16),  # 4-5: Or/brun phosphor
  Color(0.75, 0.50, 0.22),
  Color(0.90, 0.65, 0.30),  # 6-7: Or/jaune clair
  Color(1.00, 0.80, 0.40),
]
```
**Caractère** : Architecture Celtic, torches, chaleur terrestre, foyers.

#### Cercles de Pierres (Mégalithes — gris froid)

```gdscript
[
  Color(0.03, 0.03, 0.04),  # 0: Gris très sombre
  Color(0.08, 0.08, 0.10),  # 1-7: Dégradé gris neutre
  Color(0.16, 0.16, 0.20),
  Color(0.28, 0.28, 0.34),
  Color(0.42, 0.42, 0.50),
  Color(0.58, 0.58, 0.68),
  Color(0.75, 0.75, 0.85),
  Color(0.90, 0.90, 1.00),
]
```
**Caractère** : Pierre mégalithique, minéral, gris neutre, rigidité.

#### Marais (Marais des Korrigans — vert aqueux)

```gdscript
[
  Color(0.02, 0.04, 0.03),  # 0: Vert-gris profond
  Color(0.06, 0.10, 0.08),  # 1-7: Dégradé vert aqueux
  Color(0.10, 0.18, 0.14),
  Color(0.16, 0.28, 0.22),
  Color(0.24, 0.40, 0.30),
  Color(0.35, 0.55, 0.42),
  Color(0.50, 0.72, 0.55),
  Color(0.65, 0.90, 0.70),
]
```
**Caractère** : Eau stagnante, algues, brume marécageuse, monde humide.

#### Collines (Collines aux Dolmens — or/vert terre)

```gdscript
[
  Color(0.04, 0.04, 0.02),  # 0: Brun-vert profond
  Color(0.10, 0.10, 0.06),  # 1-7: Dégradé or/vert
  Color(0.18, 0.20, 0.10),
  Color(0.30, 0.34, 0.16),
  Color(0.45, 0.50, 0.24),
  Color(0.60, 0.65, 0.32),
  Color(0.75, 0.78, 0.42),
  Color(0.90, 0.92, 0.55),
]
```
**Caractère** : Terrain vallonné, dolmens, herbe pâle, douceur.

#### Îles Mystiques (Au-delà des brumes — cyan profond)

```gdscript
[
  Color(0.02, 0.04, 0.08),  # 0: Cyan profond
  Color(0.06, 0.10, 0.18),  # 1-7: Dégradé cyan/bleu
  Color(0.10, 0.18, 0.30),
  Color(0.18, 0.30, 0.46),
  Color(0.28, 0.44, 0.60),
  Color(0.42, 0.60, 0.75),
  Color(0.60, 0.78, 0.88),
  Color(0.78, 0.92, 1.00),
]
```
**Caractère** : Îles mystiques, brumes magiques, otherworldly, cyan brillant.

### Utilisation — Palette Swap Shader

```gdscript
# Créer une texture palette pour palette_swap.gdshader
var palette_tex = MerlinVisual.create_biome_palette_texture("broceliande")

# Appliquer au material du biome
biome_sprite.material.set_shader_parameter("palette", palette_tex)
```

### Application CRT per-biome

```gdscript
# Appliquer le CRT distortion profile du biome
MerlinVisual.apply_biome_crt("landes")
```

---

## CRT_ASPECT_COLORS — Triade en phosphore

Voir section **ASPECT COLORS** ci-dessus (identique logique, version CRT).

---

## AUTRES PALETTES & CONSTANTES

### TIME_OF_DAY_COLORS (Éclairage ambiant)

Overlays de couleur pour le jour/nuit (MenuPrincipal ambient).

| Moment | Couleur (RGBA) | Alpha | Ambiance |
|--------|---|-------|----------|
| night | (0.10, 0.12, 0.25, 0.35) | 0.35 | Bleu froid nuit |
| dawn | (0.45, 0.28, 0.15, 0.20) | 0.20 | Orange aube |
| morning | (0.95, 0.90, 0.80, 0.05) | 0.05 | Jaune matin clair |
| midday | (1.0, 1.0, 0.95, 0.0) | 0.0 | Blanc pur (minuit solaire) |
| afternoon | (0.90, 0.82, 0.65, 0.08) | 0.08 | Or après-midi |
| dusk | (0.55, 0.25, 0.10, 0.25) | 0.25 | Orange crépuscule |
| evening | (0.20, 0.15, 0.28, 0.30) | 0.30 | Bleu soirée |

### SEASON_COLORS & SEASON_TINTS (Saisonnalité)

Palette saisonnière pour teintage ambient global.

| Saison | Français | Color (RGB) | Tint (scale) |
|--------|----------|---|---|
| spring | printemps | (0.45, 0.70, 0.40) | (1.02, 1.07, 1.00) |
| summer | été | (0.40, 0.65, 0.85) | (1.08, 1.04, 0.95) |
| autumn | automne | (0.80, 0.55, 0.25) | (1.10, 0.92, 0.82) |
| winter | hiver | (0.60, 0.45, 0.70) | (0.84, 0.90, 1.08) |

### LLM_STATUS (Legacy — Parchemin)

Palette historique pour barre LLM (rollback si besoin).

| État | Color (RGB) | Contexte |
|------|---|----------|
| bg | (0.18, 0.15, 0.12, 0.85) | Fond parchemin |
| bg_hover | (0.22, 0.18, 0.14, 0.95) | Fond parchemin hover |
| text | (0.85, 0.80, 0.75) | Texte parchemin |
| success | (0.32, 0.58, 0.28) | Succès (vert) |
| warning | (0.72, 0.58, 0.22) | Warning (or) |
| error | (0.72, 0.28, 0.22) | Erreur (rouge) |

### MODULATE ANIMATION (Constantes de brillance)

Pour pulses, glows, highlights au runtime.

| Constante | Valeur (scale 0-1) | Usage |
|-----------|--|---------|
| MODULATE_PULSE | (1.06, 1.06, 1.06) | Pulse léger +6% |
| MODULATE_GLOW | (1.3, 1.3, 1.3) | Glow fort +30% |
| MODULATE_GLOW_DIM | (1.15, 1.15, 1.15) | Glow doux +15% |
| MODULATE_HIGHLIGHT | (1.5, 1.5, 1.5) | Highlight intense +50% |

**Utilisation** :
```gdscript
# Pulse un label
label.modulate = MerlinVisual.MODULATE_GLOW
await get_tree().create_timer(0.5).timeout
label.modulate = Color.WHITE  # Reset
```

---

## CONSTANTES DE FONTS

### Chemins et fallbacks

```gdscript
const FONT_PATHS := {
	"title": ["res://resources/fonts/terminal/VT323-Regular.ttf"],
	"body": ["res://resources/fonts/terminal/VT323-Regular.ttf"],
	"terminal": ["res://resources/fonts/terminal/VT323-Regular.ttf"],
	"celtic": ["res://resources/fonts/celtic_bit/celtic-bit.ttf"],
	# Legacy (rollback)
	"title_legacy": ["res://resources/fonts/morris/MorrisRomanBlack.otf"],
	"body_legacy": ["res://resources/fonts/morris/MorrisRomanBlackAlt.otf"],
}
```

### Tailles

| Constante | Taille | Usage |
|-----------|--------|-------|
| TITLE_SIZE | 52px | Titres principaux |
| TITLE_SMALL | 38px | Titres secondaires |
| BODY_SIZE | 22px | Corps standard |
| BODY_LARGE | 26px | Corps emphase |
| BODY_SMALL | 17px | Corps compact |
| CAPTION_SIZE | 16px | Labels |
| CAPTION_LARGE | 14px | Hints |
| CAPTION_SMALL | 13px | Labels discrets |
| CAPTION_TINY | 10px | Très petits textes |
| BUTTON_SIZE | 22px | Boutons |

### Outline (Lisibilité CRT + scanlines)

```gdscript
const OUTLINE_SIZE := 2
const OUTLINE_COLOR: Color = Color(0.02, 0.04, 0.02)  # bg_deep
```

**Raison** : Texte phosphor sur scanlines = flou naturel + besoin d'outline 2px noir pour séparation claire.

---

## CONSTANTES D'ANIMATION

### Timings généraux

| Constante | Durée (s) | Contexte |
|-----------|-----------|----------|
| ANIM_FAST | 0.2 | Réaction rapide (hover bouton) |
| ANIM_NORMAL | 0.3 | Animation standard |
| ANIM_SLOW | 0.5 | Fadeout / entrée lente |
| ANIM_VERY_SLOW | 1.5 | Breathing / ambiance |

### Typewriter (Terminal effect)

| Constante | Valeur | Contexte |
|-----------|--------|----------|
| TW_DELAY | 0.015s | Délai entre caractères |
| TW_PUNCT_DELAY | 0.060s | Pause après ponctuation |
| TW_BLIP_FREQ | 880.0 Hz | Fréquence son typewriter |
| TW_BLIP_DURATION | 0.018s | Durée du blip |
| TW_BLIP_VOLUME | 0.04 | Volume normalisé |

### CRT Effects

| Constante | Valeur | Détail |
|-----------|--------|--------|
| CRT_CURSOR_BLINK | 0.53s | Clignotement curseur |
| CRT_BOOT_LINE_DELAY | 0.12s | Délai lignes boot |
| CRT_PHOSPHOR_FADE | 0.4s | Phosphor reveal durée |
| CRT_GLITCH_DURATION | 0.08s | Glitch pulse effet |

### Card Animation (Gameplay)

| Constante | Valeur | Usage |
|-----------|--------|-------|
| CARD_FLOAT_OFFSET | 5.0px | Flottement vertical |
| CARD_FLOAT_DURATION | 2.8s | Durée breathing |
| CARD_ENTRY_DURATION | 0.65s | Carte apparition |
| CARD_ENTRY_OVERSHOOT | 1.10 | Overshoot scaling |
| CARD_ENTRY_SETTLE | 0.20s | Stabilisation post-bounce |
| CARD_EXIT_DURATION | 0.55s | Carte disparition |
| CARD_DEAL_DURATION | 0.35s | Flip carte (animation) |
| CARD_DEAL_ARC_HEIGHT | 60.0px | Arc parabole flip |

### Card 3D Tilt (Pseudo-3D hover effect)

| Constante | Valeur | Détail |
|-----------|--------|--------|
| CARD_3D_TILT_MAX | 7.0° | Rotation max (perspectif) |
| CARD_3D_SCALE_HOVER | 1.055 | Zoom hover (+5.5%) |
| CARD_3D_SHADOW_SHIFT | 10.0px | Décalage ombre dynamique |
| CARD_3D_TILT_SPEED | 8.0 | Interpolation smoothness |
| CARD_3D_SHINE_ALPHA | 0.10 | Shine overlay opacity |

### Layered Sprites (Compositing)

| Constante | Valeur | Contexte |
|-----------|--------|----------|
| USE_LAYERED_SPRITES | true | Feature flag sprite composer |
| LAYER_REVEAL_STAGGER | 0.08s | Délai entre layers |
| LAYER_REVEAL_SLIDE | 10.0px | Slide-up offset reveal |
| LAYER_REVEAL_DURATION | 0.30s | Durée reveal par layer |
| PARALLAX_MAX_SHIFT | 8.0px | Max parallax offset |
| SELECTION_STAMP_SCALE | 1.03 | Scale sélection (+3%) |
| EFFECT_REVEAL_DURATION | 0.50s | Triade pulse |
| LAYER_ILLUSTRATION_SIZE | (440, 220) | Illustration size px |

### Options Buttons (Choice reveal)

| Constante | Valeur | Détail |
|-----------|--------|--------|
| OPTION_STAGGER_DELAY | 0.12s | Délai entre choix |
| OPTION_SLIDE_DURATION | 0.35s | Durée slide |
| OPTION_SLIDE_OFFSET | 40.0px | Slide-up distance |

### Easing (Courbes d'interpolation)

```gdscript
const EASING_UI: int = Tween.EASE_OUT         # Sortie fluide (décelération)
const TRANS_UI: int = Tween.TRANS_SINE        # Transition sinusoïdale
const EASING_PATH: int = Tween.EASE_IN_OUT    # In-out (accél → décelé)
const TRANS_PATH: int = Tween.TRANS_CUBIC     # Transition cubique
```

### Pixel Transition (Transition écran)

```gdscript
const PIXEL_TRANSITION := {
	"default_block_size": 10,
	"min_block_size": 6,
	"max_block_size": 16,
	"exit_duration": 0.6,      # Disparition écran
	"enter_duration": 0.8,     # Apparition écran
	"batch_size": 8,           # Blocs animés en parallèle
	"batch_delay": 0.012,      # Délai entre batches
	"input_unlock_progress": 0.7,  # Input déverrouillé à 70%
	"bg_color": Color(0.02, 0.04, 0.02),  # bg_deep
}
```

---

## BIOME_CRT_PROFILES — Distortion per-biome

Chaque biome a un profil CRT (bruit, scanlines, glitch intensity).

```gdscript
const BIOME_CRT_PROFILES := {
	"broceliande": {"noise": 0.015, "scanline_opacity": 0.08, "glitch_probability": 0.003, "tint_blend": 0.025},
	"landes":      {"noise": 0.012, "scanline_opacity": 0.07, "glitch_probability": 0.002, "tint_blend": 0.020},
	"cotes":       {"noise": 0.018, "scanline_opacity": 0.06, "glitch_probability": 0.003, "tint_blend": 0.015},
	"villages":    {"noise": 0.008, "scanline_opacity": 0.05, "glitch_probability": 0.001, "tint_blend": 0.012},
	"cercles":     {"noise": 0.022, "scanline_opacity": 0.09, "glitch_probability": 0.005, "tint_blend": 0.028},
	"marais":      {"noise": 0.025, "scanline_opacity": 0.07, "glitch_probability": 0.006, "tint_blend": 0.024},
	"collines":    {"noise": 0.012, "scanline_opacity": 0.06, "glitch_probability": 0.002, "tint_blend": 0.016},
	"iles":        {"noise": 0.018, "scanline_opacity": 0.06, "glitch_probability": 0.004, "tint_blend": 0.020},
}
```

| Paramètre | Min | Max | Effet |
|-----------|-----|-----|-------|
| **noise** | 0.008 | 0.025 | Bruit CRT phosphor |
| **scanline_opacity** | 0.05 | 0.09 | Opacité lignes scan |
| **glitch_probability** | 0.001 | 0.006 | Chance glitch par frame |
| **tint_blend** | 0.012 | 0.028 | Fusion teinte biome |

**Biome le plus "bruyant"** : Marais (0.025 noise)
**Biome le plus "propre"** : Villages (0.008 noise)

---

## PATTERNS D'UTILISATION

### Pattern 1 : Texte standard

```gdscript
# Texte primaire
label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])

# Texte désactivé
label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor_dim"])

# Texte emphase/warning
label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["amber"])
```

### Pattern 2 : Bouton CRT complet

```gdscript
var button = Button.new()
MerlinVisual.apply_button_theme(button)  # Applique theme complet (normal/hover/pressed)
```

### Pattern 3 : Panel avec style

```gdscript
var panel = PanelContainer.new()
panel.add_theme_stylebox_override("panel", MerlinVisual.make_card_panel_style())
```

### Pattern 4 : Glow phosphor (reveal animation)

```gdscript
# Texte fade-in avec glow
var label = Label.new()
MerlinVisual.phosphor_reveal(label, 0.4)  # Tween built-in
```

### Pattern 5 : Boot sequence (CeltOS)

```gdscript
# Texte typé ligne par ligne
var label = Label.new()
await MerlinVisual.boot_line_type(label, "MERLIN OS v2.4", 0.12)
```

### Anti-patterns à éviter

```gdscript
# ❌ NE PAS hardcoder les couleurs
label.add_theme_color_override("font_color", Color(0.20, 1.00, 0.40))

# ✅ TOUJOURS utiliser CRT_PALETTE
label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE["phosphor"])

# ❌ NE PAS mélanger PALETTE et CRT_PALETTE
var color = MerlinVisual.PALETTE["ink"]  # ← Vieux
var color = MerlinVisual.CRT_PALETTE["phosphor_dim"]  # ← Bon

# ❌ NE PAS calculer les couleurs (les stocker en cache)
for i in range(100):
	label.modulate = Color(0.20, 1.00, 0.40)  # Mauvais (GPU overhead)

# ✅ Utiliser modulate directement
label.modulate = MerlinVisual.MODULATE_GLOW  # Constant, optimal
```

---

## CHECKLISTE DE VALIDATION COULEUR

Avant de valider une UI/scène CRT :

- [ ] **Tous les textes phosphor** utilisent `CRT_PALETTE["phosphor"]` ou dérivé (dim/bright)
- [ ] **Tous les fonds** utilisent `CRT_PALETTE["bg_*"]` (jamais hardcodé noir pur)
- [ ] **Tous les accents** utilisent `CRT_PALETTE["amber"]` ou `CRT_PALETTE["cyan"]`
- [ ] **Toutes les bordures** utilisent `CRT_PALETTE["border"]` ou `border_bright`
- [ ] **Pas de mélange PALETTE/CRT_PALETTE** dans la même scène
- [ ] **Pas de Color()** hardcodés (sauf const spécifiques du fichier local)
- [ ] **Outline présent** sur texte très petit (<16px)
- [ ] **Contrast ratio** ≥ 4.5:1 (WCAG AA minimum)
- [ ] **Testé en-jeu** sur ScreenDither CRT overlay (PixelTransition + scanlines)

---

## RÉFÉRENCES

| Document | Lien |
|----------|------|
| **Code source** | `scripts/autoload/merlin_visual.gd` |
| **Game Design Bible** | `docs/GAME_DESIGN_BIBLE.md` v2.4 |
| **LLM Architecture** | `docs/LLM_ARCHITECTURE.md` |
| **UI/UX Bible** | `docs/70_graphic/UI_UX_BIBLE.md` |
| **Shaders CRT** | `resources/shaders/crt_*.gdshader` |

---

**Document rédigé par Claude Code — Source de vérité unique pour la gestion des couleurs M.E.R.L.I.N**

Dernière révision : 2026-03-15
Prochaine revue : Après phase UI complète (migration PALETTE → CRT_PALETTE achevée)
