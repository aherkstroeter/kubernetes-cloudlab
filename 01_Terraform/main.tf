resource "terraform_data" "lab_inputs" {
  lifecycle {
    precondition {
      condition     = var.dns_domain == null || endswith(var.api_domain, ".${var.dns_domain}")
      error_message = "dns_domain is the zone, such as example.com. api_domain must be a name inside it."
    }

    precondition {
      condition     = var.kubeconfig_path == null || var.kubeconfig_context != null
      error_message = "kubeconfig_context is required when kubeconfig_path is set."
    }
  }
}

module "lab_dns" {
  source = "./modules/lab_dns"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  dns_domain   = var.dns_domain
  # Containers are created with gcloud and survive a cluster destroy.
  # Create each secret before the first apply that grants this binding.
  secret_ids = [
    "argocd-oidc-google",
    "argocd-github-webhook",
  ]

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

module "metallb_pool" {
  source = "./modules/metallb_pool"

  # values() is lexicographic by key. The module sorts the /32s.
  # The API address is not in this map.
  addresses = values(module.cluster.service_addresses)
}

# kubernetes_manifest reads the CRD schema during plan. depends_on and the
# wait block cannot see a CRD that Argo CD installs after this plan was built,
# so the pool is absent until kubeconfig_path is set and both CRDs are present.
locals {
  # One switch for every object that needs the API. Unset it only on the apply
  # that creates the cluster. Unsetting it later plans a destroy of these objects.
  manage_cluster_objects = var.kubeconfig_path != null
  metallb_crds_ready = (
    length(try(one(data.kubernetes_resources.ipaddresspools[*].objects), [])) == 1 &&
    length(try(one(data.kubernetes_resources.l2advertisements[*].objects), [])) == 1
  )
  pool_manifests = local.manage_cluster_objects && local.metallb_crds_ready && module.metallb_pool.ip_address_pool != null ? {
    public = module.metallb_pool.ip_address_pool
  } : {}
  advertisement_manifests = local.manage_cluster_objects && local.metallb_crds_ready && module.metallb_pool.l2_advertisement != null ? {
    public = module.metallb_pool.l2_advertisement
  } : {}
}

data "kubernetes_resources" "ipaddresspools" {
  count = local.manage_cluster_objects ? 1 : 0

  api_version    = "apiextensions.k8s.io/v1"
  kind           = "CustomResourceDefinition"
  field_selector = "metadata.name=ipaddresspools.metallb.io"
}

data "kubernetes_resources" "l2advertisements" {
  count = local.manage_cluster_objects ? 1 : 0

  api_version    = "apiextensions.k8s.io/v1"
  kind           = "CustomResourceDefinition"
  field_selector = "metadata.name=l2advertisements.metallb.io"
}

resource "terraform_data" "metallb_pool_ready" {
  count = local.manage_cluster_objects ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.metallb_crds_ready
      error_message = "MetalLB CRDs are not on the API yet. Re-run terraform apply when ipaddresspools.metallb.io and l2advertisements.metallb.io exist. This plan cannot wait for them."
    }
  }
}

resource "kubernetes_manifest" "ip_address_pool" {
  for_each = local.pool_manifests

  manifest        = each.value
  computed_fields = ["status"]

  depends_on = [terraform_data.metallb_pool_ready]
}

resource "kubernetes_manifest" "l2_advertisement" {
  for_each = local.advertisement_manifests

  manifest        = each.value
  computed_fields = ["status"]

  depends_on = [terraform_data.metallb_pool_ready]
}

check "metallb_pool" {
  assert {
    condition     = local.manage_cluster_objects
    error_message = "The MetalLB pool is skipped. Set kubeconfig_path after the MetalLB CRDs exist and apply again."
  }
}

module "api_endpoint" {
  source = "./modules/dns_endpoint"

  hostname = module.cluster.api_domain
  address  = module.cluster.api_address
}

# external-dns installs this CRD after the plan that creates the cluster.
# Destroying the endpoint while that controller is still up removes the API
# A record, because its policy is sync.
locals {
  dnsendpoint_ready = (
    length(try(one(data.kubernetes_resources.dnsendpoints[*].objects), [])) == 1
  )
  api_manifests = local.manage_cluster_objects && local.dnsendpoint_ready && module.api_endpoint.manifest != null ? {
    api = module.api_endpoint.manifest
  } : {}
}

data "kubernetes_resources" "dnsendpoints" {
  count = local.manage_cluster_objects ? 1 : 0

  api_version    = "apiextensions.k8s.io/v1"
  kind           = "CustomResourceDefinition"
  field_selector = "metadata.name=dnsendpoints.externaldns.k8s.io"
}

resource "terraform_data" "api_endpoint_ready" {
  count = local.manage_cluster_objects ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.dnsendpoint_ready
      error_message = "The DNSEndpoint CRD is not on the API yet. Re-run terraform apply when dnsendpoints.externaldns.k8s.io exists. This plan cannot wait for it."
    }
  }
}

resource "kubernetes_manifest" "api_endpoint" {
  for_each = local.api_manifests

  manifest        = each.value
  computed_fields = ["status"]

  depends_on = [terraform_data.api_endpoint_ready]
}

check "api_endpoint" {
  assert {
    condition     = local.manage_cluster_objects
    error_message = "The API DNSEndpoint is skipped. Set kubeconfig_path after external-dns has installed its CRD and apply again."
  }
}
