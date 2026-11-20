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

  bootstrap_manifest_urls = try(var.bootstrap.manifest_urls, [])
  bootstrap_helm_releases = try(var.bootstrap.helm_releases, [])
  bootstrap_script        = try(var.bootstrap.script, "")

  firewall_rules = [
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
  ]
}

check "node_egress" {
  assert {
    condition     = var.enable_nat || var.assign_public_ip
    error_message = "Enable Cloud NAT or assign a public IP so nodes can download k3s."
  }
}

module "k3s" {
  source = "../k3s"

  cluster_token   = var.cluster_token
  channel         = var.k3s_channel
  server_urls     = local.server_urls
  tls_sans        = [local.zonal_host, local.global_host]
  node_ip_command = local.node_ip_command
}

module "bootstrap" {
  source = "../bootstrap"

  manifest_urls = local.bootstrap_manifest_urls
  helm_releases = local.bootstrap_helm_releases
  script        = local.bootstrap_script
}

locals {
  primary_startup = join("\n", compact([
    module.k3s.primary_server_script,
    module.bootstrap.script,
  ]))

  nodes = merge(
    {
      for idx, name in local.server_names : name => {
        machine_type     = var.server_type
        startup_script   = idx == 0 ? local.primary_startup : module.k3s.server_script
        disk_size_gb     = var.disk_size_gb
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
        tags             = [local.network_tag]
        labels           = { role = "agent" }
        assign_public_ip = var.assign_public_ip
      }
    },
  )
}

module "vms" {
  source = "../gcp_cluster"

  name           = var.cluster_name
  region         = var.region
  zone           = var.zone
  subnet_cidr    = var.subnet_cidr
  enable_nat     = var.enable_nat
  nodes          = local.nodes
  firewall_rules = local.firewall_rules
}
