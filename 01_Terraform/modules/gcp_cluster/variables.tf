variable "name" {
  description = "Prefix for the network, subnet, and NAT resources. Also used as the cluster label."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.name))
    error_message = "name must be 1-40 characters: lowercase letters, digits, and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "region" {
  description = "Region for the subnet and Cloud NAT."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "region must look like us-central1."
  }
}

variable "zone" {
  description = "Zone for every node. Internal DNS names include this zone."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "zone must look like us-central1-a."
  }
}

variable "subnet_cidr" {
  description = "IPv4 range for the subnet. Node-to-node firewall rules use this range."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid IPv4 CIDR."
  }
}

variable "image_family" {
  description = "Image family for node boot disks."
  type        = string
  default     = "debian-13"
}

variable "image_project" {
  description = "Project that hosts image_family."
  type        = string
  default     = "debian-cloud"
}

variable "service_account_email" {
  description = "Service account attached to every VM, with the cloud-platform access scope. Null attaches no account. IAM on the account is the authorization boundary. Changing this stops each VM; do not apply it to every node at once."
  type        = string
  default     = null
}

variable "enable_nat" {
  description = "Create a Cloud NAT gateway for outbound traffic. Private nodes need this to reach the internet. The gateway is billed per hour while it exists. This module does not attach public IPs to nodes unless a node sets assign_public_ip."
  type        = bool
  default     = false
}

variable "nodes" {
  description = "VMs to create, keyed by instance name. startup_script is opaque: this module does not know what it installs."
  type = map(object({
    machine_type     = string
    startup_script   = optional(string, "")
    disk_size_gb     = optional(number, 50)
    disk_type        = optional(string, "pd-standard")
    tags             = optional(list(string), [])
    labels           = optional(map(string), {})
    assign_public_ip = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = alltrue([for node in var.nodes : node.disk_size_gb >= 10 && node.disk_size_gb == floor(node.disk_size_gb)])
    error_message = "Each node disk must be a whole number of gigabytes, at least 10."
  }

  validation {
    condition = alltrue([
      for node in var.nodes : contains(["pd-standard", "pd-balanced", "pd-ssd"], node.disk_type)
    ])
    error_message = "disk_type must be pd-standard, pd-balanced, or pd-ssd."
  }

  validation {
    condition = alltrue([
      for node in var.nodes : (
        !can(regex("^(a2|a3|a4|g2|g4)-", node.machine_type)) &&
        !strcontains(lower(node.machine_type), "gpu") &&
        !strcontains(lower(node.machine_type), "nvidia")
      )
    ])
    error_message = "machine_type must not be a GPU type. Families a2, a3, a4, g2, and g4, and names containing gpu or nvidia, are rejected."
  }
}

variable "firewall_rules" {
  description = "Ingress rules on this module's network. target_tags limits each rule to matching nodes."
  type = list(object({
    name          = string
    protocol      = string
    ports         = optional(list(string), [])
    source_ranges = list(string)
    target_tags   = list(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.firewall_rules : length(rule.target_tags) > 0 && length(rule.source_ranges) > 0
    ])
    error_message = "Each firewall rule needs source_ranges and target_tags."
  }
}
