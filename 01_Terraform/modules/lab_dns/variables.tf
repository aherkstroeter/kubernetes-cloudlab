variable "project_id" {
  description = "GCP project that holds the Cloud DNS zone."
  type        = string
}

variable "cluster_name" {
  description = "Prefix for the node service account id."
  type        = string
}

variable "dns_domain" {
  description = "Existing public Cloud DNS zone, such as example.com. Null skips DNS IAM. This module does not create the zone."
  type        = string
  default     = null
}
