#!/usr/bin/env bash
# Smoke nocturne : lance chaque scène du jeu en headless et compte les erreurs
# de script. Au réveil, le portail dit quelles scènes sont saines.
# Ne tourne QUE si le jeu n'est pas en train d'être joué (pas de vol de CPU).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
OUT="$HOME/.cache/merlin-agents/smoke-scenes.json"
DUR="${SMOKE_DURATION:-6}"

if bash "$HERE/../game/game-stack.sh" status 2>/dev/null | grep -q '"vnc_open":true'; then
    echo "jeu en cours d'utilisation — smoke reporté"; exit 0
fi
[ -d "$GAME_DIR/scenes" ] || { echo "pas de dossier scenes/ dans $GAME_DIR"; exit 0; }

TOTAL=0; BAD=0; RESULTS=""
for scene in "$GAME_DIR"/scenes/*.tscn; do
    [ -f "$scene" ] || continue
    NAME="$(basename "$scene")"
    TOTAL=$((TOTAL + 1))
    LOG="$(timeout 90 "$GODOT_BIN" --headless --path "$GAME_DIR" "res://scenes/$NAME" \
           --quit-after "$DUR" 2>&1 || true)"
    ERRS="$(printf '%s' "$LOG" | grep -c 'SCRIPT ERROR' || true)"
    [ "$ERRS" -gt 0 ] && BAD=$((BAD + 1))
    RESULTS="$RESULTS{\"scene\":\"$NAME\",\"script_errors\":$ERRS},"
done

# LES ÉPREUVES EN MOTEUR, à côté du smoke (régime du 04/09). Un smoke dit qu'une scène démarre ;
# une épreuve dit qu'un mécanisme répond — le squelette de quête, le journal des chroniques,
# l'écran qui les donne à lire. Elles écrivent dans user:// puis nettoient ce qu'elles ont créé.
EPREUVES=""; EP_BAD=0
for ep in test_quete test_journal test_ecran_chroniques test_economie; do
    [ -f "$GAME_DIR/tools/tests/$ep.gd" ] || continue
    EPLOG="$(timeout 240 "$GODOT_BIN" --headless --path "$GAME_DIR" --script "res://tools/tests/$ep.gd" 2>&1 || true)"
    if printf '%s' "$EPLOG" | grep -q "ÉPREUVE PASSÉE"; then ETAT=passee
    else ETAT=echouee; EP_BAD=$((EP_BAD + 1)); fi
    RATES="$(printf '%s' "$EPLOG" | grep -c '^  RATE' || true)"
    EPREUVES="$EPREUVES{\"epreuve\":\"$ep\",\"etat\":\"$ETAT\",\"rates\":$RATES},"
done

printf '{"t":"%s","ref":"%s","commit":"%s","total":%s,"failing":%s,"scenes":[%s],"epreuves":[%s],"epreuves_echouees":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$GAME_REF" \
    "$(git -C "$GAME_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')" \
    "$TOTAL" "$BAD" "${RESULTS%,}" "${EPREUVES%,}" "$EP_BAD" > "$OUT"

echo "$TOTAL scènes testées · $BAD en erreur · épreuves échouées : $EP_BAD"
[ "$BAD" -eq 0 ] && [ "$EP_BAD" -eq 0 ]
