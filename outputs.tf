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

output "locust_url" {
  description = "Locust URL"
  value       = "${module.public_nlb.dns_name}:8080"
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
  value       = [for node in module.emqx : format("%-16s %s", node.public_ips[0], node.fqdn)]
}

output "emqttb_nodes" {
  description = "emqttb nodes"
  value       = [for node in module.emqttb : format("%-16s %s", node.public_ips[0], node.fqdn)]
}

output "emqtt_bench_nodes" {
  description = "emqtt-bench nodes"
  value       = [for node in module.emqtt-bench : format("%-16s %s", node.public_ips[0], node.fqdn)]
}

output "http_nodes" {
  description = "http nodes"
  value       = [for node in module.http : format("%-16s %s", node.public_ips[0], node.fqdn)]
}
