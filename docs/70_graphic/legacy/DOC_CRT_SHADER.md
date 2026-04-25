# Système CRT Shader — M.E.R.L.I.N.

**Dernière mise à jour**: 2026-03-15
**Version**: 2.0
**Statut**: Actif (production)

---

## Table des matières

1. [Philosophie](#philosophie)
2. [Architecture CRT](#architecture-crt)
3. [crt_terminal.gdshader](#crt_terminalgdshader)
4. [crt_static.gdshader](#crt_staticgdshader)
5. [Guide de paramétrage](#guide-de-paramétrage)
6. [Intégration saisonnière](#intégration-saisonnière)
7. [Considérations performance](#considérations-performance)
8. [Utilisation et bonnes pratiques](#utilisation-et-bonnes-pratiques)
9. [Troubleshooting](#troubleshooting)

---

## Philosophie

### Vision esthétique

M.E.R.L.I.N. est une intelligence artificielle du futur. Le joueur la voit à travers un **terminal CRT vintage** — une fenêtre technologique anachronique sur le passé celtique. Ce paradoxe temporel définit l'identité visuelle du jeu.

**Principes:**
- **Terminal rétro** : L'écran du joueur imite un moniteur cathodique années 1980-90
- **Phosphore vert** : Teinte primaire (RGB 0.20, 1.00, 0.40) inspirée des anciens écrans VT100
- **Balayages épais** : Lignes horizontales scandées, artefacts numériques subtils
- **Distortion naturelle** : Courbure barrique légère, aberration chromatique aux bords
- **Grain temporel** : Scintillement naturel, bruit statique, interférences TV
- **Lueur phosphore** : Les pixels brillants "s'allument" légèrement (phosphore cathodique)

### Intégration narrative

La CRT est un **contenant technologique** qui encadre l'expérience fantastique :
- Les **biomes fantastiques** sont rendus sur un écran physique (la CRT)
- Les **couleurs teintées au phosphore** renforcent l'immersion dans l'écran-terminal
- Les **artefacts numériques** (glitch, wobble) symbolisent la transmission instable du futur vers le passé
- L'**interface phosphorescente** (menus, cartes) partage le même écosystème visuel

### Palette CRT intégrée (MerlinVisual)

Toutes les couleurs du système respectent la **CRT_PALETTE** centralisée :

```gdscript
# Phosphore (texte principal CRT)
"phosphor":       Color(0.20, 1.00, 0.40)      # Vert éclatant
"phosphor_dim":   Color(0.12, 0.60, 0.24)      # Vert atténué (arrière-plan)
"phosphor_bright": Color(0.40, 1.00, 0.60)     # Vert surexposé

# Ambre (couleur secondaire CRT ancienne)
"amber":          Color(1.00, 0.75, 0.20)      # Accent chaud
"amber_bright":   Color(1.00, 0.85, 0.40)      # Ambre clair

# Cyan (mystique celtique via terminal moderne)
"cyan":           Color(0.30, 0.85, 0.80)      # Surnaturel
"cyan_bright":    Color(0.50, 1.00, 0.95)      # Magie soutenue

# Fond terminal
"bg_deep":        Color(0.02, 0.04, 0.02)      # Noir presque pur
"bg_dark":        Color(0.04, 0.08, 0.04)      # Gris très sombre avec teinte verte
"bg_panel":       Color(0.06, 0.12, 0.06)      # Panneaux UI

# Artefacts CRT
"scanline":       Color(0.00, 0.00, 0.00, 0.15)  # Lignes de balayage semi-transparentes
```

---

## Architecture CRT

### Pile de couches

Le système CRT utilise **deux shaders complémentaires** :

```
┌──────────────────────────────────────────┐
│   CanvasLayer 100 (CRTLayer)             │
│   ↓ [crt_terminal.gdshader]              │
│   Distortion + Dithering + Post-process  │
├──────────────────────────────────────────┤
│   Scene du jeu (Biomes 3D + UI 2D)       │
│   ↓ couleurs teintées au phosphore       │
│   Affichage normal (unshaded render)     │
├──────────────────────────────────────────┤
│   Overlay optionnel: crt_static.gdshader │
│   (Neige statique / Interférence TV)     │
└──────────────────────────────────────────┘
```

### Pipeline d'effets

Le shader terminal suit une **pipeline 4-stages** :

1. **STAGE 1: UV DISTORTIONS** — Déformation de coordonnées écran
   - Courbure CRT (distortion barrique)
   - Wobble de scanline (balancement temporel)
   - Micro-glitches (sauts aléatoires de pixels)

2. **STAGE 2: COLOR SAMPLING** — Lecture et traitement chromatique
   - Aberration chromatique (séparation RGB aux bords)
   - Décalage couleur (shift temporel subtil)
   - Clamping au bord écran (noir si out-of-bounds)

3. **STAGE 3: COLOR PROCESSING** — Effets visuels sur la couleur
   - Grain temporal (bruit statique)
   - Scintillement (flicker de luminosité globale)
   - Teinte phosphore (coloration + blend)
   - **Scanlines** (raies horizontales foncées)
   - **Lueur phosphore** (bloom sur pixels clairs)
   - Vignette (assombrissement des bords)

4. **STAGE 4: DITHERING** — Quantification couleur + tramage Bayer
   - Réduction palette (color_levels: 2-32 niveaux)
   - Tramage 4×4 Bayer (simulation basse résolution)

### Connexions système

```
ScreenEffects (mood controller)  ← Piloté par l'état du jeu
    ↓
    ├─→ global_intensity      (0.0 = off, 1.0 = full CRT)
    ├─→ phosphor_tint        (Teinte biome: vert/ambre/cyan)
    └─→ Autres uniforms        (scanlines, noise, flicker, etc.)

    ↓ appliqué à

CanvasLayer CRTLayer (layer 100)
    ├─→ ColorRect avec shader: res://shaders/crt_terminal.gdshader
    └─→ Material avec uniforms bindés

    ↓ post-process sur

Scene du jeu (Biomes 3D, cartes 2D, UI)
    (Résultat final: écran CRT vintage)
```

---

## crt_terminal.gdshader

**Chemin**: `res://shaders/crt_terminal.gdshader`
**Type**: Canvas Item (post-process)
**Taille**: ~235 lignes
**Entrée**: `screen_texture` (framebuffer de la scène)
**Sortie**: Pixel traité avec effets CRT

### Uniforms documentation

#### MASTER CONTROLS

```gdscript
uniform float global_intensity : hint_range(0.0, 1.0) = 0.4;
```
- **Nom**: global_intensity
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.4
- **Effet**: Intensité générale du shader CRT
  - 0.0 = Désactivé complètement (passthrough transparent)
  - 0.4 = Modéré (défaut production)
  - 1.0 = Full CRT (tous les effets au max)
- **Utilisation**: Contrôle la visibilité globale. Utile pour des transitions ou des modes de jeu spéciaux
- **Note**: Beaucoup d'effets ont des gardes `if (global_intensity >= 0.001)` pour désactiver les coûts GPU

---

#### CRT CURVATURE

```gdscript
uniform float curvature : hint_range(0.0, 0.15) = 0.04;
```
- **Nom**: curvature
- **Plage**: 0.0 — 0.15
- **Défaut**: 0.04
- **Effet**: Distortion barrique (courbure du moniteur cathodique)
  - 0.0 = Écran plat (pas de courbure)
  - 0.04 = Courbure légère (défaut, réaliste pour vieux CRT)
  - 0.15 = Très bombé (effet exagéré, peu lisible)
- **Mathématique**: `distort = 1.0 + r2 * curvature * global_intensity`
  - r2 = distance²/center, pondère le centre moins que les bords
- **Utilisation**: Augmenter pour renforcer l'effet rétro, diminuer pour une lisibilité maximale
- **Perf**: Léger (une seule multiplication + pow)

---

#### CRT SCANLINES

```gdscript
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(100.0, 800.0) = 400.0;
```

**Nom**: scanline_opacity
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.12
- **Effet**: Opacité des raies horizontales scanlines
  - 0.0 = Invisible (pas de scanlines)
  - 0.12 = Subtil, authentique (défaut)
  - 0.3+ = Très visible, dominateur
- **Mathématique**: Oscillation sinusoïdale sur Y, puissance 1.5 (contraste)
  - `scanline = sin(uv.y * scanline_count * π) → [0,1]`
  - `luminance *= 1.0 - (scanline * opacity * intensity)`
- **Note**: Crée les **raies horizontales épaisses** typiques CRT

**Nom**: scanline_count
- **Plage**: 100.0 — 800.0
- **Défaut**: 400.0
- **Effet**: Nombre de scanlines sur la hauteur écran
  - 100 = Raies épaisses, grossières
  - 400 = Standard CRT années 90 (défaut, 480p→400 lines)
  - 800 = Très fins, dense
- **Note**: Plus haut = raies plus serrées mais plus subtiles
- **Tuning**: Pour une résolution 1080p, 400-600 est lisible

---

#### PHOSPHOR TINT

```gdscript
uniform vec4 phosphor_tint : source_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform float tint_blend : hint_range(0.0, 1.0) = 0.03;
```

**Nom**: phosphor_tint
- **Type**: `vec4` (sRGB color picker)
- **Défaut**: (0.2, 1.0, 0.4, 1.0) = **vert phosphore pur**
- **Effet**: Teinte colorée appliquée à l'écran
- **Options prédéfinies** (par biome):
  - **Vert phosphore** (défaut): (0.2, 1.0, 0.4) — terminal classique
  - **Ambre** (biome chaud): (1.0, 0.75, 0.2) — anciennes CRT monochrome
  - **Blanc/gris**: (0.9, 0.9, 0.9) — moniteur neutre moderne
  - **Cyan**: (0.3, 0.85, 0.8) — sci-fi mystique
- **Note**: L'alpha est ignoré (fixé à 1.0 dans le shader)
- **Utilisation**: Changer via `ScreenEffects.set_phosphor_tint()` par biome

**Nom**: tint_blend
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.03
- **Effet**: Intensité du mélange de teinte
  - 0.0 = Pas de teinte (couleurs originales)
  - 0.03 = Subtil (défaut, teinte douce mais perceptible)
  - 0.1+ = Très marqué, écran uniformément coloré
- **Mathématique**: `col.rgb = mix(col.rgb, col.rgb * tint.rgb, blend * intensity)`
  - Applique la teinte multiplicativement (préserve les contrastes)
- **Perf**: Très léger (mix + multiply)

---

#### DITHERING (Bayer 4×4)

```gdscript
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 8.0;
```

**Nom**: dither_strength
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.3
- **Effet**: Intensité du tramage Bayer 4×4
  - 0.0 = Pas de tramage (banding visible si color_levels bas)
  - 0.3 = Modéré, cassure de banding subtile (défaut)
  - 1.0 = Tramage dense, "bruit" visible
- **Mathématique**:
  ```
  dithered = col.rgb * (color_levels - 1)
  dithered += (threshold - 0.5) * dither_strength
  dithered = floor(dithered + 0.5) / (color_levels - 1)
  ```
  - Ajoute du seuil Bayer (-0.5 à +0.5) avant quantification
- **Utilisation**: Augmenter si banding visible sur gradients
- **Note**: Le tramage 4×4 crée un pattern **régulier et réaliste** (pas de bruit aléatoire)

**Nom**: color_levels
- **Plage**: 2.0 — 32.0
- **Défaut**: 8.0
- **Effet**: Nombre de niveaux par canal RGB (quantification palette)
  - 2 = 2 niveaux par canal (8 couleurs total) — très pixelisé
  - 8 = 8³ = 512 couleurs (défaut, émule mode EGA/CGA)
  - 16 = 4096 couleurs (très lisible, déjà Amiga-level)
  - 32 = 32768 couleurs (presque imperceptible)
- **Note**: 8.0 est le **sweet spot** — balance entre rétro et lisibilité
- **Tuning**: Réduire pour plus de rétro, augmenter pour modernité

---

#### PHOSPHOR GLOW

```gdscript
uniform float phosphor_glow : hint_range(0.0, 1.0) = 0.06;
```
- **Nom**: phosphor_glow
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.06
- **Effet**: Lueur des pixels brillants (bloom phosphorescé)
  - 0.0 = Pas de glow (pixels sharp)
  - 0.06 = Subtil (défaut, ajoute 6% de bloom max)
  - 0.15+ = Très luminescent, écran halo
- **Mathématique**:
  ```
  luminance = dot(col.rgb, [0.299, 0.587, 0.114])  // Luminance perceptuelle
  bloom = smoothstep(0.5, 1.0, luminance) * glow * intensity
  col.rgb += col.rgb * bloom  // Additionne au pixel
  ```
  - Affecte seulement les pixels > 50% luminance
  - Douce transition (smoothstep) pour un effet naturel
- **Utilisation**: Augmenter pour renforcer la "chaleur" phosphore des verts/ambre
- **Perf**: Très léger (dot + smoothstep)
- **Note**: Imite le **phosphore physique** qui émet légèrement plus quand excité

---

#### CHROMATIC ABERRATION (bords uniquement)

```gdscript
uniform bool chromatic_enabled = true;
uniform float chromatic_intensity : hint_range(0.0, 0.01) = 0.0005;
uniform float chromatic_falloff : hint_range(1.0, 4.0) = 3.0;
```

**Nom**: chromatic_enabled
- **Type**: `bool`
- **Défaut**: true
- **Effet**: Active/désactive la séparation RGB aux bords
- **Utilisation**: Set à `false` pour désactiver entièrement

**Nom**: chromatic_intensity
- **Plage**: 0.0 — 0.01
- **Défaut**: 0.0005
- **Effet**: Amplitude de décalage RGB par rapport aux bords
  - 0.0 = Pas de séparation
  - 0.0005 = Subtil (défaut, ~0.5 pixels @ 1080p)
  - 0.002+ = Visible, arc-en-ciel aux bords
- **Mathématique**:
  ```
  edge_factor = pow(dist_from_center * 2.0, chromatic_falloff)
  ca_amount = chromatic_intensity * edge_factor * intensity
  r = texture(screen_texture, uv + ca_offset).r      // Décalé vers l'extérieur
  g = texture(screen_texture, uv).g                    // Non décalé (centre)
  b = texture(screen_texture, uv - ca_offset).b      // Décalé vers l'intérieur
  ```
  - Seuls les bords sont affectés (falloff exponential)
- **Utilisation**: Augmenter légèrement pour renforcer effet rétro (vieux objectifs)

**Nom**: chromatic_falloff
- **Plage**: 1.0 — 4.0
- **Défaut**: 3.0
- **Effet**: Vitesse d'augmentation vers les bords
  - 1.0 = Augmentation lente (aberration uniforme loin du centre)
  - 3.0 = Exponentielle (défaut, surtout aux bords)
  - 4.0 = Très localisée (uniquement les coins)
- **Note**: Plus haut = effet seulement visible aux **extrêmes bords**

---

#### SCANLINE WOBBLE

```gdscript
uniform bool scanline_enabled = true;
uniform float scanline_wobble_intensity : hint_range(0.0, 0.005) = 0.0003;
uniform float scanline_wobble_frequency : hint_range(0.0, 100.0) = 30.0;
uniform float scanline_wobble_speed : hint_range(0.0, 5.0) = 0.8;
```

**Nom**: scanline_enabled
- **Type**: `bool`
- **Défaut**: true
- **Effet**: Active/désactive le balancement des scanlines
- **Note**: Indépendant de `scanline_opacity` (les deux peuvent exister ensemble)

**Nom**: scanline_wobble_intensity
- **Plage**: 0.0 — 0.005
- **Défaut**: 0.0003
- **Effet**: Amplitude de décalage horizontal des scanlines
  - 0.0 = Scanlines fixes
  - 0.0003 = Très subtil (défaut, ~0.3 pixels wobble)
  - 0.001+ = Wobble perceptible, "instabilité" capteur
- **Mathématique**:
  ```
  wobble = sin(uv.y * freq + TIME * speed)
  wobble += sin(uv.y * freq * 2.3 + TIME * speed * 0.7) * 0.5  // 2e fréquence
  uv.x += wobble * intensity * global_intensity
  ```
  - Combinaison de **deux fréquences** (richesse temporelle)
- **Utilisation**: Augmenter pour l'effet "vieux écran instable"

**Nom**: scanline_wobble_frequency
- **Plage**: 0.0 — 100.0
- **Défaut**: 30.0
- **Effet**: Nombre de cycles wobble sur la hauteur écran
  - 30 = Wobble moyen (défaut, pattern régulier)
  - 10 = Très ondulé (peu de cycles, grandes vagues)
  - 80+ = Wobble très fin, dense

**Nom**: scanline_wobble_speed
- **Plage**: 0.0 — 5.0
- **Défaut**: 0.8
- **Effet**: Vitesse de variation du wobble (en temps réel)
  - 0.8 = Modéré (défaut, ~0.1s par cycle)
  - 0.2 = Très lent (effet hypnotique)
  - 2.0+ = Rapide (scintillement nerveux)
- **Note**: TIME est un variable shader Godot (∞, secondes réelles)

---

#### MICRO GLITCHES

```gdscript
uniform bool glitch_enabled = true;
uniform float glitch_probability : hint_range(0.0, 0.3) = 0.005;
uniform float glitch_intensity : hint_range(0.0, 0.02) = 0.004;
uniform float glitch_line_height : hint_range(0.001, 0.05) = 0.015;
```

**Nom**: glitch_enabled
- **Type**: `bool`
- **Défaut**: true
- **Effet**: Active/désactive les micro-glitches aléatoires

**Nom**: glitch_probability
- **Plage**: 0.0 — 0.3
- **Défaut**: 0.005
- **Effet**: Probabilité qu'une ligne glitch chaque frame
  - 0.005 = 0.5% par frame (~1 glitch par 200 frames @ 60fps)
  - 0.05 = 5% par frame (glitches fréquents)
  - 0.3 = Chaoticité maximale
- **Mathématique**:
  ```
  glitch_time = floor(TIME * 10)  // Quantisé par 0.1s
  glitch_trigger = hash(glitch_time)
  if (glitch_trigger < probability * global_intensity) {
      // Décaler une ligne horizontale
  }
  ```
- **Note**: Les glitches **persistent 0.1s** (pas per-frame, plus stable)

**Nom**: glitch_intensity
- **Plage**: 0.0 — 0.02
- **Défaut**: 0.004
- **Effet**: Amplitude de décalage horizontal quand glitch occur
  - 0.004 = Subtil (~0.4 pixels)
  - 0.01 = Visible, shift de 1 pixel+
  - 0.02 = Très marqué, sauts abrupts

**Nom**: glitch_line_height
- **Plage**: 0.001 — 0.05
- **Défaut**: 0.015
- **Effet**: Épaisseur de la ligne glitch (en UV height [0,1])
  - 0.015 = Défaut, ~1.5% hauteur écran
  - 0.05 = Bande épaise (très visible)
  - 0.001 = Pixel-thin (subtil, peine visible)

---

#### BARREL DISTORTION (legacy compat)

```gdscript
uniform bool barrel_enabled = true;
uniform float barrel_intensity : hint_range(0.0, 0.1) = 0.003;
```

**Nom**: barrel_enabled
- **Type**: `bool`
- **Défaut**: true
- **Effet**: Active/désactive la distortion barrique additionnelle
- **Note**: Distinct de `curvature`, s'ajoute pour la rétro-compatibilité

**Nom**: barrel_intensity
- **Plage**: 0.0 — 0.1
- **Défaut**: 0.003
- **Effet**: Intensité additionnelle de la courbure barrique
  - 0.0 = Pas d'ajout (utiliser `curvature` seul)
  - 0.003 = Très subtil (défaut, amélioration fine)
  - 0.01 = Courbure prononcée
- **Mathématique**: `total_curve = curvature + (barrel_enabled ? barrel_intensity : 0.0)`
- **Note**: À combiner judicieusement avec `curvature` (ne pas doubler l'effet)

---

#### COLOR SHIFTING

```gdscript
uniform bool color_shift_enabled = true;
uniform float color_shift_intensity : hint_range(0.0, 0.02) = 0.0006;
uniform float color_shift_speed : hint_range(0.0, 2.0) = 0.3;
```

**Nom**: color_shift_enabled
- **Type**: `bool`
- **Défaut**: true

**Nom**: color_shift_intensity
- **Plage**: 0.0 — 0.02
- **Défaut**: 0.0006
- **Effet**: Amplitude du décalage de samplage couleur temporel
  - 0.0 = Pas de décalage (lecture UV fixe)
  - 0.0006 = Subtil (~0.06% hauteur écran)
  - 0.01+ = Ondulation chromatique perceptible
- **Mathématique**:
  ```
  shift_time = TIME * color_shift_speed
  color_offset.x = sin(shift_time + uv.y * 5.0) * intensity * global_intensity
  color_offset.y = cos(shift_time * 0.7 + uv.x * 5.0) * intensity * 0.5 * global_intensity
  // Appliquer color_offset lors du sampling texture
  ```
- **Utilisation**: Crée une **ondulation chromatique subtile** (effet stabilisateur)

**Nom**: color_shift_speed
- **Plage**: 0.0 — 2.0
- **Défaut**: 0.3
- **Effet**: Vitesse de variation du décalage
  - 0.3 = Lent, hypnotique (défaut)
  - 1.0 = Modéré
  - 2.0 = Rapide, palpitant

---

#### TEMPORAL NOISE (grain)

```gdscript
uniform bool noise_enabled = true;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.010;
uniform float noise_speed : hint_range(1.0, 60.0) = 24.0;
```

**Nom**: noise_enabled
- **Type**: `bool`
- **Défaut**: true

**Nom**: noise_intensity
- **Plage**: 0.0 — 0.1
- **Défaut**: 0.010
- **Effet**: Intensité du bruit statique additif
  - 0.0 = Aucun bruit
  - 0.010 = Subtil grain (défaut, enhancement texture)
  - 0.05+ = Bruit visible, effet VHS/analogue
- **Mathématique**:
  ```
  grain = rand(uv * 500.0 + floor(TIME * noise_speed)) - 0.5  // [-0.5, +0.5]
  col.rgb += grain * noise_intensity * global_intensity
  ```
  - Bruit pseudo-random **haute fréquence** (500× zoom UV)
  - Synchronisé sur le temps (temporel, pas spatial)
- **Utilisation**: Ajoute du **grain VHS** authentique, masque banding
- **Perf**: Modéré (random + floor)

**Nom**: noise_speed
- **Plage**: 1.0 — 60.0
- **Défaut**: 24.0
- **Effet**: Fréquence de changement du pattern bruit
  - 24 = ~24 Hz (refresh pattern)
  - 12 = Changement lent (stabilité relative)
  - 60 = Changement rapide (scintillement)
- **Note**: Valeur élevée crée une **sensation d'instabilité temporelle**

---

#### VIGNETTE

```gdscript
uniform bool vignette_enabled = true;
uniform float vignette_intensity : hint_range(0.0, 0.5) = 0.08;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.55;
```

**Nom**: vignette_enabled
- **Type**: `bool`
- **Défaut**: true

**Nom**: vignette_intensity
- **Plage**: 0.0 — 0.5
- **Défaut**: 0.08
- **Effet**: Intensité de l'assombrissement des bords
  - 0.0 = Aucune vignette (bords clairs)
  - 0.08 = Modéré (défaut, assombrissement subtle des bords)
  - 0.3+ = Cadrage fort, centre attirant l'attention
- **Mathématique**:
  ```
  dist_from_center = length(uv - 0.5)
  vignette = 1.0 - smoothstep(softness, 1.0, dist_from_center * 2.0)
  col.rgb *= mix(1.0, vignette, intensity * global_intensity)
  ```
- **Note**: Imite les vieux écrans CRT avec perte de luminosité aux bords

**Nom**: vignette_softness
- **Plage**: 0.1 — 1.0
- **Défaut**: 0.55
- **Effet**: Douceur de la transition vignette
  - 0.1 = Très dure (frontière nette)
  - 0.55 = Soft (défaut, transition progressive)
  - 1.0 = Très douce (vignette diffuse)
- **Mathématique**: `smoothstep(softness, 1.0, distance)`
  - Contrôle le gradient d'interpolation

---

#### BRIGHTNESS FLICKER

```gdscript
uniform bool flicker_enabled = true;
uniform float flicker_intensity : hint_range(0.0, 0.05) = 0.003;
uniform float flicker_speed : hint_range(1.0, 30.0) = 12.0;
```

**Nom**: flicker_enabled
- **Type**: `bool`
- **Défaut**: true

**Nom**: flicker_intensity
- **Plage**: 0.0 — 0.05
- **Défaut**: 0.003
- **Effet**: Amplitude de la variation de luminosité globale
  - 0.0 = Pas de scintillement
  - 0.003 = Subtil (défaut, ~0.3% variation)
  - 0.02+ = Scintillement visible, nervosité
- **Mathématique**:
  ```
  flick = 1.0 + (rand(vec2(floor(TIME * flicker_speed), 0.0)) - 0.5) * flicker_intensity * intensity * 2.0
  col.rgb *= flick  // Multiplie la luminance globale
  ```
  - [-0.5, +0.5] → [-intensity, +intensity] → [1±intensity]
- **Utilisation**: Crée un **scintillement naturel** de moniteur vieillissant

**Nom**: flicker_speed
- **Plage**: 1.0 — 30.0
- **Défaut**: 12.0
- **Effet**: Fréquence de changement du scintillement
  - 12 = Modéré (défaut, ~2 changements/sec)
  - 6 = Lent, pulsation
  - 24+ = Rapide, instabilité électrique

---

### Cas d'usage typiques

#### Production standard (défaut)
```gdscript
# Tous les défauts
global_intensity = 0.4      # Modéré
curvature = 0.04
scanline_opacity = 0.12
scanline_count = 400.0
phosphor_tint = vec4(0.2, 1.0, 0.4, 1.0)  # Vert
tint_blend = 0.03
color_levels = 8.0          # Quantization EGA-like
# Tous les autres = defaults
```
**Résultat**: Terminal CRT authentique années 90, jouable

#### "Glitch art" intensifié
```gdscript
global_intensity = 0.8
glitch_probability = 0.08   # Glitches fréquents
glitch_intensity = 0.015    # Sauts visibles
scanline_wobble_intensity = 0.001  # Wobble fort
color_shift_intensity = 0.015      # Aberration chromatique
chromatic_intensity = 0.003        # CA forte
noise_intensity = 0.05             # Grain VHS dense
flicker_intensity = 0.02           # Scintillement nerveux
```
**Résultat**: Écran "cassé", transmission instable

#### Historique/Archive
```gdscript
global_intensity = 0.9
scanline_opacity = 0.25    # Scanlines épaisses
scanline_count = 240.0     # Aéré (ancien 240p)
color_levels = 4.0         # 64 couleurs seulement
phosphor_tint = vec4(1.0, 0.75, 0.2, 1.0)  # Ambre (ancien)
dither_strength = 1.0      # Tramage dense
noise_intensity = 0.08
flicker_intensity = 0.04
```
**Résultat**: Archivage années 80, très dégradé

#### Moderne/Cyberpunk
```gdscript
global_intensity = 0.2
curvature = 0.01           # Courbure minimale
scanline_opacity = 0.04    # Scanlines subtiles
phosphor_tint = vec4(0.3, 0.85, 0.8, 1.0)  # Cyan
color_levels = 16.0        # Palette étendue
chromatic_intensity = 0.001  # Aberration légère
noise_intensity = 0.005    # Bruit fin
flicker_intensity = 0.001  # Scintillement imperceptible
```
**Résultat**: Interface moderne avec touches rétro

---

## crt_static.gdshader

**Chemin**: `res://shaders/crt_static.gdshader`
**Type**: Canvas Item (overlay autonome ou multi-layered)
**Taille**: ~80 lignes
**Entrée**: Aucune texture d'entrée (génère le bruit internement)
**Sortie**: Pattern bruit statique + artefacts TV

### Purpose

Tandis que `crt_terminal.gdshader` est un **post-process** sur la scène du jeu, `crt_static.gdshader` est un **shader générateur** qui crée une **couche de neige TV statique pure**. Utile pour :
- **Écrans de menu** (avant de charger la scène)
- **Mode stand-by** (écran cassé/blanc)
- **Effets narratifs** (transmission perturbée)
- **Transitions** (fade vers/depuis la neige)

### Uniforms documentation

```gdscript
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
```
- **Plage**: 0.0 — 1.0
- **Défaut**: 1.0 (full opacity)
- **Effet**: Alpha global du shader
  - 0.0 = Transparent (invisible)
  - 0.5 = Semi-transparent (couche intermédiaire)
  - 1.0 = Opaque (couche dense)
- **Utilisation**: Contrôle la visibilité du bruit statique

```gdscript
uniform float noise_speed : hint_range(1.0, 100.0) = 50.0;
```
- **Plage**: 1.0 — 100.0
- **Défaut**: 50.0
- **Effet**: Vitesse de changement du pattern bruit
  - 50 = Modéré (défaut, pattern TV rapide)
  - 10 = Lent (stabilité relative, pattern persistent)
  - 100 = Très rapide (chaos total)

```gdscript
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_count : hint_range(100.0, 800.0) = 400.0;
```
- Identiques à `crt_terminal.gdshader` (cf. ci-dessus)
- Ici: superposé sur le bruit statique (moins prégnant)

```gdscript
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.8;
```
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.8
- **Effet**: Intensité du bruit statique
  - 0.0 = Pas de bruit (écran vide/bleu)
  - 0.8 = Riche (défaut, neige TV classique)
  - 1.0 = Saturé (max statique)
- **Mathématique**:
  ```
  static_noise = rand(uv * 500.0 + TIME * noise_speed)
  coarse_noise = noise(uv * 80.0 + TIME * noise_speed * 0.3, ...)
  combined_noise = mix(static_noise, coarse_noise, 0.4) * grain_intensity
  ```
  - Combine **deux couches** de bruit (fine + grossière)

```gdscript
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.15;
```
- **Plage**: 0.0 — 0.5
- **Défaut**: 0.15
- **Effet**: Variations globales de luminosité
  - 0.15 = Modéré (défaut, scintillement naturel TV)
  - 0.3+ = Très fluctuant (instabilité électrique)

```gdscript
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
```
- **Plage**: 0.0 — 1.0
- **Défaut**: 0.3
- **Effet**: Assombrissement des bords (encadrement écran)
  - 0.0 = Bords clairs
  - 0.3 = Modéré (défaut)
  - 0.7+ = Très sombre (focus centre)

```gdscript
uniform vec4 tint : source_color = vec4(0.85, 0.9, 0.95, 1.0);
```
- **Type**: sRGB color picker
- **Défaut**: (0.85, 0.9, 0.95) = **gris-blanc léger**
- **Effet**: Teinte du bruit statique
  - (0.85, 0.9, 0.95) = Blanc cassé (défaut)
  - (0.2, 1.0, 0.4) = Vert phosphore (neige verte)
  - (1.0, 0.75, 0.2) = Ambre (neige chaude)

### Caractéristiques spéciales

**Interférences TV verticales** :
```gdscript
// Lignes de balayage verticales occasionnelles (interference)
float v_interference = 0.0;
float interference_pos = fract(TIME * 0.3) * 1.4 - 0.2;
if (abs(uv.y - interference_pos) < 0.03) {
    v_interference = (1.0 - abs(uv.y - interference_pos) / 0.03) * 0.3;
}
```
- Crée une **bande horizontale mouvante** (tuning TV classique)
- Traverse l'écran lentement (TIME * 0.3 ≈ 3.33s par cycle)
- Ajoute du **réalisme analogique**

**Edge darkening** :
```gdscript
float edge_darken = 1.0 - pow(abs(uv.x - 0.5) * 2.0, 6.0) * 0.15;
edge_darken *= 1.0 - pow(abs(uv.y - 0.5) * 2.0, 6.0) * 0.15;
```
- Assombrissement **exponentiel** des bords (power 6)
- Imite les vignettes de vieux écrans
- Combiné à `vignette_intensity` pour l'effet final

### Utilisation típica

#### Menu principal
```gdscript
# Écran titre avant le jeu
intensity = 0.7
grain_intensity = 0.9
scanline_opacity = 0.3
noise_speed = 40.0
tint = vec4(0.2, 1.0, 0.4, 1.0)  # Vert phosphore
```

#### Transition interstitielle
```gdscript
# Entre deux scènes (fade in/out)
intensity = 0.5  # Semi-transparent
grain_intensity = 0.6
noise_speed = 30.0  # Lent pour stabilité visuelle
```

#### Mode veille/cassé
```gdscript
# Écran "off" en attente
intensity = 0.2  # Très subtil
grain_intensity = 0.5
scanline_opacity = 0.5  # Scanlines très visibles
vignette_intensity = 0.8  # Très sombre aux bords
```

---

## Guide de paramétrage

### Tuning par effet visuel

#### ✓ Réduire le banding (dégradés trop nets)
- Augmenter `dither_strength` (0.3 → 0.6)
- Réduire `color_levels` (8.0 → 5.0) + dithering
- Ajouter léger `noise_intensity` (0.010 → 0.025)

**Résultat**: Gradients plus lisses, simulation texture

#### ✓ Augmenter l'effet rétro
- Augmenter `scanline_opacity` (0.12 → 0.25)
- Diminuer `color_levels` (8.0 → 4.0)
- Augmenter `dither_strength` (0.3 → 0.8)
- Augmenter `noise_intensity` (0.010 → 0.04)
- Augmenter `flicker_intensity` (0.003 → 0.015)

**Résultat**: Écran années 80 authentique

#### ✓ Renforcer la "mystique CRT" (sans perdre lisibilité)
- Augmenter `curvature` (0.04 → 0.08)
- Augmenter `phosphor_glow` (0.06 → 0.15)
- Augmenter `tint_blend` (0.03 → 0.08)
- Ajouter léger `scanline_wobble_intensity` (0.0003 → 0.001)

**Résultat**: Écran à la fois rétro et magnifique

#### ✓ Mode "transmission instable" (narrative)
- Augmenter `glitch_probability` (0.005 → 0.05)
- Augmenter `glitch_intensity` (0.004 → 0.015)
- Augmenter `scanline_wobble_intensity` (0.0003 → 0.002)
- Augmenter `chromatic_intensity` (0.0005 → 0.002)
- Augmenter `color_shift_intensity` (0.0006 → 0.005)

**Résultat**: Écran "cassé", immersion narrative

#### ✓ Mode "lecture claire" (accessibilité)
- Réduire `global_intensity` (0.4 → 0.1)
- Réduire `scanline_opacity` (0.12 → 0.02)
- Augmenter `color_levels` (8.0 → 16.0)
- Réduire `dither_strength` (0.3 → 0.05)
- Réduire tous les effets dynamiques (glitch, wobble, etc.)

**Résultat**: Minimaliste, accessible

### Par biome

#### Biome vert (Forêt/Marais)
```gdscript
phosphor_tint = vec4(0.2, 1.0, 0.4, 1.0)     # Vert saturé
tint_blend = 0.05                             # Teinte plus visible
phosphor_glow = 0.08                          # Glow prominent
```

#### Biome ambre (Désert/Montagne)
```gdscript
phosphor_tint = vec4(1.0, 0.75, 0.2, 1.0)    # Ambre chaud
tint_blend = 0.06
phosphor_glow = 0.04                          # Glow moins intense
```

#### Biome cyan (Îles/Mystique)
```gdscript
phosphor_tint = vec4(0.3, 0.85, 0.8, 1.0)    # Cyan clair
tint_blend = 0.08                             # Très saturé
chromatic_intensity = 0.001                   # Aberration chromatique subtle
```

#### Biome blanc/neutre (Temple/Sacré)
```gdscript
phosphor_tint = vec4(0.9, 0.9, 0.9, 1.0)     # Blanc
tint_blend = 0.02                             # Teinte minimale
phosphor_glow = 0.1                           # Glow maximal (luminosité)
```

---

## Intégration saisonnière

### Architecture

```
ScreenEffects (mood controller)  ← Calendrier du jeu
    ├─→ Saison : printemps/été/automne/hiver
    └─→ Mois exact (0-11)

    ↓ Détermine

phosphor_tint                 (Couleur biome + teinte saisonnière)
global_intensity              (Luminosité saisonnière)
scanline_opacity              (Densité des raies)
noise_intensity               (Grain atmosphérique)
color_levels                  (Palette réduite en hiver, enrichie en été)
```

### Propositions saisonnières

#### Printemps (avril-mai)
- **Teinte**: Vert frais (0.3, 1.0, 0.5) — plus bleu-vert
- **Luminosité**: 0.5 (augmentée, journées longues)
- **Scanlines**: 0.10 (réduites, clarté croissante)
- **Grain**: 0.005 (fin, air clair)
- **Palette**: 12 niveaux (riche, couleurs variées)
- **Effet**: Écran "réveillé", vibrant

#### Été (juin-août)
- **Teinte**: Vert éclatant (0.2, 1.0, 0.4) — phosphore pur
- **Luminosité**: 0.6 (max, midi intense)
- **Scanlines**: 0.08 (minimales)
- **Grain**: 0.003 (très fin)
- **Palette**: 16 niveaux (max, écran en pleine forme)
- **Chromatic**: -50% (réduction, écran stable)
- **Effet**: Écran au pic performance, lisible

#### Automne (sept-oct)
- **Teinte**: Ambre-vert (0.6, 0.9, 0.4) — transition
- **Luminosité**: 0.35 (diminue, crépuscule)
- **Scanlines**: 0.15 (augmentation)
- **Grain**: 0.015 (grain croissant)
- **Palette**: 10 niveaux (dégradation)
- **Flicker**: 0.008 (instabilité croissante)
- **Effet**: Écran fatigue, usé

#### Hiver (nov-janv)
- **Teinte**: Ambre (1.0, 0.75, 0.2) — chaleur rare
- **Luminosité**: 0.2 (min, jour court)
- **Scanlines**: 0.25 (épaisses, dégradation)
- **Grain**: 0.04 (noise dense, statique)
- **Palette**: 4 niveaux (extrême réduction)
- **Flicker**: 0.02 (scintillement fort)
- **Color shift**: 0.003 (drift chromatique)
- **Effet**: Écran en survie, ancien, froid

### Implémentation code

```gdscript
# ScreenEffects.gd (pseudo-code)
var season_index = MerlinStore.current_season  # 0=spring, 3=winter
var intensity_by_season = [0.5, 0.6, 0.35, 0.2]
var scanline_by_season = [0.10, 0.08, 0.15, 0.25]

func update_seasonal_crt():
    var material = crt_canvas_layer.material as ShaderMaterial
    material.set_shader_parameter("global_intensity", intensity_by_season[season_index])
    material.set_shader_parameter("scanline_opacity", scanline_by_season[season_index])
    # ... etc.
```

---

## Considérations performance

### Coûts GPU par effet

| Effet | Coût | Mobile | Notes |
|-------|------|--------|-------|
| **Curvature** | Très léger | ✓ | 1 distance, 1 multiply |
| **Scanlines** | Léger | ✓ | Sin, pow, multiply |
| **Dithering** | Léger | ✓ | Lookup table Bayer (16 floats) |
| **Phosphor glow** | Léger | ✓ | Dot + smoothstep |
| **Vignette** | Très léger | ✓ | Smoothstep |
| **Flicker** | Léger | ✓ | 1 random par frame (temporal) |
| **Noise** | Modéré | ~ | Random haute fréquence |
| **Chromatic aberration** | Modéré | ~ | 3 texture samples + falloff |
| **Scanline wobble** | Modéré | ~ | 2 sin oscillations |
| **Glitch** | Modéré | ~ | Hash + conditionnelle |
| **Color shifting** | Léger | ✓ | 2 sin, 2 cos |

### Optimisations recommandées

#### Mobile (GPU limité)
```gdscript
# Shader réduit
global_intensity = 0.3
curvature = 0.02            # Courbure légère seulement
scanline_opacity = 0.08     # Scanlines minimales
chromatic_enabled = false   # Désactiver
scanline_enabled = false    # Désactiver wobble
glitch_enabled = false      # Désactiver glitch
noise_intensity = 0.004     # Minimal
color_levels = 16.0         # Palette étendue (moins dithering)
dither_strength = 0.1       # Dithering minimal
```
**Résultat**: CRT reconnaissable, ~20% coût GPU réduction

#### Desktop (GPU puissant)
```gdscript
# Configuration full (défaut)
# Tous les effets à 100%
```

#### VR / Performance-critical
```gdscript
# Tous les bool à false sauf scanline_enabled
# Réduire toutes les intensités de moitié
global_intensity = 0.2
noise_intensity = 0.003
flicker_intensity = 0.001
```

### Profilage Godot

```gdscript
# Dans MerlinGameUI.gd
func _process(_delta):
    if Input.is_action_just_pressed("ui_debug"):
        var perf = Performance.get_monitor(Performance.TIME_GPU_VERTEX)
        var pixel = Performance.get_monitor(Performance.TIME_GPU_FRAGMENT)
        print("GPU vertex: %.2f ms, fragment: %.2f ms" % [perf, pixel])
```

---

## Utilisation et bonnes pratiques

### Connexion à la scène

#### Option 1: CanvasLayer post-process (recommandé)

```gdscript
# Dans MerlinGameUI._ready()
var crt_layer = CanvasLayer.new()
crt_layer.layer = 100  # Au-dessus de tout
crt_layer.name = "CRTLayer"

var color_rect = ColorRect.new()
color_rect.anchor_left = 0.0
color_rect.anchor_top = 0.0
color_rect.anchor_right = 1.0
color_rect.anchor_bottom = 1.0
color_rect.material = ShaderMaterial.new()
color_rect.material.shader = load("res://shaders/crt_terminal.gdshader")
color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

crt_layer.add_child(color_rect)
add_child(crt_layer)

# Garder une référence
crt_material = color_rect.material
```

#### Option 2: Node2D avec CanvasItem shader

```gdscript
# Créer une scène dédiée CRTOverlay
extends CanvasLayer

@onready var rect = ColorRect.new()

func _ready():
    layer = 100
    name = "CRTLayer"

    rect.anchor_left = 0.0
    rect.anchor_right = 1.0
    rect.anchor_top = 0.0
    rect.anchor_bottom = 1.0
    rect.material = preload("res://materials/crt_terminal.tres")  # Material resource
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

    add_child(rect)
```

### Contrôle dynamique des paramètres

```gdscript
# ScreenEffects.gd (Controller centralisé)
extends Node

@onready var crt_material: ShaderMaterial = ...

func set_crt_intensity(value: float) -> void:
    crt_material.set_shader_parameter("global_intensity", clamp(value, 0.0, 1.0))

func set_phosphor_tint(color: Color) -> void:
    crt_material.set_shader_parameter("phosphor_tint", color)

func set_scanline_opacity(value: float) -> void:
    crt_material.set_shader_parameter("scanline_opacity", clamp(value, 0.0, 1.0))

# Transition lisse
func fade_to_intensity(target: float, duration: float) -> void:
    var tween = create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_method(set_crt_intensity, crt_material.get_shader_parameter("global_intensity"), target, duration)

# Activation/désactivation complète
func enable_crt(enable: bool) -> void:
    set_crt_intensity(0.4 if enable else 0.0)

# Par biome
func apply_biome_tint(biome: String) -> void:
    var tints = {
        "forest": Color(0.2, 1.0, 0.4),      # Vert
        "desert": Color(1.0, 0.75, 0.2),     # Ambre
        "mystic": Color(0.3, 0.85, 0.8),     # Cyan
    }
    if biome in tints:
        set_phosphor_tint(tints[biome])
```

### Intégration avec MerlinStore

```gdscript
# ScreenEffects._ready()
MerlinStore.mood_changed.connect(_on_mood_changed)
MerlinStore.biome_entered.connect(_on_biome_entered)
MerlinStore.season_changed.connect(_on_season_changed)

func _on_mood_changed(new_mood: String) -> void:
    # MOOD_CALM → CRT intensity ↓
    # MOOD_TENSE → CRT intensity ↑ + glitch ↑
    var intensity_map = {
        "calm": 0.2,
        "normal": 0.4,
        "tense": 0.6,
        "crisis": 0.9,
    }
    fade_to_intensity(intensity_map.get(new_mood, 0.4), 1.5)

func _on_biome_entered(biome_name: String) -> void:
    apply_biome_tint(biome_name)

func _on_season_changed(season: int) -> void:
    # season: 0=spring, 1=summer, 2=autumn, 3=winter
    var seasonal_params = [
        {"intensity": 0.5, "scanline": 0.10, "levels": 12.0},
        {"intensity": 0.6, "scanline": 0.08, "levels": 16.0},
        {"intensity": 0.35, "scanline": 0.15, "levels": 10.0},
        {"intensity": 0.2, "scanline": 0.25, "levels": 4.0},
    ]
    var params = seasonal_params[season]
    crt_material.set_shader_parameter("global_intensity", params["intensity"])
    crt_material.set_shader_parameter("scanline_opacity", params["scanline"])
    crt_material.set_shader_parameter("color_levels", params["levels"])
```

### Interaction avec la narration

```gdscript
# LLMAdapter.gd (rapport moods narratifs ↔ CRT visuals)
func on_card_revealed(card_data: Dictionary) -> void:
    var mood_by_realm = {
        "realm_fear": "tense",
        "realm_peace": "calm",
        "realm_mystery": "normal",
        "realm_chaos": "crisis",
    }
    var mood = mood_by_realm.get(card_data.get("realm"), "normal")
    ScreenEffects.transition_mood(mood)
```

### Optimisation pour biomes spécifiques

#### Marais (vert sombre)
```gdscript
phosphor_tint = Color(0.15, 0.85, 0.30)
tint_blend = 0.08
scanline_opacity = 0.15
noise_intensity = 0.025  # Brume
phosphor_glow = 0.05
```

#### Montagne (ambre/ocre)
```gdscript
phosphor_tint = Color(1.0, 0.7, 0.2)
tint_blend = 0.07
scanline_opacity = 0.10
noise_intensity = 0.012  # Vent
phosphor_glow = 0.04
```

#### Îles mystiques (cyan)
```gdscript
phosphor_tint = Color(0.35, 0.9, 0.85)
tint_blend = 0.10
chromatic_intensity = 0.0015  # Aberration accrue
scanline_wobble_intensity = 0.0008  # Wobble mystique
glitch_probability = 0.02  # Magie = instabilité
```

---

## Troubleshooting

### Problème: Banding visible (dégradés trop nets)

**Symptômes**: Visible dans les arrière-plans ou zones de gradient

**Solutions**:
1. Augmenter `dither_strength` (0.3 → 0.6)
2. Réduire `color_levels` (8.0 → 5.0)
3. Ajouter `noise_intensity` (0.010 → 0.025)

**Code**:
```gdscript
crt_material.set_shader_parameter("dither_strength", 0.6)
crt_material.set_shader_parameter("color_levels", 5.0)
crt_material.set_shader_parameter("noise_intensity", 0.025)
```

---

### Problème: Écran complètement noir ou blanc

**Symptômes**: Image disparue après activation du shader

**Causes possibles**:
- `global_intensity` = 0.0 (réduit progressivement)
- `color_levels` = 1.0 (quantification extrême)
- `crt_material` non bindé à la scène

**Solutions**:
```gdscript
# Vérifier les valeurs par défaut
assert(crt_material.get_shader_parameter("global_intensity") > 0.001)
assert(crt_material.get_shader_parameter("color_levels") >= 2.0)

# Réinitialiser
crt_material.set_shader_parameter("global_intensity", 0.4)
crt_material.set_shader_parameter("color_levels", 8.0)
```

---

### Problème: Scintillement (flicker) trop fort

**Symptômes**: Écran palpite à chaque frame, induisant nausée

**Solutions**:
1. Réduire `flicker_intensity` (0.003 → 0.0005)
2. Réduire `flicker_speed` (12.0 → 5.0)
3. Désactiver complètement: `flicker_enabled = false`

```gdscript
crt_material.set_shader_parameter("flicker_intensity", 0.0005)
crt_material.set_shader_parameter("flicker_speed", 5.0)
# Ou:
# (Ajouter bool uniform) flicker_enabled = false
```

---

### Problème: Glitches/wobbles pas visibles

**Symptômes**: Les glitches ne sont jamais observés malgré `glitch_probability` élevée

**Cause**: `global_intensity` très bas (~0.001) atténue les effets

**Solution**:
```gdscript
# Vérifier global_intensity
var intensity = crt_material.get_shader_parameter("global_intensity")
print("CRT intensity: %.2f" % intensity)

# Si < 0.1, augmenter
if intensity < 0.1:
    crt_material.set_shader_parameter("global_intensity", 0.4)

# Tester individuellement (pour debug)
crt_material.set_shader_parameter("glitch_probability", 0.3)  # Max
# Observer les glitches; ajuster ensuite
```

---

### Problème: Coloration incorrect (teinte wrong)

**Symptômes**: Phosphor tint n'affecte pas (ou trop fort)

**Vérifier**:
```gdscript
var tint = crt_material.get_shader_parameter("phosphor_tint")
var blend = crt_material.get_shader_parameter("tint_blend")
print("Tint: %s, Blend: %.3f" % [tint, blend])

# Tint ignorée si blend = 0.0
if blend < 0.001:
    crt_material.set_shader_parameter("tint_blend", 0.05)

# Tint trop forte si blend > 0.2
if blend > 0.2:
    crt_material.set_shader_parameter("tint_blend", 0.08)
```

---

### Problème: Courbure CRT invisible

**Symptômes**: Malgré `curvature = 0.15`, écran reste plat

**Cause**: `global_intensity` < 0.001 désactive la distortion

**Solution**:
```gdscript
crt_material.set_shader_parameter("global_intensity", 0.4)
crt_material.set_shader_parameter("curvature", 0.10)

# Tester avec barrel_enabled = true aussi
crt_material.set_shader_parameter("barrel_enabled", true)
crt_material.set_shader_parameter("barrel_intensity", 0.005)
```

---

### Problème: Performance dégradée (FPS drop)

**Symptômes**: 60 FPS → 45 FPS après activation CRT

**Analyse**:
```gdscript
# Désactiver les effets coûteux individuellement
crt_material.set_shader_parameter("chromatic_enabled", false)      # Coûteux
crt_material.set_shader_parameter("scanline_enabled", false)       # Coûteux
crt_material.set_shader_parameter("glitch_enabled", false)         # Coûteux
crt_material.set_shader_parameter("noise_enabled", false)          # Modéré
crt_material.set_shader_parameter("global_intensity", 0.2)         # Réduit l'ensemble

# Réduire `color_levels` si dithering est coûteux
crt_material.set_shader_parameter("color_levels", 16.0)  # Moins de dithering
```

**Résultat optimisé**: Courbure + scanlines + teinte seules (~5% coût)

---

### Problème: Artefacts de clamping aux bords (noir abrupt)

**Symptômes**: Cadre noir autour de l'écran après courbure

**Cause**: UV distortion push les bords hors-bounds [0,1]

**C'est normal** et intentionnel (encadrement CRT). Si c'est trop:
```gdscript
crt_material.set_shader_parameter("curvature", 0.01)  # Réduire courbure
crt_material.set_shader_parameter("barrel_enabled", false)
```

---

### Problème: Scanlines trop épaisses

**Symptômes**: Les raies bloquent la lisibilité

**Solution**:
```gdscript
# Augmenter le count (raies plus serrées, donc moins visibles chacune)
crt_material.set_shader_parameter("scanline_count", 800.0)

# Réduire opacity
crt_material.set_shader_parameter("scanline_opacity", 0.05)
```

---

### Problème: Aberration chromatique non visible

**Symptômes**: `chromatic_intensity = 0.01` mais pas de séparation RGB

**Cause**: Falloff exponentiel — l'effet est concentré aux **extrêmes bords**

**Solution**:
```gdscript
# Tester au coin (shift+tilt caméra pour voir les bords)
# Ou augmenter chromatic_falloff pour plus de centre-spread
crt_material.set_shader_parameter("chromatic_falloff", 1.5)  # Réduit falloff

# Augmenter intensity
crt_material.set_shader_parameter("chromatic_intensity", 0.003)
```

---

## Feuille de route future

### Possible améliorations

1. **Plasma effet** — Boule plasma tournante en fond (mode "système corrompu")
2. **Analog VHS tape** — Asynchrone wobble (simule déroulement cassette)
3. **Retrace bloom** — Glow excessif en fin de scanline (effet beam retrace rare)
4. **RGB split persistant** — Accumulation de glitches (corruption mémoire VRAM)
5. **Ambient occlusion du CRT** — Coins physiques ombragés (shadowing 3D)
6. **Burn-in effect** — Images résiduelles persistantes (phosphore fatigué)
7. **Curvature dynamic** — Courbure qui change avec l'intensité (thermal expansion)

---

## Références et crédits

- **GodotShaders.com** — Base CRT et screen distortion
- **CRT aesthetic in games** — Articles David Holz, Shaders tutorial
- **Phosphor colors** — VT100 terminal specs (Green: RGB 0,255,102; Amber: RGB 255,192,0)
- **Bayer dithering** — Standard ordered dithering matrix (4×4)

---

**Version**: 2.0 (2026-03-15)
**Statut**: Production ready
**Maintenance**: Claude Code, Documentation Specialist
