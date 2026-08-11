#!/usr/bin/env bash
# Installation USERLAND d'Ollama sur la VM (pas de sudo, comme godot/sysroot) :
# binaire dans ~/opt/ollama, lancement assuré par l'agent ollama-serve (cron).
# Idempotent : relançable sans casse. Modèles cibles ARM 4 cœurs :
#   qwen2.5:1.5b (résident, copilote/instantané) · qwen2.5:3b (triage CI)
set -euo pipefail
OLLAMA_DIR="$HOME/opt/ollama"
BIN="$OLLAMA_DIR/bin/ollama"
mkdir -p "$OLLAMA_DIR" "$HOME/bin" "$HOME/.config"

case "$(uname -m)" in
    aarch64|arm64) ARCH=arm64 ;;
    x86_64)        ARCH=amd64 ;;
    *) echo "arch inconnue: $(uname -m)"; exit 1 ;;
esac

# ── libre >= 8 Go exigé avant de télécharger quoi que ce soit ───────────────
FREE_G="$(df -BG --output=avail "$HOME" | tail -1 | tr -dc 0-9)"
[ "$FREE_G" -ge 8 ] || { echo "disque insuffisant (${FREE_G}G libres, 8G requis)"; exit 1; }

if [ ! -x "$BIN" ]; then
    # Depuis ~v0.30 les assets GitHub sont en .tar.zst (le .tgz n'existe plus).
    echo "téléchargement ollama-linux-$ARCH.tar.zst…"
    curl -fL --retry 3 -o /tmp/ollama.tar.zst \
        "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-$ARCH.tar.zst"
    if command -v zstd >/dev/null 2>&1; then
        tar --zstd -xf /tmp/ollama.tar.zst -C "$OLLAMA_DIR"
    else
        # Pas de zstd CLI sur la VM (pas de sudo pour l'installer) : on passe
        # par le paquet python `zstandard` dans le venv du Studio.
        PY="$HOME/workspace/M.E.R.L.I.N/.venv/bin/python"
        [ -x "$PY" ] || PY="$(command -v python3)"
        "$PY" -m pip install --quiet zstandard
        "$PY" - <<'PYEOF'
import zstandard
with open("/tmp/ollama.tar.zst", "rb") as src, open("/tmp/ollama.tar", "wb") as dst:
    zstandard.ZstdDecompressor().copy_stream(src, dst)
PYEOF
        tar -xf /tmp/ollama.tar -C "$OLLAMA_DIR" && rm -f /tmp/ollama.tar
    fi
    rm -f /tmp/ollama.tar.zst
    ln -sf "$BIN" "$HOME/bin/ollama"
fi
"$BIN" --version

# ── réglages figés pour 4 cœurs ARM / 22 Go (source de vérité unique) ───────
CONF="$HOME/.config/merlin-llm.env"
if [ ! -f "$CONF" ]; then
    cat > "$CONF" <<'EOF'
# Réglages LLM locaux (VM ARM 4 cœurs, CPU only) — sourcé par les scripts llm/.
export OLLAMA_HOST=127.0.0.1:11434
export OLLAMA_KEEP_ALIVE=30m
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_MAX_LOADED_MODELS=2
# Modèles par rôle (le bench peut réécrire TRIAGE_MODEL s'il reste sur AUTO)
export COPILOT_MODEL=qwen2.5:1.5b
export TRIAGE_MODEL=AUTO
export LLM_NUM_CTX=2048
EOF
fi
. "$CONF"

# ── serveur : démarré ici une première fois, entretenu ensuite par l'agent ──
if ! curl -fsS -m 3 "http://$OLLAMA_HOST/api/version" >/dev/null 2>&1; then
    nohup env OLLAMA_HOST="$OLLAMA_HOST" OLLAMA_KEEP_ALIVE="$OLLAMA_KEEP_ALIVE" \
        OLLAMA_NUM_PARALLEL="$OLLAMA_NUM_PARALLEL" OLLAMA_MAX_LOADED_MODELS="$OLLAMA_MAX_LOADED_MODELS" \
        "$BIN" serve > "$HOME/.cache/ollama-serve.log" 2>&1 &
    for _ in $(seq 1 30); do
        curl -fsS -m 2 "http://$OLLAMA_HOST/api/version" >/dev/null 2>&1 && break; sleep 1
    done
fi
curl -fsS -m 3 "http://$OLLAMA_HOST/api/version" || { echo "serveur ollama injoignable"; exit 1; }

for m in qwen2.5:1.5b qwen2.5:3b; do
    "$BIN" list 2>/dev/null | grep -q "^$m" || { echo "pull $m…"; "$BIN" pull "$m"; }
done
"$BIN" list
echo "ollama prêt (userland, $ARCH)"
