// ===============================================================================
// GroqAdapter -- Cloud LLM for web deployment (OpenAI-compatible API)
// Fallback: FastRoute card generation if API key absent or request fails.
// ===============================================================================

import type { Card, CardOption } from '../game/CardSystem';

// --- Public types ---

export interface RunScenarioEvent {
  readonly position: number;  // 0–1 along the path
  readonly type: 'rencontre' | 'obstacle' | 'tresor' | 'danger' | 'mystere' | 'fin';
  readonly nom: string;
  readonly icone: string;
}

export interface RunScenario {
  readonly titre: string;
  readonly scenario: readonly string[];
  readonly events: readonly RunScenarioEvent[];
}

// --- Internal types ---

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
// C156: meta-llama/llama-4-scout-17b-16e-instruct — stronger instruction-following for
// reliable JSON card generation with correct effect codes and French Celtic narrative.
const GROQ_MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct';
// C156: 8s per attempt (retry×2 with temperature escalation — total budget ~26s before
// main.ts race timeout at 8s kicks in; retries run within GroqAdapter itself).
const REQUEST_TIMEOUT_MS = 8000;

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

  /** Create instance from environment or sessionStorage fallback. Returns null if no API key. */
  static fromEnv(): GroqAdapter | null {
    const envKey = import.meta.env.VITE_GROQ_API_KEY;
    if (envKey && typeof envKey === 'string' && envKey.length > 10) {
      return new GroqAdapter(envKey);
    }
    // Fallback: runtime-injected key stored in sessionStorage
    try {
      const stored = sessionStorage.getItem('merlin_groq_key');
      if (stored && stored.length > 10) return new GroqAdapter(stored);
    } catch {
      // sessionStorage unavailable (e.g., private browsing restriction)
    }
    return null;
  }

  /**
   * Generate a narrative card via Groq LLM.
   * Returns null on any failure (caller should fallback to FastRoute).
   */
  async generateCard(biome: string, context: string): Promise<Card | null> {
    // C156/C157: per-biome atmosphere injected into system prompt for thematic variety
    const biomeAtmosphere: Readonly<Record<string, string>> = {
      cotes_sauvages:    'Falaises bretonnes battues par les vents, embruns marins, mouettes en vol.',
      foret_broceliande: 'Foret profonde et mystique de Broceliande, lucioles, chenes millenaires, murmures anciens, pierres oghamiques.',
      marais_korrigans:  'Marecages gluants hantes par les Korrigans, brume verte, feux follets, roseaux sifflants.',
      landes_bruyere:    'Landes desertes de bruyere violette, vent mordant, corbeaux tournoyants, megalithes dresses.',
      cercles_pierres:   'Cercle de menhirs sous la pleine lune, energie leyline palpable, ombres dansantes, silence sacre.',
      villages_celtes:   'Village celtique anime, forge, marche aux herbes, druides en errance, enfants jouant entre les huttes.',
      collines_dolmens:  'Collines aux tombes ancestrales, dolmens moussus, vent qui porte les voix des ancetres, herbe haute.',
      iles_mystiques:    'Ile brumeuse au large, phoque qui parle, plage de galets noirs, cimetiere marin, lumiere etrange.',
    };
    const atmosphere = biomeAtmosphere[biome] ?? 'Paysage celtique mysterieux de Bretagne.';

    // C156: more explicit JSON schema with filled example values to anchor LLM output format.
    // Three-attempt retry with temperature escalation: 0.7 (strict) → 0.9 → 1.0 (creative fallback).
    const systemPrompt = `Tu es le narrateur du jeu de cartes MERLIN (celtique bretagne). Atmosphere: ${atmosphere}
REGLE ABSOLUE: Reponds UNIQUEMENT avec du JSON valide. Aucun texte, aucun markdown, aucune explication. Le JSON doit commencer par { et finir par }.

Structure JSON obligatoire (copie exactement les champs, remplace seulement les valeurs):
{"narrative":"[40-80 mots en francais, style poetique celtique, present de narration, decrit la scene]","options":[{"verb":"observer","text":"[10-20 mots, action concrete du joueur]","field":"observation","effects":["HEAL_LIFE:3"]},{"verb":"negocier","text":"[10-20 mots]","field":"bluff","effects":["ADD_REPUTATION:druides:5"]},{"verb":"fuir","text":"[10-20 mots]","field":"vigueur","effects":["DAMAGE_LIFE:2"]}]}

Verbes autorises (choisir dans cette liste uniquement): observer,ecouter,chercher,examiner,negocier,mentir,bluffer,flatter,resoudre,analyser,deduire,calculer,crocheter,esquiver,sculpter,doser,frapper,soulever,pousser,briser,mediter,chanter,invoquer,prier,deviner,sentir,toucher,gouter,lancer,parier,defier,improviser,persuader,consoler,inspirer,menacer,voler,trahir,seduire,dissimuler,contourner,sacrifier,attendre,avancer,fuir
Champs (field): observation,bluff,logique,finesse,vigueur,esprit,perception,chance
Factions (pour ADD_REPUTATION): druides,anciens,korrigans,niamh,ankou
Effets valides: HEAL_LIFE:N (N=1-5), DAMAGE_LIFE:N (N=1-5), ADD_REPUTATION:faction:N (N=1-10), ADD_ANAM:N (N=1-5)
Contraintes: exactement 3 options, 1-2 effets par option, verbes differents, JSON pur.`;

    const userPrompt = `Biome: ${biome}. Contexte: ${context}. Genere une rencontre narrative unique.`;

    // C156: retry×2 with temperature escalation — 0.7 (precise) → 0.9 → 1.0 (creative)
    const temperatures = [0.7, 0.9, 1.0] as const;
    for (let attempt = 0; attempt < temperatures.length; attempt++) {
      const temp = temperatures[attempt]!;
      try {
        const response = await this.chatCompletion([
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ], temp, 650, true);

        if (!response) {
          console.info(`[MERLIN] GroqAdapter card attempt ${attempt + 1} returned empty — retrying`);
          continue;
        }

        let parsed: unknown;
        try {
          // Strip accidental markdown fences if model wraps despite json_object mode
          const cleaned = response.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
          parsed = JSON.parse(cleaned);
        } catch {
          console.info(`[MERLIN] GroqAdapter card attempt ${attempt + 1} JSON parse failed — retrying`);
          continue;
        }

        const p = parsed as Record<string, unknown>;
        if (!p['narrative'] || !Array.isArray(p['options']) || (p['options'] as unknown[]).length !== 3) {
          console.info(`[MERLIN] GroqAdapter card attempt ${attempt + 1} invalid structure — retrying`);
          continue;
        }

        // Sanitize LLM effect values against card-level caps
        const sanitizedOptions = (p['options'] as CardOption[]).map((opt) => ({
          ...opt,
          effects: (opt.effects as string[]).map((eff) => sanitizeEffectCap(eff)),
        }));

        return {
          id: `card_groq_${Date.now()}`,
          narrative: p['narrative'] as string,
          options: sanitizedOptions as unknown as readonly [CardOption, CardOption, CardOption],
          biome,
          source: 'llm',
        };
      } catch (err: unknown) {
        console.info(`[MERLIN] GroqAdapter card attempt ${attempt + 1} failed:`, err instanceof Error ? err.message : err);
      }
    }

    console.warn('[MERLIN] GroqAdapter generateCard: all 3 attempts failed — returning null for FastRoute fallback');
    return null;
  }

  /**
   * Generate a run scenario: title + narrative paragraphs + event list for map placement.
   * Returns structured JSON or null on failure (caller uses procedural fallback).
   */
  async generateRunScenario(biome: string): Promise<RunScenario | null> {
    const biomeLabels: Readonly<Record<string, string>> = {
      cotes_sauvages: 'les Côtes Sauvages de Bretagne',
      foret_broceliande: 'la Forêt Mystique de Brocéliande',
      marais_korrigans: 'les Marais des Korrigans',
      landes_bruyere: 'les Landes de Bruyère',
      cercles_pierres: 'les Cercles de Pierres Anciens',
      villages_celtes: 'les Villages Celtes',
      collines_dolmens: 'les Collines aux Dolmens',
      iles_mystiques: 'les Îles Mystiques',
    };
    const label = biomeLabels[biome] ?? 'un territoire celtique';

    const systemPrompt = `Tu es Merlin, narrateur du jeu de cartes celtique MERLIN. Génère le scénario d'une aventure dans ${label}.
Réponds UNIQUEMENT en JSON valide (pas de markdown) avec cette structure:
{"titre":"Titre court (4-6 mots)","scenario":["Paragraphe 1 (20-30 mots)","Paragraphe 2 (20-30 mots)","Paragraphe 3 (20-30 mots)"],"events":[{"position":0.15,"type":"rencontre","nom":"Nom court","icone":"◈"},{"position":0.35,"type":"obstacle","nom":"Nom court","icone":"⬟"},{"position":0.55,"type":"tresor","nom":"Nom court","icone":"◇"},{"position":0.75,"type":"danger","nom":"Nom court","icone":"⬡"},{"position":0.92,"type":"fin","nom":"Nom court","icone":"⊕"}]}
Types d'événements: rencontre, obstacle, tresor, danger, mystere, fin.
Style: celtique poetique, present de narration, immersif. Noms liés au biome.`;

    try {
      const response = await this.chatCompletion(
        [{ role: 'user', content: systemPrompt }],
        0.85, 500, true,
      );
      if (!response) return null;
      const parsed = JSON.parse(response) as RunScenario;
      if (!parsed.titre || !Array.isArray(parsed.scenario) || !Array.isArray(parsed.events)) return null;
      return parsed;
    } catch (err: unknown) {
      console.warn('[GroqAdapter] Scenario generation failed:', err instanceof Error ? err.message : err);
      return null;
    }
  }

  /**
   * Generate a single druidic whisper from Merlin (cauldron zone).
   * Returns null on failure — caller falls back to static pool.
   */
  async generateMerlinWhisper(biome: string): Promise<string | null> {
    const messages: readonly GroqMessage[] = [
      {
        role: 'system',
        content: `Tu es Merlin, druide celte antique. Réponds avec UNE SEULE phrase mystérieuse et poétique en français (max 12 mots). Vocabulaire celte : ogham, brume, nemeton, awen, korrigan, brocéliande, sidhe. Pas de ponctuation de fin. Pas de guillemets.`,
      },
      {
        role: 'user',
        content: `Biome actuel : ${biome}. Un murmure du chaudron.`,
      },
    ];
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 4000);
      try {
        const res = await fetch(GROQ_API_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.apiKey}` },
          body: JSON.stringify({
            model: this.model,
            messages,
            temperature: 0.95,
            max_tokens: 40,
          } satisfies GroqChatRequest),
          signal: controller.signal,
        });
        if (!res.ok) return null;
        const data = await res.json() as GroqChatResponse;
        return data.choices[0]?.message.content?.trim() ?? null;
      } finally {
        clearTimeout(timeout);
      }
    } catch {
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

/**
 * Inject a Groq API key at runtime (from user settings modal).
 * Persists to sessionStorage (tab lifetime only) and resets the singleton.
 * Returns false if the key fails basic validation.
 */
export function injectAPIKey(key: string): boolean {
  if (!key || key.trim().length < 10) return false;
  const trimmed = key.trim();
  try {
    sessionStorage.setItem('merlin_groq_key', trimmed);
  } catch {
    // sessionStorage unavailable — key still usable in-memory this session
  }
  _instance = new GroqAdapter(trimmed);
  console.info('[MERLIN] Groq API key injected at runtime — cloud mode active');
  return true;
}

/**
 * Remove the runtime API key and revert to FastRoute fallback.
 */
export function clearAPIKey(): void {
  try { sessionStorage.removeItem('merlin_groq_key'); } catch { /* ignore */ }
  _instance = null;
  console.info('[MERLIN] Groq API key cleared — FastRoute fallback active');
}
