#!/usr/bin/env bash
# Synchronise le PROJET GODOT joué sur la VM avec GitHub, puis (ré)importe ses assets.
#
# Le jeu vit dans SON PROPRE dossier ($GAME_REPO_DIR), séparé de l'outillage —
# c'est indispensable : la branche du jeu ne contient pas infra/oracle/game.
#   GitHub (GAME_REPO_URL @ GAME_REF)  --clone/pull-->  GAME_REPO_DIR  --import-->  jouable
#
# L'import complet (godot --headless --import) n'est refait que si HEAD a changé
# ou si .godot/imported est vide. Idempotent, JSON sur la dernière ligne.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/game-env.sh"

GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
RUNDIR="$HOME/.cache/merlin-game"
IMPORT_MARK="$RUNDIR/import-head"
mkdir -p "$RUNDIR"

log()  { echo "[game-sync] $*"; }
fail() { echo "[game-sync] FATAL: $*" >&2; exit 1; }

# ── 1. clone ou mise à jour du dépôt du jeu ──────────────────────────────────
if [ ! -d "$GAME_REPO_DIR/.git" ]; then
    [ -n "$GAME_REPO_URL" ] || fail "GAME_REPO_URL vide (définir dans ~/.config/merlin-game.env)"
    log "=== clone du jeu : $GAME_REPO_URL ($GAME_REF) ==="
    git clone --branch "$GAME_REF" "$GAME_REPO_URL" "$GAME_REPO_DIR" 2>&1 | tail -2 \
        || fail "clone KO (branche '$GAME_REF' inexistante ?)"
fi
GAME_DIR="$GAME_REPO_DIR"   # le clone existe désormais : c'est LUI qu'on joue

cd "$GAME_DIR" || fail "dossier jeu introuvable: $GAME_DIR"
log "=== sync '$GAME_REF' dans $GAME_DIR ==="
git fetch origin "$GAME_REF" 2>&1 | tail -1 || fail "fetch KO (réseau ?)"
git checkout "$GAME_REF" 2>&1 | tail -1
git pull --ff-only origin "$GAME_REF" 2>&1 | tail -1 \
    || fail "pull --ff-only KO (historique divergent ?)"

# ── 2. moteur à la version du projet (change avec la branche) ────────────────
bash "$HERE/godot-install.sh" "$GAME_DIR" || fail "installation Godot KO"

HEAD="$(git rev-parse HEAD)"
SHORT="$(git rev-parse --short HEAD)"
imported_count() { find "$GAME_DIR/.godot/imported" -type f 2>/dev/null | wc -l; }

NEED_IMPORT=0
[ "$(cat "$IMPORT_MARK" 2>/dev/null)" != "$GAME_DIR:$HEAD" ] && NEED_IMPORT=1
[ "$(imported_count)" -eq 0 ] && NEED_IMPORT=1

if [ "$NEED_IMPORT" = 1 ]; then
    log "=== import des assets (godot --headless --import, long à froid) ==="

    # (a) *.blend : sans exécutable Blender l'import se BLOQUE définitivement
    # (constaté 316% CPU sans fin ; editor_settings blender/enabled=false ne
    # suffit pas). On les écarte ; leurs GLB équivalents sont versionnés et
    # *.blend est déjà exclu des exports.
    BSTASH="$RUNDIR/blend-stash"
    rm -rf "$BSTASH"; mkdir -p "$BSTASH"
    while IFS= read -r -d '' bf; do
        rel="${bf#$GAME_DIR/}"; mkdir -p "$BSTASH/$(dirname "$rel")"
        mv "$bf" "$BSTASH/$rel"
    done < <(find "$GAME_DIR" -path "$GAME_DIR/.git" -prune -o \
                  \( -name '*.blend' -o -name '*.blend1' \) -print0)
    log "$(find "$BSTASH" -type f | wc -l) fichier(s) .blend écartés le temps de l'import"

    # (b) *.gdextension : bibliothèques natives Windows, aucune section
    # linux.arm64 -> erreurs de chargement à chaque démarrage.
    XSTASH="$RUNDIR/gdext-stash"
    rm -rf "$XSTASH"; mkdir -p "$XSTASH"
    while IFS= read -r -d '' xf; do
        rel="${xf#$GAME_DIR/}"; mkdir -p "$XSTASH/$(dirname "$rel")"
        mv "$xf" "$XSTASH/$rel"
    done < <(find "$GAME_DIR" -path "$GAME_DIR/.git" -prune -o \
                  -name '*.gdextension*' -print0)
    log "$(find "$XSTASH" -type f | wc -l) fichier(s) .gdextension écartés"

    # (c) [editor_plugins] : un plugin éditeur (godot_mcp) ouvre un serveur TCP
    # et --import ne se termine jamais. Même recette que la CI godot-export.yml.
    sed -i '/\[editor_plugins\]/,/^$/d' "$GAME_DIR/project.godot"

    timeout 3600 "$GODOT_BIN" --headless --path "$GAME_DIR" --import \
        > "$RUNDIR/import.log" 2>&1 || true

    # Restauration systématique : arbre propre pour les pulls suivants.
    git -C "$GAME_DIR" checkout -- project.godot 2>/dev/null
    for st in "$BSTASH" "$XSTASH"; do
        [ -d "$st" ] || continue
        while IFS= read -r -d '' f; do
            rel="${f#$st/}"; mkdir -p "$GAME_DIR/$(dirname "$rel")"
            mv "$f" "$GAME_DIR/$rel"
        done < <(find "$st" -type f -print0)
        rm -rf "$st"
    done

    CNT="$(imported_count)"
    if [ "$CNT" -gt 0 ]; then
        echo "$GAME_DIR:$HEAD" > "$IMPORT_MARK"
        log "import OK ($CNT ressources) — voir $RUNDIR/import.log"
    else
        tail -20 "$RUNDIR/import.log" >&2
        fail "import KO (0 ressource dans .godot/imported)"
    fi
else
    log "import à jour (HEAD $SHORT inchangé, $(imported_count) ressources)"
fi

MAIN_SCENE="$(grep -m1 'run/main_scene' "$GAME_DIR/project.godot" | cut -d'"' -f2)"
printf '{"ref":"%s","commit":"%s","dir":"%s","main_scene":"%s","imported":%s}\n' \
    "$GAME_REF" "$SHORT" "$GAME_DIR" "$MAIN_SCENE" \
    "$([ "$(imported_count)" -gt 0 ] && echo true || echo false)"
