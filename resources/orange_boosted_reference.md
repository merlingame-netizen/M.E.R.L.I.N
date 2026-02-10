# Orange Boosted Bootstrap — Reference Design

> **SCOPE**: Projets Data / Orange UNIQUEMENT. Ne pas appliquer a M.E.R.L.I.N. (Godot) ni Cours.
> **Source**: [Orange-OpenSource/Orange-Boosted-Bootstrap](https://github.com/Orange-OpenSource/Orange-Boosted-Bootstrap) v5.3.8
> **Doc**: https://boosted.orange.com/
> **Memoire agent**: `memory/orange_data_branding.md` (reference complete pour Claude Code)

---

## CDN Links (copier-coller)

```html
<!-- Helvetica Neue (obligatoire) -->
<link href="https://cdn.jsdelivr.net/npm/boosted@5.3.8/dist/css/orange-helvetica.min.css" rel="stylesheet">

<!-- Boosted CSS -->
<link href="https://cdn.jsdelivr.net/npm/boosted@5.3.8/dist/css/boosted.min.css" rel="stylesheet">

<!-- Boosted JS Bundle -->
<script src="https://cdn.jsdelivr.net/npm/boosted@5.3.8/dist/js/boosted.bundle.min.js"></script>
```

**NPM** : `npm install boosted@5.3.8`

---

## Palette Couleurs ODS (Orange Design System)

### Couleurs principales (PPT + HTML)

| Nom | Hex | RGB | Usage |
|-----|-----|-----|-------|
| **Orange primaire** | `#FF7900` | 255, 121, 0 | Accent principal, boutons, liens |
| **Orange secondaire** | `#F16E00` | 241, 110, 0 | Hover, focus |
| **Noir** | `#000000` | 0, 0, 0 | Texte principal (light mode) |
| **Blanc** | `#FFFFFF` | 255, 255, 255 | Texte principal (dark mode) |

### Gris ODS

| Hex | RGB | Variable | Usage PPT |
|-----|-----|----------|-----------|
| `#EEEEEE` | 238, 238, 238 | gray-200 | Fond clair |
| `#DDDDDD` | 221, 221, 221 | gray-300 | Separateurs |
| `#CCCCCC` | 204, 204, 204 | gray-400 | Bordures legeres |
| `#999999` | 153, 153, 153 | gray-500 | Texte secondaire |
| `#666666` | 102, 102, 102 | gray-600 | Texte moyen |
| `#595959` | 89, 89, 89 | gray-700 | Texte fonce |
| `#333333` | 51, 51, 51 | gray-800 | Titres sur clair |
| `#141414` | 20, 20, 20 | gray-900 | Fond dark mode |

### Couleurs secondaires (max 20% de surface)

#### Bleu
| Nuance | Hex | RGB |
|--------|-----|-----|
| 100 | `#B5E8F7` | 181, 232, 247 |
| 200 | `#80CEEF` | 128, 206, 239 |
| **300** | **`#4BB4E6`** | 75, 180, 230 |
| 400 | `#3E9DD6` | 62, 157, 214 |
| 500 | `#237ECA` | 35, 126, 202 |
| 600 | `#085EBD` | 8, 94, 189 |

#### Vert
| Nuance | Hex | RGB |
|--------|-----|-----|
| 100 | `#B8EBD6` | 184, 235, 214 |
| 200 | `#84D5AF` | 132, 213, 175 |
| **300** | **`#50BE87`** | 80, 190, 135 |
| 400 | `#27A971` | 39, 169, 113 |
| 500 | `#198C51` | 25, 140, 81 |
| 600 | `#0A6E31` | 10, 110, 49 |

#### Rose
| Nuance | Hex | RGB |
|--------|-----|-----|
| 100 | `#FFE8F7` | 255, 232, 247 |
| 200 | `#FFCEEF` | 255, 206, 239 |
| **300** | **`#FFB4E6`** | 255, 180, 230 |
| 400 | `#FF8AD4` | 255, 138, 212 |
| 500 | `#D573BB` | 213, 115, 187 |
| 600 | `#BC4D9A` | 188, 77, 154 |

#### Pourpre
| Nuance | Hex | RGB |
|--------|-----|-----|
| 100 | `#D9C2F0` | 217, 194, 240 |
| 200 | `#C1A4E4` | 193, 164, 228 |
| **300** | **`#A885D8`** | 168, 133, 216 |
| 400 | `#9373BD` | 147, 115, 189 |
| 500 | `#6E4AA7` | 110, 74, 167 |
| 600 | `#492191` | 73, 33, 145 |

#### Jaune
| Nuance | Hex | RGB |
|--------|-----|-----|
| 100 | `#FFF6B6` | 255, 246, 182 |
| 200 | `#FFE45B` | 255, 228, 91 |
| **300** | **`#FFD200`** | 255, 210, 0 |
| 400 | `#FFB400` | 255, 180, 0 |
| 500 | `#B98F11` | 185, 143, 17 |
| 600 | `#9D6E06` | 157, 110, 6 |

> **Regle 80/20** : 80% couleurs principales, 20% max secondaires.
> Les nuances **300** sont les valeurs de reference de la charte.

### Couleurs fonctionnelles

| Usage | Light mode | Dark mode | Icone PPT |
|-------|-----------|-----------|-----------|
| **Success** | `#228722` | `#66CC66` | Coche verte |
| **Info** | `#4170D8` | `#6699FF` | Info bleue |
| **Warning** | `#FFCC00` | `#FFCC00` | Triangle jaune |
| **Danger** | `#CD3C14` | `#FF4D4D` | Croix rouge |

---

## Typographie

| Usage | Police | Weight | Taille |
|-------|--------|--------|--------|
| Titres H1 | Helvetica Neue 75 Bold | 700 | 34px (2.125rem) |
| Titres H2 | Helvetica Neue 75 Bold | 700 | 30px (1.875rem) |
| Titres H3 | Helvetica Neue 75 Bold | 700 | 24px (1.5rem) |
| Corps | Helvetica Neue 55 Roman | 400 | 16px (1rem) |
| Small | Helvetica Neue 55 Roman | 400 | 14px (0.875rem) |
| Labels/Boutons | Helvetica Neue 75 Bold | 700 | 16px |

- **Interlignage** : 1.125 (18px pour corps 16px)
- **Interlettrage** : -0.005rem (-0.1px)
- **Jamais** de majuscules completes
- **Jamais** d'italique
- Fallback : `Arial, sans-serif`

---

## Spacing (base 20px)

| Token | Valeur | Pixels |
|-------|--------|--------|
| 1 | 0.3125rem | 5px |
| 2 | 0.625rem | 10px |
| 3 | 1.25rem | **20px** (base) |
| 4 | 1.875rem | 30px |
| 5 | 3.75rem | 60px |

---

## Breakpoints

| Nom | Min-width | Container max | Classe |
|-----|-----------|---------------|--------|
| xs | 0 | 312px | `.col-` |
| sm | 480px | 468px | `.col-sm-` |
| md | 768px | 744px | `.col-md-` |
| lg | 1024px | 960px | `.col-lg-` |
| xl | 1280px | 1200px | `.col-xl-` |
| xxl | 1440px | 1320px | `.col-xxl-` |

---

## Composants Orange (specifiques, pas dans Bootstrap)

| Composant | Classe | Usage |
|-----------|--------|-------|
| Orange Navbar | `.navbar` + logo SVG | Barre de navigation brandee |
| Footer | `.footer` | Pied de page officiel |
| Local Navigation | `.local-nav` | Navigation secondaire |
| Title Bars | `.title-bar` | En-tete de page |
| Tags | `.tag` | Etiquettes filtrables |
| Stickers | `.sticker` | Marqueurs visuels |
| Stepped Process | `.stepped-process` | Indicateur d'etapes |
| Back to Top | `.back-to-top` | Retour en haut |
| Quantity Selector | `.quantity-selector` | +/- numerique |

---

## Dark Mode (eco-branding)

```html
<!-- Global dark mode (recommande pour ecrans) -->
<html data-bs-theme="dark">

<!-- Composant specifique en light -->
<div data-bs-theme="light">...</div>
```

- Fond dark : `#141414` (gray-900)
- Texte dark : `#FFFFFF`
- Economie : ~60% energie ecran OLED

---

## Pour les PPT (correspondance pptxgenjs)

```javascript
// Couleurs pour pptxgenjs
const ORANGE_BOOSTED = {
  // Principales
  orange:    'FF7900',
  black:     '000000',
  white:     'FFFFFF',

  // Gris
  gray200:   'EEEEEE',
  gray500:   '999999',
  gray700:   '595959',
  gray800:   '333333',
  gray900:   '141414',

  // Secondaires (nuance 300 = reference)
  blue:      '4BB4E6',
  green:     '50BE87',
  pink:      'FFB4E6',
  purple:    'A885D8',
  yellow:    'FFD200',

  // Fonctionnelles
  success:   '228722',
  info:      '4170D8',
  warning:   'FFCC00',
  danger:    'CD3C14',
};
```

---

## Template HTML

Fichier pret a l'emploi : [`orange_boosted_template.html`](orange_boosted_template.html)

Contient :
- Navbar Orange avec logo SVG
- Title bar
- Cards KPI (4 colonnes responsive)
- Tableau de donnees avec pagination
- Formulaire complet
- Stepped Process (composant Orange)
- Footer Orange
- Dark mode actif (eco-branding)

---

## Ressources externes

| Ressource | URL |
|-----------|-----|
| Documentation Boosted | https://boosted.orange.com/ |
| Repo GitHub | https://github.com/Orange-OpenSource/Orange-Boosted-Bootstrap |
| Icones Solaris | https://oran.ge/icons |
| Orange Design System | https://system.design.orange.com/ |
| OUDS Web | https://web.unified-design-system.orange.com/ |
| NPM Package | https://www.npmjs.com/package/boosted |
| Exemples interactifs | https://boosted.orange.com/docs/5.3/examples/ |
