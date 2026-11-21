provider "google" {
  project = var.project_id
  region  = var.region
}

# Unused while kubeconfig_path is null, so a new cluster can be planned before
# the API exists. A null path must not fall through to ~/.kube/config.
provider "kubernetes" {
  config_path    = coalesce(var.kubeconfig_path, "${path.module}/.kubeconfig-unset")
  config_context = var.kubeconfig_context
}
