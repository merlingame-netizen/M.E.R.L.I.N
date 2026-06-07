#!/usr/bin/env bash
# Creates a desktop launcher for the VM on macOS or Linux.
# Uses the 'merlin-vm' SSH alias (scripts/install-ssh-alias.sh).
set -euo pipefail
ALIAS="merlin-vm"

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS: a double-clickable .command that opens Terminal and SSHes in.
  DEST="$HOME/Desktop/M.E.R.L.I.N VM.command"
  cat > "$DEST" <<EOF
#!/usr/bin/env bash
ssh ${ALIAS}
EOF
  chmod +x "$DEST"
  echo "Created: $DEST  (double-click to connect)"
else
  # Linux: a .desktop launcher opening a terminal with the SSH session.
  DEST="$HOME/Desktop/merlin-vm.desktop"
  mkdir -p "$HOME/Desktop"
  cat > "$DEST" <<EOF
[Desktop Entry]
Type=Application
Name=M.E.R.L.I.N VM
Comment=SSH into the Oracle VM (+ Ollama tunnel)
Exec=x-terminal-emulator -e ssh ${ALIAS}
Icon=network-server
Terminal=false
Categories=Network;
EOF
  chmod +x "$DEST"
  # GNOME requires the launcher to be marked trusted.
  command -v gio >/dev/null 2>&1 && gio set "$DEST" metadata::trusted true 2>/dev/null || true
  echo "Created: $DEST  (double-click to connect; you may need to 'Allow Launching')"
fi
