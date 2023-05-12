output "private_ip" {
  description = "private ip of ec2 instance"
  value       = module.prometheus_ec2.private_ip[0]
}

output "public_ip" {
  description = "public ip of ec2 instance"
  value       = module.prometheus_ec2.public_ip[0]
}

output "instance_id" {
  value = module.prometheus_ec2.instance_id
}
