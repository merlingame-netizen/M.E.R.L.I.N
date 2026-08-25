#!/usr/bin/env bash
# cmd-005 (pont OCI) — deux gestes decides par Maxime (« fais donc ») :
#
# 1. REJETER LES 10 CARTES au format mort : options/verb/ADD_REPUTATION = le systeme d'AVANT le
#    pivot v11. Le jeu actuel est combinaison action+trait, 2d6 vs DC, deltas automatiques
#    (R158/R166). Les accepter aurait ENTRAINE le modele sur un format perime. L'agent
#    gd-content-gap sera recadre sur R166 avant de reproduire du contenu.
# 2. REJOUER p66 : la partie temoin de v44/v45/v46 a tourne hier PENDANT le blocage (jeu a v45),
#    sa garde a expire (rc=1) et son marqueur .fait l'empeche de rejouer. On efface LE SEUL
#    marqueur de job-066 : le Courrier (cron, */2) la reprend au prochain passage, avec cette
#    fois v47 + Bible v2.1 sur la branche du jeu.
set -u
cd /var/lib/ocarun/workspace/M.E.R.L.I.N 2>/dev/null || cd "$HOME/workspace/M.E.R.L.I.N" || { echo "KO depot"; exit 1; }

echo "A qui=$(whoami) date=$(date -u +%FT%TZ) sha=$(git rev-parse --short HEAD)"

python3 - <<'PY'
import sys
sys.path.insert(0, "tools/gd_agents")
import proposals
rej = 0
for p in proposals.listing(limit=100).get("pending", []):
    if p.get("kind") == "content":
        proposals.decide(p.get("id"), "reject",
            "format d'AVANT le pivot v11 (options/verb/ADD_REPUTATION) : le jeu actuel est "
            "combinaison action+trait, 2d6 vs DC, deltas automatiques (R158/R166). Accepter "
            "aurait entraine le modele sur un systeme mort. gd-content-gap sera recadre sur R166.")
        rej += 1
c = proposals.listing(limit=10).get("counts", {})
print("B cartes_rejetees=%d" % rej)
print("C pending=%d accepted=%d rejected=%d" % (c.get("pending", 0), c.get("accepted", 0), c.get("rejected", 0)))
PY

# ── rejouer p66 ──
M=/var/lib/ocarun/.cache/merlin-agents/courrier/job-066-partie19-v46.fait
if [ -f "$M" ]; then
    rm -f "$M" && echo "D marqueur job-066 efface — le Courrier la rejouera au prochain passage (*/2 min)"
else
    echo "D marqueur job-066 deja absent"
fi
echo "E jeu: local=$(git -C /var/lib/ocarun/workspace/merlin-game rev-parse --short HEAD 2>/dev/null) (v47+Bible attendus)"
echo "F gd-content-gap: prochaine execution laissee en place — son recadrage R166 arrive par l'outillage"
echo "G fin cmd-005"
