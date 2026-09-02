#!/usr/bin/env bash
# job-092 — LA GENERATION APRES REFACTOR, ET DEUX FUITES DE VOCABULAIRE MOTEUR.
#
# q91 a abouti : premiere quete generee ou une figure PARLE, ou Dame Aveline agit au lieu de
# regarder, avec 0,5 verbe de simple regard par beat. Elle laissait deux defauts nets, tous deux
# venant de ce que J'INJECTE et non du modele :
#
#   - les `tags` du biome (« on y trouve : Nature, Rituel, Vision ») sont une taxonomie de cartes.
#     Le modele a fini un beat sur le mot « Nature » tout seul et fait de « la Vision » un
#     personnage qui se manifeste. Ils ne partent plus.
#   - le role du Chœur commence par le nom de son pool interne, « Pilier des Druides ». q91 en a
#     fait un personnage quatre fois. La clause de tete qui ne repete que le pool est retiree.
#
# CE TOUR VERIFIE AUSSI UN REFACTOR, et c'est la vraie raison de le lancer. Le prompt d'un beat a
# ete sorti de `_beat_entier` vers `_prompt_beat`, et sa relecture vers `_lire_beat`, pour que le
# jeu de donnees d'affinage pose EXACTEMENT les questions que la production pose. Un parse check
# ne prouve pas qu'une generation marche encore : seule une quete ecrite le prouve.
#
# A relire : plus aucun « Pilier » ni « Vision » ni « Nature » en personnage, et une quete au
# moins aussi bonne que q91 — c'est-a-dire une figure qui parle et des regards sous 0,6 par beat.

set -u
RP="${REPO:-$HOME/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-$HOME/workspace/merlin-game}"
GS="$RP/infra/oracle/game/game-stack.sh"
OLLAMA="${OLLAMA_URL:-http://127.0.0.1:11434}"
ETAT="$HOME/.cache/merlin-agents/courrier"
BOITE="$RP/infra/oracle/agents/courrier"
BASE="$HOME/.cache/merlin-quete"; mkdir -p "$BASE"; chmod 777 "$BASE" 2>/dev/null
OUT="$BASE/quete_generee.json"
LOG="$HOME/.cache/merlin-game/godot.log"

NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari092-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q92 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

relancer_la_file() {
    local reste
    reste=$(cd "$BOITE" 2>/dev/null && for f in job-*.sh; do [ -f "$ETAT/${f%.sh}.fait" ] || echo "${f%.sh}"; done | head -1)
    [ -n "$reste" ] || return 0
    setsid nohup env -u RES bash "$RP/infra/oracle/agents/a_courrier.sh" > "$HOME/.cache/courrier-suite.log" 2>&1 &
}
trap relancer_la_file EXIT

# LE COURRIER NE TIRE PAS LE DEPOT DU JEU — il ne tire que le sien. job-082 a franchi sa garde
# parce qu'un autre mecanisme avait deja mis merlin-game a jour ; compter dessus, c'est attendre
# 90 minutes pour apprendre qu'on mesurait l'ancienne version. On tire soi-meme, en avance rapide
# seulement : le clone de la VM est en lecture, il n'a rien a fusionner.
git -C "$GD" pull --ff-only >/dev/null 2>&1

