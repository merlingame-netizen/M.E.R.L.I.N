#!/usr/bin/env bash
# job-097 — DEUX SUITES DE s96 : le menage que j'ai a faire, et la surcharge a montrer.
#
# 1. J'AI LAISSE LE JEU ALLUME. s96 a essaye les agents de nuit « de jour » en croyant que leur
#    garde refuserait proprement. a_partie_nuit.sh a passe la garde (personne ne jouait), libere
#    Ollama, puis lance la selection — qui DEMARRE le jeu. Le `timeout 120` l'a tue en cours, et
#    a_quete_nuit.sh a ensuite trouve le jeu occupe. Essayer un agent qui joue une partie, c'est
#    jouer une partie : la garde ne protege pas de moi.
#    Le coupeur d'inactivite (5 min) doit l'avoir eteint tout seul. On VERIFIE au lieu de le
#    supposer, et on eteint s'il tourne encore sans spectateur.
#
# 2. UNE SURCHARGE REACTIVE UN AGENT MIS EN PAUSE. gd-content-gap est `enabled: false` dans le
#    depot depuis le 25/08 — sa propre notice dit qu'il entraine le futur modele sur un canon
#    PERIME et graverait le generique DANS le modele. Une surcharge hors depot le remet a
#    */30, soit 48 fois par jour. On regarde ce qu'il a REELLEMENT ecrit ces derniers jours :
#    la decision de le couper ou non appartient a Maxime, le constat non.
set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GS="$RP/infra/oracle/game/game-stack.sh"
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari097-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s97 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

OUT="$COURRIER_RES/menage.txt"
{
echo "== 1. LE JEU QUE j'AI LAISSE ALLUME =="
ETAT="$(bash "$GS" status 2>/dev/null | tail -1)"
echo "etat : $ETAT"
echo "desire : $(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo '(aucun)')"
echo "godot en vol : $(pgrep -c godot 2>/dev/null || echo 0)"
if printf '%s' "$ETAT" | grep -q '"vnc_open":true'; then
    echo "-> le jeu tourne ENCORE : le coupeur ne l'a pas eteint, on l'eteint ici"
    env -u RES bash "$GS" stop >/dev/null 2>&1
    sleep 3
    echo "   apres arret : $(bash "$GS" status 2>/dev/null | tail -1)"
else
    echo "-> deja eteint (le coupeur d'inactivite a fait son travail, ou il n'a jamais demarre)"
fi
echo "derniers passages du coupeur :"
grep -a "game-idle" "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -4 | sed 's/^/   /'
echo
echo "== 2. CE QUE gd-content-gap A ECRIT RECEMMENT =="
echo "surcharge : $(python3 -c "import json;print(json.load(open('$HOME/.config/merlin-agent-overrides.json')).get('gd-content-gap'))" 2>/dev/null)"
echo "manifeste : $(python3 -c "
import json
for a in json.load(open('$RP/infra/oracle/agents/agents.json'))['agents']:
    if a['id']=='gd-content-gap': print('enabled=%s schedule=%r' % (a['enabled'], a['schedule']))" 2>/dev/null)"
echo "courses tracees (cron.log, 24 h) : $(tail -n 4000 "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | grep -c 'gd-content-gap')"
echo "journal de l'agent (8 dernieres lignes) :"
tail -8 "$HOME/.cache/merlin-agents/logs/gd-content-gap.log" 2>/dev/null | cut -c1-140 | sed 's/^/   /'
echo "fichiers qu'il produit, les plus recents :"
find "$HOME" -maxdepth 6 \( -path "*corpus*" -o -path "*content*" -o -path "*gd_content*" \) \
     -name "*.json*" -newermt "-3 days" 2>/dev/null | head -8 | sed 's/^/   /'
find "$RP" "$HOME/workspace/merlin-game" -maxdepth 4 -name "*.jsonl" -newermt "-3 days" 2>/dev/null | head -6 | sed 's/^/   /'
echo
echo "== 3. LA MEMOIRE, apres mon passage =="
awk '/MemAvailable/{printf "MemAvailable %d Mo\n",$2/1024}' /proc/meminfo
curl -fsS -m 5 http://127.0.0.1:11434/api/ps 2>/dev/null | python3 -c "import json,sys
try:
    ms=json.load(sys.stdin).get('models') or []
    print('modeles charges :', ', '.join(m.get('name','?') for m in ms) or 'aucun')
except Exception: print('modeles charges : (ollama muet)')"
} > "$OUT" 2>&1

dire "menage" "$(sed -n '2,5p' "$OUT" | tr '\n' ' ' | cut -c1-350)"
curl -fsS -m 90 --retry 2 -T "$OUT" -H "Filename: s97_menage.txt" -H "Title: s97 menage" "$NT" >/dev/null 2>&1
echo "job-097 : menage fait, surcharge documentee"
