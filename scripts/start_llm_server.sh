#!/bin/bash
# Launch llama.cpp server before starting Godot.

LLAMA_CPP_PATH="/chemin/vers/llama.cpp"
MODELS_PATH="/chemin/vers/models"

$LLAMA_CPP_PATH/llama-server \
  -m "$MODELS_PATH/Trinity-Nano-Preview-Q4_K_M.gguf" \
  --host 127.0.0.1 \
  --port 8080 \
  -c 4096 \
  -ngl 99 \
  --threads 8
