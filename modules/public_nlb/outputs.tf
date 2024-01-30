output "dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.nlb.dns_name
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.nlb_sg.id
}

output "emqx_target_group_arn" {
  value = aws_lb_target_group.emqx.arn
}

output "emqx_ws_target_group_arn" {
  value = aws_lb_target_group.emqx-ws.arn
}

output "emqx_api_target_group_arn" {
  value = aws_lb_target_group.emqx-api.arn
}

output "grafana_target_group_arn" {
  value = aws_lb_target_group.grafana.arn
}

output "prometheus_target_group_arn" {
  value = aws_lb_target_group.prometheus.arn
}

output "locust_target_group_arn" {
  value = aws_lb_target_group.locust.arn
}
