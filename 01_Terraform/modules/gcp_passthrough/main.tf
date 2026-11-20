resource "terraform_data" "ports" {
  lifecycle {
    precondition {
      condition = (
        (var.all_ports && length(var.ports) == 0) ||
        (!var.all_ports && length(var.ports) > 0 && length(var.ports) <= 5)
      )
      error_message = "Set either all_ports or one to five ports. GCP rejects a forwarding rule that sets both."
    }
  }
}

# EXTERNAL, not EXTERNAL_MANAGED. This is the classic passthrough network load
# balancer: it keeps the original destination address, which is what the guest
# and MetalLB expect. ARP from the VM cannot publish a Google public address.
resource "google_compute_instance_group" "this" {
  name      = "${var.name}-ig"
  zone      = var.zone
  network   = var.network
  instances = var.instances
}

resource "google_compute_region_health_check" "this" {
  name   = "${var.name}-hc"
  region = var.region

  tcp_health_check {
    port = var.health_check_port
  }
}

resource "google_compute_region_backend_service" "this" {
  name                  = var.name
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_region_health_check.this.id]

  backend {
    group          = google_compute_instance_group.this.self_link
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "this" {
  name                  = var.name
  region                = var.region
  load_balancing_scheme = "EXTERNAL"
  backend_service       = google_compute_region_backend_service.this.id
  ip_address            = var.address
  ip_protocol           = "TCP"
  network_tier          = "PREMIUM"
  all_ports             = var.all_ports ? true : null
  ports                 = var.all_ports ? null : var.ports
}
