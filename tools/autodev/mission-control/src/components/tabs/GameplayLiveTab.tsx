import { useCallback, useEffect, useMemo, useState, type ReactNode, type CSSProperties, type JSX } from 'react';

/**
 * GameplayLiveTab — v10 Dashboard "Gameplay Live" (user 2026-05-31 /goal).
 *
 * UI de pilotage live du jeu MERLIN tournant en Godot local. Lit l'état run (jauges, hand, scénario,
 * faits marquants) écrit par TweaksOverlay vers `user://dashboard_state.json` toutes les 1 s, et
 * permet d'éditer 4 axes gameplay avec hot-reload ≤500 ms : constantes (START_INTEGRITE / HAND_SIZE
 * / MAX_INTEGRITE / CORRUPTION_CAP), persona Merlin (appellations + executor_system overlay), forçage
 * de scénario, lecture du corpus 130 Brocéliande. Bridge local-only servi par godotBridgePlugin
 * (vite.config.ts) — déploiement Vercel reçoit gracefully l'erreur HTTP.
 */

interface CardSnap {
  name: string;  // aligned with MerlinCard.to_dict() in merlin_card.gd:27 (review HIGH #2 2026-06-05)
  id?: string;
  evocation?: string;
  rarity?: string;
  archetype?: string;  // v10.5 : archétype d'effet dérivé (Offensif/Défensif/Social/Mystique/Corrompu)
  tags: string[];
  corruption: number;
}

interface RunState {
  integrite: number;
  max_integrite: number;
  corruption: number;
  corruption_cap: number;
  beat_index: number;
  scenario: { title: string; total: number; pitch: string };
  hand: CardSnap[];
  discard_count: number;
  deck_count: number;
  ended: boolean;
  end_type: string;
  faits_marquants: string[];
  cartes_notables: string[];
}

interface DashboardState {
  timestamp: string;
  run: RunState;
  tweaks_active: Record<string, unknown>;
}

interface StateResp { ok: boolean; error?: string; state: DashboardState | null; dir?: string; }

interface ConstantsTweaks {
  START_INTEGRITE?: number;
  HAND_SIZE?: number;
  MAX_INTEGRITE?: number;
  CORRUPTION_CAP?: number;
}

interface PersonaOverlay {
  appellations?: string[];
  executor_system?: string;
}

interface Tweaks {
  constants?: ConstantsTweaks;
  persona_overlay?: PersonaOverlay;
  scenario_force?: { title?: string | null; beat_index?: number | null };
}

interface TweaksResp { ok: boolean; error?: string; tweaks: Tweaks; }

interface ScenarioSlim {
  id: string;
  title: string;
  archetype_id: string;
  archetype_name: string;
  pole_dominant: string;
  length: number;
}

interface ScenariosResp { ok: boolean; error?: string; scenarios: ScenarioSlim[]; total?: number; }

const POLL_INTERVAL_MS = 1500;

const DEFAULT_CONSTANTS: Required<ConstantsTweaks> = {
  START_INTEGRITE: 10,
  HAND_SIZE: 5,
  MAX_INTEGRITE: 10,
  CORRUPTION_CAP: 18,
};

const PALETTE = {
  bg: '#0a0d10',
  surface: '#141a20',
  border: '#2a3640',
  text: '#d8e0d8',
  dim: '#6e7a82',
  gold: '#c9a24b',
  green: '#7fa65c',
  violet: '#7b4fa3',
  amber: '#ffbf33',
  danger: '#ff4444',
};

function fmtPct(value: number, max: number): string {
  if (max <= 0) return '0%';
  return `${Math.round((100 * value) / max)}%`;
}

/**
 * State is "fresh" if the timestamp written by TweaksOverlay is <5s old — proxy pour
 * "Godot est en train de tourner" (le writer tick toutes les 1s). Évite de stocker un PID
 * côté React ; l'état dérive du fichier polled, pas d'un état serveur.
 */
