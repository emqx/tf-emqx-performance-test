output "private_ips" {
  description = "Private IPs of emqttb instance"
  value       = module.emqttb_ec2.private_ip
}

output "public_ips" {
  description = "Public IPs of emqttb instances"
  value       = module.emqttb_ec2.public_ip
}

output "internal_fqdn" {
  description = "Internal fqdn of emqttb instances"
  value       = module.emqttb_ec2.internal_fqdn
}

output "instance_ids" {
  value = module.emqttb_ec2.instance_id
}
