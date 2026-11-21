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

variable "secret_ids" {
  description = "Secret Manager secret ids the node account may read. Empty grants nothing. The containers are created outside this module, and no secret version is stored here."
  type        = set(string)
  default     = []
}
