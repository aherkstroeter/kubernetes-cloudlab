variable "cluster_token" {
  description = "Shared secret k3s uses to join nodes. Injected into the script, so it lands in VM metadata and Terraform state."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cluster_token) > 0 && !strcontains(var.cluster_token, "K3S_MODULE_TOKEN_END")
    error_message = "cluster_token must not be empty or contain K3S_MODULE_TOKEN_END."
  }
}

variable "channel" {
  description = "k3s release channel passed to the installer, for example stable or latest."
  type        = string
  default     = "stable"

  validation {
    condition     = can(regex("^[A-Za-z0-9._+-]+$", var.channel))
    error_message = "channel must contain only letters, digits, dots, underscores, plus signs, and hyphens."
  }
}

variable "server_urls" {
  description = "HTTPS API addresses joiners try, in order. The script uses the first host that resolves. The first entry is used while DNS is still empty. Leave this empty when you only render the primary script."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for url in var.server_urls : startswith(url, "https://")])
    error_message = "server_urls must be https URLs, for example https://10.0.0.2:6443."
  }
}

variable "tls_sans" {
  description = "Extra hostnames or IPs to add to the server certificate with --tls-san."
  type        = list(string)
  default     = []
}

variable "tls_san_command" {
  description = "Optional shell command that prints extra certificate SANs, one per line. A failure is ignored so a missing public address does not block install."
  type        = string
  default     = ""

  validation {
    condition     = !strcontains(var.tls_san_command, "K3S_MODULE_TLS_SAN_END")
    error_message = "tls_san_command cannot contain K3S_MODULE_TLS_SAN_END."
  }
}

variable "node_ip_command" {
  description = "Optional shell command that prints the IP k3s should advertise with --node-ip. When empty, k3s chooses an address."
  type        = string
  default     = ""

  validation {
    condition     = !strcontains(var.node_ip_command, "K3S_MODULE_NODE_IP_END")
    error_message = "node_ip_command cannot contain K3S_MODULE_NODE_IP_END."
  }
}

variable "extra_server_args" {
  description = "Extra arguments appended to the k3s server command."
  type        = list(string)
  default     = []
}

variable "extra_agent_args" {
  description = "Extra arguments appended to the k3s agent command."
  type        = list(string)
  default     = []
}

variable "primary_retries" {
  description = "How many times the primary install is attempted. Covers a slow first boot, not a down API."
  type        = number
  default     = 12

  validation {
    condition     = var.primary_retries == floor(var.primary_retries) && var.primary_retries >= 1 && var.primary_retries <= 120
    error_message = "primary_retries must be a whole number from 1 to 120."
  }
}

variable "join_retries" {
  description = "How many times a joining node waits for the primary API. Each attempt waits 10 seconds."
  type        = number
  default     = 60

  validation {
    condition     = var.join_retries == floor(var.join_retries) && var.join_retries >= 1 && var.join_retries <= 360
    error_message = "join_retries must be a whole number from 1 to 360."
  }
}
