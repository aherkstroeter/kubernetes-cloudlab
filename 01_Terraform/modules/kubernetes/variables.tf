variable "project_id" {
  description = "GCP project id. Join scripts use it to build the primary node's internal DNS name."
  type        = string
}

variable "region" {
  description = "Region for the subnet and Cloud NAT."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for every node."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Prefix for node names, the network, and firewall rules."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.cluster_name))
    error_message = "cluster_name must be 1-40 characters: lowercase letters, digits, and hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "cluster_token" {
  description = "Shared k3s join secret."
  type        = string
  sensitive   = true
}

variable "server_count" {
  description = "Control-plane nodes. Must be odd so embedded etcd can elect a leader."
  type        = number
  default     = 1

  validation {
    condition     = var.server_count == floor(var.server_count) && var.server_count >= 1 && var.server_count % 2 == 1
    error_message = "server_count must be a positive odd whole number, for example 1 or 3."
  }
}

variable "agent_count" {
  description = "Worker nodes."
  type        = number
  default     = 0

  validation {
    condition     = var.agent_count == floor(var.agent_count) && var.agent_count >= 0
    error_message = "agent_count must be a whole number of zero or more."
  }
}

variable "server_type" {
  description = "Machine type for control-plane nodes."
  type        = string
  default     = "e2-medium"

  validation {
    condition = (
      !can(regex("^(a2|a3|a4|g2|g4)-", var.server_type)) &&
      !strcontains(lower(var.server_type), "gpu") &&
      !strcontains(lower(var.server_type), "nvidia")
    )
    error_message = "server_type must not be a GPU machine type."
  }
}

variable "agent_type" {
  description = "Machine type for worker nodes."
  type        = string
  default     = "e2-medium"

  validation {
    condition = (
      !can(regex("^(a2|a3|a4|g2|g4)-", var.agent_type)) &&
      !strcontains(lower(var.agent_type), "gpu") &&
      !strcontains(lower(var.agent_type), "nvidia")
    )
    error_message = "agent_type must not be a GPU machine type."
  }
}

variable "disk_size_gb" {
  description = "Boot disk size for every node, in GB. Disks are billed while the nodes exist."
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb == floor(var.disk_size_gb) && var.disk_size_gb >= 10
    error_message = "disk_size_gb must be a whole number of at least 10."
  }
}

variable "disk_type" {
  description = "Boot disk type for every node. pd-standard is the cheap default."
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.disk_type)
    error_message = "disk_type must be pd-standard, pd-balanced, or pd-ssd."
  }
}

variable "api_domain" {
  description = "Public hostname clients use for the Kubernetes API. Added to the server certificate. Not an IP address."
  type        = string

  validation {
    condition = (
      can(regex("^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+[A-Za-z]{2,}$", var.api_domain)) &&
      !can(cidrhost("${var.api_domain}/32", 0)) &&
      !strcontains(var.api_domain, "LAB_ADDRESSES_END")
    )
    error_message = "api_domain must be a hostname such as api.example.com, not an IP address."
  }
}

variable "api_source_ranges" {
  description = "CIDRs allowed to reach the API address on TCP 6443. Empty means no client rule is created. There is no default of 0.0.0.0/0."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.api_source_ranges : can(cidrhost(cidr, 0))])
    error_message = "api_source_ranges must be a list of CIDRs."
  }
}

variable "service_source_ranges" {
  description = "CIDRs allowed to reach service addresses on TCP 80, 443, and 30000-32767. Null uses api_source_ranges. Empty means no client rule is created."
  type        = list(string)
  default     = null

  validation {
    condition     = var.service_source_ranges == null || alltrue([for cidr in var.service_source_ranges : can(cidrhost(cidr, 0))])
    error_message = "service_source_ranges must be null or a list of CIDRs."
  }
}

variable "service_addresses" {
  description = "Names of regional external addresses for Services of type LoadBalancer. Each becomes a passthrough rule. The MetalLB /32 pool is a separate apply against a running cluster. The API address is separate."
  type        = list(string)
  default     = ["lb-0"]

  validation {
    condition = (
      length(distinct(var.service_addresses)) == length(var.service_addresses) &&
      alltrue([
        for name in var.service_addresses : (
          name != "api" &&
          can(regex("^[a-z]([-a-z0-9]{0,16}[a-z0-9])?$", name))
        )
      ])
    )
    error_message = "Each service address name must be unique, must not be api, and must be 1-18 lowercase letters, digits, or hyphens."
  }
}

variable "extra_server_args" {
  description = "Extra arguments for every k3s server. Replacing this list drops the default ServiceLB and Traefik disables."
  type        = list(string)
  default     = ["--disable=servicelb", "--disable=traefik"]
}

variable "subnet_cidr" {
  description = "IPv4 range for cluster nodes. Internal k3s ports are limited to this range."
  type        = string
  default     = "10.10.0.0/16"
}

variable "assign_public_ip" {
  description = "Attach an ephemeral public IP to every node. Leave this false. Outbound traffic goes through Cloud NAT, and a later floating IP should be the only public address."
  type        = bool
  default     = false
}

variable "service_account_email" {
  description = "Service account attached to every node. Null attaches no account. Passed through to the VM module."
  type        = string
  default     = null
}

variable "enable_nat" {
  description = "Cloud NAT for outbound traffic such as the k3s download. Billed per hour while the cluster exists. Required when nodes have no public IP."
  type        = bool
  default     = true
}

variable "k3s_channel" {
  description = "k3s release channel."
  type        = string
  default     = "stable"
}

variable "ssh_source_ranges" {
  description = "Sources allowed to SSH to nodes. The default is IAP's proxy range, which works without a public IP on the node."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "bootstrap" {
  description = "Optional installer that runs on the primary after k3s is up. Pass manifest URLs, Helm releases, a shell script, or any combination. Helm upgrade --install runs first, then manifests in list order, then the script. A release that already matches its values does not change. Terraform does not manage objects inside the cluster after that. The script runs with set -euo pipefail, and the whole bootstrap runs again on every boot, so it must be idempotent."
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

  validation {
    condition = (
      var.bootstrap == null ||
      length(try(var.bootstrap.manifest_urls, [])) > 0 ||
      length(try(var.bootstrap.helm_releases, [])) > 0 ||
      length(trimspace(try(var.bootstrap.script, ""))) > 0
    )
    error_message = "Set bootstrap to null, or provide a manifest URL, a Helm release, or a script."
  }
}
