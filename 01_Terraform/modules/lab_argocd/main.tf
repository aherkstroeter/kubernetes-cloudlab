resource "tls_private_key" "repo" {
  count = var.install ? 1 : 0

  algorithm = "ED25519"
}

locals {
  script = var.install ? templatefile("${path.module}/templates/install.sh.tftpl", {
    repo_url             = var.repo_url
    repo_ref             = var.repo_ref
    chart_repository     = var.chart_repository
    chart_name           = var.chart_name
    chart_version        = var.chart_version
    release_name         = var.release_name
    namespace            = var.namespace
    values_path          = var.values_path
    root_app_path        = var.root_app_path
    cert_manager_version = var.cert_manager_version
  }) : ""
}
