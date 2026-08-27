#!/usr/bin/env bash
# cmd-011 (pont OCI) — ETAT DES LIEUX avant v48.1, et premiere question au SAGE.
#
# Trois choses, en sortie courte (Run Command tronque vers 2 Ko) :
#   A. la machine  : charge, memoire, cron, Godot en cours ?
#   B. les depots  : sha du jeu et de l'outillage sur la VM (est-on bien sur v48 = f066757 ?)
#   C. le Sage     : le Studio repond-il, et que dit-il d'une question tiree des textes ?
#
# Aucun identifiant, aucun chemin de cle, aucun contenu de fichier de configuration n'est
# imprime : le depot est PUBLIC.
set -u
GD="${GAME_DIR:-/var/lib/ocarun/workspace/merlin-game}"
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
[ -d "$GD" ] || GD="$HOME/workspace/merlin-game"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"

# --- A. la machine ---
mem=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo)
load=$(cut -d' ' -f1-3 /proc/loadavg)
ncron=$(crontab -l 2>/dev/null | grep -cv '^[[:space:]]*#')
godot=$(pgrep -f "bin/godot|^godot" >/dev/null 2>&1 && echo oui || echo non)
echo "A mem_libre=${mem}Go load=$load cron=$ncron godot=$godot up=$(cut -d. -f1 /proc/uptime)s"

# --- B. les depots ---
echo "B jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null || echo ABSENT)@$(git -C "$GD" rev-parse --abbrev-ref HEAD 2>/dev/null) outillage=$(git -C "$RP" rev-parse --short HEAD 2>/dev/null || echo ABSENT)"
echo "B v48_dans_le_jeu=$(grep -qs 'foret-REVE qui BOUCLE' "$GD/scripts/llm/merlin_prompt_builder.gd" && echo oui || echo NON) v46=$(grep -qs phrase_du_geste "$GD/scripts/game/merlin_resolution.gd" && echo oui || echo NON)"
echo "B dernier_courrier=$(ls -1t "$RP"/infra/oracle/agents/courrier/*.fait 2>/dev/null | head -1 | xargs -r basename)"

# --- C. le Sage ---
PORT=$(grep -oE '[0-9]{4,5}' <<<"$(grep -rhs 'port' "$RP/tools/gd_agents/"*.py 2>/dev/null | grep -iE 'default|8787|8080' | head -1)" | head -1)
[ -n "${PORT:-}" ] || PORT=8787
code=$(curl -s -o /dev/null -w '%{http_code}' -m 8 "http://127.0.0.1:$PORT/" 2>/dev/null)
echo "C studio_port=$PORT http=$code"
if [ "$code" = "200" ]; then
  Q='Quelle est la loi de Broceliande, et qu est-ce qui distingue le Voyageur des autres etres de la foret ?'
  R=$(curl -fsS -m 120 -X POST "http://127.0.0.1:$PORT/api/chat" \
      -H 'Content-Type: application/json' \
      -d "{\"voice\":\"sage\",\"message\":\"$Q\"}" 2>/dev/null \
      | python3 -c "import json,sys
try:
    d=json.load(sys.stdin)
    t=d.get('reply') or d.get('text') or d.get('message') or json.dumps(d)[:400]
    s=d.get('sources') or d.get('citations') or []
    print(str(t).replace('\n',' ')[:600])
    print('SOURCES: '+', '.join(str(x)[:60] for x in s[:4]) if s else 'SOURCES: aucune')
except Exception as e:
    print('illisible: %s' % e)" 2>/dev/null)
  echo "C sage: ${R:-pas de reponse}"
else
  echo "C sage: Studio injoignable (http=$code) — rien demande"
fi
echo "Z fin cmd-011"
