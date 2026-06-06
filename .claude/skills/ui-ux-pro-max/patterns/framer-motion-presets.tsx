/**
 * framer-motion-presets.tsx — UI UX Pro Max
 * --------------------------------------------------------------------------
 * Bibliothèque copier-coller de patterns Framer Motion (motion/react).
 * Principes : animer UNIQUEMENT transform + opacity, springs pour le tactile,
 * prefers-reduced-motion toujours respecté, zéro re-render React par frame.
 *
 * Install : npm i motion        (package "motion", import "motion/react")
 * Agnostique projet — adapter le styling (Tailwind ci-dessous par défaut).
 * --------------------------------------------------------------------------
 */

import {
  motion,
  m,
  AnimatePresence,
  LazyMotion,
  domAnimation,
  MotionConfig,
  useScroll,
  useTransform,
  useSpring,
  useMotionValue,
  useMotionTemplate,
  useInView,
  useReducedMotion,
  type Variants,
} from "motion/react"
import { useRef } from "react"

/* ════════════════════════════════════════════════════════════════════════
 * 0. SETUP — Provider racine (perf + accessibilité par défaut)
 * Enrobe ton app une seule fois. LazyMotion + domAnimation = bundle réduit,
 * et reducedMotion="user" applique prefers-reduced-motion automatiquement.
 * Utilise <m.div> au lieu de <motion.div> sous LazyMotion (tree-shaking).
 * ════════════════════════════════════════════════════════════════════════ */
export function MotionRoot({ children }: { children: React.ReactNode }) {
  return (
    <LazyMotion features={domAnimation} strict>
      <MotionConfig reducedMotion="user">{children}</MotionConfig>
    </LazyMotion>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 1. SPRINGS & EASING — vocabulaire partagé
 * Springs pour les interactions tactiles (réagissent à la vélocité).
 * Durées+ease pour le décoratif autonome.
 * ════════════════════════════════════════════════════════════════════════ */
export const spring = {
  snappy: { type: "spring", stiffness: 400, damping: 30 } as const,
  smooth: { type: "spring", stiffness: 260, damping: 32 } as const,
  gentle: { type: "spring", stiffness: 120, damping: 20 } as const,
  bouncy: { type: "spring", stiffness: 500, damping: 18 } as const,
}
export const ease = {
  out: [0.16, 1, 0.3, 1] as const, // exit fast → settle (entrées)
  inOut: [0.83, 0, 0.17, 1] as const,
}

/* ════════════════════════════════════════════════════════════════════════
 * 2. FADE/SLIDE IN — entrée d'élément (above-the-fold ou reveal)
 * NB : part de y/opacity, JAMAIS de height:0 (sinon CLS).
 * ════════════════════════════════════════════════════════════════════════ */
export const fadeInUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: spring.smooth },
}
export const fadeIn: Variants = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { duration: 0.5, ease: ease.out } },
}
export const scaleIn: Variants = {
  hidden: { opacity: 0, scale: 0.96 },
  show: { opacity: 1, scale: 1, transition: spring.smooth },
}

/* ════════════════════════════════════════════════════════════════════════
 * 3. STAGGER LIST — orchestration parent → enfants (pas de setTimeout manuel)
 * ════════════════════════════════════════════════════════════════════════ */
export const staggerParent: Variants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.06, delayChildren: 0.1 },
  },
}

