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

# Pods reach Cloud DNS through the GCE metadata server. k3s is not GKE, so this
# is not Workload Identity. The account is dedicated to the nodes and has only
# these DNS roles. The VMs use the cloud-platform access scope; IAM here is the
# authorization boundary. Attaching the account stops a VM, so that step is not
# part of an untargeted apply.
resource "google_service_account" "nodes" {
  count = var.dns_domain == null ? 0 : 1

  account_id   = "${var.cluster_name}-nodes"
  display_name = "${var.cluster_name} nodes"
  description  = "Node identity for Cloud DNS from pods. No other project roles."

  lifecycle {
    precondition {
      condition     = length("${var.cluster_name}-nodes") <= 30
      error_message = "cluster_name plus -nodes must be at most 30 characters (the service account id limit)."
    }
  }
}

resource "google_project_iam_member" "node_dns_reader" {
  count = var.dns_domain == null ? 0 : 1

  project = var.project_id
  role    = "roles/dns.reader"
  member  = "serviceAccount:${google_service_account.nodes[0].email}"
}

resource "google_dns_managed_zone_iam_member" "node_dns_admin" {
  count = var.dns_domain == null ? 0 : 1

  project      = var.project_id
  managed_zone = google_dns_managed_zone.lab[0].name
  role         = "roles/dns.admin"
  member       = "serviceAccount:${google_service_account.nodes[0].email}"
}

resource "google_dns_record_set" "service" {
  for_each = var.dns_domain == null ? {} : var.service_hostnames

  managed_zone = google_dns_managed_zone.lab[0].name
  name         = "${each.value}."
  type         = "A"
  ttl          = 300
  rrdatas      = [module.cluster.service_addresses[each.key]]
}
