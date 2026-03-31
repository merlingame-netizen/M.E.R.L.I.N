// ═══════════════════════════════════════════════════════════════════════════════
// Card Overlay — Displays narrative card with 3 options
// ═══════════════════════════════════════════════════════════════════════════════

import type { Card } from '../game/CardSystem';

const overlay = () => document.getElementById('card-overlay')!;
const textEl = () => document.getElementById('card-text')!;
const optionsEl = () => document.getElementById('card-options')!;
const cardContainer = () => document.querySelector<HTMLElement>('.card-container');

/** T047: Trigger card-flip CSS animation on the card container (0.4s rotateY). */
function triggerFlipAnimation(): void {
  const container = cardContainer();
  if (!container) return;
  // Remove class first in case it is already present from a previous card
  container.classList.remove('card-flip');
  // Force reflow so the browser registers the removal before re-adding
  void container.offsetWidth;
  container.classList.add('card-flip');
  // Clean up class after animation completes so hover/transitions are unaffected
  setTimeout(() => { container.classList.remove('card-flip'); }, 420);
}

export function showCard(card: Card): Promise<number> {
  return new Promise((resolve) => {
    textEl().textContent = card.narrative;
    const container = optionsEl();
    container.innerHTML = '';

    card.options.forEach((option, index) => {
      const btn = document.createElement('div');
      btn.className = 'card-option';
      btn.innerHTML = `
        <div class="verb">${option.verb}</div>
        <div class="desc">${option.text}</div>
      `;
      btn.addEventListener('click', () => {
        hideCard();
        resolve(index);
      });
      container.appendChild(btn);
    });

    overlay().classList.add('visible');
    // Play flip animation each time a new card is shown
    triggerFlipAnimation();
  });
}

export function hideCard(): void {
  overlay().classList.remove('visible');
}