export function StaggerList({ items }: { items: React.ReactNode[] }) {
  return (
    <m.ul
      variants={staggerParent}
      initial="hidden"
      animate="show"
      className="flex flex-col gap-3"
    >
      {items.map((node, i) => (
        <m.li key={i} variants={fadeInUp}>
          {node}
        </m.li>
      ))}
    </m.ul>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 4. SCROLL REVEAL — apparition one-shot au scroll (useInView, once:true)
 * margin négatif = déclenche un peu avant d'entrer dans le viewport.
 * ════════════════════════════════════════════════════════════════════════ */
export function ScrollReveal({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const inView = useInView(ref, { once: true, margin: "-15% 0px" })
  return (
    <m.div
      ref={ref}
      variants={fadeInUp}
      initial="hidden"
      animate={inView ? "show" : "hidden"}
    >
      {children}
    </m.div>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 5. SCROLL PARALLAX — lié au scroll, LISSÉ par un spring (anti-jank)
 * Couplage 1:1 brut = saccadé ; useSpring l'adoucit. Désactivé si reduced-motion.
 * ════════════════════════════════════════════════════════════════════════ */
export function Parallax({
  children,
  distance = 80,
}: {
  children: React.ReactNode
  distance?: number
}) {
  const ref = useRef<HTMLDivElement>(null)
  const reduce = useReducedMotion()
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start end", "end start"],
  })
  const yRaw = useTransform(scrollYProgress, [0, 1], [distance, -distance])
  const y = useSpring(yRaw, { stiffness: 120, damping: 30, mass: 0.4 })
  return (
    <div ref={ref} className="overflow-hidden">
      <m.div style={reduce ? undefined : { y }}>{children}</m.div>
    </div>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 6. GESTURES — bouton tactile (whileTap obligatoire, retour < 100ms)
 * ════════════════════════════════════════════════════════════════════════ */
export function TactileButton({
  children,
  ...props
}: React.ComponentProps<typeof m.button>) {
  return (
    <m.button
      whileHover={{ scale: 1.03 }}
      whileTap={{ scale: 0.97 }}
      transition={spring.snappy}
      className="min-h-[44px] min-w-[44px] rounded-xl px-5 py-3 font-medium"
      {...props}
    >
      {children}
    </m.button>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 7. BOUTON MAGNÉTIQUE — suit le curseur via useMotionValue (0 re-render React)
 * ════════════════════════════════════════════════════════════════════════ */
export function MagneticButton({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLButtonElement>(null)
  const mx = useMotionValue(0)
  const my = useMotionValue(0)
  const x = useSpring(mx, spring.gentle)
  const y = useSpring(my, spring.gentle)
  const reduce = useReducedMotion()

  function onMove(e: React.MouseEvent) {
    if (reduce || !ref.current) return
    const r = ref.current.getBoundingClientRect()
    mx.set((e.clientX - (r.left + r.width / 2)) * 0.35)
    my.set((e.clientY - (r.top + r.height / 2)) * 0.35)
  }
  function reset() {
    mx.set(0)
    my.set(0)
  }
  return (
    <m.button
      ref={ref}
      onMouseMove={onMove}
      onMouseLeave={reset}
      style={{ x, y }}
      whileTap={{ scale: 0.96 }}
      className="min-h-[44px] rounded-full px-6 py-3 font-semibold"
    >
      {children}
    </m.button>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 8. ANIMATEPRESENCE — montage/démontage propre (modal, toast, route)
 * key stable ; exit plus rapide que enter.
 * ════════════════════════════════════════════════════════════════════════ */
export function Modal({
  open,
  onClose,
  children,
}: {
  open: boolean
  onClose: () => void
  children: React.ReactNode
}) {
  return (
    <AnimatePresence>
      {open && (
        <m.div
          className="fixed inset-0 z-50 grid place-items-center bg-black/50"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0, transition: { duration: 0.15 } }}
          onClick={onClose}
        >
          <m.div
            role="dialog"
            aria-modal="true"
            className="rounded-2xl bg-white p-6 shadow-xl"
            initial={{ opacity: 0, scale: 0.94, y: 12 }}
            animate={{ opacity: 1, scale: 1, y: 0, transition: spring.smooth }}
            exit={{ opacity: 0, scale: 0.97, y: 8, transition: { duration: 0.15 } }}
            onClick={(e) => e.stopPropagation()}
          >
            {children}
          </m.div>
        </m.div>
      )}
    </AnimatePresence>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 9. PAGE TRANSITION — Next.js App Router (template.tsx) ou wrapper de route
 * ════════════════════════════════════════════════════════════════════════ */
export function PageTransition({ children }: { children: React.ReactNode }) {
  return (
    <m.main
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -8 }}
      transition={{ duration: 0.3, ease: ease.out }}
    >
      {children}
    </m.main>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 10. SHARED ELEMENT — transition "magique" via layoutId (FLIP automatique)
 * Le même layoutId sur deux éléments montés à des moments différents anime
 * la position/taille entre les deux. Encadrer par <LayoutGroup> si besoin.
 * ════════════════════════════════════════════════════════════════════════ */
export function SharedThumb({
  id,
  expanded,
  onClick,
}: {
  id: string
  expanded: boolean
  onClick: () => void
}) {
  return (
    <m.div
      layoutId={`card-${id}`}
      onClick={onClick}
      transition={spring.smooth}
      className={
        expanded
          ? "fixed inset-4 z-50 rounded-3xl bg-neutral-900"
          : "h-40 w-full rounded-2xl bg-neutral-900"
      }
    />
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 11. GRADIENT/MASK SUIVI CURSEUR — useMotionTemplate (string réactif, 0 RAF JS)
 * Anime une variable CSS via motion value, sans recalcul de layout.
 * ════════════════════════════════════════════════════════════════════════ */
export function SpotlightCard({ children }: { children: React.ReactNode }) {
  const mx = useMotionValue(50)
  const my = useMotionValue(50)
  const bg = useMotionTemplate`radial-gradient(240px circle at ${mx}% ${my}%, rgba(255,255,255,0.12), transparent 60%)`
  function onMove(e: React.MouseEvent<HTMLDivElement>) {
    const r = e.currentTarget.getBoundingClientRect()
    mx.set(((e.clientX - r.left) / r.width) * 100)
    my.set(((e.clientY - r.top) / r.height) * 100)
  }
  return (
    <div onMouseMove={onMove} className="group relative overflow-hidden rounded-2xl">
      <m.div style={{ background: bg }} className="pointer-events-none absolute inset-0" />
      {children}
    </div>
  )
}

/* ════════════════════════════════════════════════════════════════════════
 * 12. PROGRESS / SCROLL INDICATOR — barre de progression de lecture
 * ════════════════════════════════════════════════════════════════════════ */
export function ScrollProgress() {
  const { scrollYProgress } = useScroll()
  const scaleX = useSpring(scrollYProgress, { stiffness: 120, damping: 30 })
  return (
    <m.div
      style={{ scaleX, transformOrigin: "0%" }}
      className="fixed inset-x-0 top-0 z-50 h-1 bg-current"
    />
  )
}

/* --------------------------------------------------------------------------
 * RAPPELS PERF (cf. agent ui-ux-pro-max) :
 *  - transform + opacity UNIQUEMENT sur le chemin animé.
 *  - will-change posé puis retiré (jamais permanent).
 *  - pas de useState par frame → useMotionValue / useMotionTemplate.
 *  - hors-écran = pas animé (useInView / IntersectionObserver).
 *  - hero affiché sans dépendre du JS (LCP) ; dimensions réservées (CLS).
 *  - prefers-reduced-motion respecté (MotionRoot + useReducedMotion).
 * -------------------------------------------------------------------------- */
