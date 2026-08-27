#!/usr/bin/env bash
# JOUER UNE PARTIE ET LA RACONTER — en rendu réel, sur la VM, avec le modèle du jeu.
#
# Deux phases, appelées séparément :
#   a_partie_journal.sh selection            → les trois sentiers écrits par Merlin
#   a_partie_journal.sh partie <index> "<raison>"  → la partie jouée sur le sentier choisi
#
# POURQUOI DEUX. Le choix du sentier se fait ENTRE les deux, par quelqu'un qui a lu les trois
# propositions. Régénérer la sélection en phase 2 donnerait trois AUTRES titres — l'angle est tiré
# au sort à chaque appel — et on jouerait donc autre chose que ce qui a été montré.
#
# EN RENDU RÉEL et non en headless : c'est le jeu tel que Maxime le voit, et c'est la seule
# manière de prendre des captures. Le prix est connu et mesuré — le rendu logiciel coûte un
# facteur 2 à 3 sur chaque génération.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
type -t etape >/dev/null 2>&1 || etape() { :; }

PHASE="${1:-selection}"
PICK="${2:-0}"
RAISON="${3:-}"

GS="$HERE/../game/game-stack.sh"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
BASE="$HOME/.cache/merlin-partie"
SHOTS="$BASE/cliches"
SEL="$BASE/selection.json"
JOURNAL="$BASE/journal.json"
LOCK="$HOME/.cache/merlin-agents/e2e.lock"
mkdir -p "$BASE" "$SHOTS" "$(dirname "$LOCK")"

# Le verrou dit au veilleur (a_game_idle) de ne PAS couper : une partie n'a aucun spectateur VNC,
# et sans lui elle serait interrompue au bout de cinq minutes, au milieu du récit.
touch "$LOCK"
exec 9>"$LOCK"
# ON ATTEND, on n'abandonne pas. Le jeu lancé en arrière-plan HÉRITE de ce descripteur et tient
# donc le verrou tant qu'il vit — c'est voulu, c'est ce qui empêche le veilleur de le couper. Mais
# ça veut aussi dire qu'une phase qui vient de finir garde le verrou quelques secondes, le temps
# que Godot s'éteigne vraiment. Un `-n` refusait alors la phase suivante pour une poignée de
# secondes d'écart : c'est exactement ce qui est arrivé le 2026-08-18, et la partie n'a jamais
# démarré. Trois minutes d'attente couvrent largement une extinction.
if ! flock -w 180 9; then
    # VERROU ORPHELIN. Trois lancements de suite ont été refusés ici, dont un tenu par un shell
    # mort que `pgrep` ne voyait plus : le descripteur survivait, le verrou avec. Un garde-fou qui
    # protège une partie ne doit pas empêcher toutes les suivantes.
    #
    # Le remède est franc : si plus AUCUN jeu ne tourne, le verrou ne protège rien. On remplace le
    # fichier — un nouvel inode porte un verrou neuf, l'ancien meurt avec son processus fantôme.
    if pgrep -f "godot.*probe_partie_journal" >/dev/null 2>&1; then
        echo "une partie tourne vraiment (jeu vivant) — abandon"
        exit 1
    fi
    echo "verrou tenu par un processus mort — je le remplace"
    exec 9>&-
    rm -f "$LOCK"
    touch "$LOCK"
    exec 9>"$LOCK"
    flock -n 9 || { echo "verrou toujours pris après remplacement — abandon"; exit 1; }
fi

