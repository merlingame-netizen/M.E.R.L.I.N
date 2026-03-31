// ═══════════════════════════════════════════════════════════════════════════════
// MERLIN Store — Central State Management (Zustand, immutable)
// Ported from merlin_store.gd — Redux-like pattern
// ═══════════════════════════════════════════════════════════════════════════════

import { createStore } from 'zustand/vanilla';
import {
  FACTIONS, type FactionId,
  LIFE_START, LIFE_MAX, LIFE_DRAIN_PER_CARD,
  LIFE_DRAIN_STAGE2, LIFE_DRAIN_STAGE3,
  LIFE_DRAIN_THRESHOLD_STAGE2, LIFE_DRAIN_THRESHOLD_STAGE3,
  FACTION_SCORE_START, FACTION_CAP_PER_CARD,
  OGHAM_STARTER_SKILLS, OGHAM_SPECS,
  BIOME_DEFAULT, MIN_CARDS_FOR_VICTORY,
  getMultiplier, getMultiplierLabel,
} from './Constants';

// --- Types ---

export type GamePhase = 'title' | 'hub' | 'walk' | 'card' | 'minigame' | 'end';

export interface RunState {
  readonly active: boolean;
  readonly biome: string;
  readonly life: number;
  readonly cardsPlayed: number;
  readonly day: number;
  readonly factions: Readonly<Record<FactionId, number>>;
  readonly activeOgham: string;
  readonly oghamCooldowns: Readonly<Record<string, number>>;
  readonly oghamsDiscovered: readonly string[];
  readonly promises: readonly Promise[];
  readonly karma: number;
  readonly tension: number;
  readonly biomeCurrency: number;
}

export interface Promise {
  readonly id: string;
  readonly madeAtCard: number;
  readonly deadlineCards: number;
  readonly status: 'active' | 'fulfilled' | 'expired' | 'broken';
}

export interface MetaState {
  readonly anam: number;
  readonly factionRep: Readonly<Record<FactionId, number>>;
  readonly totalRuns: number;
  readonly totalCardsPlayed: number;
  readonly endingsSeen: readonly string[];
  readonly oghamsUnlocked: readonly string[];
  readonly oghamsEquipped: readonly string[];
  readonly talentsUnlocked: readonly string[];
}

export interface GameState {
  readonly phase: GamePhase;
  readonly run: RunState;
  readonly meta: MetaState;
}

// --- Actions ---

export interface GameActions {
  setPhase: (phase: GamePhase) => void;
  startRun: (biome?: string) => void;
  damageLife: (amount: number) => void;
  healLife: (amount: number) => void;
  drainLife: () => void;
  /** Drain life by a scaled amount based on cards already played (T038). */
  drainLifeScaled: () => void;
  addReputation: (faction: FactionId, delta: number) => void;
  addAnam: (amount: number) => void;
  addBiomeCurrency: (amount: number) => void;
  incrementCardsPlayed: () => void;
  setActiveOgham: (oghamId: string) => void;
  useOgham: (oghamId: string) => boolean;
  tickCooldowns: () => void;
  endRun: (ending?: string) => void;
  checkDeath: () => boolean;
  reset: () => void;
}

// --- Default states ---

function buildDefaultFactions(): Record<FactionId, number> {
  const result = {} as Record<FactionId, number>;
  for (const f of FACTIONS) {
    result[f] = FACTION_SCORE_START;
  }
  return result;
}

function buildDefaultRun(): RunState {
  return {
    active: false,
    biome: BIOME_DEFAULT,
    life: LIFE_START,
    cardsPlayed: 0,
    day: 1,
    factions: buildDefaultFactions(),
    activeOgham: '',
    oghamCooldowns: {},
    oghamsDiscovered: [],
    promises: [],
    karma: 0,
    tension: 0,
    biomeCurrency: 0,
  };
}

function buildDefaultMeta(): MetaState {
  return {
    anam: 0,
    factionRep: buildDefaultFactions(),
    totalRuns: 0,
    totalCardsPlayed: 0,
    endingsSeen: [],
    oghamsUnlocked: [...OGHAM_STARTER_SKILLS],
    oghamsEquipped: [...OGHAM_STARTER_SKILLS],
    talentsUnlocked: [],
  };
}

function buildDefaultState(): GameState {
  return {
    phase: 'title',
    run: buildDefaultRun(),
    meta: buildDefaultMeta(),
  };
}

// --- Store ---

export type MerlinStore = GameState & GameActions;

