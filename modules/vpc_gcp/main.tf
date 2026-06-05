terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

# Create the network + subnetwork, or look up an existing one when the caller
# passes network_name/subnetwork_name (create_network = false). Either way the
# module exposes the same outputs, so compute/DNS downstream is unchanged.
resource "google_compute_network" "vpc" {
  count                   = var.create_network ? 1 : 0
  name                    = var.prefix
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  count         = var.create_network ? 1 : 0
  name          = var.prefix
  ip_cidr_range = var.cidr
  region        = var.region
  network       = google_compute_network.vpc[0].id
}

data "google_compute_network" "existing" {
  count = var.create_network ? 0 : 1
  name  = var.network_name
}

data "google_compute_subnetwork" "existing" {
  count  = var.create_network ? 0 : 1
  name   = var.subnetwork_name
  region = var.region
}

locals {
  network    = var.create_network ? google_compute_network.vpc[0].self_link : data.google_compute_network.existing[0].self_link
  subnetwork = var.create_network ? google_compute_subnetwork.public[0].self_link : data.google_compute_subnetwork.existing[0].self_link
  # Source range for the internal allow rule = the actual subnet CIDR.
  subnet_cidr = var.create_network ? var.cidr : data.google_compute_subnetwork.existing[0].ip_cidr_range
}

# Allow all traffic between instances within the subnet (clustering, DNS, metrics).
# Target-tagged so it only affects this run's instances even on a shared network.
resource "google_compute_firewall" "internal" {
  count         = var.create_firewall ? 1 : 0
  name          = "${var.prefix}-internal"
  network       = local.network
  direction     = "INGRESS"
  source_ranges = [local.subnet_cidr]
  target_tags   = [var.network_tag]

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
}

# Allow external access to SSH and the EMQX / dashboard / monitoring ports.
resource "google_compute_firewall" "external" {
  count         = var.create_firewall ? 1 : 0
  name          = "${var.prefix}-external"
  network       = local.network
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.network_tag]

  allow {
    protocol = "tcp"
    ports = [
      "22",    # ssh
      "1883",  # mqtt
      "8883",  # mqtts
      "8083",  # ws / dashboard ws
      "8084",  # wss
      "18083", # dashboard / http api (v5)
      "18084", # dashboard https
      "8081",  # http api (v4)
      "3000",  # grafana
      "9090",  # prometheus
      "8080",  # locust
    ]
  }
}
