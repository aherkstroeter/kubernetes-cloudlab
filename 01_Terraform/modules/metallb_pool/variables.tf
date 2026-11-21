variable "addresses" {
  description = "Reserved service addresses. Each is published as a /32. The API address does not belong in this pool."
  type        = list(string)

  validation {
    condition = (
      length(distinct(var.addresses)) == length(var.addresses) &&
      alltrue([
        for address in var.addresses :
        can(cidrhost("${address}/32", 0)) && !strcontains(address, "/")
      ])
    )
    error_message = "Each address must be a unique IPv4 address with no prefix length."
  }
}
