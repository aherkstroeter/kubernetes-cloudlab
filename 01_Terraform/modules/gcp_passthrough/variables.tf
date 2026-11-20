variable "name" {
  description = "Name of the health check, backend service, and forwarding rule. At most 60 characters so the health-check suffix still fits in GCP's 63-character limit."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,58}[a-z0-9])?$", var.name))
    error_message = "name must be 1-60 characters: lowercase letters, digits, and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "region" {
  description = "Region for the health check, backend service, and forwarding rule. Must match the reserved address."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must look like us-central1."
  }
}

variable "backend_group" {
  description = "Self link of the unmanaged instance group that receives traffic. Every passthrough rule in a cluster must share one group: GCP rejects a VM that is in two load-balanced instance groups. Backend services that share a group must use the same balancing mode."
  type        = string
}

variable "address" {
  description = "Self link of the reserved regional external address this rule publishes."
  type        = string
}

variable "health_check_port" {
  description = "TCP port probed on each backend's internal address. This is not the floating address."
  type        = number
  default     = 6443

  validation {
    condition     = var.health_check_port == floor(var.health_check_port) && var.health_check_port >= 1 && var.health_check_port <= 65535
    error_message = "health_check_port must be a whole number from 1 to 65535."
  }
}

variable "ports" {
  description = "TCP ports published by the forwarding rule. Leave empty when all_ports is true."
  type        = list(string)
  default     = []
}

variable "all_ports" {
  description = "Publish every TCP port. Used for service addresses. Mutually exclusive with ports."
  type        = bool
  default     = false
}
