#!/usr/bin/env bash
# Installe (idempotent, sans root) l'éditeur Godot arm64 à la version EXIGÉE PAR
# LE PROJET passé en argument, et le rend actif via le symlink ~/bin/godot.
# Usage : godot-install.sh <dossier_projet> [--templates]
#
# La version vient de config/features de project.godot : changer de branche de
# jeu (moteur différent) réinstalle automatiquement la bonne version.
set -uo pipefail

PROJ="${1:-}"
WANT_TPL=0
[ "${2:-}" = "--templates" ] && WANT_TPL=1

log()  { echo "[godot-install] $*"; }
fail() { echo "[godot-install] FATAL: $*" >&2; exit 1; }

GV=""
if [ -n "$PROJ" ] && [ -f "$PROJ/project.godot" ]; then
    GV="$(grep -m1 'config/features' "$PROJ/project.godot" \
          | grep -oE '[0-9]+\.[0-9]+' | head -1)"
fi
GV="${GV:-4.5}"

mkdir -p "$HOME/bin"

# Préserver un binaire historique installé « à plat » (non versionné).
if [ -e "$HOME/bin/godot" ] && [ ! -L "$HOME/bin/godot" ]; then
    OLD_V="$("$HOME/bin/godot" --headless --version 2>/dev/null | head -1 | cut -d. -f1-2)"
    mv "$HOME/bin/godot" "$HOME/bin/godot-${OLD_V:-old}"
    log "binaire existant préservé en godot-${OLD_V:-old}"
fi

if [ ! -x "$HOME/bin/godot-$GV" ]; then
    log "téléchargement Godot $GV arm64 (éditeur complet)…"
    curl -fsSL "https://github.com/godotengine/godot/releases/download/${GV}-stable/Godot_v${GV}-stable_linux.arm64.zip" \
        -o "/tmp/godot-$GV.zip" || fail "téléchargement Godot $GV KO"
    unzip -o -q "/tmp/godot-$GV.zip" -d /tmp && rm -f "/tmp/godot-$GV.zip"
    install -m 0755 "/tmp/Godot_v${GV}-stable_linux.arm64" "$HOME/bin/godot-$GV" \
        || fail "installation du binaire KO"
fi
ln -sfn "$HOME/bin/godot-$GV" "$HOME/bin/godot"
log "godot actif : $("$HOME/bin/godot" --headless --version 2>/dev/null | head -1 || echo KO) (projet : ${PROJ:-?})"

# Templates d'export (~1 Go) — best-effort, sans impact sur le jeu natif.
if [ "$WANT_TPL" = 1 ]; then
    TDIR="$HOME/.local/share/godot/export_templates/${GV}.stable"
    if [ ! -d "$TDIR" ]; then
        log "téléchargement templates d'export $GV (long, une seule fois)…"
        if curl -fsSL "https://github.com/godotengine/godot/releases/download/${GV}-stable/Godot_v${GV}-stable_export_templates.tpz" \
                -o /tmp/tpl.tpz && unzip -q -o /tmp/tpl.tpz -d "/tmp/tpl-$GV"; then
            mkdir -p "$TDIR" && mv "/tmp/tpl-$GV/templates/"* "$TDIR"/ \
                && rm -rf /tmp/tpl.tpz "/tmp/tpl-$GV"
            log "templates $GV installés"
        else
            log "warn: templates $GV non installés (exports indisponibles, jeu natif non affecté)"
        fi
    fi
fi
