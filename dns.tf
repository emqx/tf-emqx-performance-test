resource "aws_route53_zone" "vpc" {
  name = local.route53_zone_name
  vpc {
    vpc_id     = module.vpc-default.vpc_id
    vpc_region = local.default_region
  }
  tags = {
    Name = local.prefix
  }
}

resource "aws_route53_zone_association" "region2" {
  count      = local.region2 != "region2-stub" ? 1 : 0
  zone_id    = aws_route53_zone.vpc.zone_id
  vpc_id     = module.vpc-region2[0].vpc_id
  vpc_region = local.region2
}

resource "aws_route53_zone_association" "region3" {
  count      = local.region3 != "region3-stub" ? 1 : 0
  zone_id    = aws_route53_zone.vpc.zone_id
  vpc_id     = module.vpc-region3[0].vpc_id
  vpc_region = local.region3
}

# https://www.emqx.io/docs/en/v5.0/deploy/cluster/create-cluster.html#autocluster-by-dns-records
resource "aws_route53_record" "emqx-cluster" {
  count   = length(local.emqx_nodes) > 1 ? 1 : 0
  zone_id = aws_route53_zone.vpc.zone_id
  name    = local.cluster_dns_name
  type    = "SRV"
  ttl     = 30
  records = [
    for node in local.emqx_nodes :
    "10 20 1883 ${node.hostname}"
  ]
}
