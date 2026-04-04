// ═══════════════════════════════════════════════════════════════════════════════
// MERLIN Constants — Ported from merlin_constants.gd (Game Design Bible v2.4)
// ═══════════════════════════════════════════════════════════════════════════════

// --- FACTIONS ---
export const FACTIONS = ['druides', 'anciens', 'korrigans', 'niamh', 'ankou'] as const;
export type FactionId = (typeof FACTIONS)[number];

export const FACTION_SCORE_START = 0;
export const FACTION_THRESHOLD_CONTENT = 50;
export const FACTION_THRESHOLD_ENDING = 80;
export const FACTION_CAP_PER_CARD = 20;

// --- LIFE ---
export const LIFE_MAX = 100;
export const LIFE_START = 100;
export const LIFE_DRAIN_PER_CARD = 1;
/** After this many cards played, drain increases to LIFE_DRAIN_STAGE2. */
export const LIFE_DRAIN_THRESHOLD_STAGE2 = 15;
/** After this many cards played, drain increases to LIFE_DRAIN_STAGE3. */
export const LIFE_DRAIN_THRESHOLD_STAGE3 = 25;
/** Drain amount per card for cards 15-24 (escalating pressure mid-run). */
export const LIFE_DRAIN_STAGE2 = 2;
/** Drain amount per card for cards 25+ (late-run tension). */
export const LIFE_DRAIN_STAGE3 = 3;
export const LIFE_LOW_THRESHOLD = 25;
export const LIFE_EVENT_FAIL_DAMAGE = 6;
export const LIFE_HEAL_PER_REST = 18;
export const MIN_CARDS_FOR_VICTORY = 25;

// --- ANAM ---
export const ANAM_REWARDS = {
  base: 10,
  victory_bonus: 15,
  minigame_won: 2,
  minigame_threshold: 80,
  ogham_used: 1,
  faction_honored: 5,
  faction_threshold: 80,
  death_cap_cards: 30,
} as const;

// --- MULTIPLIER TABLE ---
export interface MultiplierEntry {
  readonly range_min: number;
  readonly range_max: number;
  readonly label: string;
  readonly factor: number;
}

export const MULTIPLIER_TABLE: readonly MultiplierEntry[] = [
  { range_min: 0, range_max: 20, label: 'echec_critique', factor: -1.5 },
  { range_min: 21, range_max: 50, label: 'echec', factor: -1.0 },
  { range_min: 51, range_max: 79, label: 'reussite_partielle', factor: 0.5 },
  { range_min: 80, range_max: 94, label: 'reussite', factor: 1.0 },
  { range_min: 95, range_max: 100, label: 'reussite_critique', factor: 1.5 },
] as const;

export function getMultiplier(score: number): number {
  const clamped = Math.max(0, Math.min(100, score));
  for (const entry of MULTIPLIER_TABLE) {
    if (clamped >= entry.range_min && clamped <= entry.range_max) {
      return entry.factor;
    }
  }
  return 1.0;
}

export function getMultiplierLabel(score: number): string {
  const clamped = Math.max(0, Math.min(100, score));
  for (const entry of MULTIPLIER_TABLE) {
    if (clamped >= entry.range_min && clamped <= entry.range_max) {
      return entry.label;
    }
  }
  return 'reussite';
}

// --- EFFECT CAPS ---
export const EFFECT_CAPS = {
  ADD_REPUTATION: { max: 20, min: -20 },
  HEAL_LIFE: { max: 18 },
  HEAL_CRITICAL: { max: 5 },
  DAMAGE_LIFE: { max: 15 },
  DAMAGE_CRITICAL: { max: 22 },
  ADD_BIOME_CURRENCY: { max: 10 },
  UNLOCK_OGHAM: { max_per_card: 1 },
  LIFE_MAX: 100,
  LIFE_MIN: 0,
  effects_per_option: 3,
  score_bonus_cap: 2.0,
  drain_per_card: 1,
} as const;