export const store = createStore<MerlinStore>((set, get) => ({
  ...buildDefaultState(),

  setPhase: (phase) => set({ phase }),

  startRun: (biome = BIOME_DEFAULT) => set((s) => ({
    phase: 'walk' as GamePhase,
    run: {
      ...buildDefaultRun(),
      active: true,
      biome,
      factions: { ...s.meta.factionRep },
    },
  })),

  damageLife: (amount) => set((s) => ({
    run: {
      ...s.run,
      life: Math.max(0, s.run.life - Math.abs(amount)),
    },
  })),

  healLife: (amount) => set((s) => ({
    run: {
      ...s.run,
      life: Math.min(LIFE_MAX, s.run.life + Math.abs(amount)),
    },
  })),

  drainLife: () => set((s) => ({
    run: {
      ...s.run,
      life: Math.max(0, s.run.life - LIFE_DRAIN_PER_CARD),
    },
  })),

  drainLifeScaled: () => set((s) => {
    const played = s.run.cardsPlayed;
    const amount =
      played >= LIFE_DRAIN_THRESHOLD_STAGE3 ? LIFE_DRAIN_STAGE3 :
      played >= LIFE_DRAIN_THRESHOLD_STAGE2 ? LIFE_DRAIN_STAGE2 :
      LIFE_DRAIN_PER_CARD;
    return {
      run: {
        ...s.run,
        life: Math.max(0, s.run.life - amount),
      },
    };
  }),

  addReputation: (faction, delta) => set((s) => {
    const capped = Math.max(-FACTION_CAP_PER_CARD, Math.min(FACTION_CAP_PER_CARD, delta));
    const current = s.run.factions[faction] ?? 0;
    const newVal = Math.max(0, Math.min(100, current + capped));
    return {
      run: {
        ...s.run,
        factions: { ...s.run.factions, [faction]: newVal },
      },
      meta: {
        ...s.meta,
        factionRep: { ...s.meta.factionRep, [faction]: newVal },
      },
    };
  }),

  addAnam: (amount) => set((s) => ({
    meta: { ...s.meta, anam: s.meta.anam + amount },
  })),

  addBiomeCurrency: (amount) => set((s) => ({
    run: { ...s.run, biomeCurrency: s.run.biomeCurrency + amount },
  })),

  incrementCardsPlayed: () => set((s) => ({
    run: { ...s.run, cardsPlayed: s.run.cardsPlayed + 1 },
  })),

  setActiveOgham: (oghamId) => set((s) => ({
    run: { ...s.run, activeOgham: oghamId },
  })),

  useOgham: (oghamId) => {
    const s = get();
    const spec = OGHAM_SPECS[oghamId];
    if (!spec) return false;
    if (!s.meta.oghamsEquipped.includes(oghamId)) return false;
    if ((s.run.oghamCooldowns[oghamId] ?? 0) > 0) return false;

    set((s) => ({
      run: {
        ...s.run,
        activeOgham: oghamId,
        oghamCooldowns: { ...s.run.oghamCooldowns, [oghamId]: spec.cooldown },
      },
    }));
    return true;
  },

  tickCooldowns: () => set((s) => {
    const newCooldowns: Record<string, number> = {};
    for (const [key, val] of Object.entries(s.run.oghamCooldowns)) {
      const remaining = val - 1;
      if (remaining > 0) {
        newCooldowns[key] = remaining;
      }
    }
    return { run: { ...s.run, oghamCooldowns: newCooldowns } };
  }),

  endRun: (ending) => set((s) => ({
    phase: 'end' as GamePhase,
    run: { ...s.run, active: false },
    meta: {
      ...s.meta,
      totalRuns: s.meta.totalRuns + 1,
      totalCardsPlayed: s.meta.totalCardsPlayed + s.run.cardsPlayed,
      endingsSeen: ending ? [...s.meta.endingsSeen, ending] : s.meta.endingsSeen,
    },
  })),

  checkDeath: () => get().run.life <= 0,

  reset: () => set(buildDefaultState()),
}));

// --- Selectors ---

export const selectLife = (s: GameState) => s.run.life;
export const selectLifePercent = (s: GameState) => s.run.life / LIFE_MAX;
export const selectCardsPlayed = (s: GameState) => s.run.cardsPlayed;
export const selectPhase = (s: GameState) => s.phase;
export const selectIsRunActive = (s: GameState) => s.run.active;
export const selectBiome = (s: GameState) => s.run.biome;
export const selectFactions = (s: GameState) => s.run.factions;
export const selectAnam = (s: GameState) => s.meta.anam;
export const selectCanUseOgham = (s: GameState, oghamId: string) =>
  s.meta.oghamsEquipped.includes(oghamId) && (s.run.oghamCooldowns[oghamId] ?? 0) <= 0;
