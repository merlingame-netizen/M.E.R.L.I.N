// ═══════════════════════════════════════════════════════════════════════════════
// MinigameRegistry — lazy-loaded barrel for all 14 minigames.
// Imported via a single dynamic import() in main.ts so Rollup bundles all
// minigame code into one deferred chunk, fetched only when the player enters
// the first run (not at boot / menu / lair).
// ═══════════════════════════════════════════════════════════════════════════════

import { MinigameTraces }       from './mg_traces';
import { MinigameRunes }        from './mg_runes';
import { MinigameEquilibre }    from './mg_equilibre';
import { MinigameHerboristerie }from './mg_herboristerie';
import { MinigameNegociation }  from './mg_negociation';
import { MinigameCombatRituel } from './mg_combat_rituel';
import { MinigameApaisement }   from './mg_apaisement';
import { MinigameSangFroid }    from './mg_sang_froid';
import { MinigameCourse }       from './mg_course';
import { MinigameFouille }      from './mg_fouille';
import { MinigameOmbres }       from './mg_ombres';
import { MinigameVolonte }      from './mg_volonte';
import { MinigameRegard }       from './mg_regard';
import { MinigameEcho }         from './mg_echo';

export function createMinigameById(id: string, container: HTMLElement) {
  switch (id) {
    case 'runes':         return new MinigameRunes(container);
    case 'equilibre':     return new MinigameEquilibre(container);
    case 'herboristerie': return new MinigameHerboristerie(container);
    case 'negociation':   return new MinigameNegociation(container);
    case 'combat_rituel': return new MinigameCombatRituel(container);
    case 'apaisement':    return new MinigameApaisement(container);
    case 'sang_froid':    return new MinigameSangFroid(container);
    case 'course':        return new MinigameCourse(container);
    case 'fouille':       return new MinigameFouille(container);
    case 'ombres':        return new MinigameOmbres(container);
    case 'volonte':       return new MinigameVolonte(container);
    case 'regard':        return new MinigameRegard(container);
    case 'echo':          return new MinigameEcho(container);
    case 'traces':
    default:              return new MinigameTraces(container);
  }
}
