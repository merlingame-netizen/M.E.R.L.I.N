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

def cron_ok(s: str) -> bool:
    """Un `schedule` non-cron (« à la demande », « webhook/push ») écrit tel quel
    fait REJETER LA CRONTAB ENTIÈRE par `crontab -` : les 15 agents planifiés
    disparaissent d'un coup. On filtre ici, en dernière ligne de défense."""
    f = str(s or "").split()
    if len(f) != 5:
        return False
    import re
    return all(re.fullmatch(r"[\d*/,\-]+", x) for x in f)

lines, skipped = [], []
for a in agents_list:
    if not a.get("enabled"):
        continue
    if not cron_ok(a.get("schedule")):
        skipped.append(f'{a["id"]} ({a.get("schedule","")!r})')
        continue
    lines.append(f'{a["schedule"]} /bin/bash {here}/agent-run.sh {a["id"]} '
                 f'>> $HOME/.cache/merlin-agents/cron.log 2>&1')
if skipped:
    sys.stderr.write("[install-agents] cadence invalide, non planifié : "
                     + ", ".join(skipped) + "\n")
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
RC=$?
if [ "$RC" -ne 0 ]; then
    # `crontab -` est tout-ou-rien : un refus laisse l'ancienne table en place,
    # mais l'appelant DOIT le savoir (le portail répondait « activé » sur un échec).
    echo "[install-agents] ÉCHEC : crontab a refusé le bloc (rc=$RC) — table inchangée" >&2
    exit "$RC"
fi

mkdir -p "$HOME/.cache/merlin-agents/logs"
N="$(printf '%s\n' "$BLOCK" | grep -c agent-run || true)"
echo "[install-agents] $N agent(s) planifié(s) dans la crontab"
crontab -l | sed -n "/$BEGIN/,/$END/p"
