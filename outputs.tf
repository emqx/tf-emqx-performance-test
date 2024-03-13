output "bench_id" {
  description = "Benchmark ID"
  value       = local.bench_id
}

output "emqx_dashboard_url" {
  description = "EMQX Dashboard URL"
  value       = "${module.public_nlb.dns_name}:18083"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = local.monitoring_enabled ? "${module.public_nlb.dns_name}:3000" : null
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = local.monitoring_enabled ? "${module.public_nlb.dns_name}:9090" : null
}

output "locust_url" {
  description = "Locust URL"
  value       = length(module.locust) > 0 ? "${module.public_nlb.dns_name}:8080" : null
}

output "emqx_dashboard_credentials" {
  description = "EMQX Dashboard credentials"
  value       = "admin:${local.emqx_dashboard_default_password}"
}

output "grafana_credentials" {
  description = "Grafana credentials"
  value       = local.monitoring_enabled ? "admin:admin" : null
}

output "emqx_nodes" {
  description = "EMQX nodes"
  value       = [for node in module.emqx : {ip: node.public_ips[0], fqdn: node.fqdn}]
}

output "emqttb_nodes" {
  description = "emqttb nodes"
  value       = [for node in module.emqttb : {ip: node.public_ips[0], fqdn: node.fqdn}]
}

output "emqtt_bench_nodes" {
  description = "emqtt-bench nodes"
  value       = [for node in module.emqtt-bench : {ip: node.public_ips[0], fqdn: node.fqdn}]
}

output "http_nodes" {
  description = "http nodes"
  value       = [for node in module.http : {ip: node.public_ips[0], fqdn: node.fqdn}]
}

output "ssh_key_path" {
  description = "SSH key path"
  value       = local.ssh_key_path
}
