variable "project_id" {
  type        = string
  description = "GCP project id."
}

variable "credentials_file" {
  type        = string
  description = "Path to a service-account JSON key. Empty = use gcloud ADC."
  default     = ""
}

# Always Free e2-micro is only free in these US regions.
variable "region" {
  type    = string
  default = "us-west1"
  validation {
    condition     = contains(["us-west1", "us-central1", "us-east1"], var.region)
    error_message = "Always Free e2-micro is only free in us-west1, us-central1, or us-east1."
  }
}

variable "zone" {
  type    = string
  default = "us-west1-b"
}

# Free-tier guard: only e2-micro is Always Free.
variable "machine_type" {
  type    = string
  default = "e2-micro"
  validation {
    condition     = var.machine_type == "e2-micro"
    error_message = "Free tier requires e2-micro. Changing this would incur charges."
  }
}

# Free tier = 30 GB standard persistent disk total.
variable "boot_disk_gb" {
  type    = number
  default = 30
  validation {
    condition     = var.boot_disk_gb <= 30
    error_message = "Free tier covers up to 30 GB standard PD."
  }
}

variable "image" {
  type    = string
  default = "debian-cloud/debian-12"
}

variable "instance_name" {
  type    = string
  default = "merlin-micro"
}

variable "ssh_user" {
  type        = string
  description = "Login user injected into the instance."
  default     = "merlin"
}

variable "ssh_public_key" {
  type        = string
  description = "Contents of your SSH public key."
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to reach SSH (22). Use your IP/32."
  default     = "0.0.0.0/0"
}

# Optional cost guard: set to your billing account id to create a 0-spend budget alert.
variable "billing_account" {
  type    = string
  default = ""
}

variable "budget_alert_email" {
  type    = string
  default = ""
}
