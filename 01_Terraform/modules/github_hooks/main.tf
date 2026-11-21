# Push delivery for Argo CD. GitHub calls https://<argocd host>/api/webhook
# from the hooks ranges at https://api.github.com/meta. Those ranges change, so
# they are read on apply. Only IPv4 is used because the lab publishes A records.
# The rule is TCP 443 only. It does not open the API, port 80, or node ports,
# and it does not replace the client rule.

data "http" "github_meta" {
  count = var.enabled ? 1 : 0

  url = "https://api.github.com/meta"

  request_headers = {
    Accept     = "application/vnd.github+json"
    User-Agent = "homelab-terraform"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "GitHub meta API returned HTTP ${self.status_code}."
    }
  }
}

locals {
  github_hook_ipv4 = var.enabled ? [
    for cidr in jsondecode(data.http.github_meta[0].response_body).hooks : cidr
    if can(regex("^[0-9.]+/[0-9]+$", cidr))
  ] : []
}

resource "google_compute_firewall" "hooks" {
  count = var.enabled ? 1 : 0

  name          = "${var.cluster_name}-github-hooks"
  network       = var.network_name
  direction     = "INGRESS"
  source_ranges = local.github_hook_ipv4
  target_tags   = [var.cluster_name]
  description   = "GitHub hook CIDRs to Argo CD on TCP 443."

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  lifecycle {
    precondition {
      condition     = length(local.github_hook_ipv4) > 0
      error_message = "GitHub meta returned no IPv4 hook ranges."
    }
  }
}