function isStateFresh(state: DashboardState | null): boolean {
  if (!state?.timestamp) return false;
  const ts = new Date(state.timestamp).getTime();
  if (Number.isNaN(ts)) return false;
  return Date.now() - ts < 5000;
}

export function GameplayLiveTab(): JSX.Element {
  const [state, setState] = useState<DashboardState | null>(null);
  const [stateErr, setStateErr] = useState<string | null>(null);
  const [tweaks, setTweaks] = useState<Tweaks>({});
  const [scenarios, setScenarios] = useState<ScenarioSlim[]>([]);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);

  // --- Live state polling (1.5 s) ---
  useEffect(() => {
    let alive = true;
    const poll = async (): Promise<void> => {
      try {
        const res = await fetch('/api/godot/state');
        const json = (await res.json()) as StateResp;
        if (!alive) return;
        if (json.ok && json.state) {
          setState(json.state);
          setStateErr(null);
        } else {
          setStateErr(json.error ?? 'État indisponible');
          setState(null);
        }
      } catch (err: unknown) {
        if (!alive) return;
        const msg = err instanceof Error ? err.message : 'Network error';
        setStateErr(msg);
      }
    };
    poll();
    const id = setInterval(poll, POLL_INTERVAL_MS);
    return () => { alive = false; clearInterval(id); };
  }, []);

  // --- Initial load: tweaks + scenarios ---
  useEffect(() => {
    (async (): Promise<void> => {
      try {
        const res = await fetch('/api/godot/tweaks');
        const json = (await res.json()) as TweaksResp;
        if (json.ok) setTweaks(json.tweaks ?? {});
      } catch { /* silent — Vercel deploy: route absent */ }
      try {
        const res = await fetch('/api/godot/scenarios');
        const json = (await res.json()) as ScenariosResp;
        if (json.ok) setScenarios(json.scenarios ?? []);
      } catch { /* silent */ }
    })();
  }, []);

  const saveTweaks = useCallback(async (next: Tweaks): Promise<void> => {
    // Optimistic update — capturé pour revert en cas d'échec (review 2026-05-31 MEDIUM #4).
    let prev: Tweaks = {};
    setTweaks((current) => { prev = current; return next; });
    try {
      const res = await fetch('/api/godot/tweaks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(next),
      });
      const json = (await res.json()) as { ok: boolean; error?: string };
      if (json.ok) {
        setSaveMsg('✓ tweaks écrits — Godot rechargera <500 ms');
      } else {
        setTweaks(prev);  // revert : disque ↔ UI restent cohérents
        setSaveMsg(`✗ ${json.error ?? 'écriture échouée'} (revert)`);
      }
      setTimeout(() => setSaveMsg(null), 3000);
    } catch (err: unknown) {
      setTweaks(prev);  // revert sur erreur réseau
      const msg = err instanceof Error ? err.message : 'Erreur réseau';
      setSaveMsg(`✗ ${msg} (revert)`);
      setTimeout(() => setSaveMsg(null), 4000);
    }
  }, []);

  const resetTweaks = useCallback((): void => { saveTweaks({}); }, [saveTweaks]);

  const launchGame = useCallback(async (): Promise<void> => {
    setSaveMsg('⟳ lancement Godot…');
    try {
      const res = await fetch('/api/godot/launch', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
      const json = (await res.json()) as { ok: boolean; pid?: number; error?: string; already_running?: boolean };
      if (json.ok) {
        setSaveMsg(json.already_running ? `✓ déjà actif (pid ${json.pid})` : `✓ Godot lancé (pid ${json.pid}) — state JSON dans <2s`);
      } else {
        setSaveMsg(`✗ ${json.error ?? 'launch failed'}`);
      }
      setTimeout(() => setSaveMsg(null), 4000);
    } catch (err: unknown) {
      setSaveMsg(`✗ ${err instanceof Error ? err.message : 'Network error'}`);
      setTimeout(() => setSaveMsg(null), 4000);
    }
  }, []);

  const stopGame = useCallback(async (): Promise<void> => {
    setSaveMsg('⟳ arrêt Godot…');
    try {
      const res = await fetch('/api/godot/stop', { method: 'POST' });
      const json = (await res.json()) as { ok: boolean; killed_pid?: number; not_running?: boolean; error?: string };
      if (json.ok) {
        setSaveMsg(json.not_running ? '○ aucun process suivi à arrêter' : `✓ Godot arrêté (pid ${json.killed_pid})`);
      } else {
        setSaveMsg(`✗ ${json.error ?? 'stop failed'}`);
      }
      setTimeout(() => setSaveMsg(null), 4000);
    } catch (err: unknown) {
      setSaveMsg(`✗ ${err instanceof Error ? err.message : 'Network error'}`);
      setTimeout(() => setSaveMsg(null), 4000);
    }
  }, []);

  const currentConstants: Required<ConstantsTweaks> = useMemo(() => ({
    ...DEFAULT_CONSTANTS,
    ...(tweaks.constants ?? {}),
  }), [tweaks.constants]);

  const gameLive = isStateFresh(state);

  return (
    <div style={{ background: PALETTE.bg, color: PALETTE.text, fontFamily: 'var(--font-mono, monospace)', height: '100%', overflow: 'auto', padding: 16 }}>
      <Header stateErr={stateErr} saveMsg={saveMsg} onReset={resetTweaks} isGameLive={gameLive} onLaunch={launchGame} onStop={stopGame} />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginTop: 16 }}>
        <StatePane state={state} />
        <HandPane state={state} />
      </div>
      <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <ConstantsPane
          values={currentConstants}
          onChange={(c) => saveTweaks({ ...tweaks, constants: c })}
        />
        <PersonaPane
          overlay={tweaks.persona_overlay ?? {}}
          onChange={(p) => saveTweaks({ ...tweaks, persona_overlay: p })}
        />
      </div>
      <div style={{ marginTop: 16 }}>
        <ScenarioPane
          scenarios={scenarios}
          force={tweaks.scenario_force ?? {}}
          onChange={(f) => saveTweaks({ ...tweaks, scenario_force: f })}
        />
      </div>
    </div>
  );
}

