resource "google_compute_address" "this" {
  for_each = var.addresses

  name         = each.value
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  description  = "Floating address ${each.key} for a regional passthrough load balancer."
}
