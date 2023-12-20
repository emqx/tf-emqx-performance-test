module "public_nlb" {
  source     = "./modules/public_nlb"
  prefix     = local.prefix
  vpc_id     = local.vpcs[local.default_region].vpc_id
  subnet_ids = local.vpcs[local.default_region].public_subnet_ids
}

module "internal_nlb" {
  source     = "./modules/internal_nlb"
  prefix     = local.prefix
  vpc_id     = local.vpcs[local.default_region].vpc_id
  subnet_ids = local.vpcs[local.default_region].public_subnet_ids
  http_api_port = local.emqx_http_api_port
}

module "emqx" {
  for_each           = { for k, v in local.emqx_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[0]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  ami_filter         = local.emqx_ami_filter
  use_spot_instances = local.emqx_use_spot_instances
  root_volume_size   = local.emqx_root_volume_size
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
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
  for_each         = { for i, node in module.emqx : i => node if node.region == local.default_region }
  target_group_arn = module.public_nlb.emqx_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 18083
}

resource "aws_lb_target_group_attachment" "int-mqtt" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.default_region }
  target_group_arn = module.internal_nlb.mqtt_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 1883
}

resource "aws_lb_target_group_attachment" "int-httpapi" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.default_region }
  target_group_arn = module.internal_nlb.httpapi_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = local.emqx_http_api_port
}

