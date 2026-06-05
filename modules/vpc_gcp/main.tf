terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

resource "google_compute_network" "vpc" {
  name                    = var.prefix
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = var.prefix
  ip_cidr_range = var.cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Allow all traffic between instances within the subnet (clustering, DNS, metrics).
resource "google_compute_firewall" "internal" {
  name          = "${var.prefix}-internal"
  network       = google_compute_network.vpc.id
  direction     = "INGRESS"
  source_ranges = [var.cidr]
  target_tags   = [var.network_tag]

  allow { protocol = "tcp" }
  allow { protocol = "udp" }
  allow { protocol = "icmp" }
}

# Allow external access to SSH and the EMQX / dashboard / monitoring ports.
resource "google_compute_firewall" "external" {
  name          = "${var.prefix}-external"
  network       = google_compute_network.vpc.id
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
