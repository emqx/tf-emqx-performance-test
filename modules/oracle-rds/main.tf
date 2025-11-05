terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

resource "aws_db_instance" "oracle" {
  identifier_prefix           = var.prefix
  engine                      = var.engine
  engine_version              = data.aws_rds_engine_version.oracle.version_actual
  instance_class              = var.instance_class
  allocated_storage           = var.allocated_storage
  storage_type                = var.storage_type
  storage_encrypted           = var.storage_encrypted
  username                    = var.username
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.oracle.name
  vpc_security_group_ids      = var.security_group_ids
  character_set_name          = "AL32UTF8"
  license_model               = "license-included"
  skip_final_snapshot         = true
  multi_az                    = false
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_subnet_group" "oracle" {
  name       = "${var.prefix}-oracle"
  subnet_ids = var.subnet_ids
}

resource "aws_db_option_group" "oracle" {
  name                 = "${var.prefix}-oracle"
  engine_name          = var.engine
  major_engine_version = var.engine_version
  option {
    option_name                    = "SSL"
    vpc_security_group_memberships = var.security_group_ids
    port                           = var.tls_port
    option_settings {
      name  = "SQLNET.SSL_VERSION"
      value = "1.2 or 1.0"
    }
  }
}

data "aws_rds_engine_version" "oracle" {
  engine       = var.engine
  version      = var.engine_version
  default_only = true
}

data "aws_secretsmanager_secret" "master_user_secret" {
  arn = aws_db_instance.oracle.master_user_secret[0].secret_arn
}

data "aws_secretsmanager_secret_version" "master_user_secret_version" {
  secret_id = data.aws_secretsmanager_secret.master_user_secret.id
}

resource "aws_route53_record" "oracle" {
  zone_id = var.route53_zone_id
  name    = var.hostname
  type    = "CNAME"
  ttl     = "300"
  records = [aws_db_instance.oracle.address]
}
