import { useEffect, useMemo, useState, type ReactElement } from 'react';
import { AnimatePresence, motion, useReducedMotion } from 'framer-motion';
import { useResizable } from '../../hooks/useResizable';
import { FeatureQueue } from '../FeatureQueue';
import { CompletedTasks } from '../CompletedTasks';
import { AlertFeed } from '../AlertFeed';
import { StudioInsights } from '../StudioInsights';
import { DirectorInstructions } from '../DirectorInstructions';
import { HumanFeedback } from '../HumanFeedback';
import { FileUpload } from '../FileUpload';
import { SceneSelector } from '../SceneSelector';
import { SpecialistRotation } from '../SpecialistRotation';
import { ErrorBoundary } from '../ErrorBoundary';

type DrawerTab = 'tasks' | 'alerts' | 'director' | 'settings';

interface TabDef {
  key: DrawerTab;
  label: string;
  icon: ReactElement;
}

const TABS: TabDef[] = [
  {
    key: 'tasks',
    label: 'Tasks',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <rect x="3" y="4" width="18" height="16" rx="2" />
        <path d="M8 10h8M8 14h5" />
      </svg>
    ),
  },
  {
    key: 'alerts',
    label: 'Alerts',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" />
        <path d="M13.7 21a2 2 0 0 1-3.4 0" />
      </svg>
    ),
  },
  {
    key: 'director',
    label: 'Director',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <circle cx="12" cy="8" r="4" />
        <path d="M4 21v-2a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v2" />
      </svg>
    ),
  },
  {
    key: 'settings',
    label: 'Settings',
    icon: (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <circle cx="12" cy="12" r="3" />
        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09A1.65 1.65 0 0 0 15 4.6a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
      </svg>
    ),
  },
];

const STORAGE_OPEN = 'merlin.cockpit.drawer.open';
const STORAGE_TAB = 'merlin.cockpit.drawer.tab';

function loadOpen(): boolean {
  if (typeof window === 'undefined') return false;
  try {
    return window.localStorage.getItem(STORAGE_OPEN) === '1';
  } catch {
    return false;
  }
}

function loadTab(): DrawerTab {
  if (typeof window === 'undefined') return 'tasks';
  try {
    const v = window.localStorage.getItem(STORAGE_TAB);
    if (v === 'tasks' || v === 'alerts' || v === 'director' || v === 'settings') return v;
  } catch {
    // ignore
  }
  return 'tasks';
}

export function Drawer() {
  const [open, setOpen] = useState<boolean>(loadOpen);
  const [tab, setTab] = useState<DrawerTab>(loadTab);
  const reduced = useReducedMotion();

  const { size: heightPct, isDragging, startDrag } = useResizable({
    storageKey: 'merlin.cockpit.drawerHeight',
    initial: 50,
    min: 25,
    max: 80,
    axis: 'y',
  });

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_OPEN, open ? '1' : '0');
    } catch {
      // ignore
    }
  }, [open]);

  useEffect(() => {
    try {
      window.localStorage.setItem(STORAGE_TAB, tab);
    } catch {
      // ignore
    }
  }, [tab]);

  const content = useMemo(() => {
    switch (tab) {
      case 'tasks':
        return (
          <div className="drawer__grid drawer__grid--2">
            <ErrorBoundary label="FeatureQueue"><FeatureQueue /></ErrorBoundary>
            <ErrorBoundary label="CompletedTasks"><CompletedTasks /></ErrorBoundary>
          </div>
        );
      case 'alerts':
        return (
          <div className="drawer__grid drawer__grid--2">
            <ErrorBoundary label="AlertFeed"><AlertFeed /></ErrorBoundary>
            <ErrorBoundary label="StudioInsights"><StudioInsights /></ErrorBoundary>
          </div>
        );
      case 'director':
        return (
          <div className="drawer__grid drawer__grid--2">
            <ErrorBoundary label="DirectorInstructions"><DirectorInstructions /></ErrorBoundary>
            <ErrorBoundary label="HumanFeedback"><HumanFeedback /></ErrorBoundary>
            <ErrorBoundary label="FileUpload"><FileUpload /></ErrorBoundary>
            <ErrorBoundary label="SceneSelector"><SceneSelector /></ErrorBoundary>
          </div>
        );
      case 'settings':
        return (
          <div className="drawer__grid">
            <ErrorBoundary label="SpecialistRotation"><SpecialistRotation /></ErrorBoundary>
          </div>
        );
    }
  }, [tab]);

  const transition = reduced ? { duration: 0 } : { duration: 0.24, ease: [0.4, 0, 0.2, 1] as const };

  return (
    <section
      className={`drawer${open ? ' drawer--open' : ''}`}
      data-dragging={isDragging || undefined}
      style={open ? { height: `${heightPct}vh` } : undefined}
      aria-label="Workspace drawer"
    >
      <header className="drawer__header">
        <div
          className="drawer__resize"
          role="separator"
          aria-orientation="horizontal"
          aria-label="Resize drawer"
          onPointerDown={open ? startDrag : undefined}
          aria-disabled={!open}
        >
          <span className="drawer__resize-grip" aria-hidden="true" />
        </div>
        <nav className="drawer__tabs" role="tablist" aria-label="Drawer sections">
          {TABS.map((t) => {
            const active = open && tab === t.key;
            return (
              <button
                key={t.key}
                type="button"
                role="tab"
                aria-selected={active}
                className={`drawer__tab${active ? ' drawer__tab--active' : ''}`}
                onClick={() => {
                  if (!open) setOpen(true);
                  setTab(t.key);
                }}
              >
                {t.icon}
                <span>{t.label}</span>
              </button>
            );
          })}
        </nav>
        <button
          type="button"
          className="drawer__toggle"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          aria-label={open ? 'Collapse drawer' : 'Expand drawer'}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            {open ? <polyline points="6 9 12 15 18 9" /> : <polyline points="6 15 12 9 18 15" />}
          </svg>
        </button>
      </header>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            key="drawer-body"
            className="drawer__body"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={transition}
          >
            {content}
          </motion.div>
        )}
      </AnimatePresence>
    </section>
  );
}
