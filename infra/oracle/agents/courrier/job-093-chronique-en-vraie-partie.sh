#!/usr/bin/env bash
# job-093 — LA CHRONIQUE ECRITE PAR LE JEU, CONTROLEE PAR UNE VRAIE PARTIE.
#
# Le journal des chroniques est livre : chaque traversee s'ecrit dans user://chroniques et se relit
# dans l'ecran CHRONIQUES. Deux epreuves le prouvent — l'une ecrit vraiment sur le disque, l'autre
# ouvre l'ecran et clique. Mais les accroches de BEAT (la scene posee, l'issue resolue) ne sont
# prouvees qu'en unitaire : jouer huit beats demande le modele, donc la VM.
#
# LE CONTROLE EST UNE CONFRONTATION, pas une relecture. La sonde des parties temoins enregistre
# deja tout ce qui se joue, de l'exterieur. Le jeu enregistre maintenant la meme chose, de
# l'interieur. Deux temoins independants sur la MEME partie doivent raconter la meme histoire :
# meme nombre de beats, meme prose. S'ils divergent, c'est l'accroche qui ment — et une chronique
# qui ment est pire qu'une chronique absente, puisqu'on la croit.
#
# CE QUI EST INCERTAIN ET SE DECOUVRIRA ICI : le jeu tourne dans `unshare --user --map-root-user`,
# donc user:// peut se trouver ailleurs que dans le HOME du Courrier. Le job cherche la chronique
# aux endroits possibles et DIT lequel a repondu, comme on l'a fait pour la quete generee.

set -u
AGENTS="${REPO:-$HOME/workspace/M.E.R.L.I.N}/infra/oracle/agents"
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
B="$HOME/.cache/merlin-partie"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari93-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: p93 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

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

