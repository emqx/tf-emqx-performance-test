locals {
  spec              = yamldecode(file(var.spec_file))
  bench_id          = local.spec.id
  prefix            = local.bench_id
  route53_zone_name = replace("${local.prefix}.emqx.io", "/", "-")
  ssh_key_name      = local.prefix
  ssh_key_path      = pathexpand(format("./%s.pem", replace(local.ssh_key_name, "/", "-")))

  region             = try(local.spec.region, "eu-north-1")
  instance_type      = try(local.spec.instance_type, "t3.large")
  ami_filter         = try(local.spec.ami_filter, "*ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*")
  ami_owner          = try(local.spec.ami_owner, "099720109477")
  remote_user        = try(local.spec.remote_user, "ubuntu")
  use_spot_instances = try(local.spec.use_spot_instances, true)
  enable_ipv6        = try(local.spec.enable_ipv6, false)

  # collect all regions from spec
  regions = distinct(concat(
    [local.region],
    [for node in try(local.spec.emqx.nodes, []) : try(node.region, local.region)],
    [for node in try(local.spec.loadgens.nodes, []) : try(node.region, local.region)],
    [for node in try(local.spec.integrations.nodes, []) : try(node.region, local.region)]
  ))

  region2 = length(local.regions) > 1 ? local.regions[1] : "region2-stub"
  region3 = length(local.regions) > 2 ? local.regions[2] : "region3-stub"

  region_aliases = {
    (local.region)  = "default"
    (local.region2) = "region2"
    (local.region3) = "region3"
  }

  # emqx
  emqx_region                     = try(local.spec.emqx.region, local.region)
  emqx_ami_filter                 = try(local.spec.emqx.ami_filter, local.ami_filter)
  emqx_ami_owner                  = try(local.spec.emqx.ami_owner, local.ami_owner)
  emqx_remote_user                = try(local.spec.emqx.remote_user, local.remote_user)
  emqx_root_volume_size           = try(local.spec.emqx.root_volume_size, 20)
  emqx_version                    = try(local.spec.emqx.version, "latest")
  emqx_version_family             = try(local.spec.emqx.version_family, local.emqx_version == "latest" ? 5 : parseint(substr(local.emqx_version, 0, 1), 10))
  emqx_http_api_port              = local.emqx_version_family == 4 ? 8081 : 18083
  emqx_api_version                = format("v%d", local.emqx_version_family)
  emqx_instance_type              = try(local.spec.emqx.instance_type, local.instance_type)
  emqx_use_spot_instances         = try(local.spec.emqx.use_spot_instances, local.use_spot_instances)
  emqx_dashboard_default_password = try(local.spec.emqx.dashboard_default_password, "public")
  emqx_extra_volumes              = try(local.spec.emqx.extra_volumes, [])
  emqx_link_dirs                  = try(local.spec.emqx.link_dirs, [])
  emqx_instance_volumes           = try(local.spec.emqx.instance_volumes, [])
  emqx_cluster_dns_name           = "emqx-cluster.${local.route53_zone_name}"
  emqx_env_override               = try(local.spec.emqx.env_override, [])
  emqx_api_key                    = try(local.spec.emqx.api_key, "perftest")
  emqx_api_secret                 = try(local.spec.emqx.api_secret, "perftest")
  emqx_license_file               = try(local.spec.emqx.license_file, "") == "" ? "" : pathexpand(local.spec.emqx.license_file)
  emqx_license                    = try(local.spec.emqx.license_file, "") == "" ? "" : file(pathexpand(local.spec.emqx.license_file))
  emqx_license_issue_date         = local.emqx_license == "" ? "" : split("\n", base64decode(split(".", local.emqx_license)[0]))[6]
  emqx_license_valid_days         = local.emqx_license == "" ? "" : split("\n", base64decode(split(".", local.emqx_license)[0]))[7]
  emqx_license_expiry_date        = local.emqx_license_issue_date == "" ? "" : timeadd(format("%s-%s-%sT00:00:00Z", substr(local.emqx_license_issue_date, 0, 4), substr(local.emqx_license_issue_date, 4, 2), substr(local.emqx_license_issue_date, 6, 2)), format("%dh", tonumber(local.emqx_license_valid_days) * 24))

  emqx_nodes_pre = flatten([
    for node in try(local.spec.emqx.nodes, []) : [
      for i in range(0, try(node.instance_count, 1)) : {
        instance_type    = try(node.instance_type, local.emqx_instance_type)
        role             = try(node.role, "core")
        region           = try(node.region, local.emqx_region)
        az               = try(node.az, 0)
        ami_filter       = try(node.ami_filter, local.emqx_ami_filter)
        ami_owner        = try(node.ami_owner, local.emqx_ami_owner)
        remote_user      = try(node.remote_user, local.emqx_remote_user)
        extra_volumes    = try(node.extra_volumes, local.emqx_extra_volumes)
        link_dirs        = try(node.link_dirs, local.emqx_link_dirs)
        instance_volumes = try(node.instance_volumes, local.emqx_instance_volumes)
        attach_to_nlb    = try(node.attach_to_nlb, true)
      }
    ]
  ])
  emqx_core_nodes = [for node in local.emqx_nodes_pre : node if node.role == "core"]
  emqx_repl_nodes = [for node in local.emqx_nodes_pre : node if node.role == "replicant"]
  emqx_nodes = merge(
    { for i, node in local.emqx_core_nodes :
      "emqx-core-${i + 1}.${local.route53_zone_name}" => merge(node, { name = "emqx-core-${i + 1}", hostname = "emqx-core-${i + 1}.${local.route53_zone_name}" })
    },
    { for i, node in local.emqx_repl_nodes :
      "emqx-repl-${i + 1}.${local.route53_zone_name}" => merge(node, { name = "emqx-repl-${i + 1}", hostname = "emqx-repl-${i + 1}.${local.route53_zone_name}" })
    }
  )
  emqx_static_seeds = [for node in local.emqx_nodes : "emqx@${node.hostname}" if node.role == "core"]

  # loadgens
  loadgen_type                 = try(local.spec.loadgens.type, "emqtt_bench")
  loadgen_region               = try(local.spec.loadgens.region, local.region)
  loadgen_ami_filter           = try(local.spec.loadgens.ami_filter, local.ami_filter)
  loadgen_ami_owner            = try(local.spec.loadgens.ami_owner, local.ami_owner)
  loadgen_remote_user          = try(local.spec.loadgens.remote_user, local.remote_user)
  loadgen_instance_type        = try(local.spec.loadgens.instance_type, local.instance_type)
  loadgen_use_spot_instances   = try(local.spec.loadgens.use_spot_instances, local.use_spot_instances)
  loadgen_scenario             = try(local.spec.loadgens.scenario, "pub -c 100 -I 10 -t bench/%%i -s 256")
  loadgen_payload_template     = try(local.spec.loadgens.payload_template, "")
  loadgen_use_nlb              = try(local.spec.loadgens.use_nlb, true)
  loadgen_version              = try(local.spec.loadgens.version, "latest")
  loadgen_package_download_url = try(local.spec.loadgens.package_download_url, "")
  loadgen_package_file_path    = try(local.spec.loadgens.package_file_path, "")

  loadgen_nodes_pre = flatten([
    for node in try(local.spec.loadgens.nodes, []) : [
      for i in range(0, try(node.instance_count, 1)) : {
        type                 = try(node.type, local.loadgen_type)
        region               = try(node.region, local.loadgen_region)
        az                   = try(node.az, 0)
        ami_filter           = try(node.ami_filter, local.loadgen_ami_filter)
        ami_owner            = try(node.ami_owner, local.loadgen_ami_owner)
        remote_user          = try(node.remote_user, local.loadgen_remote_user)
        instance_type        = try(node.instance_type, local.loadgen_instance_type)
        use_spot_instances   = try(node.use_spot_instances, local.loadgen_use_spot_instances)
        scenario             = try(node.scenario, local.loadgen_scenario)
        payload_template     = try(node.payload_template, local.loadgen_payload_template)
        use_nlb              = try(node.use_nlb, local.loadgen_use_nlb)
        ip_aliases           = try(node.ip_aliases, 0)
        role                 = try(node.role, "")
        version              = try(node.version, local.loadgen_version)
        package_download_url = try(node.package_download_url, local.loadgen_package_download_url)
        package_file_path    = try(node.package_file_path, local.loadgen_package_file_path)
      }
    ]
  ])

  loadgen_nodes_map = {
    for loadgen in local.loadgen_nodes_pre : loadgen.type => loadgen...
  }

  loadgen_nodes = merge([
    for type, nodes in local.loadgen_nodes_map : {
      for i, n in nodes :
      "loadgen-${type}-${i + 1}.${local.route53_zone_name}" => merge(n, {
        name     = "loadgen-${type}-${i + 1}",
        hostname = "loadgen-${type}-${i + 1}.${local.route53_zone_name}"
      })
    }
  ]...)

  # integrations
  integration_region             = try(local.spec.integrations.region, local.region)
  integration_ami_filter         = try(local.spec.integrations.ami_filter, local.ami_filter)
  integration_ami_owner          = try(local.spec.integrations.ami_owner, local.ami_owner)
  integration_remote_user        = try(local.spec.integrations.remote_user, local.remote_user)
  integration_instance_type      = try(local.spec.integrations.instance_type, local.instance_type)
  integration_use_spot_instances = try(local.spec.integrations.use_spot_instances, local.use_spot_instances)

  integration_nodes_pre = flatten([
    for node in try(local.spec.integrations.nodes, []) : [
      for i in range(0, try(node.instance_count, 1)) : {
        type               = node.type
        region             = try(node.region, local.integration_region)
        az                 = try(node.az, 0)
        ami_filter         = try(node.ami_filter, local.integration_ami_filter)
        ami_owner          = try(node.ami_owner, local.integration_ami_owner)
        remote_user        = try(node.remote_user, local.integration_remote_user)
        instance_type      = try(node.instance_type, local.integration_instance_type)
        use_spot_instances = try(node.use_spot_instances, local.integration_use_spot_instances)
      }
    ]
  ])

  integration_nodes_map = {
    for node in local.integration_nodes_pre : node.type => node...
  }

  integration_nodes = merge([
    for type, nodes in local.integration_nodes_map : {
      for i, n in nodes :
      "integration-${type}-${i + 1}.${local.route53_zone_name}" => merge(n, {
        name     = "integration-${type}-${i + 1}",
        hostname = "integration-${type}-${i + 1}.${local.route53_zone_name}"
      })
    }
  ]...)

  # monitoring
  monitoring_enabled            = try(local.spec.monitoring_enabled, true)
  monitoring_ami_filter         = try(local.spec.monitoring.ami_filter, local.ami_filter)
  monitoring_ami_owner          = try(local.spec.monitoring.ami_owner, local.ami_owner)
  monitoring_remote_user        = try(local.spec.monitoring.remote_user, local.remote_user)
  monitoring_instance_type      = try(local.spec.monitoring.instance_type, local.instance_type)
  monitoring_use_spot_instances = try(local.spec.monitoring.use_spot_instances, local.use_spot_instances)
  monitoring_root_volume_size   = try(local.spec.monitoring.root_volume_size, 20)
  monitoring_hostname           = "monitoring.${local.route53_zone_name}"
}

check "max_regions" {
  assert {
    condition     = length(local.regions) <= 3
    error_message = "Max number of different regions is 3. Found: ${length(local.regions)}"
  }
}
