resource "google_dns_managed_zone" "lab" {
  count = var.dns_domain == null ? 0 : 1

  name          = replace(var.dns_domain, ".", "-")
  dns_name      = "${var.dns_domain}."
  description   = "Names for ${var.cluster_name}"
  visibility    = "public"
  force_destroy = true

  depends_on = [terraform_data.lab_inputs]
}

resource "google_dns_record_set" "api" {
  count = var.dns_domain == null ? 0 : 1

  managed_zone = google_dns_managed_zone.lab[0].name
  name         = "${var.api_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [module.cluster.api_address]
}

resource "google_dns_record_set" "service" {
  for_each = var.dns_domain == null ? {} : var.service_hostnames

  managed_zone = google_dns_managed_zone.lab[0].name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [module.cluster.service_addresses[each.key]]
}
