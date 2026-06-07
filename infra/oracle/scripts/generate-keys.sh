#!/usr/bin/env bash
# Generate the OCI API signing key (for Terraform auth) and an SSH key (for VM login).
# Run this on YOUR machine. Nothing here touches your Oracle password.
set -euo pipefail

OCI_DIR="${HOME}/.oci"
KEY="${OCI_DIR}/oci_api_key.pem"
PUB="${OCI_DIR}/oci_api_key_public.pem"
SSH_KEY="${HOME}/.ssh/merlin_oracle_ed25519"

mkdir -p "${OCI_DIR}"; chmod 700 "${OCI_DIR}"

# --- OCI API signing key (RSA 2048) ---
if [[ -f "${KEY}" ]]; then
  echo "==> API key already exists: ${KEY} (reusing)"
else
  echo "==> Generating OCI API signing key..."
  openssl genrsa -out "${KEY}" 2048
  chmod 600 "${KEY}"
  openssl rsa -pubout -in "${KEY}" -out "${PUB}"
fi

FP="$(openssl rsa -pubout -outform DER -in "${KEY}" 2>/dev/null | openssl md5 -c | awk '{print $NF}')"

# --- SSH key for instance login ---
if [[ -f "${SSH_KEY}" ]]; then
  echo "==> SSH key already exists: ${SSH_KEY} (reusing)"
else
  echo "==> Generating SSH key..."
  ssh-keygen -t ed25519 -N "" -f "${SSH_KEY}" -C "merlin-oracle"
fi

cat <<EOF

================================================================
NEXT STEPS (do these in the Oracle Cloud Console, your browser)
================================================================
1. Console > Profile (top-right) > My profile > API keys > Add API key
   > "Paste a public key" and paste EXACTLY this:

$(cat "${PUB}")

2. After adding, Oracle shows a config preview. Confirm the fingerprint is:
   ${FP}

3. Collect these OCIDs for terraform.tfvars:
   - user_ocid    : Profile > My profile  (Copy OCID)
   - tenancy_ocid : Profile > Tenancy     (Copy OCID)

----------------------------------------------------------------
Fill terraform/terraform.tfvars with:
  fingerprint      = "${FP}"
  private_key_path = "${KEY}"
  ssh_public_key   = "$(cat "${SSH_KEY}.pub")"
  region           = "eu-paris-1"
  tenancy_ocid     = "<paste>"
  user_ocid        = "<paste>"
================================================================
EOF
