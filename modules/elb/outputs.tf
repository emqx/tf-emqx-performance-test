output "elb_dns_name" {
  description = "The DNS name of the ELB"
  value       = aws_route53_record.emqx-lb.fqdn
}
