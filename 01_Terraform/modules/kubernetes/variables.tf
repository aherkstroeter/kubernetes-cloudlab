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
}

variable "agent_type" {
  description = "Machine type for worker nodes."
  type        = string
  default     = "e2-medium"
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
  description = "Optional installer that runs on the primary after k3s is up. Pass manifest URLs, Helm releases, a shell script, or any combination. Helm runs first, then manifests in list order, then the script. Use this to install Argo CD and an app that syncs your repo. Terraform does not manage objects inside the cluster after that. The script runs with set -euo pipefail, and the whole bootstrap runs again on every boot, so it must be idempotent."
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
