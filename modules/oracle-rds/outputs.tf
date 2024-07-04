output "port" {
  value = aws_db_instance.oracle.port
}

output "tls_port" {
  value = var.tls_port
}

output "username" {
  value = jsondecode(data.aws_secretsmanager_secret_version.master_user_secret_version.secret_string)["username"]
}

output "password" {
  value = jsondecode(data.aws_secretsmanager_secret_version.master_user_secret_version.secret_string)["password"]
}

output "fqdn" {
  value = aws_route53_record.oracle.fqdn
}