// === Sub-panels ============================================================

function Card(props: { title: string; children: ReactNode }): JSX.Element {
  return (
    <section style={{ background: PALETTE.surface, border: `1px solid ${PALETTE.border}`, borderRadius: 6, padding: 12 }}>
      <h3 style={{ margin: '0 0 10px', color: PALETTE.gold, fontSize: 11, letterSpacing: 1.5, textTransform: 'uppercase' }}>{props.title}</h3>
      {props.children}
    </section>
  );
}

interface HeaderProps {
  stateErr: string | null;
  saveMsg: string | null;
  onReset: () => void;
  isGameLive: boolean;
  onLaunch: () => void;
  onStop: () => void;
}

function Header(props: HeaderProps): JSX.Element {
  const msgColor = props.saveMsg?.startsWith('✓') ? PALETTE.green
    : props.saveMsg?.startsWith('⟳') ? PALETTE.amber
    : props.saveMsg?.startsWith('○') ? PALETTE.dim
    : PALETTE.danger;
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, flex: 1, minWidth: 0 }}>
        <span style={{ color: PALETTE.gold, fontSize: 14, letterSpacing: 2, textTransform: 'uppercase' }}>Gameplay Live</span>
        <span style={{
          fontSize: 10,
          padding: '2px 8px',
          borderRadius: 10,
          background: props.isGameLive ? PALETTE.green : PALETTE.border,
          color: props.isGameLive ? PALETTE.bg : PALETTE.dim,
          letterSpacing: 1,
          textTransform: 'uppercase',
          fontWeight: 600,
        }}>
          {props.isGameLive ? '● live' : '○ idle'}
        </span>
        {props.stateErr && (
          <span style={{ color: PALETTE.amber, fontSize: 11 }}>⚠ {props.stateErr}</span>
        )}
        {props.saveMsg && (
          <span style={{ color: msgColor, fontSize: 11 }}>{props.saveMsg}</span>
        )}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        {props.isGameLive ? (
          <button onClick={props.onStop} style={btnStyle('danger')} title="Tue le process Godot suivi (taskkill /T sur Windows)">
            ⏹ Arrêter
          </button>
        ) : (
          <button onClick={props.onLaunch} style={btnStyle('green')} title="Spawn Godot sur res://scenes/MerlinGame.tscn">
            ▶ Lancer le jeu
          </button>
        )}
        <button onClick={props.onReset} style={btnStyle('amber')} title="Vide user://merlin_tweaks.json — restaure les constantes par défaut">
          Reset tweaks
        </button>
      </div>
    </div>
  );
}

