#!/usr/bin/env bash
# Idempotent installer for the OBSCURA headless browser binary.
# Detects OS/arch, downloads the matching GitHub release tarball, installs to
# ~/.local/bin, and ensures that dir is on PATH for the current session.
set -euo pipefail

BIN_DIR="${OBSCURA_BIN_DIR:-$HOME/.local/bin}"
REPO="h4ckf0r0day/obscura"

# Already installed?
if command -v obscura >/dev/null 2>&1; then
  echo "obscura already installed: $(command -v obscura)"
  obscura --version 2>/dev/null || true
  exit 0
fi

# Detect platform → release asset name.
os="$(uname -s)"
arch="$(uname -m)"
case "$os" in
  Linux)  os_tag="linux" ;;
  Darwin) os_tag="macos" ;;
  *) echo "Unsupported OS: $os. Use Docker: docker run -d --name obscura -p 127.0.0.1:9222:9222 ${REPO}" >&2; exit 1 ;;
esac
case "$arch" in
  x86_64|amd64)        arch_tag="x86_64" ;;
  aarch64|arm64)       arch_tag="aarch64" ;;
  *) echo "Unsupported arch: $arch" >&2; exit 1 ;;
esac

asset="obscura-${arch_tag}-${os_tag}.tar.gz"
url="https://github.com/${REPO}/releases/latest/download/${asset}"

echo "Downloading ${asset} ..."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! curl -fLsS "$url" -o "$tmp/$asset"; then
  echo "Download failed (network policy may block GitHub releases)." >&2
  echo "Fallback: docker run -d --name obscura -p 127.0.0.1:9222:9222 ${REPO}" >&2
  exit 1
fi

tar xzf "$tmp/$asset" -C "$tmp"
mkdir -p "$BIN_DIR"
# The tarball contains an `obscura` binary at its root.
install -m 0755 "$(find "$tmp" -name obscura -type f | head -n1)" "$BIN_DIR/obscura"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) export PATH="$BIN_DIR:$PATH"
     echo "Added $BIN_DIR to PATH for this session. Persist it in your shell profile if needed." ;;
esac

echo "Installed: $BIN_DIR/obscura"
"$BIN_DIR/obscura" --version 2>/dev/null || true
