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

const VALID_FACTIONS: ReadonlySet<string> = new Set(['druides', 'niamh', 'korrigans', 'anciens', 'ankou']);
const VALID_EVENT_TYPES: ReadonlySet<string> = new Set(['rencontre', 'obstacle', 'tresor', 'danger', 'mystere', 'fin']);

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

/**
 * Validate and sanitize a single effect string.
 * Returns null if the effect is malformed or references an unknown faction.
 * Applies numeric caps via sanitizeEffectCap.
 */
function validateEffect(effect: string): string | null {
  if (typeof effect !== 'string' || effect.trim() === '') return null;
  const parts = effect.trim().split(':');
  const code = parts[0];

  if (code === 'ADD_REPUTATION') {
    // Must be ADD_REPUTATION:faction:N
    if (parts.length !== 3) return null;
    if (!VALID_FACTIONS.has(parts[1])) return null;
    if (isNaN(parseInt(parts[2], 10))) return null;
    return sanitizeEffectCap(effect.trim());
  }

  if (code === 'HEAL_LIFE' || code === 'DAMAGE_LIFE' || code === 'ADD_ANAM' || code === 'ADD_BIOME_CURRENCY') {
    if (parts.length !== 2) return null;
    if (isNaN(parseInt(parts[1], 10))) return null;
    return sanitizeEffectCap(effect.trim());
  }

  // Unknown effect code — drop silently
  return null;
}

/**
 * Sanitize a raw CardOption from LLM output.
 * Applies fallbacks for missing verb/text and strips invalid effects.
 */
