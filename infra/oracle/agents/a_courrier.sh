#!/usr/bin/env bash
# Le Courrier — canal de commande par le dépôt lui-même (né 2026-08-19).
#
# POURQUOI. Le redémarrage du conteneur de l'agent distant a emporté ~/.oci : plus de
# Run Command, donc plus AUCUN canal vers la VM, alors que la règle de Maxime est « la
# version à jour, c'est toujours celle de la VM ». Or la VM sait déjà deux choses :
# tirer ce dépôt toutes les 15 min (tools-autosync) et pousser vers GitHub (le codeur
# résident le fait à chaque mission). Le Courrier ferme la boucle : un fichier job-*.sh
# commité dans courrier/ est exécuté UNE seule fois, sa sortie est commitée dans
# courrier/resultats/ et poussée. Aucun secret ne circule : le canal, c'est git.
#
# Contrat d'un job :
#   - un script bash `courrier/job-<nom>.sh`, exécuté le plus ancien d'abord, un par réveil
#   - marqueur ~/.cache/merlin-agents/courrier/<nom>.fait posé AVANT l'exécution :
#     un job qui plante ne boucle jamais
#   - le job reçoit $RES (courrier/resultats/<nom>/ dans le dépôt) : tout ce qu'il y
#     dépose part sur GitHub ; sa sortie texte y est toujours écrite (sortie.log)
#   - budget 90 min ; verrou par agent-run.sh (pas de chevauchement)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"
REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
BOITE="$HERE/courrier"
ETAT="$HOME/.cache/merlin-agents/courrier"
mkdir -p "$ETAT" "$BOITE"

REF="$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
{ [ -n "$REF" ] && [ "$REF" != "HEAD" ]; } || { echo "dépôt en HEAD détachée — courrier muet"; exit 0; }

JOB=""
for f in $(ls "$BOITE"/job-*.sh 2>/dev/null | sort); do
    n="$(basename "$f" .sh)"
    if [ ! -f "$ETAT/$n.fait" ]; then JOB="$f"; break; fi
done
[ -n "$JOB" ] || { echo "aucun courrier en attente"; exit 0; }

NOM="$(basename "$JOB" .sh)"
RES="$BOITE/resultats/$NOM"
mkdir -p "$RES"
date -u +%Y-%m-%dT%H:%M:%SZ > "$ETAT/$NOM.fait"

RES="$RES" REPO="$REPO" GAME_DIR="${GAME_DIR:-}" timeout 5400 bash "$JOB" > "$RES/sortie.log" 2>&1
RC=$?
echo "rc=$RC" >> "$RES/sortie.log"

# ── retour du résultat : d'abord la branche de l'outillage… ────────────────
# Copie de sûreté hors dépôt AVANT tout geste git : quel que soit l'échec en
# aval, le résultat existe encore sur la VM.
cp -rf "$RES" "$ETAT/$NOM.res" 2>/dev/null || true
cd "$REPO"
git add -A "infra/oracle/agents/courrier/resultats/$NOM" >/dev/null 2>&1
POUSSE=non
if git commit -q -m "courrier: résultat $NOM (rc=$RC)"; then
    git pull --rebase -q origin "$REF" >/dev/null 2>&1 || git rebase --abort >/dev/null 2>&1 || true
    if git push -q origin "$REF" >/dev/null 2>&1; then
        POUSSE=outillage
    else
        # …sinon par le clone du JEU, qui pousse de façon prouvée (le codeur le fait).
        # Une branche dédiée, jamais la branche du jeu — même discipline que le codeur.
        GD="${GAME_DIR:-}"
        if [ -n "$GD" ] && [ -d "$GD/.git" ]; then
            CUR="$(git -C "$GD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
            git -C "$GD" checkout -q -B courrier-resultats 2>/dev/null \
                && mkdir -p "$GD/courrier-resultats/$NOM" \
                && cp -rf "$ETAT/$NOM.res/." "$GD/courrier-resultats/$NOM/" \
                && git -C "$GD" add -A "courrier-resultats/$NOM" \
                && git -C "$GD" commit -q -m "courrier: résultat $NOM (rc=$RC)" \
                && git -C "$GD" push -q -u origin courrier-resultats >/dev/null 2>&1 \
                && POUSSE=jeu
            [ -n "$CUR" ] && [ "$CUR" != "HEAD" ] && git -C "$GD" checkout -q "$CUR" 2>/dev/null
        fi
        # Le clone de l'outillage ne doit JAMAIS diverger : un commit local non
        # poussé bloquerait tools-autosync (--ff-only) pour toujours.
        git reset --hard -q "origin/$REF" >/dev/null 2>&1 || true
    fi
fi
echo "$NOM exécuté (rc=$RC) — résultat: $POUSSE"
