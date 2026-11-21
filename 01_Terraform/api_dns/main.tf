# Apply only after the API is up and the DNSEndpoint CRD exists. Cluster create
# does not run this stack. The address comes from the cluster state, because
# Git does not know it. external-dns copies the endpoint into Cloud DNS.
# Destroying this stack while external-dns is up and its policy is sync deletes
# the API A record. Cluster destroy does not need this stack first: the
# endpoint dies with the disks, and the controller stops with them.

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

module "endpoint" {
  source = "../modules/dns_endpoint"

  hostname = data.terraform_remote_state.cluster.outputs.api_domain
  address  = data.terraform_remote_state.cluster.outputs.api_address
}

resource "kubernetes_manifest" "api" {
  for_each = module.endpoint.manifest == null ? {} : { api = module.endpoint.manifest }

  manifest        = each.value
  computed_fields = ["status"]
}
