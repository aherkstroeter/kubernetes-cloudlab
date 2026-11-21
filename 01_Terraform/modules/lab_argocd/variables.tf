variable "install" {
  description = "Helm-install Argo CD from the production values in the cluster repo and apply the root app."
  type        = bool
  default     = false
}

variable "repo_url" {
  description = "Public git URL cloned on the primary. The values file in this repo is what Helm installs."
  type        = string
  default     = "https://github.com/aherkstroeter/kubernetes-cloudlab.git"
}

variable "repo_ref" {
  description = "Git ref Helm installs. Argo CD tracks this same ref."
  type        = string
  default     = "master"
}

variable "chart_repository" {
  description = "Helm repository for the Argo CD chart. Keep this aligned with 02_ArgoCD/02_platform/argocd/argo_app.yaml."
  type        = string
  default     = "https://argoproj.github.io/argo-helm"
}

variable "chart_name" {
  type    = string
  default = "argo-cd"
}

variable "chart_version" {
  description = "Chart version. Keep this aligned with the Argo CD app targetRevision."
  type        = string
  default     = "10.18.2"
}

variable "release_name" {
  type    = string
  default = "argocd"
}

variable "namespace" {
  type    = string
  default = "argocd"
}

variable "values_path" {
  description = "Path inside the repo of the values file Argo CD itself syncs."
  type        = string
  default     = "02_ArgoCD/02_platform/argocd/values.yaml"
}

variable "root_app_path" {
  type    = string
  default = "02_ArgoCD/bootstrap/root-app.yaml"
}

variable "cert_manager_version" {
  description = "cert-manager chart version whose CRDs are applied before Argo CD. The Certificate in the production values needs them. Keep this aligned with the cert-manager app."
  type        = string
  default     = "v1.21.3"
}
