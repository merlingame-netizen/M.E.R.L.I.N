# Framer Motion Presets — Index

Bibliothèque copier-coller : `framer-motion-presets.tsx`.
Package : `motion` (import `motion/react`). Install : `npm i motion`.
Agnostique projet — adapter le styling (Tailwind par défaut).

| # | Preset | Quand l'utiliser | Notes perf |
|---|--------|------------------|------------|
| 0 | `MotionRoot` | Une fois à la racine de l'app | `LazyMotion`+`domAnimation` (bundle réduit) ; `reducedMotion="user"` ; utiliser `<m.*>` |
| 1 | `spring` / `ease` | Vocabulaire de transitions partagé | Springs = tactile ; durées = décoratif |
| 2 | `fadeInUp` / `fadeIn` / `scaleIn` | Entrée d'élément, reveal | Part de `y`/`opacity`, jamais `height:0` (CLS) |
| 3 | `StaggerList` / `staggerParent` | Listes, grilles, menus | Orchestration via `staggerChildren`, pas de `setTimeout` |
| 4 | `ScrollReveal` | Apparition one-shot au scroll | `useInView once:true` — ne ré-anime pas |
| 5 | `Parallax` | Profondeur au scroll | Lissé par `useSpring`, coupé si reduced-motion |
| 6 | `TactileButton` | Tout bouton/CTA | `whileTap` obligatoire (<100ms), cible ≥44px |
| 7 | `MagneticButton` | CTA hero « premium » | `useMotionValue` → 0 re-render React |
| 8 | `Modal` (`AnimatePresence`) | Modal, toast, popover | `key` stable ; `exit` plus rapide que `enter` |
| 9 | `PageTransition` | Transitions de route (Next.js `template.tsx`) | transform+opacity only |
| 10 | `SharedThumb` (`layoutId`) | Shared-element / expand card | FLIP auto ; mesurer sur longues listes |
| 11 | `SpotlightCard` (`useMotionTemplate`) | Effet spotlight/gradient suivi curseur | Variable CSS réactive, pas de RAF JS |
| 12 | `ScrollProgress` | Barre de progression de lecture | `scaleX` sur `scrollYProgress` |

## Règles transverses (pilier perf)

1. **transform + opacity uniquement** sur le chemin animé (GPU). Jamais
   `width/height/top/left/margin/padding`.
2. **`will-change`** posé juste avant l'animation, retiré après — jamais permanent.
3. **Zéro `useState` par frame** → `useMotionValue` / `useMotionTemplate`.
4. **Hors-écran = pas animé** (`useInView` / `IntersectionObserver`).
5. **LCP** : le hero s'affiche sans dépendre du JS. **CLS** : dimensions réservées.
6. **`prefers-reduced-motion`** toujours respecté (`MotionRoot` + `useReducedMotion`).

## Accélérer le markup avec 21st.dev (Magic)

```bash
python tools/cli.py magic component-builder --query "<description riche>"
python tools/cli.py magic logo-search --query "<marque>"
```
Puis **auditer** (sémantique, a11y, cibles tactiles) avant d'animer avec les presets.
