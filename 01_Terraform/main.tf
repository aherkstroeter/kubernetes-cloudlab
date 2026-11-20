resource "terraform_data" "lab_inputs" {
  lifecycle {
    precondition {
      condition     = !(var.install_argocd && var.bootstrap != null)
      error_message = "install_argocd builds the Argo CD bootstrap. Leave bootstrap null when it is true."
    }

    precondition {
      condition = (
        var.dns_domain == null && length(var.service_hostnames) == 0
        ) || (
        var.dns_domain != null &&
        endswith(var.api_domain, ".${var.dns_domain}") &&
        alltrue([
          for name, host in var.service_hostnames :
          contains(var.service_addresses, name) && endswith(host, ".${var.dns_domain}")
        ])
      )
      error_message = "dns_domain is the zone, such as example.com. api_domain and every service hostname must be inside it, and each service_hostnames key must be a service address name."
    }
  }
}

resource "tls_private_key" "argocd_repo" {
  count = var.install_argocd ? 1 : 0

  algorithm = "ED25519"
}

locals {
  argocd_values = <<-EOT
    dex:
      enabled: false
    notifications:
      enabled: false
    configs:
      cm:
        resourceExclusionsAdditional:
          - apiGroups:
              - metallb.io
            kinds:
              - IPAddressPool
              - L2Advertisement
            clusters:
              - "*"
  EOT

  bootstrap = var.install_argocd ? {
    manifest_urls = []
    helm_releases = [{
      name        = "argocd"
      repository  = "https://argoproj.github.io/argo-helm"
      chart       = "argo-cd"
      version     = "10.18.2"
      namespace   = "argocd"
      values_yaml = local.argocd_values
    }]
    script = templatefile("${path.module}/templates/argocd-bootstrap.sh.tftpl", {
      private_key = tls_private_key.argocd_repo[0].private_key_openssh
      root_app    = file("${path.module}/../02_ArgoCD/bootstrap/root-app.yaml")
    })
  } : var.bootstrap
}

module "cluster" {
  source = "./modules/kubernetes"

  project_id            = var.project_id
  region                = var.region
  zone                  = var.zone
  cluster_name          = var.cluster_name
  cluster_token         = var.cluster_token
  server_count          = var.server_count
  agent_count           = var.agent_count
  server_type           = var.server_type
  agent_type            = var.agent_type
  disk_size_gb          = var.disk_size_gb
  disk_type             = var.disk_type
  api_domain            = var.api_domain
  api_source_ranges     = var.api_source_ranges
  service_source_ranges = var.service_source_ranges
  service_addresses     = var.service_addresses
  extra_server_args     = var.extra_server_args
  subnet_cidr           = var.subnet_cidr
  assign_public_ip      = var.assign_public_ip
  enable_nat            = var.enable_nat
  k3s_channel           = var.k3s_channel
  ssh_source_ranges     = var.ssh_source_ranges
  bootstrap             = local.bootstrap

  depends_on = [terraform_data.lab_inputs]
}
