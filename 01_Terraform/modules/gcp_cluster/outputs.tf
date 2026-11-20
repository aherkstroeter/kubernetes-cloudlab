output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.this.name
}

output "network_id" {
  description = "VPC network id."
  value       = google_compute_network.this.id
}

output "subnet_name" {
  description = "Subnet name."
  value       = google_compute_subnetwork.this.name
}

output "subnet_id" {
  description = "Subnet id."
  value       = google_compute_subnetwork.this.id
}

output "subnet_cidr" {
  description = "Subnet IPv4 CIDR."
  value       = google_compute_subnetwork.this.ip_cidr_range
}

output "nat_enabled" {
  description = "Whether a Cloud NAT gateway was created for outbound traffic."
  value       = var.enable_nat
}

output "instances" {
  description = "Per-node addresses keyed by instance name. external_ip is null when the node has no public IP. The whole map is sensitive when a startup script contains a sensitive value; callers can wrap the IPs in nonsensitive."
  value = {
    for name, vm in google_compute_instance.node : name => {
      internal_ip = vm.network_interface[0].network_ip
      external_ip = try(vm.network_interface[0].access_config[0].nat_ip, null)
      zone        = vm.zone
    }
  }
}
