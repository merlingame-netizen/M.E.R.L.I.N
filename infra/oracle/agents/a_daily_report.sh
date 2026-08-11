#!/usr/bin/env bash
# Rapport du matin (7 h) : compile les dernières 24 h en UNE page lisible —
# commits et verdicts CI, état des agents, santé min/max, smoke, disque.
# Sortie : ~/.cache/merlin-agents/daily-report.md (affiché par le portail).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

STATE="$HOME/.cache/merlin-agents"
OUT="$STATE/daily-report.md"

python3 - "$STATE" "$GAME_DIR" "$GAME_REF" > "$OUT" <<'PY'
import json, os, subprocess, sys, time
state, game_dir, game_ref = sys.argv[1:4]
now = time.time(); day_ago = now - 86400
iso = lambda t=None: time.strftime("%Y-%m-%d %H:%M", time.gmtime(t or now))

def tail_jsonl(path, n=500):
    try:
        return [json.loads(x) for x in open(path, encoding="utf-8").read().splitlines()[-n:] if x.strip()]
    except Exception:
        return []

def ts(s):
    try: return time.mktime(time.strptime(s[:19], "%Y-%m-%dT%H:%M:%S"))
    except Exception: return 0

L = [f"# Rapport du {iso()} UTC", ""]

# Commits des 24 h sur la branche du jeu
try:
    log = subprocess.run(["git", "-C", game_dir, "log", "--since=24 hours ago",
                          "--format=%h %s", f"origin/{game_ref}"],
                         capture_output=True, text=True, timeout=15).stdout.strip()
except Exception:
    log = ""
commits = [l for l in log.splitlines() if l.strip()]
L += [f"## Jeu — {game_ref}", ""]
L += [f"- {c}" for c in commits[:12]] or ["- aucun commit en 24 h"]
L.append("")

# Verdicts CI
ci = [c for c in tail_jsonl(os.path.join(state, "ci", "history.jsonl")) if ts(c.get("t","")) >= day_ago]
L += ["## CI des commits", ""]
if ci:
    for c in ci[-8:]:
        ok = c.get("scenes_failing", 1) == 0 and c.get("boot_ok")
        L.append(f"- {'VERT' if ok else 'ROUGE'} `{c.get('sha')}` — "
                 f"{c.get('scenes_failing')}/{c.get('scenes_total')} scènes KO, "
                 f"boot {'OK' if c.get('boot_ok') else 'KO'} — {c.get('subject','')}")
else:
    L.append("- aucun passage CI en 24 h")
L.append("")

# Agents en échec
L += ["## Agents", ""]
bad = []
for f in os.listdir(state):
    if f.endswith(".json") and f != "daily-report.json":
        try: d = json.load(open(os.path.join(state, f)))
        except Exception: continue
        if d.get("ok") is False:
            bad.append(f"- ÉCHEC `{d.get('id')}` ({d.get('last_run','?')}) : {d.get('summary','')[:100]}")
L += bad or ["- tous les agents au vert"]
L.append("")

# Santé min/max sur 24 h
h = [x for x in tail_jsonl(os.path.join(state, "health-history.jsonl")) if ts(x.get("t","")) >= day_ago]
L += ["## Santé (24 h)", ""]
if h:
    loads = [x["load1"] for x in h]; mems = [x["mem_pct"] for x in h]
    L += [f"- charge : {min(loads):.2f} → {max(loads):.2f} (sur {h[-1]['cpus']} cœurs)",
          f"- RAM : {min(mems)}% → {max(mems)}%",
          f"- disque : {h[-1]['disk_pct']}%  ·  {len(h)} relevés"]
else:
    L.append("- pas de relevés")
L.append("")

# Smoke nocturne
try:
    sm = json.load(open(os.path.join(state, "smoke-scenes.json")))
    L += ["## Smoke nocturne", "",
          f"- {sm.get('total')} scènes · {sm.get('failing')} en erreur · commit `{sm.get('commit')}` ({sm.get('t','')[:16]})"]
except Exception:
    L += ["## Smoke nocturne", "", "- pas encore exécuté"]
print("\n".join(L))
PY

ROUGES="$(grep -c '^- ROUGE' "$OUT" || true)"
ECHECS="$(grep -c '^- ÉCHEC' "$OUT" || true)"
echo "rapport écrit ($(wc -l < "$OUT") lignes) · $ROUGES CI rouge(s) · $ECHECS agent(s) en échec"
