#!/usr/bin/env bash
# Deploy the Oracle Always-Free A1 host from OCI CLOUD SHELL (terminal in your browser).
# No private key to hand over, no software to install on your PC, no remote control.
#
#   In the OCI Console (Edge): click the Cloud Shell icon (top-right ">_"), then:
#     git clone https://github.com/merlingame-netizen/M.E.R.L.I.N.git
#     bash M.E.R.L.I.N/infra/oracle/scripts/deploy-cloudshell.sh [region]
#
# It: browser-token auth (oci session authenticate) -> SSH key -> tfvars -> plan ->
#     free-tier guard -> apply. A1 stays in the Always Free allocation (0 EUR).
set -euo pipefail
REGION="${1:-eu-paris-1}"
PROFILE="merlin"
HERE="$(cd "$(dirname "$0")" && pwd)"
TF="$HERE/../terraform"

command -v terraform >/dev/null 2>&1 || { echo "Run this INSIDE OCI Cloud Shell (terraform is preinstalled there)."; exit 1; }
command -v oci >/dev/null 2>&1 || { echo "Run this INSIDE OCI Cloud Shell (the oci CLI is preinstalled there)."; exit 1; }

echo "==> 1/5 Browser token auth (opens a link to authenticate in a new tab)"
if ! oci session validate --profile-name "$PROFILE" --local >/dev/null 2>&1; then
  oci session authenticate --region "$REGION" --profile-name "$PROFILE"
fi

echo "==> 2/5 SSH key for the VM"
[ -f "$HOME/.ssh/merlin_oracle" ] || ssh-keygen -t ed25519 -f "$HOME/.ssh/merlin_oracle" -N "" -C "merlin-oracle"

echo "==> 3/5 Reading tenancy OCID from the session profile"
TEN="$(awk -v p="[$PROFILE]" '$0==p{f=1;next} /^\[/{f=0} f&&/^tenancy=/{sub(/^tenancy=/,"");print;exit}' "$HOME/.oci/config")"
[ -n "$TEN" ] || { echo "Could not read tenancy from ~/.oci/config [$PROFILE]"; exit 1; }

echo "==> 4/5 Writing terraform.tfvars (SecurityToken mode)"
cat > "$TF/terraform.tfvars" <<EOF
auth                = "SecurityToken"
config_file_profile = "$PROFILE"
region              = "$REGION"
tenancy_ocid        = "$TEN"
ssh_public_key      = "$(cat "$HOME/.ssh/merlin_oracle.pub")"
EOF

echo "==> 5/5 Plan + free-tier guard + apply"
cd "$TF"
terraform init -input=false
terraform plan -out=tfplan
if ! python3 "$HERE/freetier-guard.py" tfplan; then
  echo "Aborting: plan would leave the Always Free limits (would incur charges)." >&2
  exit 1
fi
terraform apply tfplan
echo
echo "==> Done. Connect:"; terraform output -raw ssh_command 2>/dev/null; echo
echo "    (key: ~/.ssh/merlin_oracle — download it from Cloud Shell via the menu if needed)"
echo "==> If you hit 'Out of host capacity', re-run with a different AD:"
echo "    add 'availability_domain_number = 2' (or 3) to $TF/terraform.tfvars and re-run."
