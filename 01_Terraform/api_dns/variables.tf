variable "kubeconfig_path" {
  description = "Kubeconfig for the running cluster. The provider reads this path or KUBE_CONFIG_PATH. It does not read KUBECONFIG, and it must not fall through to ~/.kube/config."
  type        = string
  nullable    = false
}

variable "kubeconfig_context" {
  description = "Context in kubeconfig_path. Null uses that file's current context."
  type        = string
  default     = null
}
