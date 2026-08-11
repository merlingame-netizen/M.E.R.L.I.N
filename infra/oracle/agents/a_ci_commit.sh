#!/usr/bin/env bash
# CI de commit : pour chaque nouveau commit sur la branche du jeu —
#   sync + import  →  smoke de toutes les scènes  →  boot rendu + CAPTURE réelle
# Verdict JSON + vignette PNG par commit, historique borné, lisibles du portail.
# Déclenché par : webhook push (instantané), autosync (15 min, secours), ou à la main.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

GS="$HERE/../game/game-stack.sh"
GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
CI_DIR="$HOME/.cache/merlin-agents/ci"
HIST="$CI_DIR/history.jsonl"
SYSROOT="$HOME/opt/gamestack/sysroot"
mkdir -p "$CI_DIR"

[ -d "$GAME_DIR/.git" ] || { echo "jeu pas encore cloné — rien à tester"; exit 0; }

# ── 1. y a-t-il du nouveau ? ────────────────────────────────────────────────
git -C "$GAME_DIR" fetch origin "$GAME_REF" --quiet 2>/dev/null || { echo "fetch KO (réseau ?)"; exit 1; }
SHA="$(git -C "$GAME_DIR" rev-parse --short "origin/$GAME_REF")"
LAST_DONE="$(tail -1 "$HIST" 2>/dev/null | grep -o '"sha":"[^"]*"' | cut -d'"' -f4)"
if [ "$SHA" = "$LAST_DONE" ] && [ "${CI_FORCE:-0}" != "1" ]; then
    echo "déjà testé ($SHA) — rien de neuf"; exit 0
fi

# ── 2. sync + import (game-sync gère moteur, .blend, plugins) ───────────────
bash "$HERE/../game/game-sync.sh" >&2 || { echo "CI $SHA : sync/import KO"; exit 1; }

# ── 3. smoke headless de toutes les scènes ──────────────────────────────────
TOTAL=0; BAD=0; SCJSON=""
for scene in "$GAME_DIR"/scenes/*.tscn; do
    [ -f "$scene" ] || continue
    NAME="$(basename "$scene")"; TOTAL=$((TOTAL+1))
    ERRS="$(timeout 75 "$GODOT_BIN" --headless --path "$GAME_DIR" "res://scenes/$NAME" \
            --quit-after 4 2>&1 | grep -c 'SCRIPT ERROR' || true)"
    [ "$ERRS" -gt 0 ] && BAD=$((BAD+1))
    SCJSON="$SCJSON{\"scene\":\"$NAME\",\"errors\":$ERRS},"
done

# ── 4. boot rendu + capture (préserve l'état voulu par l'humain) ────────────
WAS_RUNNING=false
bash "$GS" status 2>/dev/null | grep -q '"vnc_open":true' && WAS_RUNNING=true
BOOT_OK=false; SHOT=false
RES="$(cat "$HOME/.cache/merlin-game/last-res" 2>/dev/null || echo 960x540)"
# redémarre toujours : si le jeu tournait, il doit tourner sur le NOUVEAU commit
if bash "$GS" restart --res "$RES" >&2; then
    BOOT_OK=true; sleep 9
    if env LD_LIBRARY_PATH="$SYSROOT/usr/lib64:$SYSROOT/usr/lib" DISPLAY=:99 \
         "$SYSROOT/usr/bin/xwd" -root -silent > "$CI_DIR/$SHA.xwd" 2>/dev/null; then
        python3 "$HERE/../game/xwd2png.py" "$CI_DIR/$SHA.xwd" "$CI_DIR/$SHA.png" --every 2 >&2 && SHOT=true
    fi
    rm -f "$CI_DIR/$SHA.xwd"
fi
[ "$WAS_RUNNING" = false ] && bash "$GS" stop >/dev/null 2>&1

# ── 5. verdict + historique borné ───────────────────────────────────────────
SUBJECT="$(git -C "$GAME_DIR" log -1 --format=%s | head -c 90 | tr '"' "'")"
printf '{"t":"%s","sha":"%s","ref":"%s","subject":"%s","scenes_total":%s,"scenes_failing":%s,"boot_ok":%s,"shot":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SHA" "$GAME_REF" "$SUBJECT" \
    "$TOTAL" "$BAD" "$BOOT_OK" "$SHOT" >> "$HIST"
tail -15 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"
ls -t "$CI_DIR"/*.png 2>/dev/null | tail -n +16 | xargs -r rm -f

if [ "$BAD" -eq 0 ] && [ "$BOOT_OK" = true ]; then
    echo "CI $SHA : VERT — $TOTAL scènes saines, boot rendu OK"
else
    echo "CI $SHA : ROUGE — $BAD/$TOTAL scènes en erreur, boot=$BOOT_OK"; exit 1
fi
