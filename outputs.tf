output "emqx_public_ips" {
  description = "public ip of emqx instances"
  value       = module.emqx.public_ips
}

output "emqtt_bench_public_ips" {
  description = "public ip of emqtt_bench instances"
  value       = module.emqtt_bench.public_ips
}

output "emqx_elb_dns_name" {
  description = "elb dns name"
  value       = module.emqx_lb.elb_dns_name
}
