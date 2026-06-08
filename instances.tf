# Resolved node sets and endpoints, independent of the active cloud.
# Exactly one of the aws / gcp module sets is populated per run (see local.cloud),
# so merge/concat yields the active one. Downstream (ansible.tf, outputs.tf)
# consumes these locals instead of the cloud-specific modules.
#
# Contract: modules/ec2 and modules/gce MUST expose the same output shape
# (public_ips, private_ips, instance_ids, fqdn, region, type, attach_to_nlb,
# remote_user) for the merge to work — keep their outputs.tf in sync.
locals {
  emqx        = merge(module.emqx, module.emqx_gcp)
  loadgen     = merge(module.loadgen, module.loadgen_gcp)
  monitoring  = concat(module.monitoring, module.monitoring_gcp)
  integration = module.integration

  # Load balancer DNS names exist only on AWS.
  public_lb_dns   = local.cloud_is_aws ? module.public_nlb[0].dns_name : ""
  internal_lb_dns = local.cloud_is_aws ? module.internal_nlb[0].dns_name : ""

  emqx_first_public_ip       = length(local.emqx) > 0 ? values(local.emqx)[0].public_ips[0] : ""
  monitoring_first_public_ip = length(local.monitoring) > 0 ? local.monitoring[0].public_ips[0] : ""
  locust_public_ips          = [for n in local.loadgen : n.public_ips[0] if n.type == "locust"]
  locust_public_ip           = length(local.locust_public_ips) > 0 ? local.locust_public_ips[0] : ""

  # Reachable hosts: the NLB on AWS, a node public IP on GCP (no LB in the MVP).
  # This is the single seam for the AWS-NLB-vs-GCP special case: when GCP load
  # balancers are added, resolve their addresses here, not at each call site.
  emqx_dashboard_host = local.cloud_is_aws ? local.public_lb_dns : local.emqx_first_public_ip
  monitoring_host     = local.cloud_is_aws ? local.public_lb_dns : local.monitoring_first_public_ip
  locust_host         = local.cloud_is_aws ? local.public_lb_dns : local.locust_public_ip
}
