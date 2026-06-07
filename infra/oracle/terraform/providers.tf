# OCI provider — API-key (signing key) authentication.
# These values come from the one-time setup described in ../README.md.
# NEVER commit terraform.tfvars or the private key. See .gitignore.
provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}
