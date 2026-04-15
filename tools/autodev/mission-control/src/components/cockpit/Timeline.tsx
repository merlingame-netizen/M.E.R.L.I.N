import { useMemo } from 'react';
import { motion } from 'framer-motion';
import { useMissionStore, type FeatureTask, type GitCommit } from '../../store/mission-store';

type TimelineSection = 'NEXT' | 'RUNNING' | 'DONE';

interface TimelineItem {
  id: string;
  section: TimelineSection;
  title: string;
  meta: string;
  badge: string | null;
  timestamp: number;
}

function commitTime(commit: GitCommit): number {
  const t = Date.parse(commit.date);
  return Number.isFinite(t) ? t : 0;
}

function shortSha(sha: string): string {
  return sha.slice(0, 7);
}

function relTime(ts: number): string {
  if (!ts) return '';
  const diff = Date.now() - ts;
  const minutes = Math.round(diff / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  return `${days}d ago`;
}

function buildItems(featureQueue: FeatureTask[], gitActivity: GitCommit[]): TimelineItem[] {
  const running: TimelineItem[] = featureQueue
    .filter((t) => t.status === 'in_progress' || t.status === 'dispatched')
    .slice(0, 5)
    .map((t) => ({
      id: `run-${t.id}`,
      section: 'RUNNING' as const,
      title: t.title,
      meta: `${t.id}${t.agent ? ` · ${t.agent}` : ''}`,
      badge: t.type ?? t.sprint ?? null,
      timestamp: Date.now(),
    }));

  const next: TimelineItem[] = featureQueue
    .filter((t) => t.status === 'pending')
    .sort((a, b) => a.priority - b.priority)
    .slice(0, 6)
    .map((t) => ({
      id: `next-${t.id}`,
      section: 'NEXT' as const,
      title: t.title,
      meta: `${t.id} · P${t.priority}`,
      badge: t.type ?? t.sprint ?? null,
      timestamp: Date.now(),
    }));

  const done: TimelineItem[] = gitActivity
    .slice(0, 20)
    .map((c) => ({
      id: `git-${c.sha}`,
      section: 'DONE' as const,
      title: c.message.split('\n')[0] ?? c.message,
      meta: `${shortSha(c.sha)} · ${relTime(commitTime(c))}`,
      badge: c.type || null,
      timestamp: commitTime(c),
    }));

  return [...next, ...running, ...done];
}

const SECTION_LABEL: Record<TimelineSection, string> = {
  NEXT: 'Up next',
  RUNNING: 'Running',
  DONE: 'Done',
};

function SectionIcon({ section }: { section: TimelineSection }) {
  if (section === 'DONE') {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <polyline points="20 6 9 17 4 12" />
      </svg>
    );
  }
  if (section === 'RUNNING') {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <circle cx="12" cy="12" r="9" opacity="0.3" />
        <path d="M12 3a9 9 0 0 1 9 9" />
      </svg>
    );
  }
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9" />
      <polyline points="12 7 12 12 15 14" />
    </svg>
  );
}

export function Timeline() {
  const featureQueue = useMissionStore((s) => s.featureQueue);
  const gitActivity = useMissionStore((s) => s.gitActivity);

  const grouped = useMemo(() => {
    const items = buildItems(featureQueue, gitActivity);
    return {
      NEXT: items.filter((i) => i.section === 'NEXT'),
      RUNNING: items.filter((i) => i.section === 'RUNNING'),
      DONE: items.filter((i) => i.section === 'DONE'),
    };
  }, [featureQueue, gitActivity]);

  const sections: TimelineSection[] = ['NEXT', 'RUNNING', 'DONE'];

  return (
    <aside className="timeline" aria-label="Development timeline">
      <header className="timeline__header">
        <span className="timeline__title">Activity</span>
        <span className="timeline__subtitle">{grouped.DONE.length} done · {grouped.RUNNING.length} running · {grouped.NEXT.length} next</span>
      </header>
      <div className="timeline__scroll">
        {sections.map((section) => {
          const items = grouped[section];
          if (items.length === 0) return null;
          return (
            <section key={section} className={`timeline__section timeline__section--${section.toLowerCase()}`}>
              <h3 className="timeline__section-label">{SECTION_LABEL[section]}</h3>
              <ul className="timeline__list">
                {items.map((item, idx) => (
                  <motion.li
                    key={item.id}
                    className={`timeline__item timeline__item--${section.toLowerCase()}`}
                    initial={{ opacity: 0, x: 8 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: idx * 0.02, duration: 0.2 }}
                  >
                    <span className="timeline__icon">
                      <SectionIcon section={section} />
                    </span>
                    <span className="timeline__body">
                      <span className="timeline__item-title">{item.title}</span>
                      <span className="timeline__item-meta">
                        <code>{item.meta}</code>
                        {item.badge && <span className="timeline__badge">{item.badge}</span>}
                      </span>
                    </span>
                  </motion.li>
                ))}
              </ul>
            </section>
          );
        })}
      </div>
    </aside>
  );
}
