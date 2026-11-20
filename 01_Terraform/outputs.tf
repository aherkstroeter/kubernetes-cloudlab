output "server_internal_ips" {
  value = module.cluster.server_internal_ips
}

output "agent_internal_ips" {
  value = module.cluster.agent_internal_ips
}

output "server_public_ips" {
  value = module.cluster.server_public_ips
}

output "agent_public_ips" {
  value = module.cluster.agent_public_ips
}

output "primary_internal_ip" {
  value = module.cluster.primary_internal_ip
}

output "primary_api_urls" {
  value = module.cluster.primary_api_urls
}

output "api_address" {
  value = module.cluster.api_address
}

output "api_domain" {
  value = module.cluster.api_domain
}

output "service_addresses" {
  value = module.cluster.service_addresses
}

output "network_name" {
  value = module.cluster.network_name
}

output "kubeconfig_command" {
  value = module.cluster.kubeconfig_command
}

output "dns_name_servers" {
  description = "Nameservers to set at the registrar when dns_domain is set."
  value       = var.dns_domain == null ? [] : google_dns_managed_zone.lab[0].name_servers
}

output "argocd_deploy_key" {
  description = "Generated deploy key. The lab repo is public, so bootstrap clones over HTTPS and does not install this key."
  value       = var.install_argocd ? tls_private_key.argocd_repo[0].public_key_openssh : null
}
