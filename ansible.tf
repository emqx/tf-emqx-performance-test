locals {
  http_nodes       = [for node in module.integration : node if node.type == "http"]
  rabbitmq_nodes   = [for node in module.integration : node if node.type == "rabbitmq"]
  oracle_rds_nodes = [for _, node in module.oracle-rds : node]
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

resource "local_file" "ansible_common_group_vars" {
  content = yamlencode({
    emqx_version_family              = local.emqx_version_family
    emqx_dashboard_url               = "http://${module.public_nlb.dns_name}:18083"
    emqx_dashboard_default_password  = local.emqx_dashboard_default_password
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
    emqx_env_override               = local.emqx_env_override
    emqx_data_dir                   = try(local.spec.emqx.data_dir, "/var/lib/emqx")
    emqx_enable_perf                = try(local.spec.emqx.enable_perf, false)
    emqx_extra_config               = local.emqx_version_family == 5 ? try(local.spec.emqx.extra_config, "") : ""
    },
    try({ emqx_durable_storage_data_dir = local.spec.emqx.durable_storage_data_dir }, {}),
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
    loadgen_targets = local.loadgen_use_nlb ? [module.internal_nlb.dns_name] : [for node in module.emqx : node.fqdn if node.attach_to_nlb ]
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
    loadgen_scenario           = local.loadgen_nodes[each.value.fqdn].scenario
    loadgen_payload_template   = local.loadgen_nodes[each.value.fqdn].payload_template
    loadgen_role               = local.loadgen_nodes[each.value.fqdn].role
    loadgen_startnumber        = local.loadgen_nodes[each.value.fqdn].startnumber
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
