variable "manifest_urls" {
  description = "HTTPS URLs applied with kubectl, in order, after Helm releases."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for url in var.manifest_urls : startswith(url, "https://")])
    error_message = "manifest_urls must be https URLs."
  }
}

variable "helm_releases" {
  description = "Helm releases installed before manifests. helm upgrade --install runs on every boot, so a release that already matches these values does not change. version empty or null tracks the chart's latest. values_yaml is written to a root-only file on the node."
  type = list(object({
    name        = string
    repository  = string
    chart       = string
    version     = optional(string)
    namespace   = optional(string, "default")
    values_yaml = optional(string, "")
  }))
  default = []

  validation {
    condition = alltrue([
      for release in var.helm_releases : (
        can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", release.name)) &&
        length(release.name) <= 53 &&
        can(regex("^[A-Za-z0-9_.-]+$", release.chart)) &&
        startswith(release.repository, "https://") &&
        can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", release.namespace)) &&
        (release.version == null || release.version == "" || can(regex("^[A-Za-z0-9.+_-]+$", release.version))) &&
        !strcontains(release.values_yaml, "BOOTSTRAP_VALUES_")
      )
    ])
    error_message = "Each Helm release needs an https repository, a valid release name, chart, and namespace, and values without the BOOTSTRAP_VALUES_ delimiter."
  }
}

variable "script" {
  description = "Shell appended after manifests. It runs with set -euo pipefail and KUBECONFIG already set. Startup scripts run on every boot, so this must be idempotent."
  type        = string
  default     = ""
}
