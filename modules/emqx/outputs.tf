output "private_ips" {
  description = "Private IPs of emqx instances"
  value       = module.emqx_ec2.private_ip
}

output "public_ips" {
  description = "Public IPs of emqx instances"
  value       = module.emqx_ec2.public_ip
}

output "internal_fqdn" {
  description = "Internal fqdn of emqx instances"
  value       = module.emqx_ec2.internal_fqdn
}

output "instance_ids" {
  value = module.emqx_ec2.instance_id
}
