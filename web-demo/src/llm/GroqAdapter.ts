// ===============================================================================
// GroqAdapter -- Cloud LLM for web deployment (OpenAI-compatible API)
// Fallback: FastRoute card generation if API key absent or request fails.
// ===============================================================================

import type { Card, CardOption } from '../game/CardSystem';

// --- Types ---

interface GroqMessage {
  readonly role: 'system' | 'user' | 'assistant';
  readonly content: string;
}

interface GroqChatRequest {
  readonly model: string;
  readonly messages: readonly GroqMessage[];
  readonly temperature: number;
  readonly max_tokens: number;
  readonly response_format?: { readonly type: string };
}

interface GroqChatResponse {
  readonly choices: readonly {
    readonly message: {
      readonly content: string;
    };
  }[];
}

// --- Card-level effect caps (mirrors GAME_DESIGN_BIBLE v2.4 per-option limits) ---
// These are tighter than the engine-level EFFECT_CAPS and apply to raw LLM output.
const LLM_EFFECT_CAPS: Record<string, number> = {
  HEAL_LIFE: 5,
  DAMAGE_LIFE: 5,
  ADD_REPUTATION: 10,
  ADD_ANAM: 10,
  ADD_BIOME_CURRENCY: 10,
} as const;

/**
 * Clamp a raw effect string's numeric value to the card-level cap.
 * Format: "CODE:N" or "CODE:faction:N". Returns the effect unchanged if unknown.
 */
function sanitizeEffectCap(effect: string): string {
  const parts = effect.split(':');
  if (parts.length === 0) return effect;
  const code = parts[0];
  const cap = LLM_EFFECT_CAPS[code];
  if (cap === undefined) return effect;

  // ADD_REPUTATION:faction:N — value is parts[2]
  if (code === 'ADD_REPUTATION' && parts.length === 3) {
    const raw = parseInt(parts[2], 10);
    if (isNaN(raw)) return effect;
    const clamped = Math.max(-cap, Math.min(cap, raw));
    return `${code}:${parts[1]}:${clamped}`;
  }

  // CODE:N — value is parts[1]
  if (parts.length === 2) {
    const raw = parseInt(parts[1], 10);
    if (isNaN(raw)) return effect;
    const clamped = Math.min(cap, Math.abs(raw));
    return `${code}:${clamped}`;
  }

  return effect;
}

// --- Config ---

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
// C157: llama-3.1-8b-instant — faster & better instruction-following than llama3-8b-8192
// for structured JSON card generation (lower latency under 8s timeout).
const GROQ_MODEL = 'llama-3.1-8b-instant';
const REQUEST_TIMEOUT_MS = 9000; // C157: slight increase for JSON mode overhead

// --- Adapter ---

export class GroqAdapter {
  private readonly apiKey: string;
  private readonly model: string;

  constructor(apiKey: string, model: string = GROQ_MODEL) {
    this.apiKey = apiKey;
    this.model = model;
  }

  /** Check if Groq is available (API key present). */
  static isAvailable(): boolean {
    const key = import.meta.env.VITE_GROQ_API_KEY;
    return typeof key === 'string' && key.length > 10;
  }

  /** Create instance from environment. Returns null if no API key. */
  static fromEnv(): GroqAdapter | null {
    const key = import.meta.env.VITE_GROQ_API_KEY;
    if (!key || typeof key !== 'string' || key.length < 10) return null;
    return new GroqAdapter(key);
  }

