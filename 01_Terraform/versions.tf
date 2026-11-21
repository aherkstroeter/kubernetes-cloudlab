terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.11.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.5.0"
    }
  }
}
