mock_provider "google" {
  mock_data "google_compute_image" {
    defaults = {
      self_link = "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-13"
      name      = "debian-13"
    }
  }

  mock_resource "google_compute_address" {
    defaults = {
      address   = "203.0.113.10"
      self_link = "https://www.googleapis.com/compute/v1/projects/p/regions/us-central1/addresses/addr"
      id        = "addr"
      name      = "addr"
    }
  }

  mock_resource "google_compute_network" {
    defaults = {
      name      = "homelab-network"
      id        = "projects/p/global/networks/homelab-network"
      self_link = "https://www.googleapis.com/compute/v1/projects/p/global/networks/homelab-network"
    }
  }

  mock_resource "google_compute_subnetwork" {
    defaults = {
      name          = "homelab-subnet"
      id            = "projects/p/regions/us-central1/subnetworks/homelab-subnet"
      self_link     = "https://www.googleapis.com/compute/v1/projects/p/regions/us-central1/subnetworks/homelab-subnet"
      ip_cidr_range = "10.10.0.0/16"
    }
  }

  mock_resource "google_compute_instance" {
    defaults = {
      self_link = "https://www.googleapis.com/compute/v1/projects/p/zones/us-central1-a/instances/node"
      zone      = "us-central1-a"
      # Nested blocks cannot be set as a list here: Terraform treats that
      # value as a tuple and then rejects it. The configured block stays, and
      # computed fields such as network_ip are generated.
    }
  }
}

variables {
  project_id        = "project-test"
  cluster_name      = "homelab"
  cluster_token     = "test-token-value"
  api_domain        = "api.lab.example"
  server_count      = 1
  agent_count       = 0
  api_source_ranges = ["203.0.113.0/24"]
  service_addresses = ["lb-0"]
}

run "scripts" {
  command = apply

  assert {
    condition     = output.api_address == "203.0.113.10" && output.service_addresses["lb-0"] == "203.0.113.10"
    error_message = "API and service outputs must come from the reserved addresses."
  }

  assert {
    condition = (
      strcontains(output.primary_startup_script, "TLS_SANS+=('api.lab.example')") &&
      strcontains(output.primary_startup_script, "homelab-server-0.us-central1-a.c.project-test.internal") &&
      !strcontains(output.primary_startup_script, "TLS_SANS+=('203.0.113.10')")
    )
    error_message = "The API certificate must list the domain and internal DNS name, not the floating address."
  }

  assert {
    condition = (
      strcontains(output.primary_startup_script, "--disable=servicelb") &&
      strcontains(output.primary_startup_script, "--disable=traefik") &&
      strcontains(output.primary_startup_script, "ip addr replace '203.0.113.10/32' dev lo") &&
      strcontains(output.primary_startup_script, "name: lab-addresses") &&
      !strcontains(output.primary_startup_script, "kind: IPAddressPool") &&
      !strcontains(output.primary_startup_script, "kind: L2Advertisement")
    )
    error_message = "The primary startup script must disable the bundled load balancers and publish lab-addresses. It must not apply the MetalLB pool."
  }
}

run "rejects_gpu" {
  command = plan

  variables {
    server_type = "g2-standard-4"
  }

  expect_failures = [
    var.server_type,
  ]
}

run "rejects_ip_domain" {
  command = plan

  variables {
    api_domain = "203.0.113.10"
  }

  expect_failures = [
    var.api_domain,
  ]
}
