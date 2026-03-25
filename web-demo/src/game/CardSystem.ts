// ═══════════════════════════════════════════════════════════════════════════════
// Card System — Card generation, FastRoute fallback, minigame selection
// ═══════════════════════════════════════════════════════════════════════════════

import { ACTION_VERBS, FIELD_MINIGAMES, MINIGAME_CATALOGUE, type FactionId } from './Constants';

// --- Card types ---

export interface CardOption {
  readonly verb: string;
  readonly text: string;
  readonly field: string;
  readonly effects: readonly string[];
}

export interface Card {
  readonly id: string;
  readonly narrative: string;
  readonly options: readonly [CardOption, CardOption, CardOption];
  readonly biome: string;
  readonly source: 'fastroute' | 'llm';
}

// --- FastRoute (hardcoded fallback cards) ---

let cardCounter = 0;

function nextCardId(): string {
  return `card_${Date.now()}_${++cardCounter}`;
}

/** Picks a random item from an array. */
function pick<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Maps a verb to its lexical field. */
export function verbToField(verb: string): string {
  for (const [field, verbs] of Object.entries(ACTION_VERBS)) {
    if (verbs.includes(verb)) return field;
  }
  return 'esprit';
}

/** Picks a minigame appropriate for a lexical field. */
export function pickMinigame(field: string): string {
  const options = FIELD_MINIGAMES[field];
  if (!options || options.length === 0) return 'traces';
  return pick(options);
}

// FastRoute card templates (simplified — the full 500+ set would come from JSON)
const FASTROUTE_TEMPLATES: readonly {
  narrative: string;
  options: readonly [
    { verb: string; text: string; effects: readonly string[] },
    { verb: string; text: string; effects: readonly string[] },
    { verb: string; text: string; effects: readonly string[] },
  ];
}[] = [
  {
    narrative: 'Une brume epaisse s\'eleve entre les chenes centenaires. Des murmures anciens resonnent dans le feuillage. Un sentier se dessine, a peine visible, menant vers une clairiere ou scintille une lumiere doree.',
    options: [
      { verb: 'observer', text: 'Tu scrutes la brume, cherchant un signe dans les volutes argentees.', effects: ['HEAL_LIFE:3', 'ADD_REPUTATION:druides:5'] },
      { verb: 'se faufiler', text: 'Tu te glisses entre les racines noueuses vers la lumiere.', effects: ['ADD_BIOME_CURRENCY:5', 'DAMAGE_LIFE:2'] },
      { verb: 'apaiser', text: 'Tu respires profondement, laissant la foret te guider.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:niamh:3'] },
    ],
  },
  {
    narrative: 'Un korrigan surgit d\'un tertre moussu, ses yeux brillant d\'une malice millenaire. Il brandit un caillou grave de runes et te lance un defi : deviner le symbole cache dans la pierre.',
    options: [
      { verb: 'dechiffrer', text: 'Tu te concentres sur les gravures, cherchant le motif cache.', effects: ['ADD_REPUTATION:korrigans:8', 'ADD_ANAM:3'] },
      { verb: 'marchander', text: 'Tu proposes un echange plutot qu\'un defi.', effects: ['ADD_BIOME_CURRENCY:8', 'ADD_REPUTATION:korrigans:-3'] },
      { verb: 'combattre', text: 'Tu refuses le jeu et montres ta force.', effects: ['DAMAGE_LIFE:5', 'ADD_REPUTATION:ankou:5'] },
    ],
  },
  {
    narrative: 'Au bord d\'un lac immobile, une silhouette feminine se tient sur l\'eau. Niamh, la dame du lac, te fixe de ses yeux d\'argent. "Qu\'es-tu venu chercher ici, mortel ?" murmure-t-elle.',
    options: [
      { verb: 'parler', text: 'Tu reponds avec respect, partageant ta quete.', effects: ['ADD_REPUTATION:niamh:10', 'HEAL_LIFE:8'] },
      { verb: 'se concentrer', text: 'Tu restes silencieux, laissant ton esprit parler.', effects: ['ADD_REPUTATION:niamh:5', 'ADD_REPUTATION:druides:5'] },
      { verb: 'fuir', text: 'L\'aura surnaturelle t\'effraie. Tu recules.', effects: ['DAMAGE_LIFE:3', 'ADD_REPUTATION:niamh:-5'] },
    ],
  },
  {
    narrative: 'Un cairn imposant se dresse a la croisee de deux sentiers. Des ossements blanchis tapissent sa base. Un vent glacial souffle du nord, portant l\'odeur de la tourbe et du fer.',
    options: [
      { verb: 'fouiller a l\'aveugle', text: 'Tu fouilles parmi les offrandes deposees au pied du cairn.', effects: ['ADD_BIOME_CURRENCY:10', 'DAMAGE_LIFE:4'] },
      { verb: 'mediter', text: 'Tu t\'agenouilles et honores les ancetres.', effects: ['ADD_REPUTATION:anciens:10', 'HEAL_LIFE:3'] },
      { verb: 'pister', text: 'Tu suis les traces qui s\'eloignent du cairn.', effects: ['ADD_REPUTATION:ankou:3', 'ADD_ANAM:5'] },
    ],
  },
  {
    narrative: 'Le sol tremble sous tes pieds. Les racines d\'un if millenaire percent la terre, revelant une cavite ou pulse une lueur verdatre. Un druide age t\'observe depuis l\'ombre des branches.',
    options: [
      { verb: 'examiner', text: 'Tu t\'approches prudemment de la cavite lumineuse.', effects: ['ADD_ANAM:5', 'ADD_REPUTATION:druides:8'] },
      { verb: 'resister mentalement', text: 'Tu fermes les yeux, refusant l\'appel de la lumiere.', effects: ['HEAL_LIFE:5', 'ADD_REPUTATION:anciens:5'] },
      { verb: 'escalader', text: 'Tu grimpes dans l\'arbre pour avoir une meilleure vue.', effects: ['ADD_BIOME_CURRENCY:6', 'DAMAGE_LIFE:3'] },
    ],
  },
  {
    narrative: 'Une melodie lointaine guide tes pas vers un cercle de pierres dressees. Chaque menhir porte un ogham different, et la musique semble provenir du centre exact du cercle.',
    options: [
      { verb: 'ecouter', text: 'Tu tends l\'oreille, laissant la melodie te guider.', effects: ['HEAL_LIFE:4', 'ADD_REPUTATION:druides:6'] },
      { verb: 'dechiffrer', text: 'Tu etudies les oghams graves dans la pierre.', effects: ['ADD_ANAM:8', 'ADD_REPUTATION:anciens:4'] },
      { verb: 'courir', text: 'Tu traverses le cercle en courant, bravant l\'inconnu.', effects: ['ADD_BIOME_CURRENCY:7', 'DAMAGE_LIFE:5', 'ADD_REPUTATION:ankou:3'] },
    ],
  },
];

/** Generate a card using FastRoute (hardcoded templates). */
export function generateFastRouteCard(biome: string): Card {
  const template = pick(FASTROUTE_TEMPLATES);
  const options = template.options.map((opt) => ({
    verb: opt.verb,
    text: opt.text,
    field: verbToField(opt.verb),
    effects: opt.effects,
  })) as unknown as [CardOption, CardOption, CardOption];

  return {
    id: nextCardId(),
    narrative: template.narrative,
    options,
    biome,
    source: 'fastroute',
  };
}

/** Detect which minigame to play based on the chosen option's field. */
export function detectMinigame(card: Card, chosenOption: number): string {
  const option = card.options[chosenOption];
  if (!option) return 'traces';
  return pickMinigame(option.field);
}
