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

output "network_name" {
  value = module.cluster.network_name
}

output "kubeconfig_command" {
  value = module.cluster.kubeconfig_command
}
