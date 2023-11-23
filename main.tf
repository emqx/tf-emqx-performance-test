module "emqx-default" {
  for_each = {for node in local.emqx_nodes: node.name => node if node.region == local.default_region}
  source            = "./modules/ec2"
  instance_name     = each.key
  instance_type     = each.value.instance_type
  hostname          = each.value.hostname
  route53_zone_id   = aws_route53_zone.vpc.zone_id
  ami_filter        = local.emqx_ami_filter
  use_spot_instances = local.emqx_use_spot_instances
  root_volume_size  = local.emqx_root_volume_size
  namespace         = var.namespace
  iam_profile       = module.ec2-profile-default.iam_profile
  key_name          = module.vpc-default.key_name
  subnet_id         = module.vpc-default.public_subnet_ids[0]
  sg_ids            = [module.vpc-default.security_group_id]
  providers = {
    aws = aws.default
  }
}

module "emqx-region2" {
  for_each = {for node in local.emqx_nodes: node.name => node if node.region == local.region2}
  source            = "./modules/ec2"
  instance_name     = each.key
  instance_type     = each.value.instance_type
  hostname          = each.value.hostname
  route53_zone_id   = aws_route53_zone.vpc.zone_id
  ami_filter        = local.emqx_ami_filter
  use_spot_instances = local.emqx_use_spot_instances
  root_volume_size  = local.emqx_root_volume_size
  namespace         = var.namespace
  iam_profile       = module.ec2-profile-region2[0].iam_profile
  key_name          = module.vpc-region2[0].key_name
  subnet_id         = module.vpc-region2[0].public_subnet_ids[0]
  sg_ids            = [module.vpc-region2[0].security_group_id]
  providers = {
    aws = aws.region2
  }
}

module "emqx-region3" {
  for_each = {for node in local.emqx_nodes: node.name => node if node.region == local.region3}
  source            = "./modules/ec2"
  instance_name     = each.key
  instance_type     = each.value.instance_type
  hostname          = each.value.hostname
  route53_zone_id   = aws_route53_zone.vpc.zone_id
  ami_filter        = local.emqx_ami_filter
  use_spot_instances = local.emqx_use_spot_instances
  root_volume_size  = local.emqx_root_volume_size
  namespace         = var.namespace
  iam_profile       = module.ec2-profile-region3[0].iam_profile
  key_name          = module.vpc-region3[0].key_name
  subnet_id         = module.vpc-region3[0].public_subnet_ids[0]
  sg_ids            = [module.vpc-region3[0].security_group_id]
  providers = {
    aws = aws.region3
  }
}


# module "emqx_mqtt_int_nlb" {
#   count               = var.internal_mqtt_nlb_count
#   source              = "./modules/emqx_mqtt_int_nlb"
#   vpc_id              = module.vpc.vpc_id
#   namespace           = var.namespace
#   nlb_name            = "${var.namespace}-nlb-${count.index}"
#   tg_name             = "${var.namespace}-tg-${count.index}"
#   region              = var.region
#   subnet_ids          = module.vpc.public_subnet_ids
#   instance_count      = var.emqx_nodes
#   instance_ids        = module.emqx_core.instance_ids
#   route53_zone_id     = aws_route53_zone.int.zone_id
#   route53_zone_name   = local.int_route53_zone_name
# }

module "public_nlb" {
  source              = "./modules/public_nlb"
  vpc_id              = module.vpc-default.vpc_id
  prefix              = local.prefix
  subnet_ids          = module.vpc-default.public_subnet_ids
  emqx_instance_ips   = [for x in module.emqx-default: x.private_ip]
  monitoring_instance_ip = module.monitoring.private_ip
}

# module "emqttb" {
#   source            = "./modules/emqttb"
#   ami_filter        = local.ami_filter
#   s3_bucket_name    = var.s3_bucket_name
#   bench_id          = local.bench_id
#   package_url       = var.emqttb_package_url
#   namespace         = var.namespace
#   instance_type     = var.emqttb_instance_type
#   instance_count    = var.emqttb_nodes
#   scenario          = var.emqttb_scenario
#   sg_ids            = [module.vpc-eu-west-1.security_group_id]
#   emqx_hosts        = concat(module.emqx_core.private_ips, module.emqx_replicant.private_ips)
#   iam_profile       = module.ec2_profile.iam_profile
#   route53_zone_id   = aws_route53_zone.int.zone_id
#   route53_zone_name = local.int_route53_zone_name
#   test_duration     = var.duration
#   key_name          = module.vpc-eu-west-1.key_name
#   subnet_id         = module.vpc-eu-west-1.public_subnet_ids[0]
#   grafana_url       = module.monitoring.grafana_url
#   prometheus_push_gw_url = module.monitoring.push_gw_url
#   start_n_multiplier = var.emqttb_start_n_multiplier
#   providers = {
#     aws = aws.eu-west-1
#   }
# }

