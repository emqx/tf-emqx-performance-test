module "emqtt_bench_ec2" {
  source = "../ec2"

  namespace         = var.namespace
  instance_type     = var.instance_type
  instance_count    = var.instance_count
  ami_filter        = var.ami_filter
  sg_ids            = var.sg_ids
  s3_bucket_name    = var.s3_bucket_name
  iam_profile       = var.iam_profile
  instance_name     = "${var.namespace}-emqtt-bench"
  route53_zone_id   = var.route53_zone_id
  route53_zone_name = var.route53_zone_name
  key_name          = var.key_name
  extra_user_data   = templatefile("${path.module}/templates/user_data.tpl", {
    package_url      = var.package_url
    emqx_lb_dns_name = var.emqx_lb_dns_name
    scenario         = var.scenario
  })
}
