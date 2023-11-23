# output "emqttb_nodes" {
#   description = "public ip of emqttb instances"
#   value       = module.emqttb.*.public_ips
# }

# output "emqtt_bench_public_ips" {
#   description = "public ip of emqtt_bench instances"
#   value       = module.emqtt_bench.*.public_ips
# }

output "emqx_dashboard_credentials" {
  description = "EMQX Dashboard Credentials"
  value       = "admin:${local.emqx_dashboard_default_password}"
}

output "grafana_credentials" {
  description = "Grafana Credentials"
  value       = "admin:admin"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "${module.public_nlb.dns_name}:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "${module.public_nlb.dns_name}:3000"
}

output "emqx_nodes" {
  value = local.emqx_nodes[*].hostname
}

output "emqx_dashboard_url" {
  description = "EMQX Dashboard URL"
  value       = "${module.public_nlb.dns_name}:18083"
}

output "emqx_ami_filter" {
  value       = local.emqx_ami_filter
}
