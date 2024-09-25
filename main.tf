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

resource "local_file" "ansible_inventory" {
  content = yamlencode({
    all = {
      hosts = merge(
        { for node in module.emqx : node.fqdn => {
          ansible_host = node.public_ips[0]
          private_ip   = node.private_ips[0]
          ansible_user = local.emqx_remote_user
        } },
        { for node in module.loadgen : node.fqdn => {
          ansible_host = node.public_ips[0]
          private_ip   = node.private_ips[0]
          ansible_user = local.loadgen_remote_user
        } },
        { for node in module.integration : node.fqdn => {
          ansible_host = node.public_ips[0]
          private_ip   = node.private_ips[0]
          ansible_user = local.integration_remote_user
        } },
        { for node in module.monitoring : node.fqdn => {
          ansible_host = node.public_ips[0]
          private_ip   = node.private_ips[0]
          ansible_user = local.monitoring_remote_user
        } }
      )
    }
    emqx4       = { hosts = { for node in module.emqx : node.fqdn => {} if local.emqx_version_family == 4 } }
    emqx5       = { hosts = { for node in module.emqx : node.fqdn => {} if local.emqx_version_family == 5 } }
    emqx        = { children = { emqx4 = {}, emqx5 = {} } }
    emqttb      = { hosts = { for node in module.loadgen : node.fqdn => {} if node.type == "emqttb" } }
    emqtt_bench = { hosts = { for node in module.loadgen : node.fqdn => {} if node.type == "emqtt_bench" } }
    locust      = { hosts = { for node in module.loadgen : node.fqdn => {} if node.type == "locust" } }
    loadgen     = { children = { emqttb = {}, emqtt_bench = {}, locust = {} } }
    http        = { hosts = { for node in module.integration : node.fqdn => {} if node.type == "http" } }
    rabbitmq    = { hosts = { for node in module.integration : node.fqdn => {} if node.type == "rabbitmq" } }
    integration = { children = { http = {}, rabbitmq = {} } }
    monitoring  = { hosts = { for node in module.monitoring : node.fqdn => {} } }
  })
  filename = "${path.module}/ansible/inventory.yml"
}

locals {
  http_nodes       = [for node in module.integration : node if node.type == "http"]
  rabbitmq_nodes   = [for node in module.integration : node if node.type == "rabbitmq"]
  oracle_rds_nodes = [for _, node in module.oracle-rds : node]
}

resource "local_file" "ansible_common_group_vars" {
  content = yamlencode({
    emqx_version_family              = local.emqx_version_family
    emqx_dashboard_url               = "http://${module.public_nlb.dns_name}:18083"
    node_exporter_enabled_collectors = var.node_exporter_enabled_collectors
    deb_architecture_map             = var.deb_architecture_map
    ansible_ssh_private_key_file     = local.ssh_key_path
    emqx_script_env = {
      EMQX_ADMIN_PASSWORD = local.emqx_dashboard_default_password
      HTTP_SERVER_URL     = length(local.http_nodes) > 0 ? "http://${[for x in local.http_nodes : x.fqdn][0]}" : ""
      RABBITMQ_SERVER     = length(local.rabbitmq_nodes) > 0 ? "${[for x in local.rabbitmq_nodes : x.fqdn][0]}" : ""
      ORACLE_SERVER       = length(local.oracle_rds_nodes) > 0 ? local.oracle_rds_nodes[0].fqdn : ""
      ORACLE_PORT         = length(local.oracle_rds_nodes) > 0 ? local.oracle_rds_nodes[0].port : ""
      ORACLE_TLS_PORT     = length(local.oracle_rds_nodes) > 0 ? local.oracle_rds_nodes[0].tls_port : ""
      ORACLE_DB_USERNAME  = length(local.oracle_rds_nodes) > 0 ? local.oracle_rds_nodes[0].username : ""
      ORACLE_DB_PASSWORD  = length(local.oracle_rds_nodes) > 0 ? local.oracle_rds_nodes[0].password : ""
    }
  })
  filename = "${path.module}/ansible/group_vars/all.yml"
}

