output "dns_name" {
  description = "The DNS name of the NLB"
  value       = aws_lb.nlb.dns_name
}

output "zone_id" {
  description = "The DNS zone ID of the NLB"
  value       = aws_lb.nlb.zone_id
}
