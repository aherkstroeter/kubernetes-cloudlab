variable "enabled" {
  description = "Create the API and service A records. Turn this off only after external-dns is publishing those names."
  type        = bool
  default     = false
}

variable "zone_name" {
  description = "Existing Cloud DNS zone name. Unused when enabled is false."
  type        = string
  default     = null
}

variable "api_domain" {
  description = "Hostname of the API A record."
  type        = string
}

variable "api_address" {
  description = "Address of the API A record."
  type        = string
  default     = null
}

variable "service_hostnames" {
  description = "Service address name to hostname."
  type        = map(string)
  default     = {}
}

variable "service_addresses" {
  description = "Service address name to floating IP."
  type        = map(string)
  default     = {}
}
