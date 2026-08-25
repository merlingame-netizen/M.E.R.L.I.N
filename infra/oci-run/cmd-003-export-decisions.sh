#!/usr/bin/env bash
# cmd-003 (pont OCI) — export des decisions du Studio, rejoue apres correction du fingerprint.
# cmd-001/002 : auth OCI en echec sur OCI_FINGERPRINT malforme (15 deux-points mais un caractere
# parasite au collage). Secret repose. Si l'auth passe, c'est la preuve que je pilote la Run
# Command moi-meme.
set -u
cd /var/lib/ocarun/workspace/M.E.R.L.I.N 2>/dev/null || cd "$HOME/workspace/M.E.R.L.I.N" || { echo "KO depot"; exit 1; }

echo "A qui=$(whoami) date=$(date -u +%FT%TZ)"
echo "B sha=$(git rev-parse --short HEAD)"
echo "C cron=$(crontab -l 2>/dev/null | grep -c .)"
echo "D courrier_faits=$(ls /var/lib/ocarun/.cache/merlin-agents/courrier/*.fait 2>/dev/null | wc -l) dernier=$(ls -t /var/lib/ocarun/.cache/merlin-agents/courrier/*.fait 2>/dev/null | head -1 | xargs -r basename)"
echo "E jeu_en_vol=$(pgrep -c -f 'godot|job-06' 2>/dev/null || echo 0)"

python3 - <<'PY'
import json, sys
sys.path.insert(0, "tools/gd_agents")
import proposals, boite, memory
d = {"proposals": proposals.listing(limit=100), "boite": boite.etat(limite=30)}
for f in d["boite"].get("fils", []):
    try:
        f["messages"] = memory.chat_read(f.get("conv", ""), limit=6)
    except Exception:
        pass
open("/tmp/decisions_dump.json", "w", encoding="utf-8").write(json.dumps(d, ensure_ascii=False))
p = d["proposals"]
print("F propositions=%d (comptes: %s) fils=%d" % (
    len(p.get("pending", [])), p.get("counts", {}), len(d["boite"].get("fils", []))))
PY

NT=""
for base in https://ntfy.sh https://ntfy.adminforge.de https://ntfy.envs.net; do
    tok="canari-ocirun3-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok"; then
        NT="$base"; break
    fi
done
[ -n "$NT" ] || NT="https://ntfy.sh"
if curl -fsS -m 60 --retry 2 -T /tmp/decisions_dump.json \
     -H "Filename: decisions_dump.json" -H "Title: dump-decisions" \
     "$NT/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1; then
    echo "G dump=ENVOYE via $NT taille=$(wc -c < /tmp/decisions_dump.json)"
else
    echo "G dump=ECHEC envoi ntfy"
fi
echo "H fin"
