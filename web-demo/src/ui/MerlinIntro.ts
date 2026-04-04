// =============================================================================
// MerlinIntro — First-run dialogue overlay
// Merlin silhouette + typewriter dialogue (2-3 lines), click/Space to advance.
// Shown after the "Nouvelle Partie" walk animation, before the lair.
// =============================================================================

const MERLIN_LINES: readonly string[] = [
  'Bienvenue, voyageur. Je suis Merlin, gardien des Oghams anciens.',
  'La forêt de Brocéliande t\'attend. Chaque choix que tu feras forgera ton destin.',
  'Écoute les runes. Elles murmurent depuis la nuit des temps… Entre.',
];

function wait(ms: number): Promise<void> {
  return new Promise((res) => setTimeout(res, ms));
}

async function typewrite(el: HTMLElement, text: string, charMs = 26): Promise<void> {
  el.textContent = '';
  for (const char of text) {
    el.textContent += char;
    await wait(charMs);
  }
}

export async function runMerlinIntro(): Promise<void> {
  const overlay = document.createElement('div');
  overlay.id = 'merlin-intro-overlay';
  overlay.style.cssText = [
    'position:fixed;inset:0;z-index:9000;',
    'background:rgba(5,4,2,0.96);',
    'display:flex;flex-direction:column;align-items:center;justify-content:flex-end;',
    'padding-bottom:11vh;cursor:pointer;',
    'opacity:0;transition:opacity 0.6s;',
  ].join('');
  document.body.appendChild(overlay);

  // --- Merlin silhouette (CSS robe + staff) ---
  const silhouette = document.createElement('div');
  silhouette.style.cssText = [
    'position:absolute;bottom:27%;left:50%;transform:translateX(-50%);',
    'width:100px;height:180px;',
    'background:rgba(8,6,3,0.92);',
    'clip-path:polygon(35% 0%,65% 0%,83% 100%,17% 100%);',
    'opacity:0.75;filter:blur(0.5px);',
  ].join('');
  overlay.appendChild(silhouette);

  // Hood accent
  const hood = document.createElement('div');
  hood.style.cssText = [
    'position:absolute;bottom:calc(27% + 165px);left:50%;transform:translateX(-50%);',
    'width:38px;height:30px;border-radius:50% 50% 0 0;',
    'background:rgba(10,8,4,0.92);',
  ].join('');
  overlay.appendChild(hood);

  // Staff
  const staff = document.createElement('div');
  staff.style.cssText = [
    'position:absolute;bottom:27%;left:calc(50% + 48px);',
    'width:2px;height:200px;transform:rotate(4deg);transform-origin:bottom center;',
    'background:linear-gradient(to top,rgba(200,160,80,0.65),rgba(200,160,80,0.08));',
  ].join('');
  overlay.appendChild(staff);

  // Staff orb
  const orb = document.createElement('div');
  orb.style.cssText = [
    'position:absolute;bottom:calc(27% + 198px);left:calc(50% + 42px);',
    'width:14px;height:14px;border-radius:50%;',
    'background:radial-gradient(circle at 35% 35%,#e8c870,#c87820);',
    'box-shadow:0 0 12px rgba(200,160,80,0.6);',
  ].join('');
  overlay.appendChild(orb);

  // Ambient star particles
  for (let i = 0; i < 35; i++) {
    const star = document.createElement('div');
    const x = Math.random() * 100;
    const y = Math.random() * 60;
    const size = Math.random() * 1.8 + 0.6;
    const alpha = 0.15 + Math.random() * 0.45;
    star.style.cssText = [
      `position:absolute;left:${x}%;top:${y}%;`,
      `width:${size}px;height:${size}px;border-radius:50%;`,
      `background:rgba(200,160,80,${alpha});`,
    ].join('');
    overlay.appendChild(star);
  }

  // --- Dialogue box ---
  const dialogueBox = document.createElement('div');
  dialogueBox.style.cssText = [
    'position:relative;z-index:1;',
    'max-width:540px;width:88%;',
    'background:rgba(12,9,5,0.92);',
    'border:1px solid rgba(200,150,60,0.4);border-radius:8px;',
    'padding:20px 28px 16px;',
    'font-family:Georgia,serif;',
  ].join('');
  overlay.appendChild(dialogueBox);

  const nameEl = document.createElement('div');
  nameEl.textContent = 'Merlin';
  nameEl.style.cssText = [
    'color:#c8a050;font-size:13px;letter-spacing:0.18em;',
    'margin-bottom:10px;text-transform:uppercase;',
  ].join('');
  dialogueBox.appendChild(nameEl);

  const textEl = document.createElement('div');
  textEl.style.cssText = [
    'color:rgba(232,220,200,0.92);font-size:15px;line-height:1.65;',
    'min-height:52px;',
    'transition:opacity 0.2s;',
  ].join('');
  dialogueBox.appendChild(textEl);

  const hintEl = document.createElement('div');
  hintEl.textContent = 'Cliquez pour continuer…';
  hintEl.style.cssText = [
    'color:rgba(200,150,60,0.38);font-size:11px;text-align:right;',
    'margin-top:10px;font-style:italic;letter-spacing:0.06em;',
    'opacity:0;transition:opacity 0.5s;',
  ].join('');
  dialogueBox.appendChild(hintEl);

  // Fade in overlay
  requestAnimationFrame(() => requestAnimationFrame(() => { overlay.style.opacity = '1'; }));
  await wait(600);

  // --- Typewrite each line, wait for advance ---
  for (let i = 0; i < MERLIN_LINES.length; i++) {
    // Fade text in if coming from previous line
    if (i > 0) {
      textEl.style.opacity = '0';
      await wait(220);
      textEl.style.opacity = '1';
    }

    await typewrite(textEl, MERLIN_LINES[i]!);
    hintEl.style.opacity = '1';

    await new Promise<void>((resolve) => {
      const cleanup = (): void => {
        overlay.removeEventListener('click', onClick);
        document.removeEventListener('keydown', onKey);
      };
      const onClick = (): void => { cleanup(); resolve(); };
      const onKey = (e: KeyboardEvent): void => {
        if (e.code === 'Space' || e.code === 'Enter') {
          e.preventDefault();
          cleanup();
          resolve();
        }
      };
      overlay.addEventListener('click', onClick);
      document.addEventListener('keydown', onKey);
    });

    hintEl.style.opacity = '0';
  }

  // Fade out
  overlay.style.transition = 'opacity 0.5s';
  overlay.style.opacity = '0';
  await wait(520);
  overlay.remove();
}