  /**
   * Generate a narrative card via Groq LLM.
   * Returns null on any failure (caller should fallback to FastRoute).
   */
  async generateCard(biome: string, context: string): Promise<Card | null> {
    // C157: per-biome atmosphere injected into system prompt for thematic variety
    const biomeAtmosphere: Readonly<Record<string, string>> = {
      cotes_sauvages:    'Falaises bretonnes battues par les vents, embruns marins, mouettes en vol.',
      foret_broceliande: 'Foret profonde et mystique de Broceliande, lucioles, chenes millenaires, murmures anciens, pierres oghamiques.',
      marais_korrigans:  'Marecages gluants hantes par les Korrigans, brume verte, feux follets, roseaux sifflants.',
      landes_bruyere:    'Landes desertes de bruyere violette, vent mordant, crows tournoyants, megalithes dresses.',
      cercles_pierres:   'Cercle de menhirs sous la pleine lune, energie leyline palpable, ombres dansantes, silence sacre.',
      villages_celtes:   'Village celtique anime, forge, marche aux herbes, druides en errance, enfants jouant entre les huttes.',
      collines_dolmens:  'Collines aux tombes ancestrales, dolmens moussus, vent qui porte les voix des ancetres, herbe haute.',
      iles_mystiques:    'Ile brumeuse au large, phoque qui parle, plage de gales noirs, cimetiere marin, lumiere etrange.',
    };
    const atmosphere = biomeAtmosphere[biome] ?? 'Paysage celtique mysterieux de Bretagne.';

    const systemPrompt = `Tu es le narrateur du jeu de cartes celtique MERLIN. Atmosphère: ${atmosphere}
Reponds UNIQUEMENT en JSON valide avec cette structure exacte (pas de texte avant ou apres):
{"narrative":"Description de la scene (40-80 mots, style celtique poetique, present de narration)","options":[{"verb":"observer","text":"Action 1 (10-20 mots)","field":"observation","effects":["HEAL_LIFE:3"]},{"verb":"negocier","text":"Action 2","field":"bluff","effects":["ADD_REPUTATION:druides:5"]},{"verb":"fuir","text":"Action 3","field":"vigueur","effects":["DAMAGE_LIFE:2"]}]}
Verbes autorises: observer,ecouter,chercher,examiner,negocier,mentir,bluffer,flatter,resoudre,analyser,deduire,calculer,crocheter,esquiver,sculpter,doser,frapper,soulever,pousser,briser,mediter,chanter,invoquer,prier,deviner,sentir,toucher,gouter,lancer,parier,defier,improviser,persuader,consoler,inspirer,menacer,voler,trahir,seduire,dissimuler,contourner,sacrifier,attendre,avancer,fuir.
Champs lexicaux: observation,bluff,logique,finesse,vigueur,esprit,perception,chance.
Factions: druides,anciens,korrigans,niamh,ankou.
Effets: HEAL_LIFE:N(max 5),DAMAGE_LIFE:N(max 5),ADD_REPUTATION:faction:N(max 10),ADD_ANAM:N.
REGLES: exactement 3 options, chaque option 1-2 effets, verbes de la liste uniquement, JSON pur sans markdown.`;

    const userPrompt = `Biome: ${biome}. ${context}. Genere une rencontre unique et coherente avec l'atmosphere.`;

    try {
      // C157: pass jsonMode=true — Groq JSON mode prevents LLM from wrapping output in markdown
      const response = await this.chatCompletion([
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ], 0.8, 600, true);

      if (!response) return null;

      const parsed = JSON.parse(response);
      if (!parsed.narrative || !Array.isArray(parsed.options) || parsed.options.length !== 3) {
        console.warn('[GroqAdapter] Invalid card structure from LLM');
        return null;
      }

      // Sanitize LLM effect values against card-level caps to prevent hallucinated large values.
      // Engine-level scaleAndCap() applies a second cap, but raw card data should be clean.
      const sanitizedOptions = (parsed.options as CardOption[]).map((opt) => ({
        ...opt,
        effects: (opt.effects as string[]).map((eff) => sanitizeEffectCap(eff)),
      }));

      return {
        id: `card_groq_${Date.now()}`,
        narrative: parsed.narrative,
        options: sanitizedOptions as unknown as readonly [CardOption, CardOption, CardOption],
        biome,
        source: 'llm',
      };
    } catch (err: unknown) {
      console.warn('[GroqAdapter] Card generation failed:', err instanceof Error ? err.message : err);
      return null;
    }
  }

  /**
   * Generate narrative text (e.g., Merlin greeting, encounter flavor).
   * Returns null on failure.
   */
  async generateNarrative(prompt: string, maxTokens: number = 200): Promise<string | null> {
    try {
      return await this.chatCompletion([
        { role: 'system', content: 'Tu es Merlin, druide sage et malicieux de Broceliande. Reponds en francais, style celtique poetique, 2-4 phrases.' },
        { role: 'user', content: prompt },
      ], 0.9, maxTokens);
    } catch (err: unknown) {
      console.warn('[GroqAdapter] Narrative generation failed:', err instanceof Error ? err.message : err);
      return null;
    }
  }

  /** Low-level chat completion call.
   * @param jsonMode - if true, sets response_format to json_object (card generation only)
   */
  private async chatCompletion(
    messages: readonly GroqMessage[],
    temperature: number = 0.7,
    maxTokens: number = 400,
    jsonMode: boolean = false,
  ): Promise<string | null> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

    try {
      const body: GroqChatRequest = {
        model: this.model,
        messages,
        temperature,
        max_tokens: maxTokens,
        ...(jsonMode ? { response_format: { type: 'json_object' } } : {}),
      };

      const response = await fetch(GROQ_API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      if (!response.ok) {
        console.warn(`[GroqAdapter] HTTP ${response.status}: ${response.statusText}`);
        return null;
      }

      const data = await response.json() as GroqChatResponse;
      const content = data.choices?.[0]?.message?.content;
      return content ?? null;
    } catch (err: unknown) {
      if (err instanceof Error && err.name === 'AbortError') {
        console.warn('[GroqAdapter] Request timed out');
      }
      return null;
    } finally {
      clearTimeout(timeout);
    }
  }
}

// --- LLM Manager (singleton pattern) ---

let _instance: GroqAdapter | null | undefined;

/** Get the Groq adapter if available, or null for FastRoute fallback. */
export function getLLMAdapter(): GroqAdapter | null {
  if (_instance === undefined) {
    _instance = GroqAdapter.fromEnv();
    if (_instance) {
      console.info('[MERLIN] Groq LLM adapter initialized (cloud mode)');
    } else {
      console.info('[MERLIN] No Groq API key — using FastRoute fallback');
    }
  }
  return _instance;
}
