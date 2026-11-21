variable "hostname" {
  description = "API hostname to publish. Null publishes nothing. This is a DNS name, not an IP."
  type        = string
  default     = null

  validation {
    condition = var.hostname == null || (
      length(var.hostname) > 0 &&
      !strcontains(var.hostname, "/") &&
      !can(cidrhost("${var.hostname}/32", 0))
    )
    error_message = "hostname must be a DNS name, or null to publish nothing."
  }
}

variable "address" {
  description = "Reserved API address. Required when hostname is set. Not a prefix."
  type        = string
  default     = null

  validation {
    condition = var.address == null || (
      can(cidrhost("${var.address}/32", 0)) && !strcontains(var.address, "/")
    )
    error_message = "address must be an IPv4 address with no prefix length."
  }
}
