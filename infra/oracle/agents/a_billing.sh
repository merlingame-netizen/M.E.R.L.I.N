#!/usr/bin/env bash
# Contrôle de facturation : la VM est sur l'offre Always Free, le total DOIT
# rester à 0. Toute somme non nulle déclenche une alerte urgente sur le
# téléphone — c'est le seul agent dont l'échec coûte de l'argent.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$HOME/.cache/merlin-agents"
PY="$HOME/workspace/M.E.R.L.I.N/.venv/bin/python"
[ -x "$PY" ] || PY="$(command -v python3)"

"$PY" "$HERE/../scripts/billing_probe.py"
RC=$?

# Comparaison faite en python (bc n'est pas garanti sur la VM).
TOTAL="$("$PY" -c "
import json
try:
    d = json.load(open('$STATE/billing-data.json'))
    t = d.get('total')
    print('null' if t is None else t)
except Exception:
    print('null')")"
POSITIF="$("$PY" -c "
try: print('1' if float('$TOTAL') > 0 else '0')
except Exception: print('0')")"

# Alerte au premier centime — et une seule fois par palier (pas de spam horaire).
if [ "$TOTAL" != "null" ] && [ "$POSITIF" = "1" ]; then
    MARK="$STATE/billing-alerted"
    if [ "$(cat "$MARK" 2>/dev/null)" != "$TOTAL" ]; then
        bash "$HERE/notify.sh" urgent "FACTURATION NON NULLE" \
            "Oracle facture $TOTAL ce mois — la VM devait rester à 0. Vérifie le portail."
        printf '%s' "$TOTAL" > "$MARK"
    fi
    echo "ALERTE : $TOTAL facturé ce mois (devrait être 0)"
    exit 1
fi
rm -f "$STATE/billing-alerted"
exit $RC
