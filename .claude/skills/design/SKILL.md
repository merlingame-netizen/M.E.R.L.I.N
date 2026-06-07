---
name: design
description: >-
  MÉGA-SKILL design applicatif — l'outillage ultime pour concevoir et coder des
  interfaces (web/app) distinctives, hyper-animées ET optimisées, sur TOUS les
  projets. Réunit : direction esthétique (anti « AI slop »), moteur d'animation
  React + Framer Motion + bibliothèque de presets, génération de composants
  21st.dev (Magic), performance (Core Web Vitals) en pilier central,
  accessibilité, design tokens, et un registre de branding (Orange reste brandé,
  IDRAC charté, sinon style signature). Use this skill for ANY design /
  UI / UX / frontend / animation / landing / component / design-system work.
  Trigger words: design, UI, UX, frontend, interface, écran, composant, landing,
  animation, micro-interaction, motion, charte, design system, maquette, site,
  app, branding, accessibilité, responsive.
---

# /design — Méga-skill design applicatif

> Tu es **l'atelier design ultime**. Ta signature : des interfaces
> **mémorables, fluides (60fps), légères et accessibles**. Tu ne choisis jamais
> entre « beau/animé » et « rapide » : les deux, toujours. Et tu **respectes la
> marque** du contexte avant tout.

Ce skill est **agnostique projet** — il s'applique à une landing, un dashboard,
une app, un portfolio, l'export web d'un jeu, un design system. Il absorbe
`ui-ux-pro-max` et `frontend-design`.

---

## ⚠️ ÉTAPE 0 — CHARTE / BRANDING (toujours en premier)

**Avant toute décision visuelle**, déterminer la charte via
`branding/BRANDS.md`. Résumé de l'algorithme :

1. **Projet ORANGE** (ou marque Orange demandée) → **charte Orange obligatoire**
   (Boosted : `#FF7900`, Helvetica/Arial, fond clair, animations **sobres**).
   Le « max pack » d'animations est **bridé** : marque > effet.
2. **Client connu** (IDRAC = rouge `#A71F28`+or, …) → **sa** charte réelle.
3. **Design system hôte** imposé → il prime.
4. **Sinon** (HTML autonome hors Orange) → style signature « Dark Animated »
   (`styles/signature-dark-animated.md`), teintes adaptées au sujet.

En cas de doute sur le contexte de marque → **AskUserQuestion**, ne pas supposer.

---

## LES 4 PILIERS (NON-NÉGOCIABLES)

Tout livrable est jugé sur 4 piliers, dans cet ordre :

1. **PERFORMANT** *(pilier central)* — 60fps stable, LCP < 2.5s, CLS < 0.1,
   INP < 200ms. Aucune animation sur le chemin critique ne déclenche layout/paint.
   Un effet qui coûte des fps est retravaillé GPU-friendly **ou supprimé**.
2. **ÉVIDENT** — intention de chaque interaction lisible en < 2s sans tuto.
   L'animation **guide** l'œil, ne le distrait pas.
3. **TACTILE & ACCESSIBLE** — cibles ≥ 44×44px, retour visuel ≤ 100ms, jamais
   d'action « hover-only » critique, `prefers-reduced-motion` respecté, focus
   visible, ARIA correct, contraste WCAG AA.
4. **MÉMORABLE** — direction esthétique forte et assumée. Pas d'« AI slop ».

---

## 1. DIRECTION ESTHÉTIQUE (avant de coder)

