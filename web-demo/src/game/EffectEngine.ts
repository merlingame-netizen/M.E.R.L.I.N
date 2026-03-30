// ═══════════════════════════════════════════════════════════════════════════════
// Effect Engine — Parses and applies effect strings (port from merlin_effect_engine.gd)
// ═══════════════════════════════════════════════════════════════════════════════

import { store, type MerlinStore } from './Store';
import { EFFECT_CAPS, getMultiplier, type FactionId, FACTIONS, OGHAM_SPECS } from './Constants';

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

// --- Ogham Effect Execution ---

export interface OghamEffectResult {
  readonly oghamId: string;
  readonly effectType: string;
  readonly applied: boolean;
  readonly description: string;
}

/**
 * Apply the active ogham's effect. Called after ogham selection but before
 * card effects. Returns the result describing what happened.
 *
 * Some oghams modify card effects (handled in applyEffects via store flags),
 * while others have immediate effects applied here.
 */
export function applyOghamEffect(oghamId: string): OghamEffectResult {
  const spec = OGHAM_SPECS[oghamId];
  if (!spec) {
    return { oghamId, effectType: 'unknown', applied: false, description: 'Ogham inconnu' };
  }

  const s = store.getState();
  const params = spec.effect_params;

  switch (spec.effect) {
    case 'heal_immediate': {
      // Quert (+8 PV) or Duir (+12 PV)
      const amount = (params.amount as number) ?? 8;
      const capped = scaleAndCap('HEAL_LIFE', amount, 1.0);
      s.healLife(capped);
      return { oghamId, effectType: spec.effect, applied: true, description: `+${capped} PV` };
    }

    case 'add_biome_currency': {
      // Onn (+10 monnaie biome)
      const amount = (params.amount as number) ?? 10;
      const capped = scaleAndCap('ADD_BIOME_CURRENCY', amount, 1.0);
      s.addBiomeCurrency(capped);
      return { oghamId, effectType: spec.effect, applied: true, description: `+${capped} monnaie` };
    }

    case 'currency_and_heal': {
      // Saille (+8 monnaie +3 PV)
      const currency = (params.currency as number) ?? 8;
      const heal = (params.heal as number) ?? 3;
      s.addBiomeCurrency(scaleAndCap('ADD_BIOME_CURRENCY', currency, 1.0));
      s.healLife(scaleAndCap('HEAL_LIFE', heal, 1.0));
      return { oghamId, effectType: spec.effect, applied: true, description: `+${currency} monnaie, +${heal} PV` };
    }

    case 'heal_and_cost': {
      // Ruis (+18 PV, -5 monnaie)
      const healAmt = (params.heal as number) ?? 18;
      const cost = (params.currency_cost as number) ?? 5;
      s.healLife(scaleAndCap('HEAL_LIFE', healAmt, 1.0));
      // Currency can go negative as a cost
      s.addBiomeCurrency(-cost);
      return { oghamId, effectType: spec.effect, applied: true, description: `+${healAmt} PV, -${cost} monnaie` };
    }

    case 'sacrifice_trade': {
      // Ur (-15 PV, +20 monnaie, score buff stored as flag)
      const lifeCost = (params.life_cost as number) ?? 15;
      const currencyGain = (params.currency_gain as number) ?? 20;
      s.damageLife(lifeCost);
      s.addBiomeCurrency(scaleAndCap('ADD_BIOME_CURRENCY', currencyGain, 1.0));
      return { oghamId, effectType: spec.effect, applied: true, description: `-${lifeCost} PV, +${currencyGain} monnaie` };
    }

    // --- Effects that modify upcoming card processing ---
    // These set the activeOgham flag which is checked during card effect application.

    case 'block_first_negative':
      // Luis: handled by filterNegativeEffects in game loop
      return { oghamId, effectType: spec.effect, applied: true, description: 'Bloque le prochain effet negatif' };

    case 'cancel_all_negatives':
      // Eadhadh: all negatives blocked — handled in game loop
      return { oghamId, effectType: spec.effect, applied: true, description: 'Annule tous les effets negatifs' };

    case 'reduce_high_damage':
      // Gort: damage > threshold reduced — handled in game loop
      return { oghamId, effectType: spec.effect, applied: true, description: 'Reduit les gros degats' };

    case 'double_positives':
      // Tinne: double positive effects — handled in game loop
      return { oghamId, effectType: spec.effect, applied: true, description: 'Double les effets positifs' };

    case 'invert_effects':
      // Muin: swap positive/negative — handled in game loop
      return { oghamId, effectType: spec.effect, applied: true, description: 'Inverse positifs et negatifs' };

    case 'reveal_one_option':
      // Beith: UI-only effect — handled by card overlay
      return { oghamId, effectType: spec.effect, applied: true, description: 'Revele 1 option' };

    case 'reveal_all_options':
      // Coll: UI-only effect — handled by card overlay
      return { oghamId, effectType: spec.effect, applied: true, description: 'Revele toutes les options' };

    case 'predict_next':
      // Ailm: UI-only effect — handled by HUD
      return { oghamId, effectType: spec.effect, applied: true, description: 'Predit la prochaine carte' };

    case 'replace_worst_option':
    case 'regenerate_all_options':
    case 'force_twist':
    case 'full_reroll':
      // Narrative oghams — card generation modifiers, handled in game loop
      return { oghamId, effectType: spec.effect, applied: true, description: spec.description };

    default:
      return { oghamId, effectType: spec.effect, applied: false, description: 'Effet non implemente' };
  }
}

