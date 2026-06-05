###############################################################################
# AWS (Route53)
###############################################################################

resource "aws_route53_zone" "vpc" {
  count = local.cloud_is_aws ? 1 : 0
  name  = local.route53_zone_name
  vpc {
    vpc_id     = module.vpc-default[0].vpc_id
    vpc_region = local.region
  }
  tags = {
    Name = local.prefix
  }
}

resource "aws_route53_zone_association" "region2" {
  count      = local.cloud_is_aws && local.region2 != "region2-stub" ? 1 : 0
  zone_id    = aws_route53_zone.vpc[0].zone_id
  vpc_id     = module.vpc-region2[0].vpc_id
  vpc_region = local.region2
}

resource "aws_route53_zone_association" "region3" {
  count      = local.cloud_is_aws && local.region3 != "region3-stub" ? 1 : 0
  zone_id    = aws_route53_zone.vpc[0].zone_id
  vpc_id     = module.vpc-region3[0].vpc_id
  vpc_region = local.region3
}

# https://www.emqx.io/docs/en/v5.0/deploy/cluster/create-cluster.html#autocluster-by-dns-records
resource "aws_route53_record" "emqx-cluster" {
  count   = local.cloud_is_aws && length(local.emqx_nodes) > 1 ? 1 : 0
  zone_id = aws_route53_zone.vpc[0].zone_id
  name    = local.emqx_cluster_dns_name
  type    = "SRV"
  ttl     = 30
  records = [
    for node in local.emqx_nodes :
    "10 20 1883 ${node.hostname}"
  ]
}

###############################################################################
# GCP (Cloud DNS private zone)
###############################################################################

resource "google_dns_managed_zone" "private" {
  count       = local.cloud_is_gcp ? 1 : 0
  name        = replace(local.route53_zone_name, ".", "-")
  dns_name    = "${local.route53_zone_name}."
  description = "Private zone for ${local.prefix}"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = module.vpc_gcp[0].network
    }
  }
}

resource "google_dns_record_set" "emqx-cluster" {
  count        = local.cloud_is_gcp && length(local.emqx_nodes) > 1 ? 1 : 0
  name         = "${local.emqx_cluster_dns_name}."
  type         = "SRV"
  ttl          = 30
  managed_zone = google_dns_managed_zone.private[0].name
  rrdatas = [
    for node in local.emqx_nodes :
    "10 20 1883 ${node.hostname}."
  ]
}