Choisir un parti pris **clair et fort** (intentionnalité > intensité) :
- **Purpose** : quel problème ? quel public ?
- **Ton** : un extrême assumé — minimal brutal, maximaliste, rétro-futuriste,
  organique, luxe/raffiné, éditorial/magazine, brutaliste, art déco, pastel,
  industriel… (dans le respect de la charte de l'étape 0).
- **Différenciation** : la *seule* chose qu'on retiendra ?
- Éviter le générique : pas de « carte grise + ombre douce + dégradé violet »
  par défaut. Couleur, typo, layout et micro-détails portent une intention.

(Hérité de la skill `frontend-design` : viser le « production-grade distinctif ».)

---

## 2. MOTEUR D'ANIMATION — React + Framer Motion

- Package **`motion`** (import `motion/react`) : `motion.*`, `AnimatePresence`,
  `useScroll`, `useTransform`, `useSpring`, `useMotionValue`, `useMotionTemplate`,
  `useInView`, `useReducedMotion`, `LayoutGroup`, `layout`/`layoutId`,
  `MotionConfig`, `LazyMotion`.
- **Presets prêts à copier** : `patterns/framer-motion-presets.tsx` + index
  `patterns/PATTERNS.md`. Empiler généreusement (hors Orange) :
  fadeInUp/stagger, springs, scroll-reveal, parallax lissé, gestures, bouton
  magnétique, tilt 3D, spotlight, shared-element (`layoutId`), page transitions,
  AnimatePresence, scroll-progress, compteurs, titre lettre-par-lettre,
  constellation canvas.
- **Règles de l'art** :
  - Animer **uniquement** `transform` + `opacity` (compositées GPU). Bannir
    `width/height/top/left/margin/box-shadow` animés.
  - Springs pour le **tactile** (réagit à la vélocité) ; `duration`+`ease` pour
    le **décoratif**. `whileTap` obligatoire sur tout interactif.
  - Variants centralisés + `staggerChildren` (jamais de `setTimeout` manuel).
  - `exit` ~0.6× la durée d'`enter`. `key` stable sous `AnimatePresence`.

> Sur **projets non-React** (sites statiques, export web de jeu) : décliner les
> mêmes principes en **Motion One** / Web Animations API / CSS — transform+opacity,
> springs, reduced-motion. Le savoir-faire prime sur le framework.

---

## 3. ACCÉLÉRATEUR — 21st.dev (Magic)

Génération de composants à partir d'une description :

```bash
python tools/cli.py magic component-builder --query "<description riche>"
python tools/cli.py magic logo-search --query "<marque>"
python tools/cli.py magic inspiration --query "<idée>"
python tools/cli.py magic refiner --query "<amélioration>" --code "<jsx>"
```

(ou le MCP natif `mcp__magic__*` s'il est chargé dans la session.)

**Workflow** : brief direction → `component-builder` (squelette) → **audit**
(sémantique HTML, cibles ≥44px, contraste, retrait du bloat) → **animer** avec
les presets → **optimiser** → vérifier. Un composant Magic non audité n'est pas
livrable.

---

## 4. PERFORMANCE — pilier central (checklist gate)

**Animation** : transform/opacity only · `will-change` posé puis retiré (jamais
permanent) · pas d'anim hors-écran (`useInView`/IO) · `LazyMotion`+`domAnimation`
+ `m.*` (tree-shaking) · pas de `useState` par frame → `useMotionValue` /
`useMotionTemplate` · `repeat:Infinity` parcimonieux, coupé hors viewport · canvas
en `requestAnimationFrame` pausé sur `visibilitychange`.

**Core Web Vitals** : LCP < 2.5s (l'élément LCP/hero ne dépend pas du JS ; image
`priority` + dimensions) · CLS < 0.1 (dimensions réservées, `aspect-ratio`,
entrées via opacity/translate jamais `height:0`) · INP < 200ms (handlers légers).

**Chargement** : code-split par route + `dynamic()`/`lazy` pour le below-the-fold
lourd · images AVIF/WebP + lazy + `sizes` · fonts `next/font`/`swap`+subset ·
budget JS < ~200KB gzip initial.

---

## 5. ACCESSIBILITÉ (gate)

`prefers-reduced-motion: reduce` respecté partout (`useReducedMotion()` /
`<MotionConfig reducedMotion="user">`) · aucune info portée **uniquement** par
l'animation · pas de flash > 3/s · focus visible · ARIA roles/labels · contraste
AA (4.5:1 texte) · navigation clavier complète · cibles ≥ 44px.

---

## 6. DESIGN TOKENS & SYSTÈME

Centraliser : couleurs (palette + sémantique : bg/ink/muted/accent/functional),
typographie (échelle modulaire, 2 familles max), espacement (échelle 4/8px),
rayons, ombres, durées/easings d'animation, breakpoints. Exposer en variables
CSS (`:root`) ou tokens (Tailwind config / vanilla-extract). Réutiliser, ne pas
hardcoder. Sur Orange → tokens Boosted ; sinon → tokens de la charte choisie.

---

## 7. WORKFLOW

1. **Charte (Étape 0)** — déterminer le branding via `branding/BRANDS.md`.
2. **Cadrer** — objectif, public, contraintes, direction esthétique.
3. **Concevoir le mouvement** — lister les moments d'animation + hiérarchie.
4. **Accélérer (21st.dev)** — squelettes Magic, puis audit.
5. **Implémenter** — Framer Motion + presets + tokens.
6. **Optimiser** — checklists Performance + Accessibilité.
7. **Vérifier** — build, mesure (Lighthouse/Web Vitals), test reduced-motion,
   clavier/focus, mobile (cibles). **Toujours vérifier le rendu réel**
   (screenshot/headless) avant de livrer.
8. **Documenter** — exposer tokens/variants réutilisables ; signaler compromis.

---

## 8. LIVRAISON

- **App/site HTML autonome** demandé → **fichier unique `.html`** par défaut
  (React + Framer Motion via ESM CDN esm.sh, zéro build) — ouvrable directement.
  Proposer une version **Vite/Next buildée** si l'utilisateur veut déployer.
- **Refonte d'un existant** → extraire le contenu source **verbatim** (texte,
  labels, liens, sections, ordre) AVANT de re-styliser. **Aucune perte de
  contenu** : refonte visuelle ≠ réécriture.
- Toujours **montrer le résultat** (screenshot, ou vidéo headless pour les
  animations) puisque l'utilisateur ne voit pas le conteneur distant.

---

## RESSOURCES

| Ressource | Rôle |
|-----------|------|
| `branding/BRANDS.md` | **Étape 0** — charte par contexte (Orange/IDRAC/défaut) |
| `styles/signature-dark-animated.md` | Style par défaut hors Orange |
| `patterns/framer-motion-presets.tsx` | Bibliothèque de presets copier-coller |
| `patterns/PATTERNS.md` | Index « quand utiliser quoi » + règles perf |
| Agent `ui-ux-pro-max` | Sous-agent pour gros chantiers UI (Phase conception) |
| Démos | `demos/aurora/` (signature), `demos/idrac/` (charté) |
| Built-in `frontend-design` | Direction esthétique anti AI-slop (absorbé ici) |

## GARDE-FOUS (gates)

- **Orange = brandé, animations sobres.** Jamais le style sombre/néon sur Orange.
- `prefers-reduced-motion` jamais optionnel.
- transform/opacity only sur le chemin animé.
- Composant 21st.dev non audité = non livrable.
- Refonte = zéro perte de contenu.
- Vérifier le rendu réel avant de dire « terminé ».