// --- ACTION VERBS (8 lexical fields) ---
export const ACTION_VERBS: Record<string, readonly string[]> = {
  chance: ['cueillir', 'chercher au hasard', 'tenter sa chance', 'deviner', 'fouiller a l\'aveugle'],
  bluff: ['marchander', 'convaincre', 'mentir', 'negocier', 'charmer', 'amadouer'],
  observation: ['observer', 'scruter', 'memoriser', 'examiner', 'fixer', 'inspecter'],
  logique: ['dechiffrer', 'analyser', 'resoudre', 'decoder', 'interpreter', 'etudier'],
  finesse: ['se faufiler', 'esquiver', 'contourner', 'se cacher', 'escalader', 'traverser'],
  vigueur: ['combattre', 'courir', 'fuir', 'forcer', 'pousser', 'resister physiquement'],
  esprit: ['calmer', 'apaiser', 'mediter', 'resister mentalement', 'se concentrer', 'endurer',
    'parler', 'accepter', 'refuser', 'attendre', 's\'approcher'],
  perception: ['ecouter', 'suivre', 'pister', 'sentir', 'flairer', 'tendre l\'oreille'],
} as const;

export const ACTION_VERB_FALLBACK_FIELD = 'esprit';

// --- FIELD → MINIGAME MAPPING ---
export const FIELD_MINIGAMES: Record<string, readonly string[]> = {
  chance: ['herboristerie'],
  bluff: ['negociation'],
  observation: ['fouille', 'regard'],
  logique: ['runes'],
  finesse: ['ombres', 'equilibre'],
  vigueur: ['combat_rituel', 'course'],
  esprit: ['apaisement', 'volonte', 'sang_froid'],
  perception: ['traces', 'echo'],
} as const;

// --- MINIGAME CATALOGUE ---
export interface MinigameSpec {
  readonly name: string;
  readonly desc: string;
  readonly trigger: string;
}

export const MINIGAME_CATALOGUE: Record<string, MinigameSpec> = {
  traces: { name: 'Traces', desc: 'Suivre une sequence d\'empreintes sans sortir du chemin', trigger: 'piste|trace|empreinte|pas|sentier' },
  runes: { name: 'Runes', desc: 'Dechiffrer un ogham cache dans la pierre', trigger: 'rune|ogham|symbole|gravure|inscription' },
  equilibre: { name: 'Equilibre', desc: 'Maintenir l\'equilibre sur un passage instable', trigger: 'pont|equilibre|vertige|gouffre|precipice' },
  herboristerie: { name: 'Herboristerie', desc: 'Identifier la bonne plante parmi les toxiques', trigger: 'plante|herbe|champignon|racine|cueillir|potion' },
  negociation: { name: 'Negociation', desc: 'Convaincre un esprit par les mots justes', trigger: 'esprit|fae|parler|negocier|korrigan|convaincre|marchander' },
  combat_rituel: { name: 'Combat Rituel', desc: 'Esquiver dans un cercle sacre', trigger: 'combat|defi|guerrier|lame|epee|duel' },
  apaisement: { name: 'Apaisement', desc: 'Calmer un gardien par le rythme et la respiration', trigger: 'apaiser|calmer|respir|gardien|rage|colere' },
  sang_froid: { name: 'Sang-froid', desc: 'Maintenir le curseur stable malgre les pulsations', trigger: 'piege|danger|froid|sang|approcher|appat' },
  course: { name: 'Course', desc: 'QTE pour maintenir la poursuite ou fuir', trigger: 'courir|pourchasser|fuir|sprint|trouee|course' },
  fouille: { name: 'Fouille', desc: 'Trouver l\'indice cache en temps limite', trigger: 'fouille|chercher|indice|recueillir|ruban|preuve' },
  ombres: { name: 'Ombres', desc: 'Se deplacer entre couvertures sans etre vu', trigger: 'cacher|ombre|discret|invisible|embuscade' },
  volonte: { name: 'Volonte', desc: 'Tenir le focus malgre les murmures et le doute', trigger: 'douter|murmure|resister|volonte|doute|hesiter' },
  regard: { name: 'Regard', desc: 'Memoriser puis reproduire une sequence de formes', trigger: 'vision|forme|memoriser|fixer|apparition|spectr' },
  echo: { name: 'Echo', desc: 'Suivre l\'intensite sonore vers la bonne direction', trigger: 'voix|appel|son|echo|ecouter|cri|chant' },
} as const;

