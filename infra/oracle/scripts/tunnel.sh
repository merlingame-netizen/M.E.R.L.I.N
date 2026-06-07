#!/usr/bin/env bash
# Open the Ollama tunnel: remote 11434 -> localhost:11434 (foreground, Ctrl-C to stop).
set -euo pipefail
TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/merlin_oracle_ed25519}"

IP="$(cd "$TF_DIR" && terraform output -raw public_ip 2>/dev/null)"
USER="$(cd "$TF_DIR" && terraform output -raw ssh_user 2>/dev/null || echo ubuntu)"
[[ -n "$IP" ]] || { echo "No public_ip output — apply the VM first." >&2; exit 1; }

echo "Tunneling http://localhost:11434 -> ${USER}@${IP} (Ctrl-C to stop)"
exec ssh -N -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
  -L 11434:localhost:11434 "${USER}@${IP}"