module "emqttb" {
  for_each           = { for k, v in local.emqttb_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[0]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  ami_filter         = local.emqttb_ami_filter
  use_spot_instances = local.emqttb_use_spot_instances
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
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

module "emqtt-bench" {
  for_each           = { for k, v in local.emqtt_bench_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[0]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  ami_filter         = local.emqtt_bench_ami_filter
  use_spot_instances = local.emqtt_bench_use_spot_instances
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
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

module "locust" {
  for_each           = { for k, v in local.locust_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[0]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  ami_filter         = local.locust_ami_filter
  use_spot_instances = local.locust_use_spot_instances
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
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

module "monitoring" {
  source             = "./modules/ec2"
  region             = local.default_region
  instance_name      = "monitoring"
  instance_type      = local.monitoring_instance_type
  hostname           = local.monitoring_hostname
  subnet_id          = local.vpcs[local.default_region].public_subnet_ids[0]
  security_group_id  = local.vpcs[local.default_region].security_group_id
  ami_filter         = local.monitoring_ami_filter
  use_spot_instances = local.monitoring_use_spot_instances
  root_volume_size   = local.monitoring_root_volume_size
  prefix             = local.prefix
  region_aliases     = local.region_aliases
  route53_zone_id    = aws_route53_zone.vpc.zone_id
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
  target_group_arn = module.public_nlb.grafana_target_group_arn
  target_id        = module.monitoring.private_ips[0]
  port             = 3000
}

resource "aws_lb_target_group_attachment" "prometheus" {
  target_group_arn = module.public_nlb.prometheus_target_group_arn
  target_id        = module.monitoring.private_ips[0]
  port             = 9090
}

resource "aws_lb_target_group_attachment" "locust" {
  for_each         = { for i, node in module.locust : i => node if local.locust_nodes[node.fqdn].role == "leader"}
  target_group_arn = module.public_nlb.locust_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 8080
}

resource "local_file" "ansible_cfg" {
  content = templatefile("${path.module}/templates/ansible.cfg.tpl",
    {
      private_key_file = local.ssh_key_path
      remote_user      = "ubuntu"
  })
  filename = "${path.module}/ansible.cfg"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tpl",
    {
      emqx_nodes        = [for node in module.emqx : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      emqttb_nodes      = [for node in module.emqttb : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      emqtt_bench_nodes = [for node in module.emqtt-bench : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      locust_nodes      = [for node in module.locust : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      monitoring_nodes  = ["${module.monitoring.fqdn} ansible_host=${module.monitoring.public_ips[0]} private_ip=${module.monitoring.private_ips[0]}"]
      emqx_version_family = local.emqx_version_family
  })
  filename = "${path.module}/ansible/inventory.ini"
}

resource "local_file" "ansible_common_group_vars" {
  content = yamlencode({
    node_exporter_enabled_collectors = [
      "buddyinfo",
      "cpu",
      "diskstats",
      "ethtool",
      "filefd",
      "filesystem",
      "loadavg",
      "meminfo",
      "netdev",
      "netstat",
      "processes",
      "sockstat",
      "stat",
      "systemd",
      "tcpstat",
      "time",
      "uname",
      "vmstat"
    ]
    deb_architecture_map = {
      "armv6l" : "armhf",
      "armv7l" : "armhf",
      "aarch64" : "arm64",
      "x86_64" : "amd64",
      "i386" : "i386"
    }
  })
  filename = "${path.module}/ansible/group_vars/all.yml"
}

resource "local_file" "ansible_emqx_group_vars" {
  content = yamlencode({
    emqx_install_source                  = local.emqx_install_source,
    emqx_package_download_url            = try(local.spec.emqx.package_download_url, ""),
    emqx_package_file_path               = try(local.spec.emqx.package_file_path, ""),
    emqx_cluster_discovery_strategy      = try(local.spec.emqx.cluster_discovery_strategy, "static"),
    emqx_cluster_static_seeds            = try(local.spec.emqx.cluster_static_seeds, local.emqx_static_seeds),
    emqx_cluster_dns_name                = local.cluster_dns_name,
    emqx_cluster_dns_record_type         = try(local.spec.emqx.cluster_dns_record_type, "srv"),
    emqx_prometheus_enabled              = try(local.spec.emqx.prometheus_enabled, false),
    emqx_prometheus_push_gateway_server  = "http://${local.monitoring_hostname}:9091",
    emqx_log_console_handler_level       = try(local.spec.emqx.log_console_handler_level, "info"),
    emqx_log_file_handlers_default_level = try(local.spec.emqx.log_file_handlers_default_level, "info"),
    emqx_dashboard_default_password      = local.emqx_dashboard_default_password,
    emqx_api_key                         = local.emqx_api_key,
    emqx_api_secret                      = local.emqx_api_secret,
    emqx_bootstrap_api_keys              = local.emqx_bootstrap_api_keys,
    emqx_license_file                    = local.emqx_license_file,
  })
  filename = "${path.module}/ansible/group_vars/emqx${local.emqx_version_family}.yml"
}

resource "local_file" "ansible_emqx_host_vars" {
  for_each = { for i, node in module.emqx : i => node }
  content = yamlencode({
    emqx_node_name = "emqx@${each.value.fqdn}",
    emqx_node_role = local.emqx_nodes[each.value.fqdn].role,
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_emqttb_group_vars" {
  content = yamlencode({
    emqttb_package_download_url = try(local.spec.emqttb.package_download_url, ""),
    emqttb_package_file_path    = try(local.spec.emqttb.package_file_path, ""),
    emqttb_targets              = [for node in module.emqx : node.fqdn]
    grafana_url                 = "http://${module.monitoring.fqdn}:3000"
    prometheus_push_gw_url      = "http://${module.monitoring.fqdn}:9091"
  })
  filename = "${path.module}/ansible/group_vars/emqttb.yml"
}

resource "local_file" "ansible_emqttb_host_vars" {
  for_each = { for i, node in module.emqttb : i => node }
  content = yamlencode({
    emqttb_scenario = local.emqttb_nodes[each.value.fqdn].scenario,
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_emqtt_bench_group_vars" {
  content = yamlencode({
    emqtt_bench_package_download_url = try(local.spec.emqtt_bench.package_download_url, ""),
    emqtt_bench_package_file_path    = try(local.spec.emqtt_bench.package_file_path, ""),
    emqtt_bench_targets              = [for node in module.emqx : node.fqdn]
  })
  filename = "${path.module}/ansible/group_vars/emqtt_bench.yml"
}

resource "local_file" "ansible_emqtt_bench_host_vars" {
  for_each = { for i, node in module.emqtt-bench : i => node }
  content = yamlencode({
    emqtt_bench_scenario = local.emqtt_bench_nodes[each.value.fqdn].scenario,
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_locust_group_vars" {
  content = yamlencode({
    locust_package_download_url = try(local.spec.locust.package_download_url, ""),
    locust_package_file_path    = try(local.spec.locust.package_file_path, ""),
    locust_base_url             = "http://${module.internal_nlb.dns_name}:${local.emqx_http_api_port}/api/${local.emqx_api_version}"
    locust_version              = local.locust_version
  })
  filename = "${path.module}/ansible/group_vars/locust.yml"
}

locals {
  locust_leader = [for node in module.locust : node if local.locust_nodes[node.fqdn].role == "leader"]
}

resource "local_file" "ansible_locust_host_vars" {
  for_each = { for i, node in module.locust : i => node }
  content = yamlencode({
    locust_plan_entrypoint = local.locust_nodes[each.value.fqdn].plan_entrypoint,
    locust_role            = local.locust_nodes[each.value.fqdn].role,
    locust_leader_ip       = local.locust_leader[0].private_ips[0],
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_monitoring_group_vars" {
  content = yamlencode({
    emqx_version_family = local.emqx_version_family
  })
  filename = "${path.module}/ansible/group_vars/monitoring.yml"
}

resource "null_resource" "ansible_playbook" {
  depends_on = [
    module.emqx,
    module.emqttb,
    module.emqtt-bench,
    module.locust,
    module.monitoring,
    local_file.ansible_inventory,
    local_file.ansible_cfg,
    local_file.ansible_emqx_group_vars,
    local_file.ansible_emqx_host_vars,
    local_file.ansible_emqttb_group_vars,
    local_file.ansible_emqttb_host_vars,
    local_file.ansible_emqtt_bench_group_vars,
    local_file.ansible_emqtt_bench_host_vars,
    local_file.ansible_locust_group_vars,
    local_file.ansible_locust_host_vars
  ]

  provisioner "local-exec" {
    command = "ansible-galaxy collection install -r ansible/requirements.yml"
  }
  provisioner "local-exec" {
    command = "ansible-galaxy role install -r ansible/requirements.yml"
  }
  provisioner "local-exec" {
    command = "ansible-playbook ansible/playbook.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

