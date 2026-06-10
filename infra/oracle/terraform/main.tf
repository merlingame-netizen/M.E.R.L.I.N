locals {
  compartment_id = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid
}

# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Latest image matching the requested OS + version that is compatible with the
# A1.Flex (aarch64) shape.
data "oci_core_images" "os" {
  compartment_id           = local.compartment_id
  operating_system         = var.operating_system
  operating_system_version = var.operating_system_version
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_number - 1].name
  image_id            = data.oci_core_images.os.images[0].id

  cloud_init = base64encode(templatefile("${path.module}/../cloud-init/cloud-init.yaml.tftpl", {
    os_username          = var.os_username
    ollama_models        = var.ollama_models
    godot_version        = var.godot_version
    expose_ollama        = var.expose_ollama
    git_repos            = var.git_repos
    enable_claude_runner = var.enable_claude_runner
    enable_dev_stack     = var.enable_dev_stack
    openwebui_tag        = var.openwebui_tag
    enable_blender       = var.enable_blender
  }))
}

# ---------------------------------------------------------------------------
# Network: VCN + Internet Gateway + Route Table + Security List + Subnet
# ---------------------------------------------------------------------------
resource "oci_core_vcn" "vcn" {
  compartment_id = local.compartment_id
  display_name   = "${var.instance_name}-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "merlinvcn"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.instance_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "rt" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.instance_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_security_list" "sl" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.vcn.id
  display_name   = "${var.instance_name}-sl"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH
  ingress_security_rules {
    protocol    = "6" # TCP
    source      = var.allowed_ssh_cidr
    description = "SSH"
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Ollama API (only when explicitly exposed; default is SSH-tunnel-only)
  dynamic "ingress_security_rules" {
    for_each = var.expose_ollama ? [1] : []
    content {
      protocol    = "6"
      source      = var.allowed_ssh_cidr
      description = "Ollama API"
      tcp_options {
        min = 11434
        max = 11434
      }
    }
  }
}

resource "oci_core_subnet" "subnet" {
  compartment_id    = local.compartment_id
  vcn_id            = oci_core_vcn.vcn.id
  display_name      = "${var.instance_name}-subnet"
  cidr_block        = "10.0.1.0/24"
  route_table_id    = oci_core_route_table.rt.id
  security_list_ids = [oci_core_security_list.sl.id]
  dns_label         = "merlinsub"
}

# ---------------------------------------------------------------------------
# Compute: ARM Ampere A1 Flex (Always Free)
# ---------------------------------------------------------------------------
resource "oci_core_instance" "vm" {
  compartment_id      = local.compartment_id
  availability_domain = local.availability_domain
  display_name        = var.instance_name
  shape               = var.instance_shape

  # Flex shapes (e.g. A1.Flex) need a shape_config; fixed shapes (E2.1.Micro) must not.
  dynamic "shape_config" {
    for_each = endswith(var.instance_shape, ".Flex") ? [1] : []
    content {
      ocpus         = var.ocpus
      memory_in_gbs = var.memory_in_gbs
    }
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.subnet.id
    assign_public_ip = true
    hostname_label   = var.instance_name
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.cloud_init
  }

  # The instance is configured entirely via cloud-init; ignore drift on
  # metadata so re-applies don't try to rebuild a healthy VM.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}
