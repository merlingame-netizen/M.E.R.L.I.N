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
#   - le job reçoit $RES et $COURRIER_RES (courrier/resultats/<nom>/ dans le dépôt) :
#     tout ce qu'il y dépose part ; sa sortie texte y est toujours écrite (sortie.log)
#   - ATTENTION : game-stack lit la RÉSOLUTION d'écran dans la variable RES — tout job
#     qui lance le jeu DOIT appeler le runner via `env -u RES` (vécu 2026-08-19 : Xvfb
#     mort sur « Invalid screen configuration .../resultats/job-010-...x24 »)
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

RES="$RES" COURRIER_RES="$RES" REPO="$REPO" GAME_DIR="${GAME_DIR:-}" \
    timeout 5400 bash "$JOB" > "$RES/sortie.log" 2>&1
RC=$?
echo "rc=$RC" >> "$RES/sortie.log"

# ── retour du résultat 1/2 : liaison montante ntfy (sans AUCUN identifiant) ──
# La VM n'a JAMAIS poussé vers GitHub (aucun commit d'auteur VM, pas de branche
# auto/nightly) — ses clones sont en lecture seule. Le retour passe par ntfy.sh :
# un PUT par fichier, le poste de pilotage lit le flux JSON du sujet.
# Sujet public non devinable, commité en clair : n'y déposer QUE des résultats
# de jeu — jamais un secret, jamais un fichier de configuration.
NTFY_CR="merlin-courrier-vX9k2Qf7Lw3s"
# Les quotas des instances publiques tombent EN SILENCE (vécu 2026-08-20 : p42 muette
# de bout en bout, quota ntfy.sh par IP épuisé). Canari d'abord : la première instance
# qui rend notre jeton est la bonne ; l'URL choisie est exportée pour les jobs futurs.
NTFY_BASE=""
for _b in https://ntfy.sh https://ntfy.adminforge.de https://ntfy.envs.net; do
    _tok="canari-$NOM-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$_tok" "$_b/$NTFY_CR" >/dev/null 2>&1
    sleep 3
    if curl -fsS -m 15 "$_b/$NTFY_CR/json?poll=1&since=1m" 2>/dev/null | grep -q "$_tok"; then
        NTFY_BASE="$_b"
        break
    fi
done
[ -n "$NTFY_BASE" ] || NTFY_BASE="https://ntfy.sh"
# ── GARDE-FOU : le sujet ntfy est PUBLIC, et cette boucle expedie TOUT ce qui traine dans
# le dossier de resultats. Le 2026-08-24, job-062 (« porte du Studio ») y a depose un
# lien.txt contenant le lien magique du Studio : il est reste lisible par n'importe qui
# pendant trois heures, sur un sujet dont l'adresse est commitee en clair. La regle de
# Maxime — « le lien du Studio ne circule QUE par canal prive » — ne peut pas dependre de
# la vigilance de l'auteur de chaque job : elle doit tenir ICI, au dernier goulot.
#
# Deux filtres, volontairement stricts sur la forme et non sur le vocabulaire : le NOM du
# fichier (mots entiers — « oracle » ne doit pas declencher sur « cle »), et le CONTENU
# reduit a des formes qui n'existent PAS en prose de jeu. Le vocabulaire des NOMS a ete
# resserre sur des cas reels : « passe » collisionnait avec passe66.txt (les allusions au
# PASSE, contenu de jeu legitime) et « env » avec des noms courants — .env passe par le
# suffixe. Verifie sur neuf fichiers temoins avant livraison (cle=..., Bearer, ocid1., une
# clef privee). Un journal de partie qui raconte un secret de Broceliande passe donc,
# et un lien signe ne passe jamais.
NOM_SENSIBLE='(^|[^a-z])(lien|liens|cle|clef|cles|token|jeton|secret|secrets|mdp|motdepasse|magic|mfa|credential|credentials|key|keys)([^a-z]|$)|\.env($|\.)'
FORME_SENSIBLE='(\?|&|^|[[:space:]])(cle|clef|token|key|secret|password|pass)=[A-Za-z0-9_-]{6,}|Bearer[[:space:]]+[A-Za-z0-9._-]{12,}|BEGIN[[:space:]]+[A-Z ]*PRIVATE[[:space:]]+KEY|ocid1\.[a-z]+\.|ssh-(rsa|ed25519)[[:space:]]|AKIA[0-9A-Z]{16}|[a-z0-9-]+\.trycloud'
retenus=0
find "$RES" -type f -size -14M | while read -r f; do
    rel="$(echo "${f#"$RES"/}" | tr '/' '_')"
    base="$(basename "$f" | tr '[:upper:]' '[:lower:]')"
    if echo "$base" | grep -qE "$NOM_SENSIBLE" || grep -qaE "$FORME_SENSIBLE" "$f" 2>/dev/null; then
        # On dit QUE le fichier a ete retenu, jamais ce qu'il contient.
        curl -fsS -m 15 -H "Title: $NOM retenu" \
            -d "$rel retenu : contenu sensible — a recuperer par canal prive" \
            "$NTFY_BASE/$NTFY_CR" >/dev/null 2>&1
        retenus=$((retenus+1))
        sleep 2
        continue
    fi
    curl -fsS -m 60 --retry 2 -T "$f" \
        -H "Filename: $NOM--$rel" -H "Title: $NOM $rel" \
        "$NTFY_BASE/$NTFY_CR" >/dev/null 2>&1
    sleep 2
done
curl -fsS -m 15 -H "Title: $NOM fini" -d "rc=$RC via=$NTFY_BASE $(date -u +%H:%M:%SZ)" \
    "$NTFY_BASE/$NTFY_CR" >/dev/null 2>&1 || true

# ── retour du résultat 2/2 : la branche de l'outillage (si un jour elle pousse) ─
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
