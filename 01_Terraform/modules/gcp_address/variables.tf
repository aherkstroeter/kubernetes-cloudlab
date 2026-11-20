variable "region" {
  description = "Region for the reserved addresses. Passthrough forwarding rules must use this same region."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must look like us-central1."
  }
}

variable "addresses" {
  description = "Regional external addresses to reserve, keyed by a logical name. The value is the GCP resource name."
  type        = map(string)

  validation {
    condition = (
      length(var.addresses) > 0 &&
      length(distinct(values(var.addresses))) == length(var.addresses) &&
      alltrue([
        for name in values(var.addresses) : can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", name))
      ])
    )
    error_message = "Each address needs a unique GCP name of 1-63 characters: lowercase letters, digits, and hyphens, starting with a letter and not ending with a hyphen."
  }
}
