#!/usr/bin/env bash
# Synchronise le projet du jeu sur la VM avec GitHub puis (ré)importe les assets.
# C'est LE chemin par lequel « le projet actuel » arrive sur la VM :
#   PC (C:/Users/PGNK2128/Godot-MCP)  --push-->  GitHub  --game-sync-->  VM
# GAME_REF (branche à suivre) se règle dans ~/.config/merlin-game.env ;
# défaut : la branche actuellement extraite du repo VM.
# L'import complet Godot (--headless --import) n'est refait que si HEAD a changé
# ou si .godot/imported est vide. Idempotent, sortie JSON sur la dernière ligne.
set -uo pipefail

REPO="${MERLIN_REPO:-$HOME/workspace/M.E.R.L.I.N}"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
RUNDIR="$HOME/.cache/merlin-game"
IMPORT_MARK="$RUNDIR/import-head"

CONF="$HOME/.config/merlin-game.env"
[ -f "$CONF" ] && . "$CONF"

log()  { echo "[game-sync] $*"; }
fail() { echo "[game-sync] FATAL: $*" >&2; exit 1; }

cd "$REPO" || fail "repo introuvable: $REPO"
GAME_REF="${GAME_REF:-$(git rev-parse --abbrev-ref HEAD)}"

log "=== sync ref '$GAME_REF' ==="
git fetch origin "$GAME_REF" || fail "fetch KO (réseau ?)"
git checkout "$GAME_REF" 2>&1 | tail -1
git pull --ff-only origin "$GAME_REF" 2>&1 | tail -1 || fail "pull --ff-only KO (historique divergent ?)"

HEAD="$(git rev-parse HEAD)"
SHORT="$(git rev-parse --short HEAD)"
imported_count() { find "$REPO/.godot/imported" -type f 2>/dev/null | wc -l; }

NEED_IMPORT=0
[ "$(cat "$IMPORT_MARK" 2>/dev/null)" != "$HEAD" ] && NEED_IMPORT=1
[ "$(imported_count)" -eq 0 ] && NEED_IMPORT=1

if [ "$NEED_IMPORT" = 1 ]; then
    log "=== import des assets (godot --headless --import, long à froid) ==="
    mkdir -p "$RUNDIR"
    # Même neutralisation que la CI (godot-export.yml) pendant l'import :
    # - merlin_llm.gdextension : DLL Windows-only (aucune section linux.arm64)
    # - [editor_plugins] : godot_mcp démarre un serveur TCP dans l'éditeur et
    #   empêche le process --import de se terminer (constaté : 5% CPU sans fin)
    # Pas de Blender sur la VM : l'import headless se BLOQUE sur les *.blend
    # (constaté : 316% CPU puis blocage définitif, même avec editor_settings
    # blender/enabled=false — le réglage n'empêche pas le hang). On écarte les
    # .blend le temps de l'import ; leurs GLB équivalents sont dans le repo et
    # *.blend est déjà exclu de l'export (export_presets.cfg).
    BSTASH="$RUNDIR/blend-stash"
    rm -rf "$BSTASH"; mkdir -p "$BSTASH"
    while IFS= read -r -d '' bf; do
        rel="${bf#$REPO/}"; mkdir -p "$BSTASH/$(dirname "$rel")"
        mv "$bf" "$BSTASH/$rel"
    done < <(find "$REPO" -path "$REPO/.git" -prune -o \( -name '*.blend' -o -name '*.blend1' \) -print0)
    log "$(find "$BSTASH" -type f | wc -l) fichier(s) .blend écartés le temps de l'import"
    GDEXT="$REPO/addons/merlin_llm/merlin_llm.gdextension"
    [ -f "$GDEXT" ] && mv "$GDEXT" "$GDEXT.import-disabled"
    sed -i '/\[editor_plugins\]/,/^$/d' "$REPO/project.godot"
    # L'import peut sortir en code non nul malgré un import complet (warnings) :
    # le critère de réussite est le contenu de .godot/imported.
    # 104 GLB + génération de LOD sur 4 cœurs ARM : le froid peut dépasser 30 min.
    timeout 3600 "$GODOT_BIN" --headless --path "$REPO" --import \
        > "$RUNDIR/import.log" 2>&1 || true
    # Restauration : arbre propre pour les pulls suivants.
    git -C "$REPO" checkout -- project.godot
    [ -f "$GDEXT.import-disabled" ] && mv "$GDEXT.import-disabled" "$GDEXT"
    if [ -d "$BSTASH" ]; then
        while IFS= read -r -d '' bf; do
            rel="${bf#$BSTASH/}"; mkdir -p "$REPO/$(dirname "$rel")"
            mv "$bf" "$REPO/$rel"
        done < <(find "$BSTASH" -type f -print0)
        rm -rf "$BSTASH"
    fi
    CNT="$(imported_count)"
    if [ "$CNT" -gt 0 ]; then
        echo "$HEAD" > "$IMPORT_MARK"
        log "import OK ($CNT ressources) — voir $RUNDIR/import.log"
    else
        tail -20 "$RUNDIR/import.log" >&2
        fail "import KO (0 ressource dans .godot/imported)"
    fi
else
    log "import à jour (HEAD $SHORT inchangé, $(imported_count) ressources)"
fi

printf '{"ref":"%s","commit":"%s","imported":%s}\n' \
    "$GAME_REF" "$SHORT" "$([ "$(imported_count)" -gt 0 ] && echo true || echo false)"
