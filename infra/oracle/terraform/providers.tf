# OCI provider — two auth modes (see var.auth):
#   ApiKey (default)  : API signing key (tenancy/user/fingerprint/private_key). ../README.md.
#   SecurityToken     : browser token from `oci session authenticate` — ideal in OCI Cloud
#                       Shell (terminal in the browser, no private key file, no PC control).
# NEVER commit terraform.tfvars or any private key. See .gitignore.
provider "oci" {
  auth                = var.auth
  config_file_profile = var.config_file_profile
  tenancy_ocid        = var.tenancy_ocid
  user_ocid           = var.user_ocid
  fingerprint         = var.fingerprint
  private_key_path    = var.private_key_path
  region              = var.region
}
