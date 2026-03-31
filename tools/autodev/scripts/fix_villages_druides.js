// Fix druides over-representation in villages_celtes batch2
// Constraint: druides <= 3 cards total (any option with druides effect)
// Strategy: replace druides effects on excess cards with korrigans or anciens
const fs = require('fs');
const path = 'C:/Users/PGNK2128/Godot-MCP/web-demo/public/data/cards.json';
const cards = JSON.parse(fs.readFileSync(path, 'utf8'));

// Last 20 are batch2
const batch2Start = cards.length - 20;
const batch2 = cards.slice(batch2Start);

// Track which cards have druides and fix excess beyond 3
let druideCardCount = 0;
const MAX_DRUIDE_CARDS = 3;

// Replacements map: druides -> preferred alternative per card context
// Cards 1-indexed within batch2
const replacements = {
  // card index (0-based in batch2): { optionVerb: newFaction }
  // Card 3 (marche/marchande) - avertir: druides->anciens OK, keep
  // Card 7 (fete moissons) - benir: druides->anciens makes sense
  // Card 9 (guerisseur) - apprendre: druides->anciens (healer lore)
  // Card 10 (poteau sculpte) - saluer: druides->anciens
  // Card 11 (druide toit) - monter+appeler: keep as druide-card (thematic)
  // Card 20 (cloche assemblee) - enqueter: druides->anciens
};

batch2.forEach((card, idx) => {
  const hasDruide = card.options.some(opt => opt.effects.some(e => e.includes('druides')));
  if (!hasDruide) return;

  druideCardCount++;
  if (druideCardCount <= MAX_DRUIDE_CARDS) return; // keep first 3

  // Replace druides with korrigans or anciens in this card's effects
  card.options = card.options.map(opt => {
    const newEffects = opt.effects.map(e => {
      if (e.includes('ADD_REPUTATION:druides:')) {
        // Alternate between korrigans and anciens based on card index
        const replacement = idx % 2 === 0 ? 'korrigans' : 'anciens';
        return e.replace('druides', replacement);
      }
      return e;
    });
    return { ...opt, effects: newEffects };
  });
});

// Write back
cards.splice(batch2Start, 20, ...batch2);
fs.writeFileSync(path, JSON.stringify(cards, null, 2));
console.log('Fixed. Total cards:', cards.length);

// Re-validate
let korrigansOpts = 0, niamhOpts = 0, druideCards2 = 0, healViol = 0, repViol = 0;
batch2.forEach(card => {
  const hasDruide = card.options.some(opt => opt.effects.some(e => e.includes('druides')));
  if (hasDruide) druideCards2++;
  card.options.forEach(opt => {
    opt.effects.forEach(e => {
      if (e.includes('korrigans')) korrigansOpts++;
      if (e.includes('niamh')) niamhOpts++;
      const mH = e.match(/HEAL_LIFE:(\d+)/);
      if (mH && parseInt(mH[1]) > 5) healViol++;
      const mR = e.match(/ADD_REPUTATION:\w+:(\d+)/);
      if (mR && parseInt(mR[1]) > 20) repViol++;
    });
  });
});
console.log('druide cards after fix:', druideCards2, '(max 3)');
console.log('korrigans opts:', korrigansOpts);
console.log('niamh opts:', niamhOpts);
console.log('heal violations:', healViol);
console.log('rep violations:', repViol);
