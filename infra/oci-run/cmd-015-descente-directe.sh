#!/usr/bin/env bash
# cmd-015 (pont OCI) — LA DESCENTE, EN DIRECT.
#
# cmd-014 a rendu SUCCEEDED avec une sortie VIDE : pas une ligne, pas meme son premier echo. La
# cause la plus probable est documentee dans le script que j'appelais : a_tools_autosync.sh
# contient un `pkill -f` et son propre commentaire avertit que « le texte du script est sa propre
# ligne de commande » — un pkill mal cadre tue le shell appelant (rc=143 mesure le 24/08). Je ne
# passe donc plus par les agents : les deux depots se tirent ici, en direct.
#
# Trois regles tirees de cet echec :
#   - imprimer AVANT d'agir, pour qu'un mort subit laisse quand meme une trace ;
#   - ne jamais appeler un agent qui fait du pkill depuis une Run Command ;
#   - dire le resultat de chaque git, pas seulement le sha final.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"

RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
GD="${GAME_DIR:-/var/lib/ocarun/workspace/merlin-game}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
[ -d "$GD" ] || GD="$HOME/workspace/merlin-game"
echo "A rp=$RP gd=$GD"

# --- B. les deux depots, en direct, sans agent ---
for d in "$RP" "$GD"; do
  n=$(basename "$d")
  av=$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')
  br=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')
  # core.fileMode false est deja grave, mais on ne prend pas le risque : un mode 644 vs 755
  # avait bloque le pull 24 heures durant le 24/08.
  git -C "$d" config core.fileMode false 2>/dev/null
  out=$(git -C "$d" pull --ff-only 2>&1 | tail -2 | tr '\n' ' ')
  ap=$(git -C "$d" rev-parse --short HEAD 2>/dev/null || echo '?')
  echo "B $n $br $av -> $ap :: $(printf '%s' "$out" | head -c 130)"
done

# --- C. les marqueurs de v48.1, verifies un par un ---
A=0; B=0; C=0; D=0
grep -q "MERLIN_BOT_COUVRANT" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && A=1
grep -q "LE GESTE T'EST DONNE EN FIN DE PROMPT" "$GD/scripts/llm/merlin_prompt_builder.gd" 2>/dev/null && B=1
grep -q '"annulee"' "$GD/scripts/llm/merlin_native.gd" 2>/dev/null && C=1
grep -q "_meilleure_greffe" "$GD/tools/probe_partie_journal.gd" 2>/dev/null && D=1
echo "C sonde=$A place=$B annulation=$C draft=$D (a b c d de v48.1)"
echo "C job069=$([ -f "$RP/infra/oracle/agents/courrier/job-069-partie-v48-1.sh" ] && echo present || echo ABSENT) fait=$([ -f "$HOME/.cache/merlin-agents/courrier/job-069-partie-v48-1.fait" ] && echo oui || echo non) cron=$(crontab -l 2>/dev/null | grep -cv '^[[:space:]]*#')"
echo "Z fin cmd-015"