// --- OGHAM SPECS (18 Oghams) ---
export interface OghamSpec {
  readonly name: string;
  readonly tree: string;
  readonly unicode: string;
  readonly category: 'reveal' | 'protection' | 'boost' | 'narrative' | 'recovery' | 'special';
  readonly cooldown: number;
  readonly starter: boolean;
  readonly cost_anam: number;
  readonly branch: string;
  readonly tier: number;
  readonly effect: string;
  readonly description: string;
  readonly effect_params: Record<string, unknown>;
}

export const OGHAM_SPECS: Record<string, OghamSpec> = {
  beith: { name: 'Bouleau', tree: 'Betula', unicode: '\u1681', category: 'reveal', cooldown: 3, starter: true, cost_anam: 0, branch: 'central', tier: 0, effect: 'reveal_one_option', description: 'Revele l\'effet complet d\'1 option au choix', effect_params: { target: 'single_option' } },
  coll: { name: 'Noisetier', tree: 'Corylus', unicode: '\u1685', category: 'reveal', cooldown: 5, starter: false, cost_anam: 80, branch: 'druides', tier: 1, effect: 'reveal_all_options', description: 'Revele les effets de toutes les options', effect_params: { target: 'all_options' } },
  ailm: { name: 'Sapin', tree: 'Abies', unicode: '\u168F', category: 'reveal', cooldown: 4, starter: false, cost_anam: 60, branch: 'anciens', tier: 1, effect: 'predict_next', description: 'Predit le theme + champ lexical de la prochaine carte', effect_params: { target: 'next_card' } },
  luis: { name: 'Sorbier', tree: 'Sorbus', unicode: '\u1682', category: 'protection', cooldown: 4, starter: true, cost_anam: 0, branch: 'central', tier: 0, effect: 'block_first_negative', description: 'Bloque le prochain effet negatif unique', effect_params: { count: 1 } },
  gort: { name: 'Lierre', tree: 'Hedera', unicode: '\u168C', category: 'protection', cooldown: 6, starter: false, cost_anam: 100, branch: 'niamh', tier: 2, effect: 'reduce_high_damage', description: 'Reduit tout degat > 10 PV a 5 PV', effect_params: { threshold: 10, reduced_to: 5 } },
  eadhadh: { name: 'Tremble', tree: 'Populus', unicode: '\u1690', category: 'protection', cooldown: 8, starter: false, cost_anam: 150, branch: 'ankou', tier: 1, effect: 'cancel_all_negatives', description: 'Annule tous les effets negatifs de la carte courante', effect_params: {} },
  duir: { name: 'Chene', tree: 'Quercus', unicode: '\u1687', category: 'boost', cooldown: 4, starter: false, cost_anam: 70, branch: 'druides', tier: 2, effect: 'heal_immediate', description: 'Soin immediat de +12 PV', effect_params: { amount: 12 } },
  tinne: { name: 'Houx', tree: 'Ilex', unicode: '\u1688', category: 'boost', cooldown: 5, starter: false, cost_anam: 120, branch: 'anciens', tier: 2, effect: 'double_positives', description: 'Double les effets positifs de l\'option choisie', effect_params: { multiplier: 2.0 } },
  onn: { name: 'Ajonc', tree: 'Ulex', unicode: '\u1689', category: 'boost', cooldown: 7, starter: false, cost_anam: 90, branch: 'korrigans', tier: 1, effect: 'add_biome_currency', description: 'Genere +10 monnaie biome instantanement', effect_params: { amount: 10 } },
  nuin: { name: 'Frene', tree: 'Fraxinus', unicode: '\u1684', category: 'narrative', cooldown: 6, starter: false, cost_anam: 80, branch: 'druides', tier: 3, effect: 'replace_worst_option', description: 'Remplace la pire option par une nouvelle', effect_params: { target: 'worst_option' } },
  huath: { name: 'Aubepine', tree: 'Crataegus', unicode: '\u1686', category: 'narrative', cooldown: 5, starter: false, cost_anam: 100, branch: 'korrigans', tier: 3, effect: 'regenerate_all_options', description: 'Regenere les 3 options de la carte', effect_params: { count: 3 } },
  straif: { name: 'Prunellier', tree: 'Prunus', unicode: '\u1693', category: 'narrative', cooldown: 10, starter: false, cost_anam: 140, branch: 'anciens', tier: 3, effect: 'force_twist', description: 'Force un twist narratif majeur dans la carte suivante', effect_params: { target: 'next_card' } },
  quert: { name: 'Pommier', tree: 'Malus', unicode: '\u168A', category: 'recovery', cooldown: 4, starter: true, cost_anam: 0, branch: 'central', tier: 0, effect: 'heal_immediate', description: 'Soin de +8 PV', effect_params: { amount: 8 } },
  ruis: { name: 'Sureau', tree: 'Sambucus', unicode: '\u1694', category: 'recovery', cooldown: 8, starter: false, cost_anam: 130, branch: 'niamh', tier: 3, effect: 'heal_and_cost', description: 'Soin massif +18 PV mais -5 monnaie biome', effect_params: { heal: 18, currency_cost: 5 } },
  saille: { name: 'Saule', tree: 'Salix', unicode: '\u1691', category: 'recovery', cooldown: 6, starter: false, cost_anam: 90, branch: 'niamh', tier: 1, effect: 'currency_and_heal', description: 'Regenere +8 monnaie biome + +3 PV', effect_params: { currency: 8, heal: 3 } },
  muin: { name: 'Vigne', tree: 'Vitis', unicode: '\u168D', category: 'special', cooldown: 7, starter: false, cost_anam: 110, branch: 'korrigans', tier: 2, effect: 'invert_effects', description: 'Inverse positifs/negatifs de l\'option choisie', effect_params: {} },
  ioho: { name: 'If', tree: 'Taxus', unicode: '\u1695', category: 'special', cooldown: 12, starter: false, cost_anam: 160, branch: 'ankou', tier: 2, effect: 'full_reroll', description: 'Defausse la carte entiere et en genere une nouvelle', effect_params: {} },
  ur: { name: 'Bruyere', tree: 'Calluna', unicode: '\u1692', category: 'special', cooldown: 10, starter: false, cost_anam: 140, branch: 'ankou', tier: 3, effect: 'sacrifice_trade', description: 'Sacrifie 15 PV, gagne +20 monnaie biome + buff score', effect_params: { life_cost: 15, currency_gain: 20, score_buff: 1.3 } },
} as const;