module "emqttb-default" {
  for_each = {for node in local.emqttb_nodes: node.name => node if node.region == local.default_region}
  source            = "./modules/ec2"
  instance_name     = each.key
  instance_type     = each.value.instance_type
  hostname          = each.value.hostname
  route53_zone_id   = aws_route53_zone.vpc.zone_id
  ami_filter        = local.emqttb_ami_filter
  use_spot_instances = local.emqttb_use_spot_instances
  namespace         = var.namespace
  iam_profile       = module.ec2-profile-default.iam_profile
  key_name          = module.vpc-default.key_name
  subnet_id         = module.vpc-default.public_subnet_ids[0]
  sg_ids            = [module.vpc-default.security_group_id]
  providers = {
    aws = aws.default
  }
}

module "emqtt-bench-default" {
  for_each = {for node in local.emqtt_bench_nodes: node.name => node if node.region == local.default_region}
  source            = "./modules/ec2"
  instance_name     = each.key
  instance_type     = each.value.instance_type
  hostname          = each.value.hostname
  route53_zone_id   = aws_route53_zone.vpc.zone_id
  ami_filter        = local.emqtt_bench_ami_filter
  use_spot_instances = local.emqtt_bench_use_spot_instances
  namespace         = var.namespace
  iam_profile       = module.ec2-profile-default.iam_profile
  key_name          = module.vpc-default.key_name
  subnet_id         = module.vpc-default.public_subnet_ids[0]
  sg_ids            = [module.vpc-default.security_group_id]
  providers = {
    aws = aws.default
  }
}

# module "emqx_mqtt_int_nlb" {
#   count               = var.internal_mqtt_nlb_count
#   source              = "./modules/emqx_mqtt_int_nlb"
#   vpc_id              = module.vpc.vpc_id
#   namespace           = var.namespace
#   nlb_name            = "${var.namespace}-nlb-${count.index}"
#   tg_name             = "${var.namespace}-tg-${count.index}"
#   region              = var.region
#   subnet_ids          = module.vpc.public_subnet_ids
#   instance_count      = var.emqx_nodes
#   instance_ids        = module.emqx_core.instance_ids
#   route53_zone_id     = aws_route53_zone.int.zone_id
#   route53_zone_name   = local.int_route53_zone_name
# }

module "monitoring" {
  source            = "./modules/ec2"
  instance_name     = "monitoring"
  instance_type     = local.monitoring_instance_type
  hostname          = local.monitoring_hostname
  route53_zone_id   = aws_route53_zone.vpc.zone_id
  ami_filter        = local.monitoring_ami_filter
  use_spot_instances = local.monitoring_use_spot_instances
  root_volume_size  = local.monitoring_root_volume_size
  namespace         = var.namespace
  iam_profile       = module.ec2-profile-default.iam_profile
  key_name          = module.vpc-default.key_name
  subnet_id         = module.vpc-default.public_subnet_ids[0]
  sg_ids            = [aws_security_group.monitoring-sg.id]

  providers = {
    aws = aws.default
  }
}

resource "random_string" "random" {
  length  = 8
  special = false
  upper   = false
}

resource "local_file" "ansible_cfg" {
  content = templatefile("${path.module}/templates/ansible.cfg.tpl",
    {
      private_key_file = local.ssh_key_path
      remote_user = "ubuntu"
    })
  filename = "${path.module}/ansible.cfg"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.ini.tpl",
    {
      emqx_nodes = concat(
        [for node in module.emqx-default: "${node.fqdn} ansible_host=${node.public_ip}"],
        [for node in module.emqx-region2: "${node.fqdn} ansible_host=${node.public_ip}"],
        [for node in module.emqx-region3: "${node.fqdn} ansible_host=${node.public_ip}"]
      )
      emqttb_nodes = concat(
        [for node in module.emqttb-default: "${node.fqdn} ansible_host=${node.public_ip}"]
      )
      emqtt_bench_nodes = concat(
        [for node in module.emqtt-bench-default: "${node.fqdn} ansible_host=${node.public_ip}"]
      )
      monitoring_nodes = ["${module.monitoring.fqdn} ansible_host=${module.monitoring.public_ip}"]
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
      "armv6l": "armhf",
      "armv7l": "armhf",
      "aarch64": "arm64",
      "x86_64": "amd64",
      "i386": "i386"
    }
  })
  filename = "${path.module}/ansible/group_vars/all.yml"
}

