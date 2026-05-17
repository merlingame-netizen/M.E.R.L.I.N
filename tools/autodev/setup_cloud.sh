#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# M.E.R.L.I.N. Cloud Setup — Install Godot headless + dependencies
# Called by SessionStart hook. Idempotent (safe to re-run).
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

GODOT_VERSION="4.4.1"
GODOT_RELEASE="stable"
GODOT_DIR="/tmp/godot"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64"
GODOT_LINK="/usr/local/bin/godot"
STATUS_FILE="tools/autodev/status/watchdog.txt"

log() { echo "[setup_cloud] $(date -u +%H:%M:%S) $*"; }

# ─── Skip if already installed ────────────────────────────────────────────────
if command -v godot &>/dev/null; then
    log "Godot already available: $(godot --version 2>/dev/null || echo 'unknown')"
    exit 0
fi

# ─── Download Godot headless ──────────────────────────────────────────────────
log "Installing Godot ${GODOT_VERSION} headless..."
mkdir -p "$GODOT_DIR"

ARCHIVE="Godot_v${GODOT_VERSION}-${GODOT_RELEASE}_linux.x86_64.zip"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${GODOT_RELEASE}/${ARCHIVE}"

if [ ! -f "$GODOT_BIN" ]; then
    log "Downloading from $URL"
    curl -sL "$URL" -o "/tmp/${ARCHIVE}"
    cd "$GODOT_DIR" && unzip -qo "/tmp/${ARCHIVE}" && rm -f "/tmp/${ARCHIVE}"
    chmod +x "$GODOT_BIN"
    log "Downloaded and extracted."
else
    log "Binary already cached at $GODOT_BIN"
fi

# ─── Symlink ──────────────────────────────────────────────────────────────────
if [ -w /usr/local/bin ]; then
    ln -sf "$GODOT_BIN" "$GODOT_LINK"
    log "Symlinked to $GODOT_LINK"
else
    export PATH="$GODOT_DIR:$PATH"
    log "Added $GODOT_DIR to PATH (no write access to /usr/local/bin)"
fi

# ─── Verify ───────────────────────────────────────────────────────────────────
if command -v godot &>/dev/null || [ -x "$GODOT_BIN" ]; then
    log "Godot ready: $($GODOT_BIN --version 2>/dev/null || echo $GODOT_VERSION)"
else
    log "WARNING: Godot install failed. Continuing without Godot validation."
fi

# ─── Log to watchdog ──────────────────────────────────────────────────────────
if [ -f "$STATUS_FILE" ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) cloud-setup godot=${GODOT_VERSION}" >> "$STATUS_FILE"
fi

log "Setup complete."
