#!/usr/bin/env bash
# job-084 — LA MEME QUETE QUE q83, MAIS AVEC LE LOG EN ENTIER.
#
# q83 est morte a 352 s sans ecrire de quete, et le retour ne portait que quarante lignes de
# chargement de llama.cpp : le generateur ecrit sur godot.log, mais ce fichier commence par des
# centaines de lignes de moteur, et `tail -40` ne montre donc JAMAIS ce que le harnais a dit.
# C'est la TROISIEME fois que je filtre la reponse avant de la lire. On envoie le fichier entier,
# et un extrait des seules lignes du harnais a cote pour le lire d'un coup d'oeil.
#
# Aucune autre variable ne bouge : meme chapitre, meme longueur, meme rig que q82 et q83.
#
# q82 a prouve que le pari de conception tient : la mecanique etait parfaite, le contrat est passe.
# La PROSE, elle, avait trois defauts mesures — 23 marques de tutoiement contre 8 de vouvoiement
# dans le meme texte, un interieur de maison halluciné en pleine foret, et huit beats ou rien
# n'arrivait. Trois corrections poussees (canon vouvoye, `_marche(k,n)`, lieu referme) ; ce job
# rejoue EXACTEMENT le meme chapitre et la meme longueur pour que la difference soit lisible.
#
# La forme du job ne bouge pas d'un caractere : c'est celle de q82, la seule qui ait abouti apres
# six echecs. Une variable a la fois.
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
    tok="canari084-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q84 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

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
    A=0; B=0; C=0; D=0
    grep -q 'func _marche' "$GD/tools/generer_quete.gd" 2>/dev/null && A=1
    grep -q "l'adresse au joueur change" "$GD/tools/scenarios/valider.py" 2>/dev/null && B=1
    grep -q 'Merlin vous réveille' "$GD/data/quete/chapitres.json" 2>/dev/null && C=1
    grep -q 'fenetre 2048' "$GD/tools/generer_quete.gd" 2>/dev/null && D=1
    [ "$A$B$C$D" = "1111" ] && break
    [ "$(date +%s)" -ge "$deadline" ] && { dire "ko" "incomplet : arc=$A adresse=$B canon=$C taille_prompt=$D"; exit 1; }
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

T0=$(date +%s); BUDGET=2400; VU=0; MANQUES=0
while [ $(( $(date +%s) - T0 )) -lt "$BUDGET" ]; do
    if pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
        [ "$VU" = 0 ] && dire "en-vol" "le jeu tourne"
        VU=1; MANQUES=0
    elif [ "$VU" = 1 ]; then
        MANQUES=$(( MANQUES + 1 )); [ "$MANQUES" -ge 2 ] && break
    elif [ -s "$OUT" ]; then sleep 3; break
    elif [ $(( $(date +%s) - T0 )) -ge 300 ]; then break
    fi
    sleep 10
done
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
cp -f "$LOG" "$COURRIER_RES/q84_log.txt" 2>/dev/null || : > "$COURRIER_RES/q84_log.txt"
{
  echo "== godot.log : $(wc -l < "$LOG" 2>/dev/null || echo 0) lignes, $(stat -c%s "$LOG" 2>/dev/null || echo 0) octets"
  echo "== memoire dispo : $(sed -n 's/^MemAvailable:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo) ko"
  echo "== ce que le harnais a dit =="
  grep -naE "GÉNÉRATION|prompt=|beat +[0-9]+/|préambule|MerlinScenario mis au repos|voie|écriture|ÉCRITURE|ERREURS DU MOTEUR|moteur indisponible|chapitre .* inconnu|écrit :|SCRIPT ERROR|not declared|Erreur|error" "$LOG" 2>/dev/null | tail -80
  echo "== les 30 dernieres lignes, quelles qu'elles soient =="
  tail -30 "$LOG" 2>/dev/null
  echo "== inner.log (chien de garde) =="
  tail -20 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
} > "$COURRIER_RES/q84_extrait.txt" 2>&1

if [ -z "$TROUVE" ]; then
    dire "ko" "pas de quete apres ${DUREE}s (vu=$VU) — extrait + log entier en pieces jointes"
    for f in "$COURRIER_RES/q84_extrait.txt:q84_extrait.txt" "$COURRIER_RES/q84_log.txt:q84_log.txt"; do
        curl -fsS -m 120 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q84 ${f##*:}" "$NT" >/dev/null 2>&1
        sleep 3
    done
    exit 1
fi

cp "$TROUVE" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$TROUVE" > "$COURRIER_RES/verdict84.txt" 2>&1
VERDICT=$?
DIAG=$(python3 - "$TROUVE" <<'PY' 2>/dev/null
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
dire "verdict" "sha=$SHA · ${DUREE}s · trouvee: $TROUVE · $DIAG · CONTRAT $([ "$VERDICT" = 0 ] && echo PASSE || echo REFUSE)"
for f in "$TROUVE:q84_quete.json" "$COURRIER_RES/verdict84.txt:q84_verdict.txt" "$COURRIER_RES/q84_extrait.txt:q84_extrait.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q84 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-084 : ${DUREE}s, $DIAG"
