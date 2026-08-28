#!/usr/bin/env bash
# job-074 — LA QUETE COMPLETE. Plus de longueur forcee : le jeu tire la sienne, 8 a 25 beats.
#
# Maxime, 2026-08-28 : « on va plus loin maintenant, pas 5 beats mais des quetes completes, duree
# variable ». Toutes les parties temoins jusqu'ici passaient MERLIN_BEATS=6 — une variable dont le
# code dit lui-meme qu'elle sert « pour le DIAGNOSTIC uniquement » (merlin_scenario.gd:1324). On
# cesse simplement de la passer, et merlin_scenario tire sa longueur entre QUETE_BEATS_MIN=8 et
# QUETE_BEATS_MAX=25.
#
# CE QUE CELA CHANGE, ET QU'IL FAUDRA LIRE DANS LE VERDICT :
#   - L'ARC s'ecrit par TRANCHES DE QUATRE. Une quete de 6 beats en demandait deux ; une de 25 en
#     demande six. Or c'est cette ecriture d'arc, en fond sur le Conteur, qui a produit les beats
#     a 55 et 61 secondes des deux dernieres parties. La cible des 20 s va probablement souffrir :
#     on le dira avec le compte exact, pas avec une excuse.
#   - LA CONTINUITE se mesure sur bien plus d'enchainements : 7 a 24 au lieu de 5. Un fil qui
#     tient sur cinq beats peut deriver sur vingt — c'est precisement ce qu'on veut savoir.
#   - LES CAPTURES sont etalees depuis v50 (le beat 1 puis un sur trois, plafonnees a douze) :
#     une chronique de quete longue a enfin de quoi montrer son milieu.
#
# L'ECHEANCE est portee a 100 minutes. Une quete de 25 beats coute, rien qu'en poses deliberees
# du bot, 25 fois (25 s de reflexion + 35 s de lecture) — vingt-cinq minutes avant meme de compter
# la generation.
set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari074-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p74 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

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

deadline=$(( $(date +%s) + 6000 ))

# --- LES ONZE MARQUEURS. Neuf de v48.1/v49, plus les deux de v49.1 et v50.
while true; do
    A=0; B1=0; C=0; D=0; E=0; F=0; G=0; H=0; I=0; J=0; K=0
    grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
    grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B1=1
    grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
    grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
    grep -q "montre que ces bois REJOUENT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && E=1
    grep -q "prompt_chars" "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && F=1
    grep -q "MERLIN_BOT_COUVRANT" "$RP/infra/oracle/game/game-stack.sh" 2>/dev/null && G=1
    grep -q "_extraire_fil" "$GD/scripts/llm/merlin_scenario.gd" 2>/dev/null && H=1
    grep -q "CE QUI ATTENDAIT LE VOYAGEUR" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && I=1
    # v49.1 : sans lui le journal ne peut PAS prouver ses reussites (dc, total, marge absents).
    grep -q "L'INSTANTANE DES MECANIQUES, TOUT EN HAUT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && J=1
    # v50 : sans lui une quete de vingt beats ne rend que trois images.
    grep -q "DES CLICHES ETALES SUR TOUTE LA QUETE" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && K=1
    [ "$A$B1$C$D$E$F$G$H$I$J$K" = "11111111111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : sonde=$A place=$B1 annul=$C draft=$D boucle=$E chars=$F env=$G fil=$H queue=$I meca=$J cliches=$K (jeu=$(git -C "$GD" rev-parse --short HEAD 2>/dev/null))"; exit 1; }
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
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — QUETE COMPLETE, longueur libre 8 a 25 beats"

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

# LA LIGNE QUI CHANGE TOUT : plus de MERLIN_BEATS. Le jeu tire sa propre longueur.
MERLIN_BOT_COUVRANT=1 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "quete complete : longueur libre, la continuite doit tenir sur toute sa duree" \
    > "$COURRIER_RES/partie.log" 2>&1

if [ ! -s "$B/journal.json" ]; then
    tail -40 "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi74.txt"
    dire "ko" "journal absent : $(tail -c 250 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

cp "$B/journal.json" "$COURRIER_RES/journal.json" 2>/dev/null
mkdir -p "$COURRIER_RES/cliches"
cp "$B/cliches/"*.png "$COURRIER_RES/cliches/" 2>/dev/null
npng=$(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ')

python3 "$AGENTS/courrier/verdict_partie.py" "$B/journal.json" > "$COURRIER_RES/verdict74.txt" 2>&1
grep -q "BOT AUCUN choix justifie" "$COURRIER_RES/verdict74.txt" && \
    dire "note" "ATTENTION : partie jouee en mode HISTORIQUE (aucun choix_du_bot) — verdict valable comme point AVANT, pas comme mesure"

# La longueur EFFECTIVE, dite d'emblee : c'est la premiere chose a savoir sur une quete libre.
nb=$(python3 -c "import json,sys; print(len((json.load(open(sys.argv[1])).get('beats') or [])))" "$B/journal.json" 2>/dev/null || echo '?')
dire "verdict" "beats=$nb captures=$npng sha=$SHA $(head -c 900 "$COURRIER_RES/verdict74.txt")"

curl -fsS -m 90 --retry 2 -T "$COURRIER_RES/journal.json" \
    -H "Filename: p74_journal.json" -H "Title: p74 journal" "$NT" >/dev/null 2>&1
for png in $(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | sort); do
    curl -fsS -m 90 --retry 2 -T "$png" -H "Filename: $(basename "$png")" \
        -H "Title: p74 $(basename "$png")" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-074 : quete complete jouee ($nb beats, sha=$SHA), $npng captures."
