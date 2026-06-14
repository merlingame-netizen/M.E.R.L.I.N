# Auth: either a service-account JSON (var.credentials_file) or, if empty,
# Application Default Credentials from `gcloud auth application-default login`.
provider "google" {
  project     = var.project_id
  region      = var.region
  zone        = var.zone
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null
}