export const OGHAM_STARTER_SKILLS = ['beith', 'luis', 'quert'] as const;

// --- BIOMES (8 biomes) ---
export interface BiomeSpec {
  readonly name: string;
  readonly subtitle: string;
  readonly season: string;
  readonly difficulty: number;
  readonly maturity_threshold: number;
  readonly oghams_affinity: readonly string[];
  readonly currency_name: string;
  readonly card_interval_range_min: number;
  readonly card_interval_range_max: number;
  readonly pnj: string;
  readonly arc: string;
}

export const BIOMES: Record<string, BiomeSpec> = {
  foret_broceliande: { name: 'Foret de Broceliande', subtitle: 'Ou les arbres ont des yeux', season: 'printemps', difficulty: 0, maturity_threshold: 0, oghams_affinity: ['quert', 'huath', 'coll'], currency_name: 'Herbes enchantees', card_interval_range_min: 12, card_interval_range_max: 15, pnj: 'gwenn', arc: 'le_chene_chantant' },
  landes_bruyere: { name: 'Landes de Bruyere', subtitle: 'Ou le vent raconte des histoires', season: 'automne', difficulty: 1, maturity_threshold: 15, oghams_affinity: ['luis', 'onn', 'saille'], currency_name: 'Brins de bruyere', card_interval_range_min: 12, card_interval_range_max: 15, pnj: 'erwan', arc: 'le_chant_des_cairns' },
  cotes_sauvages: { name: 'Cotes Sauvages', subtitle: 'Ou la mer defie la terre', season: 'ete', difficulty: 1, maturity_threshold: 15, oghams_affinity: ['muin', 'nuin', 'tinne'], currency_name: 'Coquillages', card_interval_range_min: 12, card_interval_range_max: 15, pnj: 'maelle', arc: 'le_signal_de_sein' },
  villages_celtes: { name: 'Villages Celtes', subtitle: 'Ou les hommes forment le destin', season: 'ete', difficulty: 2, maturity_threshold: 25, oghams_affinity: ['duir', 'coll', 'beith'], currency_name: 'Pieces de cuivre', card_interval_range_min: 10, card_interval_range_max: 14, pnj: 'cadogan', arc: 'le_puits_des_souhaits' },
  cercles_pierres: { name: 'Cercles de Pierres', subtitle: 'Ou le temps se fissure', season: 'printemps', difficulty: 3, maturity_threshold: 30, oghams_affinity: ['ioho', 'straif', 'ruis'], currency_name: 'Fragments de rune', card_interval_range_min: 10, card_interval_range_max: 14, pnj: 'brennos', arc: 'l_alignement_perdu' },
  marais_korrigans: { name: 'Marais des Korrigans', subtitle: 'Ou la lumiere ment', season: 'automne', difficulty: 3, maturity_threshold: 40, oghams_affinity: ['gort', 'eadhadh', 'luis'], currency_name: 'Pierres phosphorescentes', card_interval_range_min: 10, card_interval_range_max: 14, pnj: 'gwen_du', arc: 'le_tertre_du_silence' },
  collines_dolmens: { name: 'Collines aux Dolmens', subtitle: 'Ou les morts veillent', season: 'hiver', difficulty: 4, maturity_threshold: 50, oghams_affinity: ['quert', 'ailm', 'coll'], currency_name: 'Os graves', card_interval_range_min: 8, card_interval_range_max: 12, pnj: 'ildiko', arc: 'la_voix_de_l_if' },
  iles_mystiques: { name: 'Iles Mystiques', subtitle: 'Ou le monde visible s\'acheve', season: 'hiver', difficulty: 5, maturity_threshold: 75, oghams_affinity: ['ailm', 'ruis', 'ioho'], currency_name: 'Ecume solidifiee', card_interval_range_min: 8, card_interval_range_max: 12, pnj: 'morgane', arc: 'le_passage_d_avalon' },
} as const;

export const BIOME_DEFAULT = 'foret_broceliande';

// --- POWER MILESTONES ---
export const POWER_MILESTONES: Record<number, { type: string; value: number; label: string; desc: string }> = {
  5: { type: 'HEAL', value: 15, label: 'Vigueur retrouvee', desc: '+15 Vie' },
  10: { type: 'MINIGAME_BONUS', value: 5, label: 'Instinct aiguise', desc: '+5% minigame' },
  15: { type: 'HEAL', value: 10, label: 'Souffle du druide', desc: '+10 Vie' },
  20: { type: 'HEAL', value: 20, label: 'Benediction ancienne', desc: '+20 Vie' },
};
