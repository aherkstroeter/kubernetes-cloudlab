# These records are the bridge until external-dns owns api and echo.
# Delete them only after that controller is ready to publish the same names.
# state rm of the zone must not be repeated here: removing these resources
# deletes the A records.

resource "google_dns_record_set" "api" {
  count = var.enabled ? 1 : 0

  managed_zone = var.zone_name
  name         = "${var.api_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.api_address]
}

resource "google_dns_record_set" "service" {
  for_each = var.enabled ? var.service_hostnames : {}

  managed_zone = var.zone_name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.service_addresses[each.key]]
}
