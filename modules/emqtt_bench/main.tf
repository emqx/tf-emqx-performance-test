module "emqtt_bench_ec2" {
  source = "../ec2"

  namespace       = var.namespace
  instance_count  = var.instance_count
  instance_type   = var.instance_type
  ami_filter      = var.ami_filter
  sg_ids          = var.sg_ids
  s3_bucket_name  = var.s3_bucket_name
  iam_profile     = var.iam_profile
  instance_name   = "emqtt-bench"
  extra_user_data = templatefile("${path.module}/templates/user_data.tpl", {
    s3_bucket_name         = var.s3_bucket_name
    bench_id               = var.bench_id
    package_url            = var.package_url
    emqx_lb_dns_name       = var.emqx_lb_dns_name
    clients_count          = var.clients_count
    payload_size           = var.payload_size
    max_message_count      = var.max_message_count
  })
}