function StatePane(props: { state: DashboardState | null }): JSX.Element {
  const s = props.state?.run;
  return (
    <Card title="State (1.5 s polling)">
      {!s ? (
        <div style={{ color: PALETTE.dim, fontSize: 12 }}>Aucun état — lancer Godot avec scenes/MerlinGame.tscn</div>
      ) : (
        <>
          <Row label="Scénario" value={s.scenario.title || '—'} />
          <Row label="Beat" value={`${s.beat_index + 1}/${s.scenario.total || 5}`} />
          <BarRow label="Intégrité" value={s.integrite} max={s.max_integrite} color={PALETTE.green} />
          <BarRow label="Corruption" value={s.corruption} max={s.corruption_cap} color={PALETTE.violet} />
          <Row label="Deck / défausse" value={`${s.deck_count} / ${s.discard_count}`} />
          {s.ended && <Row label="Fin" value={s.end_type} color={PALETTE.amber} />}
          {s.faits_marquants?.length > 0 && (
            <div style={{ marginTop: 8 }}>
              <div style={{ color: PALETTE.dim, fontSize: 10, textTransform: 'uppercase', letterSpacing: 1 }}>Faits marquants</div>
              <ul style={{ margin: '4px 0 0 16px', padding: 0, fontSize: 11, color: PALETTE.text }}>
                {s.faits_marquants.slice(-6).map((f, i) => <li key={i}>{f}</li>)}
              </ul>
            </div>
          )}
          <div style={{ marginTop: 8, color: PALETTE.dim, fontSize: 10 }}>ts: {props.state?.timestamp ?? '—'}</div>
        </>
      )}
    </Card>
  );
}

