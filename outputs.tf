output "emqx_dashboard_url" {
  description = "EMQX Dashboard URL"
  value       = "${module.public_nlb.dns_name}:18083"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "${module.public_nlb.dns_name}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "${module.public_nlb.dns_name}:9090"
}

output "emqx_dashboard_credentials" {
  description = "EMQX Dashboard credentials"
  value       = "admin:${local.emqx_dashboard_default_password}"
}

output "grafana_credentials" {
  description = "Grafana credentials"
  value       = "admin:admin"
}

output "emqx_nodes" {
  description = "EMQX nodes"
  value       = concat(
    [for node in module.emqx-default: "${node.public_ip} ${node.fqdn}"],
    [for node in module.emqx-region2: "${node.public_ip} ${node.fqdn}"],
    [for node in module.emqx-region3: "${node.public_ip} ${node.fqdn}"]
  )
}

output "emqttb_nodes" {
  description = "emqttb nodes"
  value       = concat(
    [for node in module.emqttb-default: "${node.public_ip} ${node.fqdn}"]
  )
}

output "emqtt_bench_nodes" {
  description = "emqtt-bench nodes"
  value       = concat(
    [for node in module.emqtt-bench-default: "${node.public_ip} ${node.fqdn}"]
  )
}