/**
 * Process effects list through active ogham modifiers.
 * Call this BEFORE applyEffects when an ogham is active.
 */
export function processOghamModifiers(
  effects: readonly string[],
  oghamId: string
): readonly string[] {
  const spec = OGHAM_SPECS[oghamId];
  if (!spec) return effects;

  switch (spec.effect) {
    case 'block_first_negative':
      return filterNegativeEffects(effects, 1);

    case 'cancel_all_negatives':
      return effects.filter((e) => !isNegativeEffect(e));

    case 'reduce_high_damage': {
      const threshold = (spec.effect_params.threshold as number) ?? 10;
      const reducedTo = (spec.effect_params.reduced_to as number) ?? 5;
      return effects.map((e) => {
        const parsed = parseEffect(e);
        if (!parsed.ok || parsed.code !== 'DAMAGE_LIFE') return e;
        const amount = Math.abs(parseInt(parsed.args[0], 10) || 0);
        if (amount > threshold) {
          return `DAMAGE_LIFE:${reducedTo}`;
        }
        return e;
      });
    }

    case 'double_positives':
      return effects.map((e) => {
        const parsed = parseEffect(e);
        if (!parsed.ok) return e;
        if (NEGATIVE_EFFECTS.includes(parsed.code as typeof NEGATIVE_EFFECTS[number])) return e;
        // Double numeric args for positive effects
        if (parsed.code === 'HEAL_LIFE') {
          const amount = parseInt(parsed.args[0], 10) || 0;
          return `HEAL_LIFE:${amount * 2}`;
        }
        if (parsed.code === 'ADD_REPUTATION') {
          const delta = parseInt(parsed.args[1], 10) || 0;
          if (delta > 0) return `ADD_REPUTATION:${parsed.args[0]}:${delta * 2}`;
        }
        if (parsed.code === 'ADD_ANAM') {
          const amount = parseInt(parsed.args[0], 10) || 0;
          return `ADD_ANAM:${amount * 2}`;
        }
        if (parsed.code === 'ADD_BIOME_CURRENCY') {
          const amount = parseInt(parsed.args[0], 10) || 0;
          return `ADD_BIOME_CURRENCY:${amount * 2}`;
        }
        return e;
      });

    case 'invert_effects':
      return effects.map((e) => {
        const parsed = parseEffect(e);
        if (!parsed.ok) return e;
        // Swap DAMAGE <-> HEAL
        if (parsed.code === 'DAMAGE_LIFE') {
          return `HEAL_LIFE:${parsed.args[0]}`;
        }
        if (parsed.code === 'HEAL_LIFE') {
          return `DAMAGE_LIFE:${parsed.args[0]}`;
        }
        // Invert reputation sign
        if (parsed.code === 'ADD_REPUTATION') {
          const delta = parseInt(parsed.args[1], 10) || 0;
          return `ADD_REPUTATION:${parsed.args[0]}:${-delta}`;
        }
        return e;
      });

    default:
      return effects;
  }
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
