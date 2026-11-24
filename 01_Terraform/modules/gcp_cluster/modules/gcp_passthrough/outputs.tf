output "ip_address" {
  description = "Public address published by the forwarding rule."
  value       = google_compute_forwarding_rule.this.ip_address
}

output "forwarding_rule" {
  description = "Self link of the regional forwarding rule."
  value       = google_compute_forwarding_rule.this.self_link
}

output "backend_service" {
  description = "Self link of the regional backend service."
  value       = google_compute_region_backend_service.this.self_link
}
