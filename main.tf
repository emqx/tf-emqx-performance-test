data "aws_region" "current" {}

locals {
  os_version = "20.04"
  os_arch    = "amd64"
  ami_filter = "ubuntu/images/hvm-ssd/ubuntu-*-${local.os_version}-${local.os_arch}-server-*"
  region     = data.aws_region.current.name
  mqtt_int_nlb_dns_name = "emqx-lb.${var.route53_zone_name}"
}

module "vpc" {
  source = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
}
#data "aws_caller_identity" "current" {}

resource "aws_route53_zone" "int" {
  name = var.route53_zone_name
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

module "security_group" {
  source = "./modules/security_group"

  namespace        = var.namespace
  vpc_id           = module.vpc.vpc_id
  cidr_blocks      = [var.vpc_cidr]
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
  vpc_id            = module.vpc.vpc_id
  cidr_blocks       = [var.vpc_cidr]
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  namespace         = var.namespace
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  iam_profile       = module.ec2_profile.iam_profile
  key_name          = aws_key_pair.kp.key_name
  subnet_id         = module.vpc.public_subnet_ids[0]
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
  subnet_id         = module.vpc.public_subnet_ids[0]
  prometheus_push_gw = module.prometheus.private_ip
}

module "emqx_mqtt_int_nlb" {
  count               = var.internal_mqtt_nlb_count
  source              = "./modules/emqx_mqtt_int_nlb"
  vpc_id              = module.vpc.vpc_id
  namespace           = var.namespace
  nlb_name            = "${var.namespace}-nlb-${count.index}"
  tg_name             = "${var.namespace}-tg-${count.index}"
  region              = local.region
  subnet_ids          = module.vpc.public_subnet_ids
  instance_count      = var.emqx_instance_count
  instance_ids        = module.emqx.instance_ids
  route53_zone_id     = aws_route53_zone.int.zone_id
  route53_zone_name   = var.route53_zone_name
}

module "emqx_mqtt_public_nlb" {
  count               = var.create_public_mqtt_nlb
  source              = "./modules/emqx_mqtt_public_nlb"
  vpc_id              = module.vpc.vpc_id
  namespace           = var.namespace
  subnet_ids          = module.vpc.public_subnet_ids
  instance_ids        = module.emqx.instance_ids
  instance_sg_id      = module.security_group.sg_id
}

module "emqx_dashboard_lb" {
  source              = "./modules/emqx_dashboard_lb"
  vpc_id              = module.vpc.vpc_id
  namespace           = var.namespace
  subnet_ids          = module.vpc.public_subnet_ids
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
  emqx_lb_dns_name  = module.emqx_mqtt_int_nlb[0].dns_name
  iam_profile       = module.ec2_profile.iam_profile
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  grafana_url       = var.grafana_url
  grafana_api_key   = var.grafana_api_key
  test_duration     = var.test_duration
  key_name          = aws_key_pair.kp.key_name
  prometheus_push_gw = module.prometheus.private_ip
  subnet_id         = module.vpc.public_subnet_ids[0]
}

module "emqtt_bench" {
  count             = var.use_emqtt_bench
  source            = "./modules/emqtt_bench"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = var.emqtt_bench_package_url
  namespace         = var.namespace
  instance_type     = var.emqtt_bench_instance_type
  instance_count    = var.emqtt_bench_instance_count
  scenario          = var.emqtt_bench_scenario
  sg_ids            = [module.security_group.sg_id]
  emqx_lb_dns_name  = join(",", module.emqx_mqtt_int_nlb.*.dns_name)
  iam_profile       = module.ec2_profile.iam_profile
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = var.route53_zone_name
  test_duration     = var.test_duration
  key_name          = aws_key_pair.kp.key_name
  subnet_id         = module.vpc.public_subnet_ids[0]
}
