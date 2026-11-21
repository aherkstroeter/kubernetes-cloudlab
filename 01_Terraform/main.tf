resource "terraform_data" "lab_inputs" {
  lifecycle {
    precondition {
      condition     = var.dns_domain == null || endswith(var.api_domain, ".${var.dns_domain}")
      error_message = "dns_domain is the zone, such as example.com. api_domain must be a name inside it."
    }
  }
}

module "lab_dns" {
  source = "./modules/lab_dns"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  dns_domain   = var.dns_domain

  depends_on = [terraform_data.lab_inputs]
}

module "lab_argocd" {
  source = "./modules/lab_argocd"

  install = var.install_argocd
}

locals {
  user_bootstrap   = var.bootstrap
  argocd_bootstrap = module.lab_argocd.bootstrap

  # install_argocd and an extra bootstrap both run. Argo CD is installed from
  # the production values, then the extra manifests and script.
  bootstrap = (
    local.argocd_bootstrap == null && local.user_bootstrap == null ? null : {
      manifest_urls = concat(
        try(local.argocd_bootstrap.manifest_urls, []),
        try(local.user_bootstrap.manifest_urls, []),
      )
      helm_releases = concat(
        try(local.argocd_bootstrap.helm_releases, []),
        try(local.user_bootstrap.helm_releases, []),
      )
      script = join("\n", compact([
        trimspace(try(local.argocd_bootstrap.script, "")),
        trimspace(try(local.user_bootstrap.script, "")),
      ]))
    }
  )
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
  service_account_email = module.lab_dns.service_account_email
  k3s_channel           = var.k3s_channel
  ssh_source_ranges     = var.ssh_source_ranges
  bootstrap             = local.bootstrap

  depends_on = [terraform_data.lab_inputs]
}

module "github_hooks" {
  source = "./modules/github_hooks"

  enabled      = var.allow_github_webhooks
  cluster_name = var.cluster_name
  network_name = module.cluster.network_name
}