function HandPane(props: { state: DashboardState | null }): JSX.Element {
  const hand = props.state?.run.hand ?? [];
  return (
    <Card title={`Main (${hand.length})`}>
      {hand.length === 0 ? (
        <div style={{ color: PALETTE.dim, fontSize: 12 }}>Main vide</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 11 }}>
          <thead>
            <tr style={{ color: PALETTE.dim, textAlign: 'left' }}>
              <th style={thStyle}>Nom</th>
              <th style={thStyle}>Tags</th>
              <th style={thStyle}>Corr.</th>
            </tr>
          </thead>
          <tbody>
            {hand.map((c, i) => (
              <tr key={c.id ?? i} style={{ borderTop: `1px solid ${PALETTE.border}` }}>
                <td style={{ padding: '4px 6px' }} title={c.evocation ?? ''}>{c.name}</td>
                <td style={{ padding: '4px 6px', color: PALETTE.dim }}>{(c.tags ?? []).join(', ')}</td>
                <td style={{ padding: '4px 6px', color: c.corruption > 0 ? PALETTE.violet : PALETTE.dim }}>{c.corruption}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Card>
  );
}

function ConstantsPane(props: { values: Required<ConstantsTweaks>; onChange: (c: ConstantsTweaks) => void }): JSX.Element {
  const set = (key: keyof ConstantsTweaks, raw: string): void => {
    const n = Number.parseInt(raw, 10);
    if (Number.isNaN(n)) return;
    props.onChange({ ...props.values, [key]: n });
  };
  return (
    <Card title="Constants (hot-reload ≤500 ms)">
      <NumberRow label="START_INTEGRITE" value={props.values.START_INTEGRITE} min={1} max={50} onChange={(v) => set('START_INTEGRITE', v)} />
      <NumberRow label="MAX_INTEGRITE" value={props.values.MAX_INTEGRITE} min={1} max={50} onChange={(v) => set('MAX_INTEGRITE', v)} />
      <NumberRow label="HAND_SIZE" value={props.values.HAND_SIZE} min={1} max={12} onChange={(v) => set('HAND_SIZE', v)} />
      <NumberRow label="CORRUPTION_CAP" value={props.values.CORRUPTION_CAP} min={3} max={50} onChange={(v) => set('CORRUPTION_CAP', v)} />
      <div style={{ marginTop: 6, color: PALETTE.dim, fontSize: 10 }}>Default = const local si tweak absent. Persiste dans user://merlin_tweaks.json.</div>
    </Card>
  );
}

function PersonaPane(props: { overlay: PersonaOverlay; onChange: (p: PersonaOverlay) => void }): JSX.Element {
  const apps = props.overlay.appellations ?? [];
  const sys = props.overlay.executor_system ?? '';
  const [newApp, setNewApp] = useState('');
  const addApp = (): void => {
    const v = newApp.trim();
    if (!v) return;
    props.onChange({ ...props.overlay, appellations: [...apps, v] });
    setNewApp('');
  };
  const removeApp = (idx: number): void => {
    props.onChange({ ...props.overlay, appellations: apps.filter((_, i) => i !== idx) });
  };
  return (
    <Card title="Persona Merlin (overlay)">
      <div style={{ marginBottom: 6, color: PALETTE.dim, fontSize: 10, letterSpacing: 1, textTransform: 'uppercase' }}>Appellations (override)</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4, marginBottom: 6 }}>
        {apps.map((a, i) => (
          <span key={i} style={chipStyle}>
            {a}
            <button onClick={() => removeApp(i)} style={{ marginLeft: 4, color: PALETTE.danger, background: 'none', border: 0, cursor: 'pointer', fontFamily: 'inherit' }}>×</button>
          </span>
        ))}
      </div>
      <div style={{ display: 'flex', gap: 4 }}>
        <input
          value={newApp}
          onChange={(e) => setNewApp(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') addApp(); }}
          placeholder="Ajouter une appellation..."
          style={inputStyle}
        />
        <button onClick={addApp} style={btnStyle('gold')}>+</button>
      </div>
      <div style={{ marginTop: 10, color: PALETTE.dim, fontSize: 10, letterSpacing: 1, textTransform: 'uppercase' }}>Executor system (override complet — vide = base persona.json)</div>
      <textarea
        value={sys}
        onChange={(e) => props.onChange({ ...props.overlay, executor_system: e.target.value })}
        placeholder="Override de la voix Merlin (vide = utilise data/ai/config/merlin_persona.json)"
        rows={4}
        style={{ ...inputStyle, width: '100%', marginTop: 4, fontFamily: 'inherit', fontSize: 11, resize: 'vertical' }}
      />
    </Card>
  );
}

function ScenarioPane(props: { scenarios: ScenarioSlim[]; force: { title?: string | null; beat_index?: number | null }; onChange: (f: { title?: string | null; beat_index?: number | null }) => void }): JSX.Element {
  const grouped = useMemo(() => {
    const m = new Map<string, ScenarioSlim[]>();
    for (const s of props.scenarios) {
      const key = s.archetype_name || s.archetype_id;
      const arr = m.get(key) ?? [];
      arr.push(s);
      m.set(key, arr);
    }
    return Array.from(m.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [props.scenarios]);
  return (
    <Card title={`Scenario picker (${props.scenarios.length} corpus)`}>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
        <label style={{ fontSize: 11, color: PALETTE.dim }}>Forcer titre:</label>
        <select
          value={props.force.title ?? ''}
          onChange={(e) => props.onChange({ ...props.force, title: e.target.value || null })}
          style={{ ...inputStyle, minWidth: 320 }}
        >
          <option value="">— Aucun (génération libre) —</option>
          {grouped.map(([archetype, items]) => (
            <optgroup key={archetype} label={`${archetype} (${items.length})`}>
              {items.map((s) => (
                <option key={s.id} value={s.title}>{s.title}</option>
              ))}
            </optgroup>
          ))}
        </select>
        <label style={{ fontSize: 11, color: PALETTE.dim, marginLeft: 12 }}>Beat (WIP):</label>
        <input
          type="number"
          min={0}
          max={20}
          value={props.force.beat_index ?? ''}
          onChange={(e) => {
            const v = e.target.value;
            props.onChange({ ...props.force, beat_index: v === '' ? null : Number.parseInt(v, 10) });
          }}
          placeholder="—"
          title="Forçage du beat non encore consommé côté Godot (refacto structure beats requise pour hot-reload sans casser la run en cours)."
          style={{ ...inputStyle, width: 60 }}
        />
      </div>
      {props.scenarios.length === 0 && (
        <div style={{ marginTop: 6, color: PALETTE.amber, fontSize: 10 }}>
          ⚠ Corpus non trouvé. Exécuter <code>python tools/generate_broceliande_scenarios.py</code> pour générer les 130 scénarios.
        </div>
      )}
    </Card>
  );
}

// === Small atoms ============================================================

function Row(props: { label: string; value: string; color?: string }): JSX.Element {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '2px 0' }}>
      <span style={{ color: PALETTE.dim }}>{props.label}</span>
      <span style={{ color: props.color ?? PALETTE.text }}>{props.value}</span>
    </div>
  );
}

function BarRow(props: { label: string; value: number; max: number; color: string }): JSX.Element {
  return (
    <div style={{ padding: '4px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12 }}>
        <span style={{ color: PALETTE.dim }}>{props.label}</span>
        <span style={{ color: props.color }}>{props.value}/{props.max} · {fmtPct(props.value, props.max)}</span>
      </div>
      <div style={{ height: 4, background: PALETTE.border, borderRadius: 2, overflow: 'hidden', marginTop: 2 }}>
        <div style={{ width: fmtPct(props.value, props.max), height: '100%', background: props.color, transition: 'width 0.3s ease' }} />
      </div>
    </div>
  );
}

function NumberRow(props: { label: string; value: number; min: number; max: number; onChange: (raw: string) => void }): JSX.Element {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '4px 0' }}>
      <span style={{ color: PALETTE.dim, fontSize: 11, minWidth: 140 }}>{props.label}</span>
      <input
        type="range"
        min={props.min}
        max={props.max}
        value={props.value}
        onChange={(e) => props.onChange(e.target.value)}
        style={{ flex: 1 }}
      />
      <input
        type="number"
        min={props.min}
        max={props.max}
        value={props.value}
        onChange={(e) => props.onChange(e.target.value)}
        style={{ ...inputStyle, width: 60 }}
      />
    </div>
  );
}

const thStyle: CSSProperties = { padding: '4px 6px', color: PALETTE.dim, fontWeight: 'normal', textTransform: 'uppercase', fontSize: 10, letterSpacing: 1 };
const inputStyle: CSSProperties = { background: PALETTE.bg, color: PALETTE.text, border: `1px solid ${PALETTE.border}`, borderRadius: 3, padding: '4px 6px', fontFamily: 'inherit', fontSize: 11 };
const chipStyle: CSSProperties = { display: 'inline-flex', alignItems: 'center', background: PALETTE.bg, color: PALETTE.gold, border: `1px solid ${PALETTE.border}`, borderRadius: 12, padding: '2px 8px', fontSize: 11 };

function btnStyle(variant: 'gold' | 'amber' | 'green' | 'danger'): CSSProperties {
  const colorMap: Record<typeof variant, string> = {
    gold: PALETTE.gold,
    amber: PALETTE.amber,
    green: PALETTE.green,
    danger: PALETTE.danger,
  };
  const color = colorMap[variant];
  return {
    background: PALETTE.bg,
    color,
    border: `1px solid ${color}`,
    borderRadius: 3,
    padding: '4px 12px',
    fontSize: 11,
    cursor: 'pointer',
    fontFamily: 'inherit',
    textTransform: 'uppercase',
    letterSpacing: 1,
  };
}