resource "local_file" "ansible_emqx_group_vars" {
  content = yamlencode({
    emqx_install_source = local.emqx_install_source,
    emqx_package_download_url = try(local.spec.emqx.package_download_url, ""),
    emqx_package_file_path = try(local.spec.emqx.package_file_path, ""),
    emqx_cluster_discovery_strategy = try(local.spec.emqx.cluster_discovery_strategy, "static"),
    emqx_cluster_static_seeds = try(local.spec.emqx.cluster_static_seeds, local.emqx_static_seeds),
    emqx_cluster_dns_name = local.cluster_dns_name,
    emqx_cluster_dns_record_type = try(local.spec.emqx.cluster_dns_record_type, "srv"),
    emqx_prometheus_enable = try(local.spec.emqx.prometheus_enable, true),
    # emqx_prometheus_push_gateway_server = "http://${local.monitoring_hostname}:9091",
    emqx_log_console_handler_level = try(local.spec.emqx.log_console_handler_level, "info"),
    emqx_log_file_handlers_default_level = try(local.spec.emqx.log_file_handlers_default_level, "info"),
    emqx_dashboard_default_password = local.emqx_dashboard_default_password,
    emqx_api_key = local.emqx_api_key,
    emqx_api_secret = local.emqx_api_secret,
    emqx_bootstrap_api_keys = local.emqx_bootstrap_api_keys,
  })
  filename = "${path.module}/ansible/group_vars/emqx.yml"
}

resource "local_file" "ansible_emqx_host_vars" {
  for_each = {for node in local.emqx_nodes: node.name => node}
  content = yamlencode({
    emqx_node_name = "emqx@${each.value.hostname}",
    emqx_node_role = each.value.role
  })
  filename = "${path.module}/ansible/host_vars/${each.value.hostname}.yml"
}

resource "local_file" "ansible_emqttb_group_vars" {
  content = yamlencode({
    emqttb_package_download_url = try(local.spec.emqttb.package_download_url, ""),
    emqttb_package_file_path = try(local.spec.emqttb.package_file_path, ""),
    emqttb_targets = concat(
        [for node in module.emqx-default: node.fqdn],
        [for node in module.emqx-region2: node.fqdn],
        [for node in module.emqx-region3: node.fqdn]
      )
    grafana_url = "http://${module.monitoring.fqdn}:3000"
    prometheus_push_gw_url = "http://${module.monitoring.fqdn}:9091"
  })
  filename = "${path.module}/ansible/group_vars/emqttb.yml"
}

resource "local_file" "ansible_emqttb_host_vars" {
  for_each = {for node in local.emqttb_nodes: node.name => node}
  content = yamlencode({
    emqttb_scenario = each.value.scenario
  })
  filename = "${path.module}/ansible/host_vars/${each.value.hostname}.yml"
}

resource "local_file" "ansible_emqtt_bench_group_vars" {
  content = yamlencode({
    emqtt_bench_package_download_url = try(local.spec.emqtt_bench.package_download_url, ""),
    emqtt_bench_package_file_path = try(local.spec.emqtt_bench.package_file_path, ""),
    emqtt_bench_targets = concat(
        [for node in module.emqx-default: node.fqdn],
        [for node in module.emqx-region2: node.fqdn],
        [for node in module.emqx-region3: node.fqdn]
      )
  })
  filename = "${path.module}/ansible/group_vars/emqtt_bench.yml"
}

resource "local_file" "ansible_emqtt_bench_host_vars" {
  for_each = {for node in local.emqtt_bench_nodes: node.name => node}
  content = yamlencode({
    emqtt_bench_scenario = each.value.scenario
  })
  filename = "${path.module}/ansible/host_vars/${each.value.hostname}.yml"
}

resource "local_file" "ansible_monitoring_group_vars" {
  content = yamlencode({
    prometheus_node_exporter_targets = concat(
      [for node in local.emqx_nodes: "${node.hostname}:9100"],
      [for node in local.emqttb_nodes: "${node.hostname}:9100"],
      [for node in local.emqtt_bench_nodes: "${node.hostname}:9100"]
      ),
    prometheus_emqx_targets = [for node in local.emqx_nodes: "${node.hostname}:18083"]
  })
  filename = "${path.module}/ansible/group_vars/monitoring.yml"
}

resource "null_resource" "ansible_playbook" {
  depends_on = [
    module.emqx-default,
    module.emqx-region2,
    module.emqx-region3,
    module.emqttb-default,
    module.emqtt-bench-default,
    module.monitoring,
    local_file.ansible_inventory,
    local_file.ansible_cfg,
    local_file.ansible_emqx_group_vars,
    local_file.ansible_emqx_host_vars,
    local_file.ansible_emqttb_group_vars,
    local_file.ansible_emqttb_host_vars,
    local_file.ansible_emqtt_bench_group_vars,
    local_file.ansible_emqtt_bench_host_vars
  ]

  provisioner "local-exec" {
    command = "ansible-galaxy collection install -r ansible/requirements.yml"
  }
  provisioner "local-exec" {
    command = "ansible-playbook ansible/playbook.yml"
    environment = {
      no_proxy = "*"
    }
  }
}

resource "aws_security_group" "monitoring-sg" {
  name        = "${local.prefix}-monitoring-instance-sg"
  description = "Allow all inbound traffic within sg, within VPC, external SSH access and all outbound traffic"
  vpc_id      = module.vpc-default.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    self             = true
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [var.vpc_cidr]
  }

  ingress {
    from_port        = 3000
    to_port          = 3000
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 9090
    to_port          = 9090
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
