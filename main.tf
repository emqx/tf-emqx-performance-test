module "public_nlb" {
  source     = "./modules/public_nlb"
  prefix     = local.prefix
  vpc_id     = local.vpcs[local.region].vpc_id
  subnet_ids = local.vpcs[local.region].public_subnet_ids
  providers = {
    aws = aws.default
  }
}

module "internal_nlb" {
  source        = "./modules/internal_nlb"
  prefix        = local.prefix
  vpc_id        = local.vpcs[local.region].vpc_id
  subnet_ids    = local.vpcs[local.region].public_subnet_ids
  http_api_port = local.emqx_http_api_port
  providers = {
    aws = aws.default
  }
}

module "emqx" {
  for_each           = local.emqx_nodes
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  extra_volumes      = each.value.extra_volumes
  instance_volumes   = each.value.instance_volumes
  attach_to_nlb      = each.value.attach_to_nlb
  ami_filter         = each.value.ami_filter
  ami_owner          = each.value.ami_owner
  remote_user        = each.value.remote_user
  vpc_id             = local.vpcs[each.value.region].vpc_id
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[each.value.az]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  use_spot_instances = local.emqx_use_spot_instances
  root_volume_size   = local.emqx_root_volume_size
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
  certs              = module.certs.certs
  providers = {
    aws.default = aws.default
    aws.region2 = aws.region2
    aws.region3 = aws.region3
  }
  depends_on = [
    aws_route53_zone_association.region2,
    aws_route53_zone_association.region3
  ]
}

resource "aws_lb_target_group_attachment" "emqx" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region }
  target_group_arn = module.public_nlb.emqx_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 18083
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "emqx-ws" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.public_nlb.emqx_ws_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8083
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "emqx-api" {
  for_each         = local.emqx_version_family == 4 ? { for i, node in module.emqx : i => node if node.region == local.region } : {}
  target_group_arn = module.public_nlb.emqx_api_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8081
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mqtt" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.internal_nlb.mqtt_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 1883
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mqtts" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.internal_nlb.mqtts_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8883
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-httpapi" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region }
  target_group_arn = module.internal_nlb.httpapi_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = local.emqx_http_api_port
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mgmt" {
  for_each         = local.emqx_version_family == 4 ? { for i, node in module.emqx : i => node if node.region == local.region } : {}
  target_group_arn = module.internal_nlb.mgmt_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 18083
  provider         = aws.default
}

module "loadgen" {
  for_each           = local.loadgen_nodes
  source             = "./modules/ec2"
  region             = each.value.region
  type               = each.value.type
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  ip_aliases         = each.value.ip_aliases
  ami_filter         = each.value.ami_filter
  ami_owner          = each.value.ami_owner
  use_spot_instances = each.value.use_spot_instances
  remote_user        = each.value.remote_user
  vpc_id             = local.vpcs[each.value.region].vpc_id
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[each.value.az]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
  certs              = module.certs.certs
  providers = {
    aws.default = aws.default
    aws.region2 = aws.region2
    aws.region3 = aws.region3
  }
  depends_on = [
    aws_route53_zone_association.region2,
    aws_route53_zone_association.region3
  ]
}

resource "aws_lb_target_group_attachment" "locust" {
  for_each         = { for i, node in module.loadgen : i => node if node.region == local.region && node.type == "locust" }
  target_group_arn = module.public_nlb.locust_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8080
  provider         = aws.default
}

module "integration" {
  for_each           = { for hostname, node in local.integration_nodes : hostname => node if node.type != "oracle-rds" }
  source             = "./modules/ec2"
  region             = each.value.region
  type               = each.value.type
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  ami_filter         = each.value.ami_filter
  ami_owner          = each.value.ami_owner
  use_spot_instances = each.value.use_spot_instances
  remote_user        = each.value.remote_user
  vpc_id             = local.vpcs[each.value.region].vpc_id
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[each.value.az]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
  certs              = module.certs.certs
  providers = {
    aws.default = aws.default
    aws.region2 = aws.region2
    aws.region3 = aws.region3
  }
  depends_on = [
    aws_route53_zone_association.region2,
    aws_route53_zone_association.region3
  ]
}

module "oracle-rds" {
  for_each           = { for hostname, node in local.integration_nodes : hostname => node if node.type == "oracle-rds" }
  source             = "./modules/oracle-rds"
  instance_class     = each.value.instance_type
  hostname           = each.value.hostname
  subnet_ids         = local.vpcs[each.value.region].public_subnet_ids
  security_group_ids = [local.vpcs[each.value.region].security_group_id]
  prefix             = local.prefix
  route53_zone_id    = aws_route53_zone.vpc.zone_id
  providers = {
    aws = aws.default
  }
}

module "monitoring" {
  count              = local.monitoring_enabled ? 1 : 0
  source             = "./modules/ec2"
  region             = local.region
  instance_name      = "monitoring"
  instance_type      = local.monitoring_instance_type
  hostname           = local.monitoring_hostname
  vpc_id             = local.vpcs[local.region].vpc_id
  subnet_id          = local.vpcs[local.region].public_subnet_ids[0]
  security_group_id  = local.vpcs[local.region].security_group_id
  ami_filter         = local.monitoring_ami_filter
  ami_owner          = local.monitoring_ami_owner
  use_spot_instances = local.monitoring_use_spot_instances
  root_volume_size   = local.monitoring_root_volume_size
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
  certs              = module.certs.certs
  providers = {
    aws.default = aws.default
    aws.region2 = aws.region2
    aws.region3 = aws.region3
  }
  depends_on = [
    aws_route53_zone_association.region2,
    aws_route53_zone_association.region3
  ]
}

resource "aws_lb_target_group_attachment" "grafana" {
  count            = local.monitoring_enabled ? 1 : 0
  target_group_arn = module.public_nlb.grafana_target_group_arn
  target_id        = module.monitoring[0].instance_ids[0]
  port             = 3000
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "prometheus" {
  count            = local.monitoring_enabled ? 1 : 0
  target_group_arn = module.public_nlb.prometheus_target_group_arn
  target_id        = module.monitoring[0].instance_ids[0]
  port             = 9090
  provider         = aws.default
}

module "certs" {
  source = "./modules/certs"
  subject = {
    cn = "EMQX"
    o  = "EMQ Technologies"
    c  = "SE"
  }
}