# LA CHRONIQUE D'AVANT NE DOIT PAS POLLUER LA MESURE. On note ce qui existe deja pour ne compter
# ensuite que ce que CETTE partie a ecrit — sans rien effacer : ce sont des donnees de jeu.
CHRONO_AVANT=$(find "$HOME/.local/share/godot" "$HOME/.godot" "$HOME" -maxdepth 6 -type d -name chroniques 2>/dev/null | head -1)
N_AVANT=0
[ -n "$CHRONO_AVANT" ] && N_AVANT=$(ls "$CHRONO_AVANT"/*.json 2>/dev/null | grep -vc index.json || echo 0)

# LA LIGNE QUI CHANGE TOUT : plus de MERLIN_BEATS. Le jeu tire sa propre longueur.
MERLIN_BOT_COUVRANT=1 env -u RES bash "$AGENTS/a_partie_journal.sh" partie 0 \
    "quete complete : longueur libre, la continuite doit tenir sur toute sa duree" \
    > "$COURRIER_RES/partie.log" 2>&1

if [ ! -s "$B/journal.json" ]; then
    tail -40 "$COURRIER_RES/partie.log" > "$COURRIER_RES/pourquoi93.txt"
    dire "ko" "journal absent : $(tail -c 250 "$COURRIER_RES/partie.log" | tr '\n' ' ')"
    exit 1
fi

cp "$B/journal.json" "$COURRIER_RES/journal.json" 2>/dev/null
mkdir -p "$COURRIER_RES/cliches"
cp "$B/cliches/"*.png "$COURRIER_RES/cliches/" 2>/dev/null
npng=$(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ')

python3 "$AGENTS/courrier/verdict_partie.py" "$B/journal.json" > "$COURRIER_RES/verdict93.txt" 2>&1
grep -q "BOT AUCUN choix justifie" "$COURRIER_RES/verdict93.txt" && \
    dire "note" "ATTENTION : partie jouee en mode HISTORIQUE (aucun choix_du_bot) — verdict valable comme point AVANT, pas comme mesure"

# La longueur EFFECTIVE, dite d'emblee : c'est la premiere chose a savoir sur une quete libre.
nb=$(python3 -c "import json,sys; print(len((json.load(open(sys.argv[1])).get('beats') or [])))" "$B/journal.json" 2>/dev/null || echo '?')
dire "verdict" "beats=$nb captures=$npng sha=$SHA $(head -c 700 "$COURRIER_RES/verdict93.txt")"

# ── LA CONFRONTATION DES DEUX TEMOINS ─────────────────────────────────────────────────────────
# La sonde a compte $nb beats de l'exterieur. Le jeu, de l'interieur, a ecrit sa chronique. Les
# deux doivent s'accorder ; sinon l'accroche ment, et une chronique qui ment est pire qu'absente.
CHRONO=$(find "$HOME/.local/share/godot" "$HOME/.godot" "$HOME" -maxdepth 6 -type d -name chroniques 2>/dev/null | head -1)
if [ -z "$CHRONO" ]; then
    dire "chronique" "AUCUN dossier chroniques trouve — user:// est ailleurs que dans le HOME du Courrier (le jeu tourne sous unshare). Cherche : \$HOME/.local/share/godot, \$HOME/.godot, \$HOME"
else
    RECENTE=$(ls -t "$CHRONO"/*.json 2>/dev/null | grep -v index.json | head -1)
    if [ -z "$RECENTE" ]; then
        dire "chronique" "dossier trouve ($CHRONO) mais AUCUNE chronique dedans — l'accroche d'ouverture n'a pas tire"
    else
        cp "$RECENTE" "$COURRIER_RES/chronique.json" 2>/dev/null
        cp "$CHRONO/index.json" "$COURRIER_RES/chronique_index.json" 2>/dev/null
        CMP=$(python3 - "$RECENTE" "$B/journal.json" <<'PYX' 2>&1
import json, sys
def charge(p):
    try:
        return json.load(open(p, encoding="utf-8"))
    except Exception as e:
        return {"_erreur": str(e)}
c = charge(sys.argv[1]); j = charge(sys.argv[2])
cb = c.get("beats") or []
jb = j.get("beats") or []
poses = len(cb)
resolus = sum(1 for b in cb if b.get("degre"))
signes = sum(len(str(b.get("scene",""))) + len(str(b.get("issue",""))) for b in cb)
# LA PROSE DOIT ETRE LA MEME, pas seulement le compte : deux temoins qui comptent pareil et
# racontent autre chose, c'est exactement le defaut qu'on cherche.
accords = 0
for a, b in zip(cb, jb):
    if str(a.get("scene","")).strip()[:60] and str(a.get("scene","")).strip()[:60] == str(b.get("narration","")).strip()[:60]:
        accords += 1
print("chronique: %d pose(s), %d resolu(s), %d signes | sonde: %d beat(s) | scenes identiques: %d/%d | fin: %s"
      % (poses, resolus, signes, len(jb), accords, min(len(cb), len(jb)),
         (c.get("fin") or {}).get("type", "AUCUNE (interrompue)")))
PYX
)
        dire "chronique" "$CMP"
        for f in "$COURRIER_RES/chronique.json:p93_chronique.json" "$COURRIER_RES/chronique_index.json:p93_chronique_index.json"; do
            curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: p93 ${f##*:}" "$NT" >/dev/null 2>&1
            sleep 2
        done
    fi
fi

curl -fsS -m 90 --retry 2 -T "$COURRIER_RES/journal.json" \
    -H "Filename: p93_journal.json" -H "Title: p93 journal" "$NT" >/dev/null 2>&1
for png in $(ls "$COURRIER_RES/cliches/"*.png 2>/dev/null | sort); do
    curl -fsS -m 90 --retry 2 -T "$png" -H "Filename: $(basename "$png")" \
        -H "Title: p93 $(basename "$png")" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-093 : quete complete jouee ($nb beats, sha=$SHA), $npng captures."
