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

resource "aws_route53_zone" "int" {
  name = var.dns_zone_name
  vpc {
    vpc_id = local.vpc_id
  }
}

module "security_group" {
  source = "./modules/security_group"

  namespace        = var.emqx_namespace
  vpc_id           = local.vpc_id
  cidr_blocks      = [aws_default_vpc.default.cidr_block]
}

module "emqx_package" {
  source         = "./modules/emqx_package"
  region         = local.region
  s3_bucket_name = var.s3_bucket_name
  s3_prefix      = var.s3_prefix
  package_file   = var.package_file
}

module "emqx" {
  source              = "./modules/emqx"
  ami_filter          = local.ami_filter
  s3_bucket_name      = var.s3_bucket_name
  package_url         = module.emqx_package.package_url
  emqx_namespace      = var.emqx_namespace
  emqx_instance_count = var.emqx_instance_count
  emqx_instance_type  = var.emqx_instance_type
  route53_zone_id     = aws_route53_zone.int.zone_id
  route53_zone_name   = var.dns_zone_name
  sg_ids              = [module.security_group.sg_id]
}

module "emqx_lb" {
  source              = "./modules/elb"
  vpc_id              = local.vpc_id
  namespace           = var.emqx_namespace
  region              = local.region
  subnet_ids          = data.aws_subnets.vpc_subnets.ids
  instance_count      = var.emqx_instance_count
  instance_ids        = module.emqx.instance_ids
  forwarding_config   = var.forwarding_config
  route53_zone_id     = aws_route53_zone.int.zone_id
  route53_zone_name   = var.dns_zone_name
}

