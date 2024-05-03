output "public_ips" {
  value = concat(aws_instance.default.*.public_ip, aws_instance.region2.*.public_ip, aws_instance.region3.*.public_ip)
}

output "private_ips" {
  value = concat(aws_instance.default.*.private_ip, aws_instance.region2.*.private_ip, aws_instance.region3.*.private_ip)
}

output "instance_ids" {
  value = concat(aws_instance.default.*.id, aws_instance.region2.*.id, aws_instance.region3.*.id)
}

output "fqdn" {
  value = aws_route53_record.dns.fqdn
}

output "region" {
  value = var.region
}

output "attach_to_nlb" {
  value = var.attach_to_nlb
}