resource "local_file" "ansible_emqx_group_vars" {
  content = yamlencode(merge({
    emqx_install_source                  = try(local.spec.emqx.install_source, "package")
    emqx_package_download_url            = try(local.spec.emqx.package_download_url, "")
    emqx_package_file_path               = try(local.spec.emqx.package_file_path, "")
    emqx_git_repo                        = try(local.spec.emqx.git_repo, "https://github.com/emqx/emqx.git")
    emqx_git_ref                         = try(local.spec.emqx.git_ref, "master")
    emqx_edition                         = try(local.spec.emqx.edition, "emqx")
    emqx_builder_image                   = try(local.spec.emqx.builder_image, "ghcr.io/emqx/emqx-builder/5.3-9:1.15.7-26.2.5-3-ubuntu22.04")
    emqx_cluster_discovery_strategy      = try(local.spec.emqx.cluster_discovery_strategy, "static")
    emqx_cluster_static_seeds            = try(local.spec.emqx.cluster_static_seeds, local.emqx_static_seeds)
    emqx_cluster_dns_name                = local.emqx_cluster_dns_name
    emqx_cluster_dns_record_type         = try(local.spec.emqx.cluster_dns_record_type, "srv")
    emqx_prometheus_enabled              = try(local.spec.emqx.prometheus_enabled, false)
    emqx_prometheus_push_gateway_server  = "http://${local.monitoring_hostname}:9091"
    emqx_log_console_handler_level       = try(local.spec.emqx.log_console_handler_level, "info")
    emqx_log_file_handlers_default_level = try(local.spec.emqx.log_file_handlers_default_level, "info")
    emqx_api_key                         = try(local.spec.emqx.api_key, "perftest")
    emqx_api_secret                      = try(local.spec.emqx.api_secret, "perftest")
    emqx_bootstrap_api_keys = [
      {
        key    = try(local.spec.emqx.api_key, "perftest")
        secret = try(local.spec.emqx.api_secret, "perftest")
      }
    ]
    emqx_license_file               = try(local.spec.emqx.license_file, "") == "" ? "" : pathexpand(local.spec.emqx.license_file)
    emqx_license                    = try(local.spec.emqx.license_file, "") == "" ? "" : file(pathexpand(local.spec.emqx.license_file))
    emqx_scripts                    = try(local.spec.emqx.scripts, [])
    emqx_version                    = local.emqx_version
    emqx_dashboard_default_password = local.emqx_dashboard_default_password
    emqx_data_dir                   = try(local.spec.emqx.data_dir, "/var/lib/emqx")
    emqx_durable_sessions_enabled   = try(local.spec.emqx.durable_sessions_enabled, false)
    emqx_enable_perf                = try(local.spec.emqx.enable_perf, false)
    },
    try({ emqx_durable_sessions_batch_size = local.spec.emqx.durable_sessions_batch_size }, {}),
    try({ emqx_durable_sessions_idle_poll_interval = local.spec.emqx.durable_sessions_idle_poll_interval }, {}),
    try({ emqx_durable_sessions_heartbeat_interval = local.spec.emqx.durable_sessions_heartbeat_interval }, {}),
    try({ emqx_durable_sessions_renew_streams_interval = local.spec.emqx.durable_sessions_renew_streams_interval }, {}),
    try({ emqx_durable_sessions_gc_interval = local.spec.emqx.durable_sessions_gc_interval }, {}),
    try({ emqx_durable_sessions_gc_batch_size = local.spec.emqx.durable_sessions_gc_batch_size }, {}),
    try({ emqx_durable_sessions_message_retention_period = local.spec.emqx.durable_sessions_message_retention_period }, {}),
    try({ emqx_durable_sessions_force_persistence = local.spec.emqx.durable_sessions_force_persistence }, {}),
    try({ emqx_durable_storage_backend = local.spec.emqx.durable_storage_backend }, {}),
    try({ emqx_durable_storage_storage_layout = local.spec.emqx.durable_storage_storage_layout }, {}),
    try({ emqx_durable_storage_data_dir = local.spec.emqx.durable_storage_data_dir }, {}),
    try({ emqx_durable_storage_n_shards = local.spec.emqx.durable_storage_n_shards }, {}),
    try({ emqx_durable_storage_n_sites = local.spec.emqx.durable_storage_n_sites }, {}),
    try({ emqx_durable_storage_replication_factor = local.spec.emqx.durable_storage_replication_factor }, {}),
    local.monitoring_enabled ? { grafana_url = "http://${module.monitoring[0].fqdn}:3000", prometheus_push_gw_url = "http://${module.monitoring[0].fqdn}:9091", loki_url = "http://${module.monitoring[0].fqdn}:3100" } : {}
    ))
  filename = "${path.module}/ansible/group_vars/emqx${local.emqx_version_family}.yml"
}

