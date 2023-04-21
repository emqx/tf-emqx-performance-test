output "private_ips" {
  description = "private ip of ec2 instance"
  value       = module.emqttb_ec2.private_ip
}

output "public_ips" {
  description = "public ip of ec2 instance"
  value       = module.emqttb_ec2.public_ip
}

output "instance_ids" {
  value = module.emqttb_ec2.instance_id
}
