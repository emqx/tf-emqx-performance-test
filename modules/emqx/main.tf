terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

locals {
  cluster_dns_name = "emqx-cluster.${var.route53_zone_name}"
  zone_id  = var.route53_zone_id
}

module "emqx_ec2" {
  source = "../ec2"

  namespace         = var.namespace
  instance_count    = var.instance_count
  instance_type     = var.instance_type
  ami_filter        = var.ami_filter
  sg_ids            = var.sg_ids
  s3_bucket_name    = var.s3_bucket_name
  iam_profile       = var.iam_profile
  instance_name     = "emqx-${substr(var.node_role, 0, 4)}"
  route53_zone_id   = var.route53_zone_id
  route53_zone_name = var.route53_zone_name
  key_name          = var.key_name
  subnet_id         = var.subnet_id
  extra_user_data   = templatefile("${path.module}/templates/user_data.tpl", {
    test_duration          = var.test_duration
    s3_bucket_name         = var.s3_bucket_name
    bench_id               = var.bench_id
    package_url            = var.package_url
    cluster_dns_name       = var.cluster_dns_name
    prometheus_push_gw_url = var.prometheus_push_gw_url
    node_role              = var.node_role
    launch_index_offset    = var.launch_index_offset
    core_nodes             = var.core_nodes
  })
}

