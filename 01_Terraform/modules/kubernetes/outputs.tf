output "server_internal_ips" {
  description = "Internal IPs of control-plane nodes, in name order."
  value       = nonsensitive([for name in local.server_names : module.vms.instances[name].internal_ip])
}

output "agent_internal_ips" {
  description = "Internal IPs of worker nodes, in name order."
  value       = nonsensitive([for name in local.agent_names : module.vms.instances[name].internal_ip])
}

output "server_public_ips" {
  description = "Ephemeral public IPs of control-plane nodes. Null when assign_public_ip is false."
  value       = nonsensitive([for name in local.server_names : module.vms.instances[name].external_ip])
}

output "agent_public_ips" {
  description = "Ephemeral public IPs of worker nodes. Null when assign_public_ip is false."
  value       = nonsensitive([for name in local.agent_names : module.vms.instances[name].external_ip])
}

output "primary_internal_ip" {
  description = "Internal IP of the first control-plane node."
  value       = nonsensitive(module.vms.instances[local.primary_name].internal_ip)
}

output "primary_api_urls" {
  description = "Internal API addresses joiners try, in order. These are DNS names, not floating IPs."
  value       = local.server_urls
}

output "network_name" {
  description = "VPC network name."
  value       = module.vms.network_name
}

output "subnet_name" {
  description = "Subnet name."
  value       = module.vms.subnet_name
}

output "subnet_cidr" {
  description = "Subnet IPv4 CIDR."
  value       = module.vms.subnet_cidr
}

output "kubeconfig_command" {
  description = "Prints the admin kubeconfig from the primary over IAP. The server address in that file is the node's loopback until a floating API address exists. The caller also needs roles/iap.tunnelResourceAccessor."
  value       = "gcloud compute ssh ${local.primary_name} --project ${var.project_id} --zone ${var.zone} --tunnel-through-iap --command 'sudo cat /etc/rancher/k3s/k3s.yaml'"
}
