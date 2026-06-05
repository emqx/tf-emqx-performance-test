module "public_nlb" {
  source     = "./modules/public_nlb"
  count      = local.cloud_is_aws ? 1 : 0
  prefix     = local.prefix
  vpc_id     = local.vpcs[local.region].vpc_id
  subnet_ids = local.vpcs[local.region].public_subnet_ids
  providers = {
    aws = aws.default
  }
}

module "internal_nlb" {
  source        = "./modules/internal_nlb"
  count         = local.cloud_is_aws ? 1 : 0
  prefix        = local.prefix
  vpc_id        = local.vpcs[local.region].vpc_id
  subnet_ids    = local.vpcs[local.region].public_subnet_ids
  http_api_port = local.emqx_http_api_port
  providers = {
    aws = aws.default
  }
}

module "emqx" {
  for_each           = local.cloud_is_aws ? local.emqx_nodes : {}
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
  route53_zone_id    = aws_route53_zone.vpc[0].zone_id
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
  target_group_arn = module.public_nlb[0].emqx_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 18083
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "emqx-https" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region }
  target_group_arn = module.public_nlb[0].emqx_https_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 18084
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "emqx-ws" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.public_nlb[0].emqx_ws_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8083
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "emqx-api" {
  for_each         = local.emqx_version_family == 4 ? { for i, node in module.emqx : i => node if node.region == local.region } : {}
  target_group_arn = module.public_nlb[0].emqx_api_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8081
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mqtt" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.internal_nlb[0].mqtt_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 1883
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mqtts" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.internal_nlb[0].mqtts_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8883
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-ws" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region && node.attach_to_nlb }
  target_group_arn = module.internal_nlb[0].ws_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8083
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-httpapi" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.region }
  target_group_arn = module.internal_nlb[0].httpapi_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = local.emqx_http_api_port
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mgmt" {
  for_each         = local.emqx_version_family == 4 ? { for i, node in module.emqx : i => node if node.region == local.region } : {}
  target_group_arn = module.internal_nlb[0].mgmt_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 18083
  provider         = aws.default
}

module "loadgen" {
  for_each           = local.cloud_is_aws ? local.loadgen_nodes : {}
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
  route53_zone_id    = aws_route53_zone.vpc[0].zone_id
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
  target_group_arn = module.public_nlb[0].locust_target_group_arn
  target_id        = each.value.instance_ids[0]
  port             = 8080
  provider         = aws.default
}

module "integration" {
  for_each           = { for hostname, node in local.integration_nodes : hostname => node if local.cloud_is_aws && node.type != "oracle-rds" }
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
  route53_zone_id    = aws_route53_zone.vpc[0].zone_id
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
  for_each           = { for hostname, node in local.integration_nodes : hostname => node if local.cloud_is_aws && node.type == "oracle-rds" }
  source             = "./modules/oracle-rds"
  instance_class     = each.value.instance_type
  hostname           = each.value.hostname
  subnet_ids         = local.vpcs[each.value.region].public_subnet_ids
  security_group_ids = [local.vpcs[each.value.region].security_group_id]
  prefix             = local.prefix
  route53_zone_id    = aws_route53_zone.vpc[0].zone_id
  providers = {
    aws = aws.default
  }
}

module "monitoring" {
  count              = local.cloud_is_aws && local.monitoring_enabled ? 1 : 0
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
  route53_zone_id    = aws_route53_zone.vpc[0].zone_id
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
  count            = local.cloud_is_aws && local.monitoring_enabled ? 1 : 0
  target_group_arn = module.public_nlb[0].grafana_target_group_arn
  target_id        = module.monitoring[0].instance_ids[0]
  port             = 3000
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "prometheus" {
  count            = local.cloud_is_aws && local.monitoring_enabled ? 1 : 0
  target_group_arn = module.public_nlb[0].prometheus_target_group_arn
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

###############################################################################
# GCP compute (alternative target — only one cloud is active per run)
###############################################################################

module "emqx_gcp" {
  for_each              = local.cloud_is_gcp ? local.emqx_nodes : {}
  source                = "./modules/gce"
  region                = each.value.region
  zone                  = local.gcp_zone
  instance_name         = each.value.name
  instance_type         = each.value.instance_type
  hostname              = each.value.hostname
  image_family          = local.gcp_image_family
  image_project         = local.gcp_image_project
  subnetwork            = module.vpc_gcp[0].subnetwork
  network_tag           = module.vpc_gcp[0].network_tag
  service_account_email = local.gcp_service_account_email
  remote_user           = local.gcp_oslogin_user
  dns_zone_name         = google_dns_managed_zone.private[0].name
  root_volume_size      = local.emqx_root_volume_size
  attach_to_nlb         = each.value.attach_to_nlb
  certs                 = module.certs.certs
  depends_on = [
    google_project_iam_member.oslogin
  ]
}

module "loadgen_gcp" {
  for_each              = local.cloud_is_gcp ? local.loadgen_nodes : {}
  source                = "./modules/gce"
  region                = each.value.region
  zone                  = local.gcp_zone
  type                  = each.value.type
  instance_name         = each.value.name
  instance_type         = each.value.instance_type
  hostname              = each.value.hostname
  image_family          = local.gcp_image_family
  image_project         = local.gcp_image_project
  subnetwork            = module.vpc_gcp[0].subnetwork
  network_tag           = module.vpc_gcp[0].network_tag
  service_account_email = local.gcp_service_account_email
  remote_user           = local.gcp_oslogin_user
  dns_zone_name         = google_dns_managed_zone.private[0].name
  certs                 = module.certs.certs
  depends_on = [
    google_project_iam_member.oslogin
  ]
}

module "monitoring_gcp" {
  count                 = local.cloud_is_gcp && local.monitoring_enabled ? 1 : 0
  source                = "./modules/gce"
  region                = local.gcp_region
  zone                  = local.gcp_zone
  instance_name         = "monitoring"
  instance_type         = local.monitoring_instance_type
  hostname              = local.monitoring_hostname
  image_family          = local.gcp_image_family
  image_project         = local.gcp_image_project
  subnetwork            = module.vpc_gcp[0].subnetwork
  network_tag           = module.vpc_gcp[0].network_tag
  service_account_email = local.gcp_service_account_email
  remote_user           = local.gcp_oslogin_user
  dns_zone_name         = google_dns_managed_zone.private[0].name
  root_volume_size      = local.monitoring_root_volume_size
  certs                 = module.certs.certs
  depends_on = [
    google_project_iam_member.oslogin
  ]
}
