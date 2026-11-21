variable "enabled" {
  description = "Allow the current GitHub hook IPv4 ranges to reach TCP 443."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Prefix for the firewall rule and the target tag."
  type        = string
}

variable "network_name" {
  description = "VPC network name."
  type        = string
}
