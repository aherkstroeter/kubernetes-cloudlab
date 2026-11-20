output "primary_server_script" {
  description = "Startup script for the first server. It runs k3s with --cluster-init."
  value       = local.primary_server_script
  sensitive   = true
}

output "server_script" {
  description = "Startup script for extra control-plane nodes. They join server_urls."
  value       = local.server_script
  sensitive   = true
}

output "agent_script" {
  description = "Startup script for worker nodes. They join server_urls."
  value       = local.agent_script
  sensitive   = true
}
