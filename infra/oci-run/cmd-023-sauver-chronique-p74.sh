#!/usr/bin/env bash
# cmd-023 (pont OCI) — SAUVER LA CHRONIQUE DE p74 AVANT QU'ELLE NE S'EFFACE.
#
# Les neuf captures de p74 et son journal rendent deja 404 sur ntfy : adminforge purge les pieces
# jointes en quelques heures. Le journal avait ete tire a temps et vit en local ; les images, non.
# Toute chronique qui ne passe que par ce canal disparait donc dans la journee — precisement ce que
# v50 venait d'enrichir en portant les captures de trois a neuf.
#
# Les fichiers sont encore sur la VM : a_courrier.sh range chaque job sous
# infra/oracle/agents/courrier/resultats/<job>/, donc DANS le depot, et ce chemin n'est pas ignore.
# On les commite.
set -u
echo "A depart $(date -u +%H:%M:%SZ)"
RP="${REPO:-/var/lib/ocarun/workspace/M.E.R.L.I.N}"
[ -d "$RP" ] || RP="$HOME/workspace/M.E.R.L.I.N"
SRC="$RP/infra/oracle/agents/courrier/resultats/job-074-quete-complete"
DST="$RP/docs/chroniques/p74"

[ -d "$SRC" ] || { echo "Z ABSENT : $SRC"; exit 1; }
echo "B source : $(ls "$SRC" 2>/dev/null | tr '\n' ' ' | head -c 200)"
echo "B cliches : $(ls "$SRC/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ') fichier(s)"

# Poids : on refuse d'alourdir l'historique par accident.
POIDS=$(du -sk "$SRC" 2>/dev/null | awk '{print $1}')
echo "C poids=${POIDS}Ko"
if [ "${POIDS:-0}" -gt 12288 ]; then
  echo "Z REFUS : ${POIDS}Ko > 12 Mo — rien n'est commite, dis-le et on choisira quoi garder"
  exit 1
fi

mkdir -p "$DST/cliches"
cp "$SRC/journal.json" "$DST/journal.json" 2>/dev/null
cp "$SRC/verdict74.txt" "$DST/verdict.txt" 2>/dev/null
cp "$SRC/cliches/"*.png "$DST/cliches/" 2>/dev/null
echo "D verse : $(ls "$DST/cliches/"*.png 2>/dev/null | wc -l | tr -d ' ') capture(s), journal=$([ -s "$DST/journal.json" ] && echo oui || echo NON)"
for f in "$DST/cliches/"*.png; do [ -f "$f" ] && echo "D   $(basename "$f") $(stat -c%s "$f")o"; done

cd "$RP" || exit 1
git config user.name "Claude" 2>/dev/null
git config user.email "noreply@anthropic.com" 2>/dev/null
git add -f "docs/chroniques/p74" 2>/dev/null
if git diff --cached --quiet 2>/dev/null; then
  echo "E rien de neuf a committer"
else
  git commit -q -m "docs(chronique): p74 — journal et captures de la premiere quete a longueur libre" \
    -m "Rapatrie depuis la VM : ntfy avait deja purge les pieces jointes (404 en quelques heures)." \
    -m "20 beats tires librement, 9 captures etalees (v50), reussite 20/20, continuite 15/19." 2>&1 | head -3
  BR=$(git rev-parse --abbrev-ref HEAD)
  for i in 1 2 3 4; do
    git pull -q --rebase origin "$BR" 2>/dev/null
    git push -q origin "$BR" 2>/dev/null && { echo "E pousse sur $BR"; break; }
    echo "E push echoue, essai $i"; sleep $((2**i))
  done
fi
echo "Z fin cmd-023"
