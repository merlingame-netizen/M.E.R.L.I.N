#!/usr/bin/env bash
# job-086 — LE VEILLEUR NE RELANCE PLUS LE HARNAIS PAR-DESSUS LUI-MEME.
#
# q85 a donne la cause, et elle explique aussi q83. Le journal de q85 commence par un demarrage
# NEUF de Godot, sa derniere ligne est une pensee de menu, et la ligne de commande n'a AUCUN
# `--script` : ce n'est pas mon harnais qui tournait a la fin, c'est le jeu normal.
#
# C'est le veilleur (a_game_watchdog). Mon `$GS start` pose « desire=running » ; le veilleur voit
# ensuite « desire=running » sans VNC ouvert, en conclut que le jeu est tombe, et relance —
# SANS MERLIN_SCRIPT. Il tue donc le harnais, demarre le jeu normal a sa place, et rouvre
# godot.log en ecriture, ce qui efface tout ce que le harnais avait dit.
#
# Trois echecs, une seule cause : q83 morte a 352 s, q85 remplacee par le menu, et q84 achevee par
# ma propre veille qui reagissait a cette meme relance a quarante secondes de la fin.
#
# Correction posee dans l'outillage, pas dans ce job : game-stack ecrit `harness` avec le script
# lance, et le veilleur ne relance jamais un harnais — il ne sait pas le relancer. Ce job verifie
# en plus, dix secondes apres le depart, que `--script` est bien arrive jusqu'a Godot : si la
# consigne se perd encore, on le dit tout de suite au lieu de mesurer le menu pendant dix minutes.
#
# q84 a tout dit. La generation MARCHAIT : sept beats sur huit ecrits, prompts de 383 a 805 jetons
# (jamais pres des 2048 — l'hypothese de la fenetre etait fausse), rythme de 30 a 58 s par appel.
# C'est LE JOB qui a tue le jeu a quarante secondes de la fin : la regle de vie « deux `pgrep`
# manques d'affilee = c'est fini » a declare mort un processus qui ecrivait le beat 7.
#
# `pgrep` n'est pas un signal de vie, c'est une supposition. Le vrai signal, c'est le LOG QUI
# GRANDIT : tant que godot.log gagne des lignes, quelque chose travaille, que pgrep le voie ou non.
# Et le vrai signal de FIN, c'est le fichier de quete qui apparait — pas la disparition d'un
# processus, qui arrive de toute facon apres.
#
# La veille devient donc : la quete existe -> fini. Sinon, le log a bouge il y a moins de deux
# minutes -> on attend, quoi que dise pgrep. Sinon seulement, on compte les manques, et il en faut
# six (une minute) au lieu de deux.
#
# Le jeu ne bouge pas d'une ligne : q84 a prouve que le generateur fait son travail.
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
    tok="canari086-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: q86 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }

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
while [ $(( $(date +%s) - T0 )) -lt "$BUDGET" ]; do
    # 1. LA FIN, LA VRAIE : le fichier est ecrit. Rien d'autre a attendre.
    if [ -s "$OUT" ]; then sleep 3; break; fi
    if pgrep -f "godot.*generer_quete" >/dev/null 2>&1; then
        [ "$VU" = 0 ] && dire "en-vol" "le jeu tourne"
        VU=1; MANQUES=0
    else
        # 2. LE LOG QUI GRANDIT prime sur pgrep : c'est le seul signe qui ne suppose rien.
        AGE=999
        [ -f "$LOG" ] && AGE=$(( $(date +%s) - $(stat -c %Y "$LOG" 2>/dev/null || echo 0) ))
        if [ "$AGE" -lt 120 ]; then
            MANQUES=0
        elif [ "$VU" = 1 ]; then
            MANQUES=$(( MANQUES + 1 ))
            [ "$MANQUES" -ge 6 ] && break
        elif [ $(( $(date +%s) - T0 )) -ge 300 ]; then
            break
        fi
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
cp -f "$LOG" "$COURRIER_RES/q86_log.txt" 2>/dev/null || : > "$COURRIER_RES/q86_log.txt"
{
  echo "== godot.log : $(wc -l < "$LOG" 2>/dev/null || echo 0) lignes, $(stat -c%s "$LOG" 2>/dev/null || echo 0) octets"
  echo "== memoire dispo : $(sed -n 's/^MemAvailable:[[:space:]]*\([0-9]*\).*/\1/p' /proc/meminfo) ko"
  echo "== ce que le harnais a dit =="
  grep -naE "GÉNÉRATION|prompt=|beat +[0-9]+/|préambule|MerlinScenario mis au repos|voie|écriture|ÉCRITURE|ERREURS DU MOTEUR|moteur indisponible|chapitre .* inconnu|écrit :|SCRIPT ERROR|not declared|Erreur|error" "$LOG" 2>/dev/null | tail -80
  echo "== les 30 dernieres lignes, quelles qu'elles soient =="
  tail -30 "$LOG" 2>/dev/null
  echo "== inner.log (chien de garde) =="
  tail -20 "$HOME/.cache/merlin-game/inner.log" 2>/dev/null
} > "$COURRIER_RES/q86_extrait.txt" 2>&1

if [ -z "$TROUVE" ]; then
    dire "ko" "pas de quete apres ${DUREE}s (vu=$VU) — extrait + log entier en pieces jointes"
    for f in "$COURRIER_RES/q86_extrait.txt:q86_extrait.txt" "$COURRIER_RES/q86_log.txt:q86_log.txt"; do
        curl -fsS -m 120 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q86 ${f##*:}" "$NT" >/dev/null 2>&1
        sleep 3
    done
    exit 1
fi

cp "$TROUVE" "$COURRIER_RES/quete_generee.json"
python3 "$GD/tools/scenarios/valider.py" "$TROUVE" > "$COURRIER_RES/verdict86.txt" 2>&1
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
for f in "$TROUVE:q86_quete.json" "$COURRIER_RES/verdict86.txt:q86_verdict.txt" "$COURRIER_RES/q86_extrait.txt:q86_extrait.txt"; do
    curl -fsS -m 90 --retry 2 -T "${f%%:*}" -H "Filename: ${f##*:}" -H "Title: q86 ${f##*:}" "$NT" >/dev/null 2>&1
    sleep 2
done
echo "job-086 : ${DUREE}s, $DIAG"
