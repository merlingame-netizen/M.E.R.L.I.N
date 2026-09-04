#!/usr/bin/env bash
# job-098 — LE CANON REFAIT EST-IL ARRIVE, ET L'ATELIER LE DIGERE-T-IL ?
#
# Le canon a ete refait ici ; il ne vaut que si la VM l'a tire et si gd-content-gap — qui tourne
# 48 fois par jour — produit desormais des propositions ancrees dans le vrai monde. On regarde
# donc trois choses, dans cet ordre : le fichier sur la VM, l'epreuve avec la venv du Studio, et
# les propositions REELLES que l'agent a deposees depuis.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
PY="$RP/.venv/bin/python"; [ -x "$PY" ] || PY=python3
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari098-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s98 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

# Le canon n'arrive qu'au passage de tools-autosync (4 fois par heure). On l'attend.
deadline=$(( $(date +%s) + 3000 ))
while ! grep -q "Ar C.hoad Kozh" "$RP/data/ai/lore_canon.json" 2>/dev/null; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "le canon refait n'est pas arrive en 50 min (sha=$(git -C "$RP" rev-parse --short HEAD 2>/dev/null))"; exit 1; }
    sleep 60
done

OUT="$COURRIER_RES/canon.txt"
{
echo "== LE CANON SUR LA VM =="
echo "sha outillage : $(git -C "$RP" rev-parse --short HEAD 2>/dev/null)"
"$PY" - "$RP" <<'PY'
import json, sys
c = json.load(open(sys.argv[1] + "/data/ai/lore_canon.json", encoding="utf-8"))
print("  version=%s · %d biomes · %d factions · %d figures · %d lacunes"
      % (c.get("version"), len(c.get("biomes", [])), len(c.get("factions", [])),
         len(c.get("npcs", [])), len(c.get("gaps", []))))
print("  biomes :", ", ".join(b["name"] for b in c.get("biomes", [])[:6]), "...")
print("  interdits :", c["scenario_constraints"]["forbidden_words"])
PY
echo
echo "== L'EPREUVE, avec la venv du Studio =="
cd "$RP" && "$PY" tools/gd_agents/test_lore_canon.py 2>&1 | tail -4
echo
echo "== CE QUE L'ATELIER PROPOSE MAINTENANT =="
echo "propositions gd-content-gap deposees dans les 12 dernieres heures :"
find "$HOME/.cache/merlin-proposals" -name "*gd-content-gap*" -newermt "-12 hours" 2>/dev/null | wc -l
DERNIERE="$(find "$HOME/.cache/merlin-proposals" -name "*gd-content-gap*" -newermt "-12 hours" 2>/dev/null | sort | tail -1)"
if [ -n "$DERNIERE" ]; then
    echo "la plus recente : $(basename "$DERNIERE")"
    "$PY" - "$DERNIERE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
# On cherche le monde dans ce que l'agent a produit : un biome breton et aucune faction fantome.
t = json.dumps(d, ensure_ascii=False)
vrais = [b for b in ("Ar C'hoad Kozh", "Kerlan", "Ys", "Menez Hom", "Yeun Elez", "Enez Glenn",
                     "Marc'had an Deur", "Ar C'hairn", "Kastell Skeud", "Ar Vevenn",
                     "Enez Gouel", "Menez Du") if b in t]
morts = [m for m in ("Niamh", "Manannan", "Brigid", "Lugh", "Cernunnos", "Maelgwn", "Keridwen",
                     "Foret de Broceliande", "Landes de Bruyere", "anciens") if m in t]
print("  biomes reels cites :", vrais or "AUCUN")
print("  restes du monde mort :", morts or "aucun")
print("  extrait :", str(d.get("change", {}).get("summary", d.get("summary", "")))[:200])
PY
else
    echo "  (aucune proposition recente — l'agent n'a pas encore tourne depuis le canon refait)"
fi
echo
echo "== LE CORPUS D'ENTRAINEMENT =="
for f in auto_corpus.jsonl curated_corpus.jsonl; do
    C="$RP/data/ai/training/$f"
    [ -f "$C" ] && echo "  $f : $(wc -l < "$C") exemples, dernier ajout $(date -r "$C" -u +%Y-%m-%dT%H:%MZ)"
done
} > "$OUT" 2>&1

dire "canon" "$(grep -A2 'LE CANON SUR LA VM' "$OUT" | tail -2 | tr '\n' ' ' | cut -c1-300) · $(grep 'EPREUVE' -A3 "$OUT" | grep -o 'ÉPREUVE.*' | head -1)"
curl -fsS -m 90 --retry 2 -T "$OUT" -H "Filename: s98_canon.txt" -H "Title: s98 canon" "$NT" >/dev/null 2>&1
echo "job-098 : canon verifie sur la VM"
