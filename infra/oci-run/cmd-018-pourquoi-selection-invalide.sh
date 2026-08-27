#!/usr/bin/env bash
# cmd-018 (pont OCI) — POURQUOI LA SELECTION DE p70 A ETE JUGEE INVALIDE.
#
# p70 s'est arrete avant de jouer : « selection invalide », apres deux tentatives. Or la queue du
# log montre de la PROSE GENEREE (« les sentiers qui se referment vers le Val sans Retour »,
# « le Chevalier a l'armure ternie ») : le modele a donc bien ecrit. C'est la validation du
# fichier qui a refuse — `ok` faux, ou zero sentier.
#
# Trois suspects possibles, et je ne veux en eliminer aucun par raisonnement :
#   - selection.json absent ou ecrit ailleurs que la ou le job le cherche ;
#   - `ok` a false parce que la phase n'a pas atteint sa fin (delai, plantage) ;
#   - v48.1c : une generation ANNULEE rend desormais une erreur au lieu d'un demi-texte. Si
#     quelque chose annule la voie pendant la selection, ce qui passait avant en silence
#     echoue maintenant bruyamment — ce serait une regression de MON patch, et il faut le savoir.
#
# On lit, on ne devine pas.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
B="$HOME/.cache/merlin-partie"
RES="$HOME/.cache/merlin-agents/courrier-res"
[ -d "$RES" ] || RES=$(ls -1td "$HOME"/.cache/merlin-agents/*res* 2>/dev/null | head -1)

echo "A selection.json=$([ -s "$B/selection.json" ] && stat -c %s "$B/selection.json" || echo ABSENT) octets  mtime=$(stat -c %y "$B/selection.json" 2>/dev/null | cut -c1-19)"
if [ -s "$B/selection.json" ]; then
  python3 - "$B/selection.json" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    print("B ok=%s sentiers=%d cles=%s" % (d.get("ok"), len(d.get("sentiers") or []), ",".join(sorted(d.keys()))[:110]))
    for s in (d.get("sentiers") or [])[:3]:
        print("B   - %s" % str(s.get("titre",""))[:70])
except Exception as e:
    print("B selection.json ILLISIBLE : %s" % e)
PY
fi

# le log de la selection : les lignes qui disent pourquoi
L=$(ls -1t "$RES"/sel*.log "$RES"/*/sel*.log 2>/dev/null | head -1)
echo "C log=${L:-ABSENT}"
if [ -n "${L:-}" ]; then
  echo "C etapes: $(grep -ac 'etape' "$L" 2>/dev/null) ; erreurs:"
  grep -aE "SCRIPT ERROR|annulee|erreur|ERREUR|timeout|delai|echec|vide|introuvable" "$L" 2>/dev/null | tail -6 | cut -c1-150
  echo "C queue du log :"
  tail -c 420 "$L" 2>/dev/null | tr '\n' ' ' | cut -c1-420
fi
# la trace du jeu lui-meme
G="$HOME/.cache/merlin-game/godot.log"
[ -s "$G" ] && { echo "D godot.log (hors bruit llama) :"; grep -avE "llama_|load_tensors|ggml|print_info|init:" "$G" 2>/dev/null | grep -aE "SELECTION|selection|SCRIPT ERROR|annulee|JOURNAL" | tail -8 | cut -c1-150; }
echo "Z fin cmd-018"
