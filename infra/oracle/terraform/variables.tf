# ---------------------------------------------------------------------------
# Authentication (from `oci` API signing key — see ../README.md, Step 1-2)
# ---------------------------------------------------------------------------
variable "tenancy_ocid" {
  type        = string
  description = "OCID of your tenancy (root). Console: Profile > Tenancy."
}

variable "user_ocid" {
  type        = string
  description = "OCID of your user. Console: Profile > My profile. (Only for auth = ApiKey.)"
  default     = ""
}

variable "fingerprint" {
  type        = string
  description = "Fingerprint of the API signing public key. (Only for auth = ApiKey.)"
  default     = ""
}

variable "private_key_path" {
  type        = string
  description = "Local path to the API signing PRIVATE key (PEM). (Only for auth = ApiKey.)"
  default     = "~/.oci/oci_api_key.pem"
}

variable "auth" {
  type        = string
  description = "OCI auth method: \"ApiKey\" (default) or \"SecurityToken\" (browser/Cloud Shell token via `oci session authenticate` — no private key)."
  default     = "ApiKey"
  validation {
    condition     = contains(["ApiKey", "SecurityToken"], var.auth)
    error_message = "auth must be \"ApiKey\" or \"SecurityToken\"."
  }
}

variable "config_file_profile" {
  type        = string
  description = "OCI CLI profile used when auth = SecurityToken (e.g. from `oci session authenticate --profile-name merlin`)."
  default     = "DEFAULT"
}

variable "region" {
  type        = string
  description = "OCI region identifier."
  default     = "eu-paris-1"
}

variable "compartment_ocid" {
  type        = string
  description = "Target compartment OCID. Leave empty to deploy into the tenancy root compartment."
  default     = ""
}

# ---------------------------------------------------------------------------
# Instance shape (Always Free quota: 4 OCPU + 24 GB RAM total across A1 VMs)
# ---------------------------------------------------------------------------
variable "instance_name" {
  type        = string
  description = "Display name + hostname label for the VM."
  default     = "merlin-arm-a1"
}

variable "instance_shape" {
  type        = string
  description = "Compute shape. Always-Free options: VM.Standard.A1.Flex (ARM) or VM.Standard.E2.1.Micro (AMD x86, fixed 1/8 OCPU 1GB)."
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type        = number
  description = "Number of ARM OCPUs (Always Free max 4). Only used for *.Flex shapes."
  default     = 4
}

variable "memory_in_gbs" {
  type        = number
  description = "RAM in GB (Always Free max 24)."
  default     = 24
}

variable "boot_volume_size_in_gbs" {
  type        = number
  description = "Boot volume size in GB (Always Free block storage total = 200 GB)."
  default     = 100
}

# Image selection — Canonical Ubuntu aarch64 by default.
variable "operating_system" {
  type        = string
  description = "OS for the image lookup."
  default     = "Canonical Ubuntu"
}

variable "operating_system_version" {
  type        = string
  description = "OS version for the image lookup."
  default     = "22.04"
}

# Default OS user baked into the image (Ubuntu -> ubuntu, Oracle Linux -> opc).
variable "os_username" {
  type        = string
  description = "Default login user of the chosen image."
  default     = "ubuntu"
}

# ---------------------------------------------------------------------------
# Placement / capacity (A1 is frequently 'Out of host capacity')
# ---------------------------------------------------------------------------
variable "availability_domain_number" {
  type        = number
  description = "1-based index into the region's availability domains. Try 1, then 2/3 if capacity errors."
  default     = 1
}

# ---------------------------------------------------------------------------
# Access / SSH
# ---------------------------------------------------------------------------
variable "ssh_public_key" {
  type        = string
  description = "Contents of your SSH PUBLIC key (id_ed25519.pub) for instance login."
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to reach SSH (22). Strongly recommended to set your own IP/32."
  default     = "0.0.0.0/0"
}

variable "expose_ollama" {
  type        = bool
  description = "If true, open Ollama port 11434 to allowed_ssh_cidr. Default false — use an SSH tunnel instead."
  default     = false
}

# ---------------------------------------------------------------------------
# Workload provisioning (cloud-init)
# ---------------------------------------------------------------------------
variable "ollama_models" {
  type        = list(string)
  description = "Gemma models to pull on first boot (CPU inference)."
  default     = ["gemma3:4b", "gemma3:12b"]
}

variable "godot_version" {
  type        = string
  description = "Godot headless version to install (matches project: 4.4.1)."
  default     = "4.4.1"
}

variable "git_repos" {
  type        = list(string)
  description = "Git clone URLs to mirror into ~/workspace on first boot."
  default = [
    "https://github.com/merlingame-netizen/M.E.R.L.I.N.git",
    "https://github.com/merlingame-netizen/merlin-web.git",
  ]
}

# ---------------------------------------------------------------------------
# Claude Code runner (systemd service on the VM)
# ---------------------------------------------------------------------------
variable "enable_claude_runner" {
  type        = bool
  description = "Install a systemd service that can run a headless Claude Code task at boot. Stays inactive until /etc/merlin/runner.env is configured with ANTHROPIC_API_KEY."
  default     = true
}

# ---------------------------------------------------------------------------
# Dev services stack (docker compose, all bound to 127.0.0.1)
# ---------------------------------------------------------------------------
variable "enable_dev_stack" {
  type        = bool
  description = "Deploy the docker compose stack (Open WebUI, code-server, Filebrowser, PostgreSQL). All services are loopback-only (SSH-tunnel access)."
  default     = true
}

variable "openwebui_tag" {
  type        = string
  description = "Open WebUI image tag. Pin to a release (e.g. v0.5.20) if 'main' regresses on arm64."
  default     = "main"
}

variable "enable_blender" {
  type        = bool
  description = "Install Blender headless via the linuxserver arm64 container + /usr/local/bin/blender wrapper. WARNING: arm64 build is not guaranteed to be 4.5; test asset_forge scripts before relying on it."
  default     = false
}

variable "budget_alert_email" {
  type        = string
  description = "Email notified by the cost-guard budget alert on any spend. Set in terraform.tfvars (not committed)."
  default     = ""
}
