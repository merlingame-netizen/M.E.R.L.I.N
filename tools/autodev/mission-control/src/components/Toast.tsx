import { create } from 'zustand';
import { AnimatePresence, motion } from 'framer-motion';
import { useEffect } from 'react';

export type ToastLevel = 'success' | 'error' | 'info' | 'warn';

export interface ToastEntry {
  id: string;
  level: ToastLevel;
  message: string;
  createdAt: number;
}

interface ToastStore {
  toasts: ToastEntry[];
  push: (level: ToastLevel, message: string) => void;
  dismiss: (id: string) => void;
}

export const useToastStore = create<ToastStore>((set) => ({
  toasts: [],
  push: (level, message) => set((s) => ({
    toasts: [...s.toasts, { id: crypto.randomUUID(), level, message, createdAt: Date.now() }].slice(-5),
  })),
  dismiss: (id) => set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
}));

export function toast(level: ToastLevel, message: string): void {
  useToastStore.getState().push(level, message);
}

const LEVEL_STYLE: Record<ToastLevel, { bg: string; border: string; color: string }> = {
  success: { bg: 'rgba(16, 185, 129, 0.18)', border: 'rgba(16, 185, 129, 0.5)', color: '#a7f3d0' },
  error:   { bg: 'rgba(239, 68, 68, 0.18)',  border: 'rgba(239, 68, 68, 0.5)',  color: '#fecaca' },
  info:    { bg: 'rgba(59, 130, 246, 0.18)', border: 'rgba(59, 130, 246, 0.5)', color: '#bfdbfe' },
  warn:    { bg: 'rgba(245, 158, 11, 0.18)', border: 'rgba(245, 158, 11, 0.5)', color: '#fde68a' },
};

const AUTO_DISMISS_MS = 3000;

export function ToastViewport() {
  const toasts = useToastStore((s) => s.toasts);
  const dismiss = useToastStore((s) => s.dismiss);

  useEffect(() => {
    if (toasts.length === 0) return;
    const timers = toasts.map((t) => {
      const remaining = AUTO_DISMISS_MS - (Date.now() - t.createdAt);
      return window.setTimeout(() => dismiss(t.id), Math.max(0, remaining));
    });
    return () => { timers.forEach((id) => window.clearTimeout(id)); };
  }, [toasts, dismiss]);

  return (
    <div className="toast-viewport" aria-live="polite" aria-atomic="true">
      <AnimatePresence>
        {toasts.map((t) => {
          const s = LEVEL_STYLE[t.level];
          return (
            <motion.div
              key={t.id}
              role="status"
              className="toast"
              initial={{ opacity: 0, x: 40, scale: 0.95 }}
              animate={{ opacity: 1, x: 0, scale: 1 }}
              exit={{ opacity: 0, x: 40, scale: 0.95 }}
              transition={{ duration: 0.25, ease: [0.4, 0, 0.2, 1] }}
              style={{ background: s.bg, borderColor: s.border, color: s.color }}
              onClick={() => dismiss(t.id)}
            >
              {t.message}
            </motion.div>
          );
        })}
      </AnimatePresence>
    </div>
  );
}
