# Join addresses are internal DNS names, so the scripts do not depend on VM
# addresses and nodes do not need a public IP of their own.
locals {
  network_tag  = var.cluster_name
  primary_name = "${var.cluster_name}-server-0"
  zonal_host   = "${local.primary_name}.${var.zone}.c.${var.project_id}.internal"
  global_host  = "${local.primary_name}.c.${var.project_id}.internal"
  server_urls = [
    "https://${local.zonal_host}:6443",
    "https://${local.global_host}:6443",
  ]

  server_names = [for idx in range(var.server_count) : "${var.cluster_name}-server-${idx}"]
  agent_names  = [for idx in range(var.agent_count) : "${var.cluster_name}-agent-${idx}"]

  node_ip_command = "curl -sf --max-time 5 -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip"

  address_names = merge(
    { api = "${var.cluster_name}-api" },
    { for name in var.service_addresses : name => "${var.cluster_name}-${name}" },
  )

  service_source_ranges = var.service_source_ranges == null ? var.api_source_ranges : var.service_source_ranges

  bootstrap_manifest_urls = try(var.bootstrap.manifest_urls, [])
  bootstrap_helm_releases = try(var.bootstrap.helm_releases, [])
  bootstrap_user_script   = try(var.bootstrap.script, "")

  base_firewall_rules = [
    {
      name          = "${var.cluster_name}-iap-ssh"
      protocol      = "tcp"
      ports         = ["22"]
      source_ranges = var.ssh_source_ranges
      target_tags   = [local.network_tag]
    },
    {
      name          = "${var.cluster_name}-internal-tcp"
      protocol      = "tcp"
      ports         = ["6443", "2379", "2380", "10250", "30000-32767"]
      source_ranges = [var.subnet_cidr]
      target_tags   = [local.network_tag]
    },
    {
      name          = "${var.cluster_name}-internal-udp"
      protocol      = "udp"
      ports         = ["8472", "30000-32767"]
      source_ranges = [var.subnet_cidr]
      target_tags   = [local.network_tag]
    },
    {
      name          = "${var.cluster_name}-internal-icmp"
      protocol      = "icmp"
      ports         = []
      source_ranges = [var.subnet_cidr]
      target_tags   = [local.network_tag]
    },
    {
      name          = "${var.cluster_name}-health"
      protocol      = "tcp"
      ports         = ["6443"]
      source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
      target_tags   = [local.network_tag]
    },
  ]

  api_firewall_rules = length(var.api_source_ranges) == 0 ? [] : [
    {
      name          = "${var.cluster_name}-api"
      protocol      = "tcp"
      ports         = ["6443"]
      source_ranges = var.api_source_ranges
      target_tags   = [local.network_tag]
    },
  ]

  service_firewall_rules = length(local.service_source_ranges) == 0 ? [] : [
    {
      name          = "${var.cluster_name}-svc"
      protocol      = "tcp"
      ports         = ["80", "443", "30000-32767"]
      source_ranges = local.service_source_ranges
      target_tags   = [local.network_tag]
    },
  ]

  firewall_rules = concat(
    local.base_firewall_rules,
    local.api_firewall_rules,
    local.service_firewall_rules,
  )
}

check "node_egress" {
  assert {
    condition     = var.enable_nat || var.assign_public_ip
    error_message = "Enable Cloud NAT or assign a public IP so nodes can download k3s."
  }
}

module "addresses" {
  source = "../gcp_address"

  region    = var.region
  addresses = local.address_names
}

module "k3s" {
  source = "../k3s"

  cluster_token     = var.cluster_token
  channel           = var.k3s_channel
  server_urls       = local.server_urls
  tls_sans          = [var.api_domain, local.zonal_host, local.global_host]
  extra_server_args = var.extra_server_args
  node_ip_command   = local.node_ip_command
}

module "bootstrap" {
  source = "../bootstrap"

  manifest_urls = local.bootstrap_manifest_urls
  helm_releases = local.bootstrap_helm_releases
  # The ConfigMap has to exist before kube-vip starts. The pool has to wait until
  # the MetalLB chart has installed its CRDs, so it stays after the user script.
  script = join("\n", compact([
    trimspace(templatefile("${path.module}/templates/configmap.sh.tftpl", {
      api_address = module.addresses.addresses["api"].address
      api_domain  = var.api_domain
    })),
    trimspace(local.bootstrap_user_script),
    trimspace(templatefile("${path.module}/templates/addresses.sh.tftpl", {
      service_addresses = [for name in var.service_addresses : module.addresses.addresses[name].address]
    })),
  ]))
}

locals {
  api_loopback = templatefile("${path.module}/templates/loopback.sh.tftpl", {
    api_address = module.addresses.addresses["api"].address
  })

  # Shebang has to be line 1. The rendered k3s script repeats it, which is then only a comment.
  startup_header = "#!/bin/bash\nset +x\nset -euo pipefail"

  primary_startup = join("\n", [
    local.startup_header,
    local.api_loopback,
    module.k3s.primary_server_script,
    module.bootstrap.script,
  ])

  server_startup = join("\n", [
    local.startup_header,
    local.api_loopback,
    module.k3s.server_script,
  ])

  nodes = merge(
    {
      for idx, name in local.server_names : name => {
        machine_type     = var.server_type
        startup_script   = idx == 0 ? local.primary_startup : local.server_startup
        disk_size_gb     = var.disk_size_gb
        disk_type        = var.disk_type
        tags             = [local.network_tag]
        labels           = { role = "server" }
        assign_public_ip = var.assign_public_ip
      }
    },
    {
      for name in local.agent_names : name => {
        machine_type     = var.agent_type
        startup_script   = module.k3s.agent_script
        disk_size_gb     = var.disk_size_gb
        disk_type        = var.disk_type
        tags             = [local.network_tag]
        labels           = { role = "agent" }
        assign_public_ip = var.assign_public_ip
      }
    },
  )
}

module "vms" {
  source = "../gcp_cluster"

  name                  = var.cluster_name
  region                = var.region
  zone                  = var.zone
  subnet_cidr           = var.subnet_cidr
  enable_nat            = var.enable_nat
  service_account_email = var.service_account_email
  nodes                 = local.nodes
  firewall_rules        = local.firewall_rules
}

# One group for every forwarding rule. GCP allows a VM to be in only one
# load-balanced instance group, so the API rule and the service rules cannot
# each bring their own group. Agents fail the TCP 6443 health check and receive
# no load-balanced traffic until that check moves to a port they serve.
resource "google_compute_instance_group" "nodes" {
  name    = "${var.cluster_name}-nodes"
  zone    = var.zone
  network = module.vms.network_self_link
  instances = nonsensitive([
    for name in concat(local.server_names, local.agent_names) :
    module.vms.instances[name].self_link
  ])
}

module "api_lb" {
  source = "../gcp_passthrough"

  name              = "${var.cluster_name}-api"
  region            = var.region
  backend_group     = google_compute_instance_group.nodes.self_link
  address           = module.addresses.addresses["api"].self_link
  health_check_port = 6443
  ports             = ["6443"]
}

module "service_lb" {
  source   = "../gcp_passthrough"
  for_each = toset(var.service_addresses)

  name              = "${var.cluster_name}-${each.key}"
  region            = var.region
  backend_group     = google_compute_instance_group.nodes.self_link
  address           = module.addresses.addresses[each.key].self_link
  health_check_port = 6443
  all_ports         = true
}
