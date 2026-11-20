variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "cluster_name" {
  type = string
}

variable "cluster_token" {
  type      = string
  sensitive = true
}

variable "server_count" {
  type    = number
  default = 1
}

variable "agent_count" {
  type    = number
  default = 0
}

variable "server_type" {
  type    = string
  default = "e2-medium"
}

variable "agent_type" {
  type    = string
  default = "e2-medium"
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "disk_type" {
  type    = string
  default = "pd-standard"
}

variable "api_domain" {
  type = string
}

variable "api_source_ranges" {
  type    = list(string)
  default = []
}

variable "service_source_ranges" {
  type    = list(string)
  default = null
}

variable "service_addresses" {
  type    = list(string)
  default = ["lb-0"]
}

variable "extra_server_args" {
  type    = list(string)
  default = ["--disable=servicelb", "--disable=traefik"]
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "enable_nat" {
  type    = bool
  default = true
}

variable "k3s_channel" {
  type    = string
  default = "stable"
}

variable "ssh_source_ranges" {
  type    = list(string)
  default = ["35.235.240.0/20"]
}

variable "install_argocd" {
  type        = bool
  default     = false
  description = "Install Argo CD with Helm and apply the root app. Leave bootstrap null when this is true."
}

variable "dns_domain" {
  type        = string
  default     = null
  description = "Public Cloud DNS zone, such as example.com. Null skips DNS. api_domain and service_hostnames must be names inside it."
}

variable "service_hostnames" {
  type        = map(string)
  default     = {}
  description = "Service address name to hostname. Each name gets an A record at that floating address."
}

variable "bootstrap" {
  type = object({
    manifest_urls = optional(list(string), [])
    helm_releases = optional(list(object({
      name        = string
      repository  = string
      chart       = string
      version     = optional(string)
      namespace   = optional(string, "default")
      values_yaml = optional(string, "")
    })), [])
    script = optional(string, "")
  })
  default = null
}
