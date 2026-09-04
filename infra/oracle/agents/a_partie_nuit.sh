#!/usr/bin/env bash
# LA PARTIE DE LA NUIT — une par nuit, gardée datée, lisible au réveil.
#
# POURQUOI CET AGENT. Maxime veut voir si le jeu s'améliore. La seule mesure qui réponde vraiment
# est une partie entière jouée par la machine, relue beat par beat. `a_partie_journal.sh` sait
# déjà la jouer ; ce qui manquait, c'est qu'elle se joue TOUTE SEULE chaque nuit et qu'elle SURVIVE
# à la suivante — le journal courant (~/.cache/merlin-partie/journal.json) est écrasé à chaque
# partie, donc sans copie datée il n'y a jamais qu'un seul point de mesure, celui d'hier.
#
# LA CHRONIQUE EST DOUBLE, et c'est voulu. La sonde écrit son journal de l'extérieur ; le jeu écrit
# le sien (MerlinJournal) de l'intérieur. Les deux atterrissent dans l'onglet Chronique du Studio,
# où ils se lisent côte à côte. Une divergence entre eux est un défaut d'instrumentation — c'est
# ainsi qu'on a trouvé le geste vide de p93.
#
# CE QU'IL NE FAIT PAS : il ne joue pas si quelqu'un est devant, et il ne touche à rien d'autre.
# Le playtest bot tourne à 3 h 30, celui-ci à 4 h 05 : le moteur est mono-place, deux travaux LLM
# en même temps se ralentissent l'un l'autre (mesuré sur p93, un beat à 83 s).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
GS="$HERE/../game/game-stack.sh"
B="$HOME/.cache/merlin-partie"
GARDE="$B/nuit/$(date -u +%Y-%m-%d)"
JOURNAL="$B/journal.json"
SEL="$B/selection.json"

# ── PERSONNE DEVANT. Même garde que le playtest bot : l'état désiré dit si Maxime a demandé
#    que le jeu tourne. On ne lui prend pas la machine sous les doigts.
DESIRED="$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo stopped)"
if [ "$DESIRED" = "running" ]; then
    echo "le jeu est demandé par quelqu'un — partie de la nuit annulée"; exit 0
fi
if bash "$GS" status 2>/dev/null | grep -q '"vnc_open":true'; then
    echo "un spectateur est connecté — partie de la nuit annulée"; exit 0
fi
if [ -d "$GARDE" ] && [ -s "$GARDE/journal.json" ]; then
    echo "la partie de cette nuit est déjà jouée ($GARDE)"; exit 0
fi

# ── DE LA PLACE. Une partie complète charge deux cerveaux : sans marge, le noyau tue le jeu en
#    pleine charge et le journal ne dit rien (vécu sur p65). On rend d'abord la mémoire d'Ollama.
for m in $(curl -fsS -m 5 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/ps" 2>/dev/null | python3 -c "import json,sys
try:
    for x in (json.load(sys.stdin).get('models') or []): print(x.get('name',''))
except Exception: pass"); do
    curl -fsS -m 60 "${OLLAMA_URL:-http://127.0.0.1:11434}/api/generate" \
        -d "{\"model\":\"$m\",\"keep_alive\":0}" >/dev/null 2>&1
done
DISPO=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
if [ "${DISPO:-0}" -lt 12000000 ]; then
    echo "mémoire insuffisante (${DISPO} ko disponibles) — partie de la nuit reportée"; exit 0
fi

# ── LA SÉLECTION, puis LA PARTIE. Deux phases, comme le veut le chroniqueur : le sentier est tiré
#    d'abord, la partie le joue ensuite. Ici personne ne choisit, donc on prend le premier — et on
#    le dit dans la raison, pour qu'aucune lecture ne croie à un choix éclairé.
rm -f "$SEL" "$JOURNAL"
if ! env -u RES bash "$HERE/a_partie_journal.sh" selection >/dev/null 2>&1 || [ ! -s "$SEL" ]; then
    echo "sélection des sentiers impossible — partie de la nuit abandonnée"; exit 1
fi
env -u RES bash "$HERE/a_partie_journal.sh" partie 0 \
    "partie de la nuit : longueur libre, sentier pris au premier sans arbitrage" >/dev/null 2>&1 || true

if [ ! -s "$JOURNAL" ]; then
    echo "aucun journal produit — voir $HOME/.cache/merlin-game/godot.log"; exit 1
fi

# ── LA GARDER. C'est tout l'intérêt : demain elle sera encore là, à côté de celle de demain.
mkdir -p "$GARDE"
cp "$JOURNAL" "$GARDE/journal.json"
[ -s "$SEL" ] && cp "$SEL" "$GARDE/selection.json"
if [ -d "$B/cliches" ]; then
    mkdir -p "$GARDE/cliches"
    cp "$B/cliches/"*.png "$GARDE/cliches/" 2>/dev/null || true
fi
python3 "$HERE/courrier/verdict_partie.py" "$GARDE/journal.json" > "$GARDE/verdict.txt" 2>&1 || true

# ── NE PAS REMPLIR LE DISQUE. Trente nuits suffisent à voir une tendance ; au-delà, ce sont des
#    images de 200 Ko qu'on ne rouvrira jamais. Les journaux, eux, sont légers et restent.
find "$B/nuit" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -n -30 | while read -r vieux; do
    rm -rf "$vieux"
done

python3 - "$GARDE/journal.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
b = d.get("beats") or []
fin = (d.get("fin") or {}).get("type", "?")
banc = sum(1 for x in b if x.get("provenance") == "secours" or x.get("secours"))
signes = sum(len(str(x.get("narration", "")) + str(x.get("resolution", ""))) for x in b)
print("%d beats · fin %s · %d au banc · %d signes de prose" % (len(b), fin, banc, signes))
PY
