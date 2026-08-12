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
# ATTENTION : agent-run.sh ecrit dans le SOUS-DOSSIER state/ (RUN_DIR="$STATE_DIR/state",
# deplacement fait pour eviter la collision de noms avec llm-bench.json / billing.json).
# Scanner la racine ne trouvait plus AUCUN etat d'agent : le rapport annoncait donc
# invariablement "tous les agents au vert". On scanne le sous-dossier, avec repli sur la
# racine pour les etats historiques — meme logique que probes.agents().
L += ["## Agents", ""]
bad = []
seen = set()
for d_dir in (os.path.join(state, "state"), state):
    if not os.path.isdir(d_dir):
        continue
    for f in os.listdir(d_dir):
        if not f.endswith(".json") or f == "daily-report.json" or f in seen:
            continue
        try: d = json.load(open(os.path.join(d_dir, f)))
        except Exception: continue
        if not isinstance(d, dict) or "ok" not in d:
            continue          # billing-data.json, smoke-scenes.json… : pas des etats d'agent
        seen.add(f)
        if d.get("ok") is False:
            bad.append(f"- ÉCHEC `{d.get('id', f[:-5])}` ({d.get('last_run','?')}) : "
                       f"{str(d.get('summary',''))[:100]}")
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
smoke_ko = None
try:
    sm = json.load(open(os.path.join(state, "smoke-scenes.json")))
    smoke_ko = sm.get("failing")
    L += ["## Smoke nocturne", "",
          f"- {sm.get('total')} scènes · {sm.get('failing')} en erreur · commit `{sm.get('commit')}` ({sm.get('t','')[:16]})"]
except Exception:
    L += ["## Smoke nocturne", "", "- pas encore exécuté"]

# ── Relevé d'avancement (une ligne par jour, append-only, HORS dépôt) ────────
# Une photo quotidienne des chiffres qui comptent : le portail en trace la
# courbe. Le fichier vit dans ~/merlin-memory/ (jamais purgé par le garde-disque)
# et n'est jamais réécrit — on ne peut pas embellir le passé.
def _count(d):
    try: return len([x for x in os.listdir(d) if x.endswith(".json")])
    except Exception: return 0

def _lines(p):
    try: return sum(1 for x in open(p, encoding="utf-8") if x.strip())
    except Exception: return 0

try:
    home = os.path.expanduser("~")
    props = os.path.join(home, ".cache", "merlin-proposals")
    tool_repo = os.path.join(home, "workspace", "M.E.R.L.I.N")
    point = {
        "t": time.strftime("%Y-%m-%d", time.gmtime()),
        "cartes": (_lines(os.path.join(tool_repo, "data/ai/training/auto_corpus.jsonl"))
                   + _lines(os.path.join(tool_repo, "data/ai/training/curated_corpus.jsonl"))),
        "propositions_attente": _count(os.path.join(props, "inbox")),
        "propositions_acceptees": _count(os.path.join(props, "accepted")),
        "propositions_rejetees": _count(os.path.join(props, "rejected")),
        "missions_en_file": _count(os.path.join(home, ".cache/merlin-missions/queue")),
        "missions_faites": _count(os.path.join(home, ".cache/merlin-missions/done")),
        "scenes_ko": smoke_ko,
        "agents_ko": len(bad),
        "commits_24h": len(commits),
    }
    prog = os.path.join(home, "merlin-memory", "progress.jsonl")
    os.makedirs(os.path.dirname(prog), exist_ok=True)
    # Un seul point par jour : on remplace la ligne du jour si elle existe déjà.
    old = [x for x in (open(prog, encoding="utf-8").read().splitlines()
                       if os.path.exists(prog) else []) if x.strip()]
    old = [x for x in old if '"t": "%s"' % point["t"] not in x and
           '"t":"%s"' % point["t"] not in x]
    with open(prog, "w", encoding="utf-8") as f:
        f.write("\n".join(old[-400:] + [json.dumps(point, ensure_ascii=False)]) + "\n")
    L += ["", "## Avancement", "",
          f"- {point['cartes']} cartes · {point['propositions_attente']} décision(s) en attente "
          f"· {point['missions_faites']} mission(s) faite(s)"]
except Exception as exc:
    L += ["", f"- relevé d'avancement indisponible : {type(exc).__name__}"]

print("\n".join(L))
PY

ROUGES="$(grep -c '^- ROUGE' "$OUT" || true)"
ECHECS="$(grep -c '^- ÉCHEC' "$OUT" || true)"
bash "$HERE/notify.sh" low "Rapport du matin" \
    "$ROUGES CI rouge(s), $ECHECS agent(s) en échec — détail sur le portail."
echo "rapport écrit ($(wc -l < "$OUT") lignes) · $ROUGES CI rouge(s) · $ECHECS agent(s) en échec"