deadline=$(( $(date +%s) + 5400 ))
while true; do
    A=0; B=0; C=0
    grep -q 'func _prompt_beat' "$GD/tools/generer_quete.gd" 2>/dev/null && A=1
    grep -q 'func _role_sans_jargon' "$GD/tools/generer_quete.gd" 2>/dev/null && B=1
    grep -q 'on ne coupe pas ce qui' "$RP/infra/oracle/agents/a_game_idle.sh" 2>/dev/null && C=1
    [ "$A$B$C" = "111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : refactor=$A jargon=$B coupeur=$C"; exit 1; }
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
    dispo=$(sed -n 's/^MemAvailable:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo)
    if ! pgrep -x godot >/dev/null 2>&1 && [ "${dispo:-0}" -gt 14000000 ]; then bon=$((bon+1)); else bon=0; fi
    sleep 30
done
T_DEPART=$(date +%s)
dire "depart" "$(date -u +%H:%M:%SZ) sha=$SHA — ch1, 8 beats"

env -u RES bash "$GS" stop >/dev/null 2>&1
sleep 5
rm -f "$OUT"
MERLIN_SCRIPT="res://tools/generer_quete.gd" \
  MERLIN_CHAPITRE=1 MERLIN_BEATS_Q=8 MERLIN_QUETE_OUT="$OUT" \
  MERLIN_QUIT_AFTER_S=3300 \
  env -u RES bash "$GS" start > "$COURRIER_RES/lancement.log" 2>&1

# LA CONSIGNE EST-ELLE ARRIVEE ? `--script` doit figurer dans la ligne de commande de Godot. Sans
# ce controle, un harnais qui ne part pas ressemble a un harnais qui echoue, et coute un cycle.
sleep 12
LIGNE="$(grep -a 'native-inner. godot' "$HOME/.cache/merlin-game/inner.log" 2>/dev/null | tail -1)"
case "$LIGNE" in
    *generer_quete*) dire "amorce" "le harnais est bien lance" ;;
    *) dire "ko" "le jeu est parti SANS --script : $LIGNE"
       env -u RES bash "$GS" stop >/dev/null 2>&1; exit 1 ;;
esac
HARNAIS_MARQUE="$(cat "$HOME/.cache/merlin-game/harness" 2>/dev/null || echo VIDE)"
[ "$HARNAIS_MARQUE" = "VIDE" ] && dire "note" "game-stack ne pose pas encore la marque de harnais — le veilleur peut relancer par-dessus"

T0=$(date +%s); BUDGET=2400; VU=0; MANQUES=0
RAISON="inconnue"; JOURNAL="$COURRIER_RES/veille.txt"; : > "$JOURNAL"
# SIX MINUTES DE SILENCE, pas deux : q89 a mesure qu'un beat tient 130 s sans ecrire une ligne
# (1500 jetons a evaluer a 30 tok/s, puis 400 a ecrire a 5 tok/s). Deux minutes condamnaient un
# beat qui travaillait normalement.
SILENCE_MAX=360
while :; do
    ECOULE=$(( $(date +%s) - T0 ))
    if [ -s "$OUT" ]; then RAISON="fichier trouve apres ${ECOULE}s"; sleep 3; break; fi
    if [ "$ECOULE" -ge "$BUDGET" ]; then RAISON="budget de ${BUDGET}s epuise"; break; fi
    AGE=999
    [ -f "$LOG" ] && AGE=$(( $(date +%s) - $(stat -c %Y "$LOG" 2>/dev/null || echo 0) ))
    if pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
        [ "$VU" = 0 ] && dire "en-vol" "le jeu tourne"
        VU=1; MANQUES=0
    else
        MANQUES=$(( MANQUES + 1 ))
        echo "${ECOULE}s pgrep manque (${MANQUES}e fois), log vieux de ${AGE}s" >> "$JOURNAL"
        # On ne conclut a la mort que si le processus manque ET que le log est fige depuis
        # longtemps. pgrep seul s'est trompe deux fois ; le log, jamais.
        if [ "$VU" = 1 ] && [ "$AGE" -ge "$SILENCE_MAX" ]; then
            RAISON="processus absent et log fige depuis ${AGE}s (apres ${ECOULE}s)"; break
        fi
        if [ "$VU" = 0 ] && [ "$ECOULE" -ge 300 ]; then
            RAISON="le jeu n'est jamais apparu en ${ECOULE}s"; break
        fi
    fi
    sleep 10
done
echo "sortie de veille : $RAISON" >> "$JOURNAL"
sleep 8
env -u RES bash "$GS" stop >/dev/null 2>&1
DUREE=$(( $(date +%s) - T_DEPART ))

# LA QUETE PEUT ETRE A DEUX ENDROITS : le chemin demande, ou le repli user:// du generateur.
TROUVE=""
[ -s "$OUT" ] && TROUVE="$OUT"
if [ -z "$TROUVE" ]; then
    CAND=$(find "$HOME/.local/share/godot" "$HOME/.godot" -name 'quete_generee.json' -newermt "-2 hours" 2>/dev/null | head -1)
    [ -n "$CAND" ] && TROUVE="$CAND"
fi

