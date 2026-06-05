output "public_ips" {
  value = google_compute_instance.instance.network_interface[0].access_config[*].nat_ip
}

output "private_ips" {
  value = [google_compute_instance.instance.network_interface[0].network_ip]
}

output "instance_ids" {
  value = [google_compute_instance.instance.instance_id]
}

output "fqdn" {
  value = trimsuffix(google_dns_record_set.dns.name, ".")
}

output "region" {
  value = var.region
}

output "attach_to_nlb" {
  value = var.attach_to_nlb
}

output "type" {
  value = var.type
}

output "remote_user" {
  value = var.remote_user
}
