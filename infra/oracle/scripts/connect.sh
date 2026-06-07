#!/usr/bin/env bash
# One-shot SSH into the VM using terraform outputs (no ~/.ssh/config needed).
# Any extra args are passed to ssh (e.g. ./connect.sh merlin-status).
set -euo pipefail
TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/merlin_oracle_ed25519}"

IP="$(cd "$TF_DIR" && terraform output -raw public_ip 2>/dev/null)"
USER="$(cd "$TF_DIR" && terraform output -raw ssh_user 2>/dev/null || echo ubuntu)"
[[ -n "$IP" ]] || { echo "No public_ip output — apply the VM first." >&2; exit 1; }

exec ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${USER}@${IP}" "$@"
