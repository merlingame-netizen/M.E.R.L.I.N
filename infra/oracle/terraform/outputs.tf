output "instance_id" {
  description = "OCID of the created instance."
  value       = oci_core_instance.vm.id
}

output "public_ip" {
  description = "Public IP of the VM."
  value       = oci_core_instance.vm.public_ip
}

output "availability_domain" {
  description = "AD the instance landed in."
  value       = local.availability_domain
}

output "image_id" {
  description = "Image OCID used for the boot volume."
  value       = local.image_id
}

output "ssh_user" {
  description = "Default OS login user."
  value       = var.os_username
}

output "ssh_command" {
  description = "Ready-to-use SSH command."
  value       = "ssh ${var.os_username}@${oci_core_instance.vm.public_ip}"
}

output "ollama_tunnel_command" {
  description = "Forward the remote Ollama API to localhost:11434."
  value       = "ssh -N -L 11434:localhost:11434 ${var.os_username}@${oci_core_instance.vm.public_ip}"
}
