resource "terraform_data" "zone_in_region" {
  lifecycle {
    precondition {
      condition     = startswith(var.zone, "${var.region}-")
      error_message = "zone ${var.zone} must belong to region ${var.region}."
    }
  }
}

data "google_compute_image" "boot" {
  family  = var.image_family
  project = var.image_project
}

resource "google_compute_network" "this" {
  name                    = "${var.name}-network"
  auto_create_subnetworks = false
  description             = "Network for ${var.name}."
}

resource "google_compute_subnetwork" "this" {
  name                     = "${var.name}-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.this.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "rule" {
  for_each = { for rule in var.firewall_rules : rule.name => rule }

  name          = each.value.name
  network       = google_compute_network.this.name
  direction     = "INGRESS"
  source_ranges = each.value.source_ranges
  target_tags   = each.value.target_tags

  dynamic "allow" {
    for_each = length(each.value.ports) > 0 ? [each.value] : []
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "allow" {
    for_each = length(each.value.ports) == 0 ? [each.value] : []
    content {
      protocol = allow.value.protocol
    }
  }
}

resource "google_compute_router" "nat" {
  count = var.enable_nat ? 1 : 0

  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "nat" {
  count = var.enable_nat ? 1 : 0

  name                               = "${var.name}-nat"
  router                             = google_compute_router.nat[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.this.self_link
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_instance" "node" {
  for_each = var.nodes

  name         = each.key
  machine_type = each.value.machine_type
  zone         = var.zone
  tags         = each.value.tags

  labels = merge(
    { cluster = var.name },
    each.value.labels,
  )

  boot_disk {
    initialize_params {
      image = data.google_compute_image.boot.self_link
      size  = each.value.disk_size_gb
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.this.id

    dynamic "access_config" {
      for_each = each.value.assign_public_ip ? [1] : []
      content {}
    }
  }

  metadata_startup_script = each.value.startup_script

  lifecycle {
    # The image family resolves to the newest build. Ignore it after create so
    # a later plan does not replace the fleet just because Debian published an image.
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }

  depends_on = [
    google_compute_firewall.rule,
    google_compute_router_nat.nat,
  ]
}