# LE LOG ENTIER, plus un extrait de ce que le HARNAIS a dit. Les deux : l'extrait pour lire vite,
# le fichier complet parce que c'est exactement ce que j'ai coupe trois fois de suite.
cp -f "$LOG" "$COURRIER_RES/q92_log.txt" 2>/dev/null || : > "$COURRIER_RES/q92_log.txt"
{
  echo "== godot.log : $(wc -l < "$LOG" 2>/dev/null || echo 0) lignes, $(stat -c%s "$LOG" 2>/dev/null || echo 0) octets"
  echo "== memoire dispo : $(sed -n 's/^MemAvailable:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo) ko"
  echo "== ce que le harnais a dit =="
  grep -naE "GÉNÉRATION|prompt=|beat +[0-9]+/|préambule|MerlinScenario mis au repos|voie|écriture|ÉCRITURE|ERREURS DU MOTEUR|moteur indisponible|chapitre .* inconnu|écrit :|SCRIPT ERROR|not declared|Erreur|error" "$LOG" 2>/dev/null | tail -80
  echo "== les 30 dernieres lignes, quelles qu'elles soient =="
  tail -30 "$LOG" 2>/dev/null
  echo "== la veille, tour par tour =="
  cat "$JOURNAL" 2>/dev/null
  echo "== inner.log (chien de garde) =="
  tail -20 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
} > "$COURRIER_RES/q92_extrait.txt" 2>&1

if [ -z "$TROUVE" ]; then
    dire "ko" "pas de quete apres ${DUREE}s (vu=$VU) — VEILLE : $RAISON"
    for f in "$COURRIER_RES/q92_extrait.txt:q92_extrait.txt" "$COURRIER_RES/q92_log.txt:q92_log.txt"; do
        curl -fsS -m 120 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q92 ${f##*:}" "$NT" >/dev/null 2>&1
        sleep 3
    done
    exit 1
fi

cp "$TROUVE" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$TROUVE" > "$COURRIER_RES/verdict92.txt" 2>&1
VERDICT=$?
DIAG=$(python3 "$GD/tools/scenarios/relire.py" "$TROUVE" 2>/dev/null | tr '\n' ' ' | tr -s ' ')
[ -n "$DIAG" ] || DIAG=$(python3 - "$TROUVE" <<'PY' 2>/dev/null
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
e=d.get('_erreurs_moteur') or {}
b=d.get('beats') or []
chars=sum(len(str(x.get('scene',''))+str(x.get('issue',''))) for x in b)
vides=[x['n'] for x in b if len(str(x.get('scene','')).strip())<40]
import re
txt=" ".join(str(x.get('scene',''))+" "+str(x.get('issue','')) for x in b)
nu=re.sub(r"«[^»]*»"," ",txt)
tu=len(re.findall(r"\b(?:[Tt]u|[Tt]on|[Tt]a|[Tt]es|[Tt]oi)\b",nu))
vs=len(re.findall(r"\b(?:[Vv]ous|[Vv]otre|[Vv]os)\b",nu))
# Un nom propre est une majuscule qui n'est PAS en tete de phrase : sans ce filtre, « Contre »
# et « Derriere » comptent comme des figures et le nombre ne veut plus rien dire.
noms=sorted(set(re.findall(r"(?<=[a-zéèêàç,] )([A-ZÉÈÀÇ][a-zéèêàçâîôûïüë']{2,})",txt))
            - {"Vous","Votre","Vos","Elle","Elles","Ils","Cela"})
print("%d beats · %d car. · vides: %s · TU=%d VOUS=%d · noms: %s · ERREURS: %s"
  % (len(b), chars, vides or 'aucun', tu, vs, ", ".join(noms[:8]) or 'AUCUN',
     "; ".join("%dx %s" % (v,k) for k,v in e.items()) if e else 'AUCUNE'))
PY
)
dire "verdict" "sha=$SHA · ${DUREE}s ($RAISON) · $DIAG · CONTRAT $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE)"
for f in "$TROUVE:q92_quete.json" "$COURRIER_RES/verdict92.txt:q92_verdict.txt" "$COURRIER_RES/q92_extrait.txt:q92_extrait.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q92 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-092 : ${DUREE}s, $DIAG"
