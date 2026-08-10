#!/usr/bin/env bash
# Provisioning Oracle Linux 9 (aarch64) pour la VM A1 MERLIN — execute via Run Command
# (root). L'image Ubuntu est abandonnee : son agent snap n'embarque PAS le plugin
# Run Command (verifie le 2026-08-10 — liste de plugins sans "Compute Instance Run
# Command"), donc aucun pilotage distant possible. Oracle Linux le supporte nativement.
#
#   curl -fsSL https://raw.githubusercontent.com/merlingame-netizen/M.E.R.L.I.N/main/infra/oracle/studio/provision-ol9.sh | bash
#
# Idempotent. Termine en appelant up.sh (Studio + tunnel) qui imprime URL + token.
set -uo pipefail

say() { printf '%s\n' "$*"; }
say "=== provision-ol9: $(date -u +%H:%M:%S) sur $(uname -m) ==="

# ── 1. Paquets de base (dnf) ────────────────────────────────────────────────
dnf -y install git curl unzip tar tmux jq python3 python3-pip >/dev/null 2>&1 \
  || say "[warn] dnf base incomplet"

# ── 2. Swap 8G (marge pour les modeles quantises) ──────────────────────────
if [ ! -f /swapfile ]; then
  fallocate -l 8G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  say "swap 8G actif"
fi

# ── 3. Godot headless arm64 (smoke tests + export web) ─────────────────────
if ! command -v godot >/dev/null 2>&1; then
  GV="4.6"
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${GV}-stable/Godot_v${GV}-stable_linux.arm64.zip" -o /tmp/godot.zip \
    && unzip -o -q /tmp/godot.zip -d /tmp \
    && install -m 0755 "/tmp/Godot_v${GV}-stable_linux.arm64" /usr/local/bin/godot \
    && rm -f /tmp/godot.zip
fi
say "godot: $(godot --headless --version 2>/dev/null | head -1 || echo absent)"

# ── 4. Node 20 (build serveur + Claude Code CLI) ───────────────────────────
if ! command -v node >/dev/null 2>&1; then
  dnf -y module enable nodejs:20 >/dev/null 2>&1 || true
  dnf -y install nodejs >/dev/null 2>&1 || say "[warn] node absent"
fi
say "node: $(node --version 2>/dev/null || echo absent)"

# ── 5. Ollama (LLM local, loopback) ────────────────────────────────────────
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh >/dev/null 2>&1 || say "[warn] ollama KO"
  systemctl enable --now ollama >/dev/null 2>&1 || true
fi
say "ollama: $(curl -fsS http://127.0.0.1:11434/api/version 2>/dev/null | jq -r .version 2>/dev/null || echo down)"

# ── 6. Depot du jeu (public) dans /root/workspace ──────────────────────────
REPO="$HOME/workspace/M.E.R.L.I.N"
if [ ! -d "$REPO/.git" ]; then
  mkdir -p "$(dirname "$REPO")"
  git clone --quiet https://github.com/merlingame-netizen/M.E.R.L.I.N.git "$REPO"
fi
git -C "$REPO" pull --ff-only --quiet 2>/dev/null || true
say "repo: $(git -C "$REPO" log --oneline -1 2>/dev/null || echo absent)"

# ── 7. Studio + tunnel (imprime URL + token) ───────────────────────────────
bash "$REPO/infra/oracle/studio/up.sh"

# ── 8. Modeles Gemma en arriere-plan (long ; ne bloque pas l'URL) ──────────
nohup bash -c 'ollama pull gemma4:e4b-it-qat; ollama pull gemma4:12b-it-qat; echo done > /root/MODELS_DONE' \
  >/var/log/merlin-models.log 2>&1 &
say "pull modeles lance en arriere-plan (journal: /var/log/merlin-models.log)"
say "=== provision-ol9: termine $(date -u +%H:%M:%S) ==="
