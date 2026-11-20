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
