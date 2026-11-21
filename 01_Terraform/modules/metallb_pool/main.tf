# Manifests only. The caller applies them to a cluster that already has the
# MetalLB CRDs. This module does not talk to an API and does not create the
# metallb-system namespace; the chart owns that.

locals {
  cidrs = sort([for address in var.addresses : "${address}/32"])

  ip_address_pool = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "IPAddressPool"
    metadata = {
      name      = "public"
      namespace = "metallb-system"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      autoAssign = true
      addresses  = local.cidrs
    }
  }

  l2_advertisement = {
    apiVersion = "metallb.io/v1beta1"
    kind       = "L2Advertisement"
    metadata = {
      name      = "public"
      namespace = "metallb-system"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      ipAddressPools = tolist(["public"])
    }
  }
}
