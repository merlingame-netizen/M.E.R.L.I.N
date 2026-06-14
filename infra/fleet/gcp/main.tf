resource "google_compute_network" "vpc" {
  name                    = "${var.instance_name}-vpc"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.instance_name}-allow-ssh"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [var.allowed_ssh_cidr]
}
# Uptime Kuma (:3001) is NOT exposed publicly — reached only via SSH tunnel
# (ssh -L 3001:localhost:3001). The container binds to 127.0.0.1 on the VM.

resource "google_compute_instance" "vm" {
  name         = var.instance_name
  machine_type = var.machine_type # e2-micro (Always Free)
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.boot_disk_gb
      type  = "pd-standard" # free tier requires standard PD
    }
  }

  network_interface {
    network = google_compute_network.vpc.name
    access_config {} # ephemeral public IP
  }

  metadata = {
    ssh-keys       = "${var.ssh_user}:${var.ssh_public_key}"
    startup-script = file("${path.module}/startup-script.sh")
  }

  labels = {
    role = "merlin-vps-light"
  }
}
