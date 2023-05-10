output "mqtt_lb_dns_name" {
  description = "The DNS name of the MQTT Load Balancer"
  value       = aws_lb.mqtt.dns_name
}
