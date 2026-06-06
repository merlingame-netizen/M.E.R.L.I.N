---
name: ui-ux-pro-max
description: >-
  Max pack pour produire des sites web très animés ET optimisés, tous projets.
  Orchestre le workflow conception → génération (21st.dev/Magic) → animation
  (React + Framer Motion) → optimisation (Core Web Vitals). Use this skill when
  the user wants an animated landing page, hero section, micro-interactions,
  scroll-driven effects, page transitions, or any "production-grade" animated
  web UI. Pulls from a ready-to-copy Framer Motion preset library.
---

# UI UX Pro Max — Skill

Tu produis des interfaces web **mémorables, fluides (60fps), et légères**.
Moteur : **Framer Motion** (`motion/react`). Accélérateur : **21st.dev (Magic)**.
Garde-fou : **Core Web Vitals**. Agent de référence :
`.claude/agents/ui-ux-pro-max.md` (lis-le pour les règles détaillées).

Cette skill est **agnostique projet** — elle ne suppose aucun contexte
MERLIN/Godot. Si le projet hôte impose un design system, il prime.

## Quand l'utiliser

Landing pages, hero sections, micro-interactions, transitions de page,
scroll-reveal/parallax, boutons magnétiques, listes en stagger, shared-element
transitions — dès qu'il faut « du mouvement qui claque sans plomber les perfs ».

## Workflow (6 étapes)

1. **Cadrer** — objectif, audience, direction esthétique (assume un parti pris,
   évite l'« AI slop » → appuie-toi sur la skill `frontend-design`), contraintes
   du framework hôte.
2. **Concevoir le mouvement** — liste les moments d'animation : entrée
   above-the-fold, reveals au scroll, gestures (hover/tap/drag), transitions de
   page. Définis la hiérarchie (quoi bouge, pourquoi, dans quel ordre).
3. **Accélérer avec 21st.dev** — génère les squelettes de composants :
   ```bash
   python tools/cli.py magic component-builder --query "<description riche du composant>"
   python tools/cli.py magic logo-search --query "<marque>"
   ```
   (ou le MCP natif `mcp__magic__*` s'il est chargé dans la session).
   **Audite** ensuite le résultat : sémantique HTML, cibles ≥44px, contraste,
   retrait du bloat.
4. **Animer** — réutilise les presets de `patterns/framer-motion-presets.tsx`
   (variants, springs, scroll, AnimatePresence, gestures, page transitions).
   Variants centralisés ; springs pour le tactile, durées pour le décoratif.
5. **Optimiser (pilier central)** — passe la checklist :
   - transform/opacity uniquement sur le chemin animé ;
   - `will-change` posé puis retiré ; pas d'animation hors-écran (`useInView`) ;
   - `LazyMotion`+`domAnimation`, `m.*` pour le tree-shaking ;
   - pas de `useState` par frame → `useMotionValue`/`useMotionTemplate` ;
   - LCP < 2.5s (hero non dépendant du JS), CLS < 0.1 (dimensions réservées),
     INP < 200ms ;
   - `prefers-reduced-motion` respecté (`useReducedMotion` /
     `MotionConfig reducedMotion="user"`).
6. **Vérifier & livrer** — build, mesure perf si dispo, test reduced-motion,
   test clavier/focus, test mobile. Documente les variants/tokens réutilisables.

## Garde-fous (gates)

- Un effet qui coûte des fps est retravaillé en GPU-friendly **ou supprimé**.
- `prefers-reduced-motion` n'est jamais optionnel.
- Un composant 21st.dev non audité n'est pas livrable.
- Le hero ne doit jamais attendre une animation JS pour s'afficher (LCP).

## Ressources

- `patterns/framer-motion-presets.tsx` — bibliothèque copier-coller.
- `patterns/PATTERNS.md` — index des presets + quand les utiliser.
- Agent détaillé : `.claude/agents/ui-ux-pro-max.md`.
