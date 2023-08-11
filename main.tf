data "aws_caller_identity" "current" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
  alias  = "primary"

  default_tags {
    tags = {
      Name        = "${var.namespace}/${var.bench_id}"
      BenchmarkId = var.bench_id
      Environment = "test"
    }
  }
}

provider "aws" {
  region = var.secondary_region
  alias  = "secondary"

  default_tags {
    tags = {
      Name        = "${var.namespace}/${var.bench_id}"
      BenchmarkId = var.bench_id
      Environment = "test"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  providers = {
    aws = aws.primary
  }
}

module "secondary_vpc" {
  source = "./modules/vpc"
  vpc_cidr = var.secondary_vpc_cidr
  providers = {
    aws = aws.secondary
  }
}

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = module.vpc.vpc_id
  peer_vpc_id   = module.secondary_vpc.vpc_id
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_region   = var.secondary_region
  auto_accept   = false
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider = aws.secondary

  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true
}

resource "aws_route" "route_primary_to_secondary" {
  provider = aws.primary

  route_table_id            = module.vpc.main_route_table_id
  destination_cidr_block    = var.secondary_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

resource "aws_route" "route_secondary_to_primary" {
  provider = aws.secondary

  route_table_id            = module.secondary_vpc.main_route_table_id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

#data "aws_region" "current" {}

locals {
  os_version = "20.04"
  os_arch    = "amd64"
  ami_filter = "ubuntu/images/hvm-ssd/ubuntu-*-${local.os_version}-${local.os_arch}-server-*"
  route53_zone_name = replace("${var.bench_id}.${var.namespace}.emqx.io", "/", "-")
  ssh_key_name = "${var.namespace}-${var.bench_id}"
  # mqtt_int_nlb_dns_name = "emqx-lb.${var.route53_zone_name}"
  cluster_dns_name = "emqx-cluster.${local.route53_zone_name}"
  emqx_replicant_nodes = var.emqx_nodes - var.emqx_core_nodes
}

resource "aws_route53_zone" "int" {
  name = local.route53_zone_name
  vpc {
    vpc_id = module.vpc.vpc_id
  }
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_zone_association" "secondary" {
  zone_id = aws_route53_zone.int.zone_id
  vpc_id  = module.secondary_vpc.vpc_id
  vpc_region = var.secondary_region
}

resource "aws_security_group" "vpc_sg" {
  name        = "${var.namespace}-vpc-sg"
  description = "Allow all inbound traffic within sg, external SSH access and all outbound traffic"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group" "secondary_vpc_sg" {
  name        = "${var.namespace}-secondary-vpc-sg"
  description = "Allow all inbound traffic within sg, external SSH access and all outbound traffic"
  vpc_id      = module.secondary_vpc.vpc_id
  provider    = aws.secondary
}

module "security_group_rules" {
  source = "./modules/security_group_rules"
  sg_id = aws_security_group.vpc_sg.id
  cidr_ipv4 = var.vpc_cidr
  secondary_cidr_ipv4 = var.secondary_vpc_cidr
}

module "security_group_rules2" {
  source = "./modules/security_group_rules"
  sg_id = aws_security_group.secondary_vpc_sg.id
  cidr_ipv4 = var.secondary_vpc_cidr
  secondary_cidr_ipv4 = var.vpc_cidr
  providers = {
    aws = aws.secondary
  }
}

module "ec2_profile" {
  source         = "./modules/ec2_profile"
  namespace      = var.namespace
  s3_bucket_name = var.s3_bucket_name
}

module "emqx_package" {
  source         = "./modules/emqx_package"
  region         = var.region
  s3_bucket_name = var.s3_bucket_name
  s3_prefix      = var.bench_id
  package_file   = var.emqx_package_file
}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = local.ssh_key_name
  public_key = tls_private_key.pk.public_key_openssh
}

resource "aws_key_pair" "kp2" {
  key_name   = local.ssh_key_name
  public_key = tls_private_key.pk.public_key_openssh
  provider   = aws.secondary
}

resource "local_sensitive_file" "pem_file" {
  filename = pathexpand(format("~/.ssh/%s.pem", replace(local.ssh_key_name, "/", "-")))
  file_permission = "600"
  directory_permission = "700"
  content = tls_private_key.pk.private_key_pem
}

module "prometheus" {
  source            = "./modules/prometheus"
  vpc_id            = module.vpc.vpc_id
  cidr_blocks       = [var.vpc_cidr, var.secondary_vpc_cidr]
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  namespace         = var.namespace
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = local.route53_zone_name
  iam_profile       = module.ec2_profile.iam_profile
  key_name          = aws_key_pair.kp.key_name
  subnet_id         = module.vpc.public_subnet_ids[0]
  remote_write_url  = var.prometheus_remote_write_url
  remote_write_region = var.prometheus_remote_write_region
  emqx_targets      = concat(
    [for x in range(1, var.emqx_core_nodes+1): "emqx-core-${x}.${local.route53_zone_name}"],
    [for x in range(1, local.emqx_replicant_nodes+1): "emqx-repl-${x}.${local.route53_zone_name}"]
  )
  emqttb_targets    = [
    for x in range(1, var.emqttb_nodes+1):
      "emqttb-${x}.${local.route53_zone_name}"
  ]
  emqtt_bench_targets = [
    for x in range(1, var.emqtt_bench_nodes+1):
      "emqtt-bench-${x}.${local.route53_zone_name}"
  ]
}

# https://www.emqx.io/docs/en/v5.0/deploy/cluster/create-cluster.html#autocluster-by-dns-records
resource "aws_route53_record" "emqx-cluster" {
  zone_id = aws_route53_zone.int.zone_id
  name    = local.cluster_dns_name
  type    = "SRV"
  ttl     = 30
  records = [
    for x in range(1, var.emqx_core_nodes+1):
      "10 20 1883 emqx-core-${x}.${local.route53_zone_name}"
  ]
}

module "emqx_core" {
  source            = "./modules/emqx"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = module.emqx_package.package_url
  namespace         = var.namespace
  instance_type     = var.emqx_core_instance_type
  instance_count    = var.emqx_core_nodes
  launch_index_offset = 0
  node_role         = "core"
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = local.route53_zone_name
  test_duration     = var.duration
  sg_ids            = [aws_security_group.vpc_sg.id]
  iam_profile       = module.ec2_profile.iam_profile
  key_name          = aws_key_pair.kp.key_name
  subnet_id         = module.vpc.public_subnet_ids[0]
  prometheus_push_gw_url = module.prometheus.push_gw_url
  cluster_dns_name  = local.cluster_dns_name
}

module "emqx_replicant" {
  source            = "./modules/emqx"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = module.emqx_package.package_url
  namespace         = var.namespace
  instance_type     = var.emqx_replicant_instance_type
  instance_count    = local.emqx_replicant_nodes
  node_role         = "replicant"
  core_nodes        = [
    for x in range(1, var.emqx_core_nodes+1):
      "emqx@emqx-core-${x}.${local.route53_zone_name}"
  ]
  launch_index_offset = var.emqx_core_nodes
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = local.route53_zone_name
  test_duration     = var.duration
  sg_ids            = [aws_security_group.secondary_vpc_sg.id]
  iam_profile       = module.ec2_profile.iam_profile
  key_name          = aws_key_pair.kp2.key_name
  subnet_id         = module.secondary_vpc.public_subnet_ids[0]
  prometheus_push_gw_url = module.prometheus.push_gw_url
  cluster_dns_name  = local.cluster_dns_name
  providers = {
    aws = aws.secondary
  }
}

# module "emqx_mqtt_int_nlb" {
#   count               = var.internal_mqtt_nlb_count
#   source              = "./modules/emqx_mqtt_int_nlb"
#   vpc_id              = module.vpc.vpc_id
#   namespace           = var.namespace
#   nlb_name            = "${var.namespace}-nlb-${count.index}"
#   tg_name             = "${var.namespace}-tg-${count.index}"
#   region              = var.region
#   subnet_ids          = module.vpc.public_subnet_ids
#   instance_count      = var.emqx_nodes
#   instance_ids        = module.emqx_core.instance_ids
#   route53_zone_id     = aws_route53_zone.int.zone_id
#   route53_zone_name   = local.route53_zone_name
# }

# module "emqx_mqtt_public_nlb" {
#   count               = var.create_public_mqtt_nlb
#   source              = "./modules/emqx_mqtt_public_nlb"
#   vpc_id              = module.vpc.vpc_id
#   namespace           = var.namespace
#   subnet_ids          = module.vpc.public_subnet_ids
#   instance_ids        = module.emqx_core.instance_ids
#   instance_sg_id      = module.security_group.sg_id
# }

module "emqx_dashboard_lb" {
  source              = "./modules/emqx_dashboard_lb"
  vpc_id              = module.vpc.vpc_id
  namespace           = var.namespace
  subnet_ids          = module.vpc.public_subnet_ids
  instance_ids        = module.emqx_core.instance_ids
  instance_sg_id      = aws_security_group.vpc_sg.id
}

module "emqttb" {
  source            = "./modules/emqttb"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = var.emqttb_package_url
  namespace         = var.namespace
  instance_type     = var.emqttb_instance_type
  instance_count    = var.emqttb_nodes
  scenario          = var.emqttb_scenario
  sg_ids            = [aws_security_group.secondary_vpc_sg.id]
  emqx_hosts        = concat(module.emqx_core.private_ips, module.emqx_replicant.private_ips)
  iam_profile       = module.ec2_profile.iam_profile
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = local.route53_zone_name
  test_duration     = var.duration
  key_name          = aws_key_pair.kp2.key_name
  subnet_id         = module.secondary_vpc.public_subnet_ids[0]
  grafana_url       = module.prometheus.grafana_url
  prometheus_push_gw_url = module.prometheus.push_gw_url
  start_n_multiplier = var.emqttb_start_n_multiplier
  providers = {
    aws = aws.secondary
  }
}

module "emqtt_bench" {
  source            = "./modules/emqtt_bench"
  ami_filter        = local.ami_filter
  s3_bucket_name    = var.s3_bucket_name
  bench_id          = var.bench_id
  package_url       = var.emqtt_bench_package_url
  namespace         = var.namespace
  instance_type     = var.emqtt_bench_instance_type
  instance_count    = var.emqtt_bench_nodes
  scenario          = var.emqtt_bench_scenario
  sg_ids            = [aws_security_group.secondary_vpc_sg.id]
  emqx_hosts        = concat(module.emqx_core.private_ips, module.emqx_replicant.private_ips)
  iam_profile       = module.ec2_profile.iam_profile
  route53_zone_id   = aws_route53_zone.int.zone_id
  route53_zone_name = local.route53_zone_name
  test_duration     = var.duration
  key_name          = aws_key_pair.kp2.key_name
  subnet_id         = module.secondary_vpc.public_subnet_ids[0]
  start_n_multiplier = var.emqtt_bench_start_n_multiplier
  providers = {
    aws = aws.secondary
  }
}
