locals {
  dns_name = "emqx-cluster.${var.route53_zone_name}"
}

module "emqx_ec2" {
  source = "../ec2"

  namespace       = var.namespace
  instance_count  = var.instance_count
  instance_type   = var.instance_type
  ami_filter      = var.ami_filter
  sg_ids          = var.sg_ids
  s3_bucket_name  = var.s3_bucket_name
  iam_profile     = var.iam_profile
  instance_name   = "emqx"
  extra_user_data = templatefile("${path.module}/templates/user_data.tpl", {
    s3_bucket_name = var.s3_bucket_name
    bench_id       = var.bench_id
    package_url    = var.package_url
    emqx_dns_name  = local.dns_name
  })

}

resource "aws_route53_record" "emqx" {
  zone_id = var.route53_zone_id
  name    = local.dns_name
  type    = "A"
  ttl     = 30
  records = module.emqx_ec2.private_ip
}
