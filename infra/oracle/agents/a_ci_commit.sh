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

# ── 3. smoke headless de toutes les scènes (logs d'erreur conservés) ────────
TOTAL=0; BAD=0
ERRLOG="$CI_DIR/$SHA-errors.log"; : > "$ERRLOG"
for scene in "$GAME_DIR"/scenes/*.tscn; do
    [ -f "$scene" ] || continue
    NAME="$(basename "$scene")"; TOTAL=$((TOTAL+1))
    OUT="$(timeout 75 "$GODOT_BIN" --headless --path "$GAME_DIR" "res://scenes/$NAME" \
            --quit-after 4 2>&1 || true)"
    ERRS="$(printf '%s' "$OUT" | grep -c 'SCRIPT ERROR' || true)"
    if [ "$ERRS" -gt 0 ]; then
        BAD=$((BAD+1))
        { echo "=== $NAME ==="; printf '%s\n' "$OUT" | grep -A2 'SCRIPT ERROR' | head -20; } >> "$ERRLOG"
    fi
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

# ── 5. triage LLM : si rouge, un modèle local écrit le diagnostic ───────────
DIAG=""
if { [ "$BAD" -gt 0 ] || [ "$BOOT_OK" = false ]; } && [ -s "$ERRLOG" ]; then
    DIAG="$({ echo "Log d'erreurs Godot 4 du commit $SHA :"; head -c 3000 "$ERRLOG"
              echo; echo "En 2 phrases en français : quel est le bug et dans quel fichier corriger ?"
            } | bash "$HERE/../llm/llm-ask.sh" --timeout 120 2>/dev/null | head -c 400 || true)"
fi
[ "$BAD" -eq 0 ] && rm -f "$ERRLOG"

# ── 6. verdict + historique borné (JSON via python : diag = texte libre) ────
SUBJECT="$(git -C "$GAME_DIR" log -1 --format=%s | head -c 90)"
env HIST="$HIST" SHA="$SHA" REF="$GAME_REF" SUBJECT="$SUBJECT" TOTAL="$TOTAL" \
    BAD="$BAD" BOOT_OK="$BOOT_OK" SHOT="$SHOT" DIAG="$DIAG" python3 - <<'PY'
import json, os, time
e = os.environ
rec = {"t": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "sha": e["SHA"],
       "ref": e["REF"], "subject": e["SUBJECT"], "scenes_total": int(e["TOTAL"]),
       "scenes_failing": int(e["BAD"]), "boot_ok": e["BOOT_OK"] == "true",
       "shot": e["SHOT"] == "true", "diag": e["DIAG"]}
lines = []
try: lines = open(e["HIST"], encoding="utf-8").read().splitlines()
except FileNotFoundError: pass
lines.append(json.dumps(rec, ensure_ascii=False))
open(e["HIST"], "w", encoding="utf-8").write("\n".join(lines[-15:]) + "\n")
PY
ls -t "$CI_DIR"/*.png 2>/dev/null | tail -n +16 | xargs -r rm -f

# ── 7. verdict final + notification téléphone ───────────────────────────────
PREV_RED=false
[ -n "$LAST_DONE" ] && grep "\"sha\":\"$LAST_DONE\"" "$HIST" 2>/dev/null | tail -1 \
    | grep -q '"scenes_failing":0,"boot_ok":true' || PREV_RED=true
if [ "$BAD" -eq 0 ] && [ "$BOOT_OK" = true ]; then
    [ "$PREV_RED" = true ] && [ -n "$LAST_DONE" ] && \
        bash "$HERE/notify.sh" default "CI de nouveau VERTE" "$SHA — $SUBJECT"
    echo "CI $SHA : VERT — $TOTAL scènes saines, boot rendu OK"
else
    bash "$HERE/notify.sh" urgent "CI ROUGE — $SHA" \
        "$BAD/$TOTAL scènes KO, boot=$BOOT_OK. ${DIAG:-pas de diagnostic}"
    echo "CI $SHA : ROUGE — $BAD/$TOTAL scènes en erreur, boot=$BOOT_OK"
    [ -n "$DIAG" ] && echo "diagnostic : $DIAG"
    exit 1
fi
