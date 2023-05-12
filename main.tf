resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_region" "current" {}

locals {
  os_version = "20.04"
  os_arch    = "amd64"
  ami_filter = "ubuntu/images/hvm-ssd/ubuntu-*-${local.os_version}-${local.os_arch}-server-*"
  vpc_id     = aws_default_vpc.default.id
  region     = data.aws_region.current.name
}

#data "aws_caller_identity" "current" {}

data "aws_subnets" "vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

resource "aws_route53_zone" "int" {
  name = var.route53_zone_name
  vpc {
    vpc_id = local.vpc_id
  }
}

module "security_group" {
  source = "./modules/security_group"

  namespace        = var.namespace
  vpc_id           = local.vpc_id
  cidr_blocks      = [aws_default_vpc.default.cidr_block]
}

module "ec2_profile" {
  source         = "./modules/ec2_profile"
  namespace      = var.namespace
  s3_bucket_name = var.s3_bucket_name
}

module "emqx_package" {
  source         = "./modules/emqx_package"
  region         = local.region
  s3_bucket_name = var.s3_bucket_name
  s3_prefix      = var.bench_id
  package_file   = var.package_file
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_sensitive_file" "pem_file" {
  filename = pathexpand("~/.ssh/${var.ssh_key_name}.pem")
  file_permission = "600"
  directory_permission = "700"
  content = tls_private_key.pk.private_key_pem
}

module "prometheus" {
  source            = "./modules/prometheus"
  vpc_id           = local.vpc_id
  cidr_blocks      = [aws_default_vpc.default.cidr_block]
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  namespace         = var.namespace
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  iam_profile       = module.ec2_profile.iam_profile
  key_name          = aws_key_pair.kp.key_name
}

module "emqx" {
  source            = "./modules/emqx"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = module.emqx_package.package_url
  namespace         = var.namespace
  instance_count    = var.emqx_instance_count
  instance_type     = var.emqx_instance_type
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  sg_ids            = [module.security_group.sg_id]
  iam_profile       = module.ec2_profile.iam_profile
  key_name          = aws_key_pair.kp.key_name
  prometheus_push_gw = module.prometheus.private_ip
}

module "emqx_lb" {
  source              = "./modules/elb"
  vpc_id              = local.vpc_id
  namespace           = var.namespace
  region              = local.region
  subnet_ids          = data.aws_subnets.vpc_subnets.ids
  instance_count      = var.emqx_instance_count
  instance_ids        = module.emqx.instance_ids
  forwarding_config   = var.forwarding_config
  route53_zone_id     = aws_route53_zone.int.zone_id
  route53_zone_name   = var.route53_zone_name
}

module "emqx_dashboard_lb" {
  source              = "./modules/emqx_dashboard_lb"
  vpc_id              = local.vpc_id
  namespace           = var.namespace
  subnet_ids          = data.aws_subnets.public.ids
  instance_ids        = module.emqx.instance_ids
  instance_sg_id      = module.security_group.sg_id
}

module "emqx_mqtt_lb" {
  count               = var.create_public_mqtt_lb
  source              = "./modules/emqx_mqtt_lb"
  vpc_id              = local.vpc_id
  namespace           = var.namespace
  subnet_ids          = data.aws_subnets.public.ids
  instance_ids        = module.emqx.instance_ids
  instance_sg_id      = module.security_group.sg_id
}

module "emqttb" {
  count             = var.use_emqttb
  source            = "./modules/emqttb"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = var.emqttb_package_url
  namespace         = var.namespace
  instance_type     = var.emqttb_instance_type
  instance_count    = var.emqttb_instance_count
  scenario          = var.emqttb_scenario
  sg_ids            = [module.security_group.sg_id]
  emqx_lb_dns_name  = module.emqx_lb.elb_dns_name
  iam_profile       = module.ec2_profile.iam_profile
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  grafana_url       = var.grafana_url
  grafana_api_key   = var.grafana_api_key
  test_duration     = var.test_duration
  key_name          = aws_key_pair.kp.key_name
  prometheus_push_gw = module.prometheus.private_ip
}

module "emqtt_bench" {
  count             = var.use_emqtt_bench
  source            = "./modules/emqtt_bench"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  package_url       = var.emqtt_bench_package_url
  namespace         = var.namespace
  instance_type     = var.emqtt_bench_instance_type
  instance_count    = var.emqtt_bench_instance_count
  scenario          = var.emqtt_bench_scenario
  sg_ids            = [module.security_group.sg_id]
  emqx_lb_dns_name  = module.emqx_lb.elb_dns_name
  iam_profile       = module.ec2_profile.iam_profile
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  key_name          = aws_key_pair.kp.key_name
}
