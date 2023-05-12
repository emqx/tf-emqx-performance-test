output "emqx_public_ips" {
  description = "public ip of emqx instances"
  value       = module.emqx.public_ips
}

output "emqttb_public_ips" {
  description = "public ip of emqttb instances"
  value       = module.emqttb.*.public_ips
}

output "emqtt_bench_public_ips" {
  description = "public ip of emqtt_bench instances"
  value       = module.emqtt_bench.*.public_ips
}

output "emqx_elb_dns_name" {
  description = "elb dns name"
  value       = module.emqx_lb.elb_dns_name
}

output "emqx_dashboard_dns_name" {
  description = "EMQX Dashboard DNS name"
  value       = module.emqx_dashboard_lb.dashboard_dns_name
}

output "emqx_mqtt_lb_dns_name" {
  description = "The DNS name of the MQTT Load Balancer"
  value       = module.emqx_mqtt_lb.*.mqtt_lb_dns_name
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${module.prometheus.public_ip}:3000/"
}
