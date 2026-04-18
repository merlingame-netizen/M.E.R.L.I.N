#!/usr/bin/env bash
# validate_headless.sh — Linux headless validation for M.E.R.L.I.N.
# Equivalent of validate.bat for Codespaces/CI environments
set -euo pipefail

GODOT="${GODOT_BIN:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ERRORS=0

echo "=========================================="
echo " M.E.R.L.I.N. Headless Validation (Linux)"
echo "=========================================="

# Step 0: Editor Parse Check
echo ""
echo "[Step 0] Editor Parse Check..."
OUTPUT=$("$GODOT" --headless --editor --quit-after 10 --path "$PROJECT_DIR" 2>&1 || true)
SCRIPT_ERRORS=$(echo "$OUTPUT" | grep -c "SCRIPT ERROR" || true)
if [ "$SCRIPT_ERRORS" -gt 0 ]; then
    echo "  FAIL: $SCRIPT_ERRORS script error(s) found"
    echo "$OUTPUT" | grep "SCRIPT ERROR"
    ERRORS=$((ERRORS + 1))
else
    echo "  PASS: No script errors"
fi

# Step 1: GDScript Static Analysis
echo ""
echo "[Step 1] GDScript Static Analysis..."
# Check for deprecated yield()
YIELD_COUNT=$(grep -rn "yield(" "$PROJECT_DIR/scripts/" --include="*.gd" | grep -v "# " | wc -l || true)
if [ "$YIELD_COUNT" -gt 0 ]; then
    echo "  WARN: $YIELD_COUNT deprecated yield() calls found (use await)"
    grep -rn "yield(" "$PROJECT_DIR/scripts/" --include="*.gd" | grep -v "# " | head -5
fi
# Check for := with CONST indexing
INFER_COUNT=$(grep -rn ":=" "$PROJECT_DIR/scripts/" --include="*.gd" | grep -E "\.[A-Z_]+\[" | wc -l || true)
if [ "$INFER_COUNT" -gt 0 ]; then
    echo "  WARN: $INFER_COUNT type inference from CONST indexing (:= with CONST[x])"
fi
# Check for Python-style // division
DIV_COUNT=$(grep -rn "[^/]//[^/]" "$PROJECT_DIR/scripts/" --include="*.gd" | grep -v "# " | grep -v "http" | wc -l || true)
if [ "$DIV_COUNT" -gt 0 ]; then
    echo "  WARN: $DIV_COUNT Python-style // division (use int(x/y))"
fi
echo "  Static analysis complete"

# Step 5: Scene Smoke Tests
echo ""
echo "[Step 5] Scene Smoke Tests..."
SCENES=(
    "res://scenes/IntroCeltOS.tscn"
    "res://scenes/MenuPrincipal.tscn"
    "res://scenes/SelectionSauvegarde.tscn"
    "res://scenes/HubAntre.tscn"
    "res://scenes/TransitionBiome.tscn"
    "res://scenes/MerlinGame.tscn"
)

# Import project first
"$GODOT" --headless --path "$PROJECT_DIR" --import --quit 2>/dev/null || true

SCENE_PASS=0
SCENE_FAIL=0
for SCENE in "${SCENES[@]}"; do
    SCENE_NAME=$(basename "$SCENE" .tscn)
    OUTPUT=$(timeout 30 "$GODOT" --headless --quit-after 15 --path "$PROJECT_DIR" --scene-path "$SCENE" 2>&1 || true)
    SE=$(echo "$OUTPUT" | grep -c "SCRIPT ERROR" || true)
    if [ "$SE" -gt 0 ]; then
        echo "  FAIL: $SCENE_NAME ($SE script errors)"
        SCENE_FAIL=$((SCENE_FAIL + 1))
        ERRORS=$((ERRORS + 1))
    else
        echo "  PASS: $SCENE_NAME"
        SCENE_PASS=$((SCENE_PASS + 1))
    fi
done
echo "  Scenes: $SCENE_PASS passed, $SCENE_FAIL failed"

# Summary
echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
    echo " RESULT: FAIL ($ERRORS error(s))"
    exit 1
else
    echo " RESULT: PASS (all checks green)"
    exit 0
fi
