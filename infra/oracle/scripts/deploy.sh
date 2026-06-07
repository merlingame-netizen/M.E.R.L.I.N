#!/usr/bin/env bash
# Thin wrapper around terraform init/plan/apply for the Oracle ARM A1 host.
set -euo pipefail
cd "$(dirname "$0")/../terraform"

terraform init -input=false
terraform plan -out=tfplan

# Free-tier guard: block the apply if the plan leaves Always Free limits.
if ! python3 "$(dirname "$0")/freetier-guard.py" tfplan; then
  echo "Aborting: plan would incur charges. Adjust variables and re-run." >&2
  exit 1
fi

read -r -p "Apply this plan? [y/N] " ans
if [[ "${ans,,}" == "y" ]]; then
  terraform apply tfplan
  echo
  echo "==> Done. Connect with:"
  terraform output -raw ssh_command; echo
  echo "==> Ollama tunnel:"
  terraform output -raw ollama_tunnel_command; echo
else
  echo "Aborted. (plan saved as terraform/tfplan)"
fi
