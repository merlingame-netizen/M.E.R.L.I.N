#!/usr/bin/env bash
# Add a 'merlin-vm' host alias to ~/.ssh/config so you can just `ssh merlin-vm`.
# Also forwards the remote Ollama (11434) over the tunnel automatically.
# Reads the public IP / user from terraform outputs.
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/merlin_oracle_ed25519}"
ALIAS="${1:-merlin-vm}"

IP="$(cd "$TF_DIR" && terraform output -raw public_ip 2>/dev/null)"
USER="$(cd "$TF_DIR" && terraform output -raw ssh_user 2>/dev/null || echo ubuntu)"

if [[ -z "${IP}" ]]; then
  echo "Could not read public_ip from terraform outputs. Has the VM been applied?" >&2
  exit 1
fi

CFG="${HOME}/.ssh/config"
mkdir -p "${HOME}/.ssh"; touch "${CFG}"; chmod 600 "${CFG}"

# Remove any previous block for this alias (between markers) then append fresh.
TMP="$(mktemp)"
awk -v a="${ALIAS}" '
  $0=="# >>> "a" (managed by merlin) >>>" {skip=1}
  skip && $0=="# <<< "a" (managed by merlin) <<<" {skip=0; next}
  !skip {print}
' "${CFG}" > "${TMP}" || cp "${CFG}" "${TMP}"

cat >> "${TMP}" <<EOF
# >>> ${ALIAS} (managed by merlin) >>>
Host ${ALIAS}
    HostName ${IP}
    User ${USER}
    IdentityFile ${SSH_KEY}
    LocalForward 11434 localhost:11434
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new
# <<< ${ALIAS} (managed by merlin) <<<
EOF

mv "${TMP}" "${CFG}"; chmod 600 "${CFG}"

cat <<EOF
==> Added '${ALIAS}' to ${CFG}

Now you can simply:
    ssh ${ALIAS}                # shell on the VM (+ Ollama tunneled to localhost:11434)
    scp file ${ALIAS}:~/        # copy files
    code --remote ssh-remote+${ALIAS} /home/${USER}/workspace   # VS Code Remote-SSH

(IP ${IP}, user ${USER}, key ${SSH_KEY})
EOF
