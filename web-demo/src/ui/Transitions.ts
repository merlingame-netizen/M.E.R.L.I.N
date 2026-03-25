// ═══════════════════════════════════════════════════════════════════════════════
// Transitions — Fade overlay for scene transitions
// ═══════════════════════════════════════════════════════════════════════════════

const fadeEl = () => document.getElementById('fade-overlay')!;

export function fadeIn(durationMs = 800): Promise<void> {
  return new Promise((resolve) => {
    const el = fadeEl();
    el.style.transition = `opacity ${durationMs}ms ease`;
    el.classList.add('active');
    setTimeout(resolve, durationMs);
  });
}

export function fadeOut(durationMs = 800): Promise<void> {
  return new Promise((resolve) => {
    const el = fadeEl();
    el.style.transition = `opacity ${durationMs}ms ease`;
    el.classList.remove('active');
    setTimeout(resolve, durationMs);
  });
}

export async function crossFade(action: () => void | Promise<void>, durationMs = 600): Promise<void> {
  await fadeIn(durationMs);
  await action();
  await fadeOut(durationMs);
}
