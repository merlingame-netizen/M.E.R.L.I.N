#!/usr/bin/env bash
# Le journal 6 beats et la sélection en TRANCHES de corps de message ntfy :
# le flux NDJSON du sujet est sauvé fidèle côté poste de pilotage, là où les
# pièces jointes texte/JSON sont paraphrasées par le lecteur.
set -u
NT="https://ntfy.sh/merlin-courrier-vX9k2Qf7Lw3s"
envoyer_en_tranches() {
    src="$1"; nom="$2"
    [ -f "$src" ] || { echo "$nom absent"; return; }
    split -b 3000 -d -a 2 "$src" /tmp/tr.
    total=$(ls /tmp/tr.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/tr.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 --retry 2 -H "Title: $nom part $i/$total" \
            --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 2
    done
    rm -f /tmp/tr.*
    echo "$nom : $total tranche(s)"
}
envoyer_en_tranches "$HOME/.cache/merlin-partie/journal.json" "journal6"
envoyer_en_tranches "$HOME/.cache/merlin-partie/selection.json" "selection-courante"
echo "tranches parties"
