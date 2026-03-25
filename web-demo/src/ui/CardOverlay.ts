// ═══════════════════════════════════════════════════════════════════════════════
// Card Overlay — Displays narrative card with 3 options
// ═══════════════════════════════════════════════════════════════════════════════

import type { Card } from '../game/CardSystem';

const overlay = () => document.getElementById('card-overlay')!;
const textEl = () => document.getElementById('card-text')!;
const optionsEl = () => document.getElementById('card-options')!;

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
  });
}

export function hideCard(): void {
  overlay().classList.remove('visible');
}
