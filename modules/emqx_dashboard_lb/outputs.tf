output "dashboard_dns_name" {
  description = "The DNS name of the Dashboard"
  value       = aws_lb.dashboard.dns_name
}
