// ═══════════════════════════════════════════════════════════════════════════════
// Effect Engine — Parses and applies effect strings (port from merlin_effect_engine.gd)
// ═══════════════════════════════════════════════════════════════════════════════

import { store, type MerlinStore } from './Store';
import { EFFECT_CAPS, getMultiplier, type FactionId, FACTIONS } from './Constants';

// Valid effect codes and their expected argument count
const VALID_CODES: Record<string, number> = {
  DAMAGE_LIFE: 1,
  HEAL_LIFE: 1,
  ADD_REPUTATION: 2,
  ADD_ANAM: 1,
  ADD_BIOME_CURRENCY: 1,
  ADD_KARMA: 1,
  ADD_TENSION: 1,
  PROGRESS_MISSION: 1,
  SET_FLAG: 2,
  ADD_TAG: 1,
  REMOVE_TAG: 1,
  ADD_PROMISE: 2,
  FULFILL_PROMISE: 1,
  BREAK_PROMISE: 1,
  UNLOCK_OGHAM: 1,
  PLAY_SFX: 1,
  SHOW_DIALOG: 1,
};

export const NEGATIVE_EFFECTS = ['DAMAGE_LIFE'] as const;

interface ParsedEffect {
  readonly ok: boolean;
  readonly code: string;
  readonly args: readonly string[];
  readonly error?: string;
}

function parseEffect(effectCode: string): ParsedEffect {
  const parts = effectCode.split(':');
  if (parts.length === 0) {
    return { ok: false, code: '', args: [], error: 'Empty effect' };
  }
  const code = parts[0];
  if (!(code in VALID_CODES)) {
    return { ok: false, code, args: [], error: `Unknown effect: ${code}` };
  }
  const expected = VALID_CODES[code];
  const args = parts.slice(1);
  if (args.length !== expected) {
    return { ok: false, code, args, error: `Bad arg count for ${code}: expected ${expected}, got ${args.length}` };
  }
  return { ok: true, code, args };
}

function scaleAndCap(code: string, rawAmount: number, multiplier: number): number {
  const scaled = Math.round(rawAmount * Math.abs(multiplier));
  const capsMap: Record<string, { max?: number; min?: number }> = {
    ADD_REPUTATION: EFFECT_CAPS.ADD_REPUTATION,
    HEAL_LIFE: EFFECT_CAPS.HEAL_LIFE,
    HEAL_CRITICAL: EFFECT_CAPS.HEAL_CRITICAL,
    DAMAGE_LIFE: EFFECT_CAPS.DAMAGE_LIFE,
    DAMAGE_CRITICAL: EFFECT_CAPS.DAMAGE_CRITICAL,
    ADD_BIOME_CURRENCY: EFFECT_CAPS.ADD_BIOME_CURRENCY,
  };
  const cap = capsMap[code];
  if (!cap) return scaled;
  let result = scaled;
  if (cap.max !== undefined) result = Math.min(result, cap.max);
  if (cap.min !== undefined) result = Math.max(result, cap.min);
  return result;
}

export interface EffectResult {
  readonly applied: readonly string[];
  readonly rejected: readonly string[];
}

/** Apply a list of raw effect strings to the store. */
export function applyEffects(effects: readonly string[], multiplier = 1.0): EffectResult {
  const applied: string[] = [];
  const rejected: string[] = [];
  const s = store.getState();

  for (const effectStr of effects) {
    const parsed = parseEffect(effectStr);
    if (!parsed.ok) {
      rejected.push(effectStr);
      continue;
    }

    const { code, args } = parsed;

    switch (code) {
      case 'DAMAGE_LIFE': {
        const raw = Math.abs(parseInt(args[0], 10) || 0);
        const scaled = scaleAndCap(code, raw, multiplier);
        store.getState().damageLife(scaled);
        applied.push(effectStr);
        break;
      }
      case 'HEAL_LIFE': {
        const raw = parseInt(args[0], 10) || 0;
        const scaled = scaleAndCap(code, raw, multiplier);
        store.getState().healLife(scaled);
        applied.push(effectStr);
        break;
      }
      case 'ADD_REPUTATION': {
        const faction = args[0] as FactionId;
        if (!FACTIONS.includes(faction)) {
          rejected.push(effectStr);
          break;
        }
        const raw = parseInt(args[1], 10) || 0;
        const scaled = scaleAndCap(code, raw, multiplier);
        store.getState().addReputation(faction, multiplier < 0 ? -scaled : scaled);
        applied.push(effectStr);
        break;
      }
      case 'ADD_ANAM': {
        const raw = parseInt(args[0], 10) || 0;
        const scaled = scaleAndCap(code, raw, multiplier);
        store.getState().addAnam(scaled);
        applied.push(effectStr);
        break;
      }
      case 'ADD_BIOME_CURRENCY': {
        const raw = parseInt(args[0], 10) || 0;
        const scaled = scaleAndCap(code, raw, multiplier);
        store.getState().addBiomeCurrency(scaled);
        applied.push(effectStr);
        break;
      }
      case 'PLAY_SFX':
      case 'SHOW_DIALOG':
        // Fire-and-forget UI effects — handled by UI layer
        applied.push(effectStr);
        break;
      default:
        // Other effects: apply without scaling for now
        applied.push(effectStr);
        break;
    }
  }

  return { applied, rejected };
}

/** Validate an effect string without applying it. */
export function validateEffect(effectCode: string): boolean {
  return parseEffect(effectCode).ok;
}

/** Check if an effect code is negative (used by Ogham protection). */
export function isNegativeEffect(effectCode: string): boolean {
  const parsed = parseEffect(effectCode);
  if (!parsed.ok) return false;
  return NEGATIVE_EFFECTS.includes(parsed.code as typeof NEGATIVE_EFFECTS[number]);
}

/** Filter out negative effects (for protection Oghams like Luis). */
export function filterNegativeEffects(effects: readonly string[], count = 1): readonly string[] {
  let blocked = 0;
  return effects.filter((e) => {
    if (blocked >= count) return true;
    if (isNegativeEffect(e)) {
      blocked++;
      return false;
    }
    return true;
  });
}
