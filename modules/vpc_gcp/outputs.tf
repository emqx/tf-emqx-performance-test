output "network" {
  value = google_compute_network.vpc.self_link
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "subnetwork" {
  value = google_compute_subnetwork.public.self_link
}

output "network_tag" {
  value = var.network_tag
}

output "region" {
  value = var.region
}
