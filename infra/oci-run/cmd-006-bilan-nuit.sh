#!/usr/bin/env bash
# cmd-006 (pont OCI) — bilan du matin : qu'a fait la chaine cette nuit ?
# p66 rejouee (v44/45/46), v48 tire par game-autosync, ateliers de corpus en pause.
# Sortie courte (Oracle tronque ~2 Ko) : etiquettes A-Z, jamais de secret.
set -u
R=/var/lib/ocarun/workspace/M.E.R.L.I.N
G=/var/lib/ocarun/workspace/merlin-game
cd "$R" 2>/dev/null || cd "$HOME/workspace/M.E.R.L.I.N" || { echo "KO depot"; exit 1; }

echo "A date=$(date -u +%FT%TZ) qui=$(whoami)"
echo "B outillage=$(git rev-parse --short HEAD) cron=$(crontab -l 2>/dev/null | grep -c .)"
echo "C jeu=$(git -C "$G" rev-parse --short HEAD 2>/dev/null) (v48=f066757 attendu)"
echo "D content-gap+corpus dans cron ? $(crontab -l 2>/dev/null | grep -cE 'a_gd_content|a_corpus_night') (attendu 0 = bien en pause)"

echo "E == p66 rejouee ? =="
ls -t /var/lib/ocarun/.cache/merlin-agents/courrier/job-066*.fait 2>/dev/null | head -1 | xargs -r stat -c '%y %n' 2>/dev/null || echo "job-066 SANS marqueur (pas encore rejouee, ou en cours)"

echo "F == derniers marqueurs Courrier (5) =="
ls -t /var/lib/ocarun/.cache/merlin-agents/courrier/*.fait 2>/dev/null | head -5 | xargs -r -n1 basename

echo "G == journal du jour (chapitre) =="
ls -t "$R"/memory/journal/*.md "$HOME"/merlin-memory/journal/*.md 2>/dev/null | head -1 | xargs -r tail -c 500 2>/dev/null | tr '\n' ' ' | cut -c1-460
echo ""
echo "H == smoke nocturne (erreurs de scene ?) =="
ls -t /var/lib/ocarun/.cache/merlin-*/smoke*.txt "$HOME"/.cache/merlin-*/smoke*.log 2>/dev/null | head -1 | xargs -r tail -c 300 2>/dev/null | tr '\n' ' '
echo ""
echo "I == propositions en attente (apres nettoyage) =="
python3 -c "import sys;sys.path.insert(0,'tools/gd_agents');import proposals;c=proposals.listing(limit=5)['counts'];print('pending=%d accepted=%d rejected=%d'%(c.get('pending',0),c.get('accepted',0),c.get('rejected',0)))" 2>/dev/null || echo "proposals illisible"
echo "Z fin cmd-006"
