#!/usr/bin/env bash
# Open the Ollama tunnel: remote 11434 -> localhost:11434 (foreground, Ctrl-C to stop).
set -euo pipefail
TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/merlin_oracle_ed25519}"

IP="$(cd "$TF_DIR" && terraform output -raw public_ip 2>/dev/null)"
USER="$(cd "$TF_DIR" && terraform output -raw ssh_user 2>/dev/null || echo ubuntu)"
[[ -n "$IP" ]] || { echo "No public_ip output — apply the VM first." >&2; exit 1; }

echo "Tunneling VM services to localhost (Ctrl-C to stop):"
echo "  :8790 MERLIN Studio  :3000 Open WebUI  :8443 code-server  :8081 Filebrowser  :11434 Ollama  :5432 Postgres"
exec ssh -N -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
  -L 8790:localhost:8790 \
  -L 11434:localhost:11434 \
  -L 3000:localhost:3000 \
  -L 8443:localhost:8443 \
  -L 8081:localhost:8081 \
  -L 5432:localhost:5432 \
  "${USER}@${IP}"
