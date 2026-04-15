import { useCallback, useEffect, useRef, useState } from 'react';

interface UseResizableOptions {
  storageKey: string;
  initial: number;
  min: number;
  max: number;
  axis?: 'x' | 'y';
}

interface UseResizableResult {
  size: number;
  setSize: (n: number) => void;
  isDragging: boolean;
  startDrag: (e: React.PointerEvent) => void;
}

function clamp(n: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, n));
}

function loadStored(key: string, fallback: number, min: number, max: number): number {
  if (typeof window === 'undefined') return fallback;
  try {
    const raw = window.localStorage.getItem(key);
    if (raw === null) return fallback;
    const parsed = Number(raw);
    if (Number.isFinite(parsed)) return clamp(parsed, min, max);
  } catch {
    // ignore
  }
  return fallback;
}

export function useResizable({
  storageKey,
  initial,
  min,
  max,
  axis = 'x',
}: UseResizableOptions): UseResizableResult {
  const [size, setSizeState] = useState<number>(() => loadStored(storageKey, initial, min, max));
  const [isDragging, setIsDragging] = useState(false);
  const dragRef = useRef<{ startCoord: number; startSize: number; viewport: number } | null>(null);

  const setSize = useCallback(
    (n: number) => {
      const next = clamp(n, min, max);
      setSizeState(next);
      try {
        window.localStorage.setItem(storageKey, String(next));
      } catch {
        // ignore
      }
    },
    [storageKey, min, max],
  );

  const startDrag = useCallback(
    (e: React.PointerEvent) => {
      e.preventDefault();
      const viewport = axis === 'x' ? window.innerWidth : window.innerHeight;
      dragRef.current = {
        startCoord: axis === 'x' ? e.clientX : e.clientY,
        startSize: size,
        viewport,
      };
      setIsDragging(true);
    },
    [axis, size],
  );

  useEffect(() => {
    if (!isDragging) return;
    const handleMove = (e: PointerEvent) => {
      const drag = dragRef.current;
      if (!drag) return;
      const coord = axis === 'x' ? e.clientX : e.clientY;
      const deltaPct = ((coord - drag.startCoord) / drag.viewport) * 100;
      const next = clamp(drag.startSize + deltaPct, min, max);
      setSizeState(next);
    };
    const handleUp = () => {
      const drag = dragRef.current;
      if (drag) {
        try {
          window.localStorage.setItem(storageKey, String(clamp(loadStored(storageKey, drag.startSize, min, max), min, max)));
        } catch {
          // ignore
        }
      }
      setIsDragging(false);
      dragRef.current = null;
    };
    window.addEventListener('pointermove', handleMove);
    window.addEventListener('pointerup', handleUp);
    window.addEventListener('pointercancel', handleUp);
    return () => {
      window.removeEventListener('pointermove', handleMove);
      window.removeEventListener('pointerup', handleUp);
      window.removeEventListener('pointercancel', handleUp);
    };
  }, [isDragging, axis, min, max, storageKey]);

  useEffect(() => {
    if (isDragging) return;
    try {
      window.localStorage.setItem(storageKey, String(size));
    } catch {
      // ignore
    }
  }, [size, isDragging, storageKey]);

  return { size, setSize, isDragging, startDrag };
}
