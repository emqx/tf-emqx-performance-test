output "bench_id" {
  description = "Benchmark ID"
  value       = local.bench_id
}

output "spec_file" {
  description = "Benchmark spec file"
  value       = var.spec_file
}

output "emqx_dashboard_url" {
  description = "EMQX Dashboard URL"
  value       = "http://${module.public_nlb.dns_name}:18083"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = local.monitoring_enabled ? "http://${module.public_nlb.dns_name}:3000" : null
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = local.monitoring_enabled ? "http://${module.public_nlb.dns_name}:9090" : null
}

output "locust_url" {
  description = "Locust URL"
  value       = length([for node in module.loadgen : node if node.type == "locust"]) > 0 ? "${module.public_nlb.dns_name}:8080" : null
}

output "emqx_dashboard_credentials" {
  description = "EMQX Dashboard credentials"
  value       = "admin:${local.emqx_dashboard_default_password}"
}

output "grafana_credentials" {
  description = "Grafana credentials"
  value       = local.monitoring_enabled ? "admin:grafana" : null
}

output "emqx_nodes" {
  description = "EMQX nodes"
  value       = [for node in module.emqx : { ip : node.public_ips[0], fqdn : node.fqdn }]
}

output "loadgen_nodes" {
  description = "loadgen nodes"
  value       = [for node in module.loadgen : { ip : node.public_ips[0], fqdn : node.fqdn }]
}

output "emqttb_nodes" {
  description = "emqttb nodes"
  value       = [for node in module.loadgen : { ip : node.public_ips[0], fqdn : node.fqdn } if node.type == "emqttb"]
}

output "emqtt_bench_nodes" {
  description = "emqtt bench nodes"
  value       = [for node in module.loadgen : { ip : node.public_ips[0], fqdn : node.fqdn } if node.type == "emqtt_bench"]
}

output "locust_nodes" {
  description = "locust nodes"
  value       = [for node in module.loadgen : { ip : node.public_ips[0], fqdn : node.fqdn } if node.type == "locust"]
}

output "http_nodes" {
  description = "http nodes"
  value       = [for node in module.integration : { ip : node.public_ips[0], fqdn : node.fqdn } if node.type == "http"]
}

output "kafka_nodes" {
  description = "kafka nodes"
  value       = [for node in module.integration : { ip : node.public_ips[0], fqdn : node.fqdn } if node.type == "kafka"]
}

output "rabbitmq_nodes" {
  description = "rabbitmq nodes"
  value       = [for node in module.integration : { ip : node.public_ips[0], fqdn : node.fqdn } if node.type == "rabbitmq"]
}

output "monitoring_nodes" {
  description = "monitoring nodes"
  value       = [for node in module.monitoring : { ip : node.public_ips[0], fqdn : node.fqdn }]
}

output "ssh_key_path" {
  description = "SSH key path"
  value       = local.ssh_key_path
}

output "emqx_version_family" {
  description = "EMQX version family, 4 or 5"
  value       = local.emqx_version_family
}

output "emqx_api_key" {
  description = "EMQX API key for authentication"
  value       = local.emqx_api_key
}

output "emqx_api_secret" {
  description = "EMQX API secret for authentication"
  value       = local.emqx_api_secret
}