etape 1 4 "décharger Ollama"
# La RAM et les cœurs reviennent au jeu : un modèle résident double le temps de génération
# (mesuré 31,5 s contre 63,2 s). Sur une partie de douze beats, l'écart se compte en dizaines de
# minutes.
for m in $(curl -fsS -m 5 "$OLLAMA/api/ps" | python3 -c "
import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "$OLLAMA/api/generate" -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done

bash "$GS" stop >/dev/null 2>&1

# 2026-08-24 (p65) — DRAIN AVANT LANCEMENT. `stop` rend la main avant que Godot ne soit
# vraiment mort : un mourant de la phase precedente peut encore tenir l'affichage :99 et la
# memoire au moment ou le suivant charge 4,79 Gio de modele. On attend qu'il n'y ait plus
# AUCUN godot de sonde avant de lancer — c'est gratuit, et ca supprime un chevauchement.
fin_drain=$(( $(date +%s) + 90 ))
while pgrep -f "godot.*probe_partie_journal" >/dev/null 2>&1; do
    [ "$(date +%s)" -ge "$fin_drain" ] && break
    sleep 3
done

if [ "$PHASE" = "selection" ]; then
    etape 2 4 "les trois sentiers (jusqu'à 5 min)"
    rm -f "$SEL"
    MERLIN_SCRIPT="res://tools/probe_partie_journal.gd" MERLIN_PHASE=selection \
        MERLIN_BIOME="${MERLIN_BIOME:-foret}" MERLIN_SELECTION_OUT="$SEL" \
        MERLIN_SHOTS_DIR="$SHOTS" MERLIN_QUIT_AFTER_S=420 \
        bash "$GS" start >/dev/null 2>&1
    BUDGET=430
else
    etape 2 4 "la partie (jusqu'à 2 h)"
    [ -s "$SEL" ] || { echo "aucune sélection — lancer la phase 'selection' d'abord"; exit 1; }
    rm -f "$JOURNAL"
    MERLIN_SCRIPT="res://tools/probe_partie_journal.gd" MERLIN_PHASE=partie \
        MERLIN_BIOME="${MERLIN_BIOME:-foret}" MERLIN_SELECTION_IN="$SEL" \
        MERLIN_PICK="$PICK" MERLIN_PICK_RAISON="$RAISON" \
        MERLIN_JOURNAL_OUT="$JOURNAL" MERLIN_SHOTS_DIR="$SHOTS" \
        MERLIN_BEATS="${MERLIN_BEATS:-}" \
        MERLIN_BOT_COUVRANT="${MERLIN_BOT_COUVRANT:-}" \
        MERLIN_QUIT_AFTER_S=7200 \
        bash "$GS" start >/dev/null 2>&1
    BUDGET=7250
fi

etape 3 4 "attente du résultat"
CIBLE="$SEL"; [ "$PHASE" = "partie" ] && CIBLE="$JOURNAL"
T0=$(date +%s)
# On attend que le JEU s'arrête, pas que le fichier apparaisse : le journal est écrit au fil de
# l'eau, donc sa seule présence ne dit pas que la partie est finie.
# 2026-08-21 — GRÂCE DE DÉMARRAGE (p48 : « aucun résultat après 0s »). Au premier lancement à
# froid après reboot, godot met plus de 10 s à apparaître : casser au premier pgrep manqué
# faisait tuer le jeu par le stop de clôture EN PLEINE CHARGE des modèles. Tant que le jeu n'a
# JAMAIS été vu, on ne casse pas : en sélection la cible écrite suffit à conclure, et un bail
# franc à 300 s couvre le lancement réellement mort. Dès qu'il a été VU, sa disparition conclut
# comme avant.
VU=0
MANQUES=0
while [ $(( $(date +%s) - T0 )) -lt "$BUDGET" ]; do
    if pgrep -f "godot.*probe_partie_journal" >/dev/null 2>&1; then
        VU=1
        MANQUES=0
    elif [ "$VU" = 1 ]; then
        # Un seul pgrep manque ne conclut plus une partie : sous forte charge (chargement des
        # modeles, 4,79 Gio), un passage peut rater un processus bien vivant. Deux d'affilee.
        MANQUES=$(( MANQUES + 1 ))
        [ "$MANQUES" -ge 2 ] && break
    elif [ "$PHASE" = "selection" ] && [ -s "$CIBLE" ]; then
        sleep 2
        break
    elif [ $(( $(date +%s) - T0 )) -ge 300 ]; then
        break  # jamais vu en 5 min et rien d'écrit : le lancement a réellement échoué
    fi
    sleep 10
done
DUREE=$(( $(date +%s) - T0 ))

etape 4 4 "clôture"
printf 'stopped' > "$HOME/.cache/merlin-game/desired"
bash "$GS" stop >/dev/null 2>&1

if [ ! -s "$CIBLE" ]; then
    # 2026-08-24 (p65) — UN ECHEC MUET COUTE UNE PARTIE ET UNE NUIT. Le jeu etait vivant a
    # t=0 (`$GS start` ne rend la main qu'une fois le VNC ouvert) et mort dix secondes plus
    # tard, en pleine charge des modeles : les douze dernieres lignes du journal ne
    # montraient que llama_model_loader, et n'ont RIEN explique. On dit desormais l'etat de
    # la memoire, le verdict du noyau (tue par l'OOM ?), et le journal de l'enveloppe.
    echo "aucun résultat après ${DUREE}s (phase=$PHASE, vu=$VU, manques=$MANQUES)"
    echo "-- memoire --"
    awk '/MemTotal|MemAvailable|SwapFree/ {print $1, $2}' /proc/meminfo 2>/dev/null
    echo "-- noyau (tue par le manque de memoire ?) --"
    { dmesg -T 2>/dev/null || journalctl -k -n 200 --no-pager 2>/dev/null; } \
        | grep -iE "out of memory|oom-kill|killed process" | tail -4
    echo "-- enveloppe (inner.log) --"
    tail -12 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
    echo "-- jeu (godot.log, hors bruit llama) --"
    grep -av "^llama_model_loader\|^print_info\|^load_tensors\|^llama_kv_cache\|^ggml_" \
        "$HOME/.cache/merlin-game/godot.log" 2>/dev/null | tail -25
    exit 1
fi
echo "phase $PHASE terminée en ${DUREE}s → $CIBLE"
python3 -c "
import json,sys
d=json.load(open('$CIBLE'))
if 'sentiers' in d and 'beats' not in d:
    for i,s in enumerate(d.get('sentiers') or []):
        print('%d. %s — %s' % (i, s['titre'], s['pitch']))
else:
    print('beats: %d · fin: %s · cliches: %d' % (len(d.get('beats') or []),
          (d.get('fin') or {}).get('type','?'), len(d.get('cliches') or [])))
" 2>/dev/null || true
