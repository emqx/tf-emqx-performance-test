module "public_nlb" {
  source     = "./modules/public_nlb"
  prefix     = local.prefix
  vpc_id     = local.vpcs[local.default_region].vpc_id
  subnet_ids = local.vpcs[local.default_region].public_subnet_ids
  providers = {
    aws = aws.default
  }
}

module "internal_nlb" {
  source        = "./modules/internal_nlb"
  prefix        = local.prefix
  vpc_id        = local.vpcs[local.default_region].vpc_id
  subnet_ids    = local.vpcs[local.default_region].public_subnet_ids
  http_api_port = local.emqx_http_api_port
  providers = {
    aws = aws.default
  }
}

module "emqx" {
  for_each           = { for k, v in local.emqx_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  vpc_id             = local.vpcs[each.value.region].vpc_id
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
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "emqx-api" {
  for_each         = local.emqx_version_family == 4 ? { for i, node in module.emqx : i => node if node.region == local.default_region } : {}
  target_group_arn = module.public_nlb.emqx_api_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 8081
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mqtt" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.default_region }
  target_group_arn = module.internal_nlb.mqtt_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 1883
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-httpapi" {
  for_each         = { for i, node in module.emqx : i => node if node.region == local.default_region }
  target_group_arn = module.internal_nlb.httpapi_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = local.emqx_http_api_port
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "int-mgmt" {
  for_each         = local.emqx_version_family == 4 ? { for i, node in module.emqx : i => node if node.region == local.default_region } : {}
  target_group_arn = module.internal_nlb.mgmt_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 18083
  provider         = aws.default
}

module "emqttb" {
  for_each           = { for k, v in local.emqttb_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  vpc_id             = local.vpcs[each.value.region].vpc_id
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
  ip_alias_count     = try(each.value.ip_alias_count, 0)
  vpc_id             = local.vpcs[each.value.region].vpc_id
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
  vpc_id             = local.vpcs[each.value.region].vpc_id
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

resource "aws_lb_target_group_attachment" "locust" {
  for_each         = { for i, node in module.locust : i => node if node.region == local.default_region }
  target_group_arn = module.public_nlb.locust_target_group_arn
  target_id        = each.value.private_ips[0]
  port             = 8080
  provider         = aws.default
}

module "http" {
  for_each           = { for k, v in local.http_nodes : k => v }
  source             = "./modules/ec2"
  region             = each.value.region
  instance_name      = each.value.name
  instance_type      = each.value.instance_type
  hostname           = each.value.hostname
  vpc_id             = local.vpcs[each.value.region].vpc_id
  subnet_id          = local.vpcs[each.value.region].public_subnet_ids[0]
  security_group_id  = local.vpcs[each.value.region].security_group_id
  ami_filter         = local.http_ami_filter
  use_spot_instances = local.http_use_spot_instances
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
  vpc_id             = local.vpcs[local.default_region].vpc_id
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
  provider         = aws.default
}

resource "aws_lb_target_group_attachment" "prometheus" {
  target_group_arn = module.public_nlb.prometheus_target_group_arn
  target_id        = module.monitoring.private_ips[0]
  port             = 9090
  provider         = aws.default
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
      emqx_nodes          = [for node in module.emqx : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      emqttb_nodes        = [for node in module.emqttb : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      emqtt_bench_nodes   = [for node in module.emqtt-bench : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      locust_nodes        = [for node in module.locust : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      http_nodes          = [for node in module.http : "${node.fqdn} ansible_host=${node.public_ips[0]} private_ip=${node.private_ips[0]}"]
      monitoring_nodes    = ["${module.monitoring.fqdn} ansible_host=${module.monitoring.public_ips[0]} private_ip=${module.monitoring.private_ips[0]}"]
      emqx_version_family = local.emqx_version_family
  })
  filename = "${path.module}/ansible/inventory.ini"
}

resource "local_file" "ansible_common_group_vars" {
  content = yamlencode({
    node_exporter_enabled_collectors = var.node_exporter_enabled_collectors
    deb_architecture_map = var.deb_architecture_map
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
    emqx_version_family                  = local.emqx_version_family,
    emqx_package_version                 = local.emqx_package_version,
    emqx_scripts                         = local.emqx_scripts,
    http_server_url                      = length(module.http) > 0 ? "http://${[for x in module.http: x.fqdn][0]}" : "",
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
  count = length(module.locust)
  content = yamlencode({
    locust_version                       = local.locust_version
    locust_leader_ip                     = local.locust_leader[0].private_ips[0],
    locust_topics_count                  = local.locust_topics_count
    locust_unsubscribe_client_batch_size = local.locust_unsubscribe_client_batch_size
    locust_max_client_id                 = local.locust_max_client_id
    locust_client_prefix_list            = local.locust_client_prefix_list
    locust_users                         = local.locust_users
    locust_payload_size                  = local.locust_payload_size
    locust_base_url                      = "http://${module.internal_nlb.dns_name}:${local.emqx_http_api_port}/api/${local.emqx_api_version}"
    locust_emqx_dashboard_url            = "http://${module.public_nlb.dns_name}:18083"
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
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_monitoring_group_vars" {
  content = yamlencode({
    emqx_version_family = local.emqx_version_family
  })
  filename = "${path.module}/ansible/group_vars/monitoring.yml"
}

resource "null_resource" "ansible_playbook_common" {
  depends_on = [
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
    command = "ansible-playbook ansible/common.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_node_exporter" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/node_exporter.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_monitoring" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/monitoring.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_http" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/http.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_emqx" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/emqx.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_emqttb" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/emqttb.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_emqtt_bench" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/emqtt_bench.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_playbook_locust" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/locust.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "null_resource" "ansible_ensure_kernel_tuning" {
  depends_on = [
    null_resource.ansible_playbook_common
  ]
  provisioner "local-exec" {
    command = "ansible all -m command -a 'sysctl --load=/etc/sysctl.d/perftest.conf' --become"
  }
}
