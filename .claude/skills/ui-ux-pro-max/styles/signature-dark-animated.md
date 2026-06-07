# Signature Style — « Dark Animated » (défaut apps HTML hors Orange)

> **Préférence utilisateur enregistrée (2026-06-07).** Pour toute **app / site
> HTML autonome** demandé par l'utilisateur **hors contexte Orange**, c'est le
> style par défaut, sauf demande contraire explicite. Sur projets **Orange**,
> appliquer la charte Orange à la place.

C'est le style des démos `demos/aurora/` (référence) et `demos/idrac/`
(déclinaison chartée). « Beau ET rapide », mouvement omniprésent mais au service
de la lecture.

## ADN visuel

- **Fond sombre profond** (`#05060a`–`#0a0a12`) + vignette radiale douce + grain léger.
- **Accent bi-couleur en dégradé** (2-3 teintes vives) décliné sur : titres
  (`background-clip:text`), CTA, glows, blobs. Adapter les teintes à la **charte
  du client** (ex. IDRAC = rouge `#A71F28` + or `#f5b731`).
- **Typo** : sans-serif géométrique grasse pour les titres (Inter/Montserrat,
  800-900, `letter-spacing:-.03em`), mono pour les accents techniques (Space Mono).
- **Cartes verre** (`rgba` + bordure subtile, `border-radius:16-22px`).
- **Hiérarchie** : hero plein écran → preuve/chiffres → grille de features → CTA.

## Animations embarquées (le « max pack » signature)

Toujours via **React + Framer Motion** (`motion/react`), presets dans
`../patterns/framer-motion-presets.tsx`. Empiler généreusement :

1. **Entrée en stagger** (parent `staggerChildren` → enfants `fadeInUp` spring).
2. **Titre dégradé animé** (`background-position` en boucle) + option **lettre
   par lettre** (split spans, stagger).
3. **CTA magnétiques** (`useMotionValue` suit le curseur, 0 re-render).
4. **Cartes tilt 3D** (`rotateX/rotateY` perspective, glare overlay) au survol.
5. **Spotlight** suivant le curseur (`useMotionTemplate` radial-gradient).
6. **Compteurs** animés au scroll (`animate()` + `useInView`).
7. **Parallax** de blobs/éléments déco (scroll lié, lissé `useSpring`).
8. **Barre de progression** de lecture en haut.
9. **Fond canvas** (constellation/particules) léger en rAF — pausé si onglet caché.
10. **Modal `AnimatePresence`** (entrée spring, sortie ~0.6× plus rapide).
11. **Scroll-reveal** one-shot (`useInView once:true`).

## Garde-fous NON-négociables (pilier perf central)

- `transform` + `opacity` **uniquement** sur le chemin animé (GPU).
- **`prefers-reduced-motion`** respecté partout (`<MotionConfig reducedMotion="user">`
  + `useReducedMotion()` pour couper parallax/canvas/tilt).
- Canvas : `requestAnimationFrame` pausé via `visibilitychange` ; densité de
  particules plafonnée ; pas d'anim hors-écran.
- LCP : le hero s'affiche sans dépendre du JS si possible (texte critique en SSR/
  HTML statique) ; CLS verrouillé (dimensions réservées).
- Cibles tactiles ≥ 44-48px, focus visible.

## Livraison

- **Fichier unique `.html` autonome** par défaut (React + Framer Motion via ESM
  CDN esm.sh, zéro build) — ouvrable directement. Proposer une version Vite/Next
  buildée si l'utilisateur veut déployer.
- Toujours **vérifier le rendu réel** (screenshot headless) avant de livrer.
- **Aucune perte de contenu** lors d'une refonte : extraire le contenu source
  verbatim (texte, labels, liens, sections, ordre) avant de re-styliser.