function sanitizeOption(raw: Record<string, unknown>, index: number): import('../game/CardSystem').CardOption {
  const verb = (typeof raw['verb'] === 'string' && raw['verb'].trim().length > 0)
    ? raw['verb'].trim().toUpperCase()
    : 'CHOISIR';

  const text = (typeof raw['text'] === 'string' && raw['text'].trim().length > 0)
    ? raw['text'].trim()
    : 'Le druide hésite.';

  const field = (typeof raw['field'] === 'string' && raw['field'].trim().length > 0)
    ? raw['field'].trim()
    : 'esprit';

  const rawEffects = Array.isArray(raw['effects']) ? (raw['effects'] as unknown[]) : [];
  const effects = rawEffects
    .filter((e): e is string => typeof e === 'string')
    .map((e) => validateEffect(e))
    .filter((e): e is string => e !== null)
    .slice(0, 2); // max 2 effects per option

  console.info(`[MERLIN LLM] option[${index}] verb=${verb} effects=[${effects.join(', ')}]`);
  return { verb, text, field, effects };
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
    // 3. Try localStorage (persisted across sessions with user consent)
    try {
      const persisted = localStorage.getItem('merlin_groq_key');
      if (persisted && persisted.trim().length >= 10) {
        return new GroqAdapter(persisted.trim());
      }
    } catch { /* localStorage unavailable */ }
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

    // C216: richer Celtic lore context — factions, ogham runes, sacred verbs, 2nd-person narrative.
    // Three-attempt retry with temperature escalation: 0.7 (strict) → 0.9 → 1.0 (creative fallback).
    const systemPrompt = `Tu es le narrateur du jeu MERLIN (Bretagne celtique). Atmosphere: ${atmosphere}
FACTIONS: Druides(sagesse/nature), Anciens(ancetres/temps), Korrigans(chaos/ruse), Niamh(eau/guerison), Ankou(mort/transformation).
RUNES OGHAM: Beith=nouveau-depart, Huath=epreuve, Ruis=metamorphose, Sail=intuition, Muin=secret, Gort=quete.
REGLE ABSOLUE: Reponds UNIQUEMENT avec du JSON valide. Pas de markdown. Commence par { et termine par }.

Structure JSON exacte:
{"narrative":"Vous [verbe]... UNE phrase 15-30 mots, present, 2e personne, atmosphere celtique.","options":[{"verb":"EXPLORER","text":"Vous explorez... 8-15 mots.","field":"observation","effects":["HEAL_LIFE:2"]},{"verb":"NEGOCIER","text":"Vous negociez... 8-15 mots.","field":"bluff","effects":["ADD_REPUTATION:druides:6"]},{"verb":"FUIR","text":"Vous fuyez... 8-15 mots.","field":"vigueur","effects":["DAMAGE_LIFE:2","ADD_REPUTATION:ankou:-4"]}]}

VERBES (1 mot MAJUSCULES, 3 DIFFERENTS parmi): EXPLORER, ECOUTER, CHERCHER, EXAMINER, NEGOCIER, PROTEGER, TRANSFORMER, GUERIR, INVOQUER, REVELER, DEFIER, SACRIFIER, MEDITER, CHANTER, PRIER, PERSUADER, BLUFFER, MENACER, ESQUIVER, ATTENDRE, FUIR, AVANCER, VOLER, BRISER, DEVINER

EFFETS (1 ou 2 par option, JAMAIS 0 ni plus de 2):
- HEAL_LIFE:N (1-5) | DAMAGE_LIFE:N (1-5)
- ADD_REPUTATION:faction:N — faction=druides|niamh|korrigans|anciens|ankou, N entre -10 et 10

FIELD parmi: observation|bluff|logique|finesse|vigueur|esprit|perception|chance`;

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

        // Validate narrative field
        if (!p['narrative'] || typeof p['narrative'] !== 'string') {
          console.info(`[MERLIN LLM] card attempt ${attempt + 1} missing narrative — retrying`);
          continue;
        }

        // Validate and fixup options array
        if (!Array.isArray(p['options'])) {
          console.info(`[MERLIN LLM] card attempt ${attempt + 1} options not an array — retrying`);
          continue;
        }

        let rawOptions = p['options'] as Record<string, unknown>[];

        // Count fixup — silent correction
        if (rawOptions.length < 2) {
          console.info(`[MERLIN LLM] card attempt ${attempt + 1} only ${rawOptions.length} options — retrying`);
          continue;
        }
        if (rawOptions.length > 3) {
          console.info(`[MERLIN LLM] card attempt ${attempt + 1} ${rawOptions.length} options — trimming to 3`);
          rawOptions = rawOptions.slice(0, 3);
        }
        if (rawOptions.length === 2) {
          // Duplicate 3rd option with a variation to reach exactly 3
          console.info(`[MERLIN LLM] card attempt ${attempt + 1} only 2 options — duplicating 3rd`);
          rawOptions = [...rawOptions, { ...rawOptions[1], verb: 'ATTENDRE', text: 'Le druide observe en silence.' }];
        }

        // Sanitize each option (fallbacks + effect validation)
        const sanitizedOptions = rawOptions.map((opt, i) =>
          sanitizeOption(opt, i),
        );

        return {
          id: `card_groq_${Date.now()}`,
          narrative: (p['narrative'] as string).trim(),
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
      cotes_sauvages:    'les Côtes Sauvages de Bretagne',
      foret_broceliande: 'la Forêt Mystique de Brocéliande',
      marais_korrigans:  'les Marais des Korrigans',
      landes_bruyere:    'les Landes de Bruyère',
      cercles_pierres:   'les Cercles de Pierres Anciens',
      villages_celtes:   'les Villages Celtes',
      collines_dolmens:  'les Collines aux Dolmens',
      iles_mystiques:    'les Îles Mystiques',
    };
    // C216: biome-specific keywords injected into scenario prompt for thematic immersion
    const BIOME_KEYWORDS: Readonly<Record<string, string>> = {
      foret_broceliande: 'chênes millénaires, brume matinale, cerfs blancs, fontaines magiques',
      marais_korrigans:  'marécages sombres, feux follets, chants stridents, boue ancestrale',
      landes_bruyere:    'vent du large, bruyères violettes, menhirs oubliés, horizons infinis',
      cercles_pierres:   'pierres dressées, alignements astrologiques, sacrifices anciens',
      monts_brumeux:     'sommets perdus dans les nuages, aigles royaux, vents glacials',
      plaine_druides:    'prairies sacrées, feux rituels, cérémonies nocturnes, gui blanc',
      vallee_anciens:    'ruines celtes, ancêtres endormis, artefacts enfouis, portes du temps',
      cotes_sauvages:    'falaises battues, marée noire, phares abandonnés, naufrages oubliés',
      villages_celtes:   'forge rougeoyante, marché aux herbes, druides en errance, huttes de torchis',
      collines_dolmens:  'dolmens moussus, vent portant les voix des ancêtres, herbe haute, silence',
      iles_mystiques:    'phoque qui parle, plage de galets noirs, cimetière marin, lumière étrange',
    };
    const label = biomeLabels[biome] ?? 'un territoire celtique';
    const keywords = BIOME_KEYWORDS[biome] ?? 'lieux anciens, brume celtique, présences invisibles';

    const systemPrompt = `Tu es Merlin, narrateur du jeu de cartes celtique MERLIN. Génère le scénario d'une aventure dans ${label}.
Mots-clés du biome à utiliser: ${keywords}.
Réponds UNIQUEMENT en JSON valide (pas de markdown) avec cette structure — EXACTEMENT 5 events aux positions indiquées:
{"titre":"Titre évocateur 4-6 mots","scenario":["Vous pénétrez dans... (20-30 mots, 2e personne, présent)","Un signe ancien... (20-30 mots)","La quête s'épaissit... (20-30 mots)"],"events":[{"position":0.15,"type":"rencontre","nom":"Nom thématique court","icone":"◈"},{"position":0.35,"type":"obstacle","nom":"Nom thématique court","icone":"⬟"},{"position":0.55,"type":"tresor","nom":"Nom thématique court","icone":"◇"},{"position":0.75,"type":"danger","nom":"Nom thématique court","icone":"⬡"},{"position":0.92,"type":"fin","nom":"Nom thématique court","icone":"⊕"}]}
Types valides: rencontre, obstacle, tresor, danger, mystere, fin. Noms courts et liés au biome. Style: poétique, celtique, immersif.`;

    try {
      const response = await this.chatCompletion(
        [{ role: 'user', content: systemPrompt }],
        0.85, 500, true,
      );
      if (!response) return null;

      let parsed: Record<string, unknown>;
      try {
        const cleaned = response.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
        parsed = JSON.parse(cleaned) as Record<string, unknown>;
      } catch {
        console.info('[MERLIN LLM] generateRunScenario JSON parse failed — using procedural fallback');
        return null;
      }

      if (!parsed['titre'] || !Array.isArray(parsed['scenario']) || !Array.isArray(parsed['events'])) {
        console.info('[MERLIN LLM] generateRunScenario invalid structure — using procedural fallback');
        return null;
      }

      // Validate and filter events
      const validEvents = (parsed['events'] as unknown as RunScenarioEvent[]).filter((ev) => {
        if (typeof ev !== 'object' || ev === null) return false;
        if (!VALID_EVENT_TYPES.has(ev['type'] as string)) {
          console.info(`[MERLIN LLM] dropping event with unknown type: ${ev['type']}`);
          return false;
        }
        const pos = ev['position'];
        if (typeof pos !== 'number' || pos < 0 || pos > 1) {
          console.info(`[MERLIN LLM] dropping event with invalid position: ${pos}`);
          return false;
        }
        return true;
      }) as RunScenarioEvent[];

      if (validEvents.length === 0) {
        console.info('[MERLIN LLM] generateRunScenario no valid events — using procedural fallback');
        return null;
      }

      return {
        titre: String(parsed['titre']),
        scenario: (parsed['scenario'] as unknown[]).map(String),
        events: validEvents,
      };
    } catch (err: unknown) {
      console.warn('[MERLIN LLM] generateRunScenario failed:', err instanceof Error ? err.message : err);
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
        const raw = data.choices[0]?.message.content ?? null;
        if (!raw) return null;

        // Strip surrounding quotes, trim whitespace
        let whisper = raw.trim().replace(/^["«»""]|["«»""]$/g, '').trim();

        // Too short to be meaningful
        if (whisper.length < 5) return null;

        // Truncate to 80 chars max (at word boundary if possible)
        if (whisper.length > 80) {
          const cut = whisper.slice(0, 80).lastIndexOf(' ');
          whisper = cut > 40 ? whisper.slice(0, cut) : whisper.slice(0, 80);
        }

        return whisper;
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
  // Persist to localStorage if user opted in
  try {
    if (localStorage.getItem('merlin_groq_persist') === '1') {
      localStorage.setItem('merlin_groq_key', trimmed);
    }
  } catch { /* ignore */ }
  _instance = new GroqAdapter(trimmed);
  console.info('[MERLIN] Groq API key injected at runtime — cloud mode active');
  return true;
}

/**
 * Remove the runtime API key and revert to FastRoute fallback.
 */
export function clearAPIKey(): void {
  try {
    sessionStorage.removeItem('merlin_groq_key');
    localStorage.removeItem('merlin_groq_key');
    localStorage.removeItem('merlin_groq_persist');
  } catch { /* ignore */ }
  _instance = null;
  console.info('[MERLIN] Groq API key cleared — FastRoute fallback active');
}
