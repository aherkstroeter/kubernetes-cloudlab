# The zone itself stays outside this project. Recreating it would drop DNSSEC
# and publish new nameservers. external-dns writes the records inside it.
# Pods reach Cloud DNS through the GCE metadata server. k3s is not GKE, so this
# is not Workload Identity. The account is dedicated to the nodes and has only
# these DNS roles. The VMs use the cloud-platform access scope; IAM here is the
# authorization boundary. Attaching the account stops a VM, so that step is not
# part of an untargeted apply.

locals {
  enabled   = var.dns_domain != null
  zone_name = local.enabled ? replace(var.dns_domain, ".", "-") : null
}

data "google_dns_managed_zone" "lab" {
  count = local.enabled ? 1 : 0

  name = local.zone_name
}

resource "google_service_account" "nodes" {
  count = local.enabled ? 1 : 0

  account_id   = "${var.cluster_name}-nodes"
  display_name = "${var.cluster_name} nodes"
  description  = "Node identity for Cloud DNS and Secret Manager from pods. No project-wide roles."

  lifecycle {
    precondition {
      condition     = length("${var.cluster_name}-nodes") <= 30
      error_message = "cluster_name plus -nodes must be at most 30 characters (the service account id limit)."
    }
  }
}

resource "google_project_iam_member" "node_dns_reader" {
  count = local.enabled ? 1 : 0

  project = var.project_id
  role    = "roles/dns.reader"
  member  = "serviceAccount:${google_service_account.nodes[0].email}"
}

resource "google_dns_managed_zone_iam_member" "node_dns_admin" {
  count = local.enabled ? 1 : 0

  project      = var.project_id
  managed_zone = data.google_dns_managed_zone.lab[0].name
  role         = "roles/dns.admin"
  member       = "serviceAccount:${google_service_account.nodes[0].email}"
}
