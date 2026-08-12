#!/usr/bin/env bash
# Installe (idempotent) les agents dans la crontab utilisateur — pas de systemd
# sur cette VM (Run Command tourne sans sudo). Le bloc est délimité par des
# marqueurs : réexécuter le script remplace proprement l'ancien bloc.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HERE/agents.json"
BEGIN="# >>> merlin-agents >>>"
END="# <<< merlin-agents <<<"

chmod +x "$HERE"/*.sh

BLOCK="$(python3 - "$MANIFEST" "$HERE" <<'PY'
import json, sys
manifest, here = sys.argv[1], sys.argv[2]
# Les réglages faits depuis le portail vivent HORS du dépôt (overrides.py) :
# écrire dans le manifeste versionné bloquerait les déploiements.
sys.path.insert(0, here)
try:
    from overrides import agents as _agents
    agents_list = _agents()
except Exception:
    agents_list = json.load(open(manifest))["agents"]
lines = []
for a in agents_list:
    if not a.get("enabled"):
        continue
    lines.append(f'{a["schedule"]} /bin/bash {here}/agent-run.sh {a["id"]} '
                 f'>> $HOME/.cache/merlin-agents/cron.log 2>&1')
print("\n".join(lines))
PY
)"

CUR="$(crontab -l 2>/dev/null || true)"
CLEAN="$(printf '%s\n' "$CUR" | awk -v b="$BEGIN" -v e="$END" '
    $0==b {skip=1} !skip {print} $0==e {skip=0}')"

{ printf '%s\n' "$CLEAN"
  printf '%s\n' "$BEGIN"
  printf '%s\n' "$BLOCK"
  printf '%s\n' "$END"; } | crontab -

mkdir -p "$HOME/.cache/merlin-agents/logs"
N="$(printf '%s\n' "$BLOCK" | grep -c agent-run || true)"
echo "[install-agents] $N agent(s) planifié(s) dans la crontab"
crontab -l | sed -n "/$BEGIN/,/$END/p"
