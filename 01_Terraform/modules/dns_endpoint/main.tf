# Manifest only. The caller applies it to a cluster that already has the
# DNSEndpoint CRD. Git does not know the reserved address, so this object does
# not live in the Argo CD repo. external-dns publishes it. kube-system exists
# before that namespace does.

resource "terraform_data" "inputs" {
  lifecycle {
    precondition {
      condition     = var.hostname == null || var.address != null
      error_message = "address is required when hostname is set."
    }
  }
}

locals {
  manifest = var.hostname == null ? null : {
    apiVersion = "externaldns.k8s.io/v1alpha1"
    kind       = "DNSEndpoint"
    metadata = {
      name      = "api"
      namespace = "kube-system"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      endpoints = tolist([
        {
          dnsName    = var.hostname
          recordTTL  = 300
          recordType = "A"
          targets    = tolist([var.address])
        },
      ])
    }
  }
}
