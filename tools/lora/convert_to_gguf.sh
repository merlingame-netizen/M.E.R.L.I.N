#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Convert LoRA adapter from HuggingFace PEFT format to GGUF for llama.cpp
# ═══════════════════════════════════════════════════════════════════════════════
#
# Prerequisites:
#   - llama.cpp repository cloned: git clone https://github.com/ggerganov/llama.cpp
#   - Python dependencies: pip install gguf safetensors torch
#
# Usage:
#   bash tools/lora/convert_to_gguf.sh [LORA_DIR] [OUTPUT_FILE]
#
#   Default LORA_DIR:    output/merlin_narrator_lora
#   Default OUTPUT_FILE: addons/merlin_llm/adapters/merlin_narrator_lora.gguf

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LORA_DIR="${1:-$PROJECT_ROOT/output/merlin_narrator_lora}"
OUTPUT_FILE="${2:-$PROJECT_ROOT/addons/merlin_llm/adapters/merlin_narrator_lora.gguf}"
BASE_MODEL="Qwen/Qwen2.5-3B-Instruct"

# Check llama.cpp path
LLAMA_CPP="${LLAMA_CPP_PATH:-$HOME/llama.cpp}"

echo "═══════════════════════════════════════════════════════════"
echo "  M.E.R.L.I.N. LoRA → GGUF Conversion"
echo "═══════════════════════════════════════════════════════════"
echo "  LoRA adapter:  $LORA_DIR"
echo "  Base model:    $BASE_MODEL"
echo "  Output:        $OUTPUT_FILE"
echo "  llama.cpp:     $LLAMA_CPP"
echo "═══════════════════════════════════════════════════════════"

# Verify inputs
if [ ! -d "$LORA_DIR" ]; then
    echo "ERROR: LoRA directory not found: $LORA_DIR"
    echo "Run train_narrator_lora.py first."
    exit 1
fi

if [ ! -f "$LLAMA_CPP/convert_lora_to_gguf.py" ]; then
    echo "ERROR: llama.cpp not found at: $LLAMA_CPP"
    echo "Set LLAMA_CPP_PATH environment variable or clone llama.cpp to ~/llama.cpp"
    echo ""
    echo "  git clone https://github.com/ggerganov/llama.cpp ~/llama.cpp"
    exit 1
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Convert
echo ""
echo "[convert] Running conversion..."
python "$LLAMA_CPP/convert_lora_to_gguf.py" \
    --base "$BASE_MODEL" \
    --lora "$LORA_DIR" \
    --outfile "$OUTPUT_FILE"

echo ""
echo "[convert] Done!"
echo "  Output: $OUTPUT_FILE"
echo "  Size:   $(du -h "$OUTPUT_FILE" | cut -f1)"
echo ""
echo "To use in M.E.R.L.I.N., copy to:"
echo "  addons/merlin_llm/adapters/merlin_narrator_lora.gguf"
echo ""
echo "The game will auto-detect and load the adapter on startup."
