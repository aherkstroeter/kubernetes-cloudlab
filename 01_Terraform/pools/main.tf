# Apply only after the API and the MetalLB CRDs exist. Cluster create does not
# run this stack. Cluster destroy does not need it: the objects die with the
# disks. Plan fails until the CRDs exist, because kubernetes_manifest reads them.
# The chart owns the metallb-system namespace. Do not create it here.
# Destroying this stack while the API is up deletes the pool.

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

data "terraform_remote_state" "cluster" {
  backend = "local"

  config = {
    path = abspath("${path.module}/../terraform.tfstate")
  }
}

module "pool" {
  source = "../modules/metallb_pool"

  # values() is lexicographic by key. The module sorts the /32s.
  addresses = values(data.terraform_remote_state.cluster.outputs.service_addresses)
}

resource "kubernetes_manifest" "ip_address_pool" {
  for_each = module.pool.ip_address_pool == null ? {} : { public = module.pool.ip_address_pool }

  manifest        = each.value
  computed_fields = ["status"]
}

resource "kubernetes_manifest" "l2_advertisement" {
  for_each = module.pool.l2_advertisement == null ? {} : { public = module.pool.l2_advertisement }

  manifest        = each.value
  computed_fields = ["status"]
}
