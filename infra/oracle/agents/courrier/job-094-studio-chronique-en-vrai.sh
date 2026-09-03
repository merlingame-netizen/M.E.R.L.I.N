#!/usr/bin/env bash
# job-094 — L'ONGLET CHRONIQUE, INTERROGE SUR LA VM ELLE-MEME.
#
# L'onglet est ecrit, eprouve ici sur 22 controles et rendu dans un vrai Chromium avec p74. Mais
# c'est SUR LA VM qu'il doit lire les parties : les copies de surete du Courrier, les resultats,
# et les chroniques que le jeu ecrit depuis hier. Rien de tout cela n'existe dans mon bac a sable.
# Ce job demande au Studio local ce qu'il voit, avec le jeton que le keepalive lui donne.
#
# Trois choses, dans l'ordre :
#   1. l'epreuve du module, avec le python du Studio (la venv) — la vraie machine, pas la mienne ;
#   2. /api/chroniques et /chroniques/liseuse sur 127.0.0.1:8790 — ce que l'onglet affichera ;
#   3. le verdict COMPLET de p93 et son journal : le retour d'hier etait tronque a 700 signes,
#      et il porte les mesures des taches #19 (attente), #20 (empreinte du lore) et #21 (trous).
#
# Un 401 « mfa_required » n'est pas un echec : c'est la porte a deux facteurs, et le job le dit.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
ENVF="$HOME/.config/merlin-studio.env"
PORT=8790
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari094-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s94 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
joindre() { curl -fsS -m 120 --retry 2 -T "$1" -H "Filename: $2" -H "Title: s94 $2" "$NT" >/dev/null 2>&1; sleep 2; }

# La garde : le module doit etre arrive par l'autosync.
deadline=$(( $(date +%s) + 2400 ))
while [ ! -f "$RP/tools/merlin_studio/chroniques.py" ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "chroniques.py jamais arrive par l'autosync"; exit 1; }
    sleep 30
done
SHA="$(git -C "$RP" rev-parse --short HEAD)"
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA"

# ── 1. L'EPREUVE, AVEC LE PYTHON DU STUDIO
PY="$RP/.venv/bin/python"; [ -x "$PY" ] || PY=python3
( cd "$RP" && "$PY" tools/merlin_studio/test_chroniques.py ) > "$COURRIER_RES/epreuve.txt" 2>&1
EPREUVE=$(grep -E "^ÉPREUVE|RATE" "$COURRIER_RES/epreuve.txt" | tr '\n' ' ' | head -c 300)
dire "epreuve" "python=$(basename "$(dirname "$(dirname "$PY")")")/$(basename "$PY") · $EPREUVE"

# ── 2. CE QUE LE STUDIO VOIT
TOKEN="$(sed -n 's/^STUDIO_TOKEN=//p' "$ENVF" 2>/dev/null | head -1)"
AUTH=(); [ -n "$TOKEN" ] && AUTH=(-u "merlin:$TOKEN")
for i in 1 2 3 4 5 6; do
    curl -fsS -m 5 "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 && break
    sleep 20
done
CODE=$(curl -s -m 20 "${AUTH[@]}" -o "$COURRIER_RES/api_chroniques.json" -w '%{http_code}' "http://127.0.0.1:$PORT/api/chroniques" 2>/dev/null || echo 000)
RESUME=$(python3 - "$COURRIER_RES/api_chroniques.json" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print("illisible : %s" % e); sys.exit()
if "error" in d and not d.get("parties"):
    print("erreur : %s" % d["error"]); sys.exit()
P = d.get("parties") or []
print("%d partie(s) : %s" % (len(P), " · ".join("%s[%s] %db/%dbanc %s" % (
    p.get("id"), p.get("provenance","?")[:9], p.get("beats",0), p.get("banc",0), (p.get("fin") or "—")[:6]) for p in P[:10])))
PY
)
dire "api" "HTTP $CODE · $RESUME"
LCODE=$(curl -s -m 60 "${AUTH[@]}" -o "$COURRIER_RES/liseuse.html" -w '%{http_code}' "http://127.0.0.1:$PORT/chroniques/liseuse" 2>/dev/null || echo 000)
LSIZE=$(stat -c%s "$COURRIER_RES/liseuse.html" 2>/dev/null || echo 0)
LMARK=$(grep -c "const PARTIES = {" "$COURRIER_RES/liseuse.html" 2>/dev/null || echo 0)
dire "liseuse" "HTTP $LCODE · $LSIZE octets · PARTIES injectees=$LMARK"
# LES SOURCES SUR LE DISQUE, pour comparer a ce que l'API a rendu.
{
  echo "== copies du Courrier =="; ls -la "$HOME/.cache/merlin-agents/courrier/"*.res/journal.json 2>/dev/null
  echo "== resultats commites =="; ls "$RP/infra/oracle/agents/courrier/resultats/"*/journal.json 2>/dev/null
  echo "== docs =="; ls "$RP/docs/chroniques/"*/journal.json 2>/dev/null
  echo "== chroniques du jeu =="; ls -la "$HOME/.local/share/godot/app_userdata/MERLIN/chroniques/" 2>/dev/null
} > "$COURRIER_RES/sources.txt" 2>&1
joindre "$COURRIER_RES/sources.txt" s94_sources.txt
joindre "$COURRIER_RES/api_chroniques.json" s94_api.json

# ── 3. LE VERDICT COMPLET DE p93, ET SON JOURNAL
J93=$(ls -d "$HOME/.cache/merlin-agents/courrier/job-093"*.res 2>/dev/null | head -1)
if [ -n "$J93" ] && [ -s "$J93/journal.json" ]; then
    python3 "$RP/infra/oracle/agents/courrier/verdict_partie.py" "$J93/journal.json" > "$COURRIER_RES/verdict93_complet.txt" 2>&1
    joindre "$COURRIER_RES/verdict93_complet.txt" p93_verdict_complet.txt
    joindre "$J93/journal.json" p93_journal.json
    dire "p93" "verdict complet et journal joints ($(wc -c < "$J93/journal.json") octets)"
else
    dire "p93" "copie de surete absente : $J93"
fi
echo "job-094 : api=$CODE liseuse=$LCODE ($LSIZE o) · $RESUME"
