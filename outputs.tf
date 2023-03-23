output "public_ips" {
  description = "public ip of emqx instances"
  value       = module.emqx.public_ips
}

output "elb_dns_name" {
  description = "elb dns name"
  value       = module.emqx_lb.elb_dns_name
}
