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
  bootstrap             = var.bootstrap
}
