#!/usr/bin/env bash
# job-073 — LA PARTIE TEMOIN DE v49 : LA CONTINUITE, en plus des trois cibles dures.
#
# Ce que cette partie doit prouver, et que le verdict mesure desormais tout seul :
#   CONTINUITE N/5 — combien d'enchainements s'ouvrent sur ce que l'issue precedente a
#   laisse. La derniere partie (p71, avant v49) affiche 0 sur 5 : c'est la ligne de base.
#
#   1. SECOURS = 0            2. reussite complete a chaque geste       3. <= 20 s d'ATTENTE MACHINE
#
# Trois lecons de p69 et p70 sont gravees ici :
#
#   - p70 est mort a la SELECTION en disant seulement « selection invalide », alors que la sonde
#     ecrit le MOTIF dans selection.json. Le message d'echec lit desormais ce motif. Un echec doit
#     dire pourquoi, pas obliger a une commande de plus.
#   - la selection a droit a TROIS essais, pas deux : elle exige 3 sentiers ou rien
#     (merlin_scenario.gd:1090), donc une seule generation manquee condamne toute la partie.
#   - le verdict n'est plus recopie ici : il vit dans verdict_partie.py, qui juge la cible temps
#     sur attente_moteur_s et REFUSE de conclure sur un budget dont le releve ne porte pas le
#     label « issue ».
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari073-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p73 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

# Le MOTIF du refus de selection, tel que la sonde l'ecrit — pas la queue d'un log.
motif_sel() { python3 - "$B/selection.json" <<'PY' 2>/dev/null || echo "selection.json illisible"
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print("ok=%s sentiers=%d motif=%s mur=%sms" % (d.get("ok"), len(d.get("sentiers") or []),
          str(d.get("motif","(aucun)"))[:90], d.get("mur_ms")))
except Exception as e:
    print("selection.json illisible : %s" % e)
PY
}
sel_valide() { python3 - "$B/selection.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1])); ok=bool(d.get("ok")) and len(d.get("sentiers") or [])>=1
except Exception: ok=False
sys.exit(0 if ok else 1)
PY
}

deadline=$(( $(date +%s) + 3000 ))

# --- LES SEPT MARQUEURS, verifies un par un. Un seul absent et la partie ne prouve rien.
while true; do
    A=0; B1=0; C=0; D=0; E=0; F=0; G=0
    grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
    grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B1=1
    grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
    grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
    grep -q "montre que ces bois REJOUENT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && E=1
    grep -q "prompt_chars" "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && F=1
    grep -q "MERLIN_BOT_COUVRANT" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null && G=1
    # v49 — LE FIL CONCRET. Sans lui la partie ne mesurerait pas ce qu'on lui demande : la ligne
    # CONTINUITE du verdict resterait a 0 sur 5 sans qu'on sache si c'est le correctif qui echoue
    # ou son absence qui parle.
    H=0; I=0
    grep -q "_extraire_fil" "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null && H=1
    grep -q "CE QUI ATTENDAIT LE VOYAGEUR" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && I=1
    [ "$A$B1$C$D$E$F$G$H$I" = "111111111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "v49 incomplet : sonde=$A place=$B1 annul=$C draft=$D boucle=$E chars=$F env=$G fil=$H queue=$I (jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"; exit 1; }
    sleep 30
done
SHA="$(git -C "$GD" rev-parse --short HEAD)"

for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

bon=0
while [ "$bon" -lt 2 ]; do
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "jamais d'accalmie"; exit 1; }
    dispo=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && ! pgrep -f "bin/godot" >/dev/null 2>&1 && [ "$dispo" -gt 14000000 ]; then bon=$((bon+1)); else bon=0; fi
    sleep 30
done
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA (v49 — le fil concret)"

# --- LA SELECTION : trois essais. Elle exige 3 sentiers ou rien ; une generation manquee ne
# doit pas condamner la partie, et l'echec doit dire son MOTIF.
essais=0
while :; do
    essais=$((essais+1))
    env -u RES bash "$AGENTS/a_partie_journal.sh" selection > "$COURRIER_RES/sel$essais.log" 2>&1
    [ -s "$B/selection.json" ] && sel_valide && break
    if [ "$essais" -ge 3 ]; then
        dire "ko" "selection refusee 3 fois : $(motif_sel)"
        exit 1
    fi
    sleep 25
done

MERLIN_BEATS=6 MERLIN_BOT_COUVRANT=1 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "partie temoin v49 : la scene doit s'ouvrir sur ce que l'issue precedente a laisse" \
    > "$COURRIER_RES/partie.log" 2>&1

# Le mode couvrant a-t-il vraiment tourne ? On le demande au JOURNAL, pas a un log.
#
# p71 a joue la partie ENTIERE et je l'ai jetee : ma garde cherchait « choix des cartes :
# COUVRANT » dans partie.log, alors que a_partie_journal.sh lance le jeu avec `>/dev/null 2>&1`.
# La sortie du JEU part dans godot.log ; partie.log ne porte que celle du harnais. La ligne ne
# pouvait donc JAMAIS s'y trouver — une garde impossible a satisfaire, exactement comme celle de
# job-066, et une partie de plus perdue.
#
# La preuve vit dans le journal : v48.1a y ecrit `choix_du_bot` a chaque beat des que le mode
# couvrant tourne. C'est une donnee du jeu, pas une ligne de log soumise a une redirection.
# Et elle ne s'evalue qu'APRES le journal, jamais avant : une partie jouee ne se jette plus.
if [ ! -s "$B/journal.json" ]; then
    tail -40 "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi73.txt"
    dire "ko" "journal absent : $(tail -c 250 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

cp "$B/journal.json" "$COURRIER_RES/journal.json" 2>/dev/null
mkdir -p "$COURRIER_RES/cliches"
cp "$B/cliches/"*.png "$COURRIER_RES/cliches/" 2>/dev/null
npng=$(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ')

python3 "$AGENTS/courrier/verdict_partie.py" "$B/journal.json" > "$COURRIER_RES/verdict73.txt" 2>&1
# Le verdict dit lui-meme si le mode couvrant a tourne (ligne BOT). On le SIGNALE, on ne jette pas :
# une partie jouee garde sa valeur meme si elle a tourne en mode historique — elle sert alors de
# point de comparaison, ce que p69 a prouve.
grep -q "BOT AUCUN choix justifie" "$COURRIER_RES/verdict73.txt" && \
    dire "note" "ATTENTION : partie jouee en mode HISTORIQUE (aucun choix_du_bot) — verdict valable comme point AVANT, pas comme mesure de v48.1"
dire "verdict" "captures=$npng sha=$SHA $(head -c 800 "$COURRIER_RES/verdict73.txt")"
curl -fsS -m 60 --retry 2 -T "$COURRIER_RES/journal.json" \
    -H "Filename: p73_journal.json" -H "Title: p73 journal" "$NT" >/dev/null 2>&1
echo "job-073 : partie jouee (sha=$SHA), $npng captures + journal dans COURRIER_RES."