resource "local_file" "ansible_emqx_host_vars" {
  for_each = { for i, node in module.emqx : i => node }
  content = yamlencode({
    emqx_node_name = "emqx@${each.value.fqdn}"
    emqx_node_role = local.emqx_nodes[each.value.fqdn].role
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_loadgen_group_vars" {
  count = length(module.loadgen) > 0 ? 1 : 0
  content = yamlencode(merge({
    loadgen_targets = local.loadgen_use_nlb ? [module.internal_nlb.dns_name] : [for node in module.emqx : node.fqdn]
    },
    local.monitoring_enabled ? { grafana_url = "http://${module.monitoring[0].fqdn}:3000", prometheus_push_gw_url = "http://${module.monitoring[0].fqdn}:9091", loki_url = "${module.monitoring[0].fqdn}:3100" } : {},
    try({ emqttb_options = local.spec.loadgens.emqttb_options }, {}),
    try({ emqtt_bench_options = local.spec.loadgens.emqtt_bench_options }, {}),
    try({ locust_options = local.spec.loadgens.locust_options }, {})
  ))

  filename = "${path.module}/ansible/group_vars/loadgen.yml"
}

resource "local_file" "ansible_loadgen_host_vars" {
  for_each = { for i, node in module.loadgen : i => node }
  content = yamlencode({
    loadgen_scenario         = local.loadgen_nodes[each.value.fqdn].scenario
    loadgen_payload_template = local.loadgen_nodes[each.value.fqdn].payload_template
    loadgen_role             = local.loadgen_nodes[each.value.fqdn].role
  })
  filename = "${path.module}/ansible/host_vars/${each.value.fqdn}.yml"
}

resource "local_file" "ansible_locust_group_vars" {
  count = length([for n in module.loadgen : n if n.type == "locust"]) > 0 ? 1 : 0
  content = yamlencode({
    locust_leader_ip = [for n in module.loadgen : n.private_ips[0] if n.type == "locust" && local.loadgen_nodes[n.fqdn].role == "leader"][0]
    locust_base_url  = "http://${module.internal_nlb.dns_name}:${local.emqx_http_api_port}/api/${local.emqx_api_version}"
  })
  filename = "${path.module}/ansible/group_vars/locust.yml"
}

resource "terraform_data" "ansible_init" {
  depends_on = [
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = "ansible-galaxy collection install -r ansible/requirements.yml"
  }
  provisioner "local-exec" {
    command = "ansible-galaxy role install -r ansible/requirements.yml"
  }
}

resource "terraform_data" "ansible_playbook_http" {
  depends_on = [
    module.integration,
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/http.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "terraform_data" "ansible_playbook_rabbitmq" {
  depends_on = [
    module.integration,
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/rabbitmq.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "terraform_data" "ansible_playbook_emqx" {
  depends_on = [
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars,
    local_file.ansible_emqx_group_vars,
    local_file.ansible_emqx_host_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/emqx.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "terraform_data" "ansible_playbook_loadgen" {
  depends_on = [
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars,
    local_file.ansible_loadgen_group_vars,
    local_file.ansible_locust_group_vars,
    local_file.ansible_loadgen_host_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/loadgen.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "terraform_data" "ansible_playbook_tuning" {
  depends_on = [
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/tuning.yml"
  }
}

resource "terraform_data" "ansible_playbook_monitoring" {
  depends_on = [
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/monitoring.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "terraform_data" "ansible_playbook_node_exporter" {
  depends_on = [
    terraform_data.ansible_init,
    local_file.ansible_common_group_vars
  ]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/node_exporter.yml"
    environment = {
      no_proxy = "*"
    }
  }
}
