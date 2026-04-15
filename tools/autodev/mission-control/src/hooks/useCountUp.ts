import { useEffect, useRef, useState } from 'react';

export interface UseCountUpOptions {
  duration?: number;
  decimals?: number;
}

export function useCountUp(target: number, { duration = 600, decimals = 0 }: UseCountUpOptions = {}): number {
  const [value, setValue] = useState(target);
  const fromRef = useRef(target);
  const startRef = useRef<number | null>(null);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (typeof window === 'undefined') {
      setValue(target);
      return;
    }

    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reduceMotion || duration <= 0) {
      setValue(target);
      return;
    }

    fromRef.current = value;
    startRef.current = null;

    const factor = Math.pow(10, decimals);
    const tick = (ts: number) => {
      if (startRef.current === null) startRef.current = ts;
      const elapsed = ts - startRef.current;
      const t = Math.min(1, elapsed / duration);
      const eased = 1 - Math.pow(1 - t, 3); // ease-out cubic
      const next = fromRef.current + (target - fromRef.current) * eased;
      setValue(Math.round(next * factor) / factor);
      if (t < 1) {
        rafRef.current = window.requestAnimationFrame(tick);
      }
    };

    rafRef.current = window.requestAnimationFrame(tick);
    return () => {
      if (rafRef.current !== null) window.cancelAnimationFrame(rafRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, duration, decimals]);

  return value;
}
