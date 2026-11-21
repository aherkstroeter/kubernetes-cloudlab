output "zone_name" {
  description = "Cloud DNS zone name. Null when dns_domain is null."
  value       = one(data.google_dns_managed_zone.lab[*].name)
}

output "dns_name" {
  description = "Cloud DNS zone dns name, including the trailing dot. Null when dns_domain is null."
  value       = one(data.google_dns_managed_zone.lab[*].dns_name)
}

output "name_servers" {
  description = "Nameservers of the existing zone. Null when dns_domain is null."
  value       = one(data.google_dns_managed_zone.lab[*].name_servers)
}

output "service_account_email" {
  description = "Node service account email. Null when dns_domain is null."
  value       = one(google_service_account.nodes[*].email)
}
