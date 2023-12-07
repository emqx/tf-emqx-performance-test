# EMQX Performance Test

Requirements
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS credentials in shell environment

This creates an EMQX cluster with configurable number of core and replicant nodes, [emqttb](https://github.com/emqx/emqttb) and/or [emqtt-bench](https://github.com/emqx/emqtt-bench) load generator nodes, and prometheus+grafana instance in a private VPC.

## Quick start

```bash
terraform init
terraform apply -parallelism 48
# this will take a while, wait until terraform finishes
# if something fails during ansible provisioning, try to re-run corresponding playbook
env no_proxy='*' ansible-playbook ansible/emqx.yml
env no_proxy='*' ansible-playbook ansible/emqttb.yml
env no_proxy='*' ansible-playbook ansible/emqtt_bench.yml
# start emqttb benchmark
ansible emqttb -m command -a 'systemctl start emqttb' --become
# (optionally) open emqx dashboard and/or grafana to watch metrics
# cleanup when done
terraform destroy -parallelism 48
```

Default emqx dashboard credentials are `admin:public`, grafana credentials are `admin:admin`.

## Operations

Terraform creates infrastructure and provisions ansible inventory and variables, and as the final step invokes ansible playbooks to install emqx, emqttb, emqtt-bench, prometheus and grafana.
To start the test, you need to start loadgen manually (as indicated above, and in the examples below).
After terraform run you can use ansible separately to start/stop loadgens, manage emqx nodes, etc.

Some examples:
    
```bash
# start/stop benchmark with emqttb
ansible emqttb -m command -a 'systemctl start emqttb' --become
ansible emqttb -m command -a 'systemctl stop emqttb' --become
# start/stop benchmark with emqtt-bench
ansible emqtt_bench -m command -a 'systemctl start emqtt-bench' --become
ansible emqtt_bench -m command -a 'systemctl stop emqtt-bench' --become
# start/stop/restart emqx on all nodes
ansible emqx -m command -a 'systemctl start emqx' --become
ansible emqx -m command -a 'systemctl stop emqx' --become
ansible emqx -m command -a 'systemctl restart emqx' --become
# get emqx cluster status on all nodes
ansible emqx -m command -a 'emqx ctl cluster status' --become
# reinstall emqx
ansible-playbook ansible/emqx.yml
# reinstall emqttb
ansible-playbook ansible/emqttb.yml
# reinstall emqtt-bench
ansible-playbook ansible/emqtt-bench.yml
```

To ssh directly into instances, use terraform output to get IP addresses, and generated ssh private key in `.ssh` directory, for example:

```bash
ssh 52.53.191.91 -l ubuntu -i ~/.ssh/foobar.pem
```
Key name is generated as `<id>.pem` (`id` is from test spec file).

You can also modify ansible variables directly under `ansible/group_vars` and `ansible/host_vars` directories, and re-run ansible playbooks without recreating terraform infrastructure.

*NOTE*: if you see `ERROR! A worker was found in a dead state` while running ansible, try to add `env no_proxy='*'` before `ansible-playbook` commands.

## Test spec

Test specs are yaml files under `tests` directory. By default `tests/default.yml` is used. You can specify a different test spec file by adding `-var spec_file=<absolute file path or file path relative to the current directory>` parameter when running terraform.

*IMPORTANT*: this variable must also be used when you run `terraform destroy` to cleanup the infrastructure.

Processing of test spec is implemented in `locals.tf`.

- most specific settings override less specific ones
- one can use any combination of regions for the infrastructure as long as there are total of 3 regions or less
- emqx, emqttb and emqtt-bench nodes can be deployed to any region
- load balancer serving emqx dashboard, grafana UI and prometheus UI is deployed to the default region, which means
  - at least one emqx node should be deployed to the default region
  - monitoring node with grafana and prometheus is deployed to the default region
- scenario for emqttb and emqtt-bench goes directly into rendered systemd unit file, hence, for example, percent symbol should be escaped as `%%`

Example test spec:

```yaml
id: foobar                 # mandatory field, used as a prefix for all resources, must be unique, but not very long
region: eu-west-1          # default region
instance_type: m6g.large   # default instance type
os_name: ubuntu-jammy      # default os name for base AMI
os_version: 22.04          # default os version for base AMI
cpu_arch: arm64            # default cpu architecture for base AMI
use_spot_instances: true   # whether to use spot instances
emqx:                      # emqx related settings
  instance_type: m6g.large # one can override default parameters here for all emqx nodes
  nodes:                   # list of emqx nodes
    - role: core           # role of the node, can be core or replicant (default is core)
      region: eu-west-1    # region of the node
      instance_count: 1    # number of instances to launch (default is 1)
      instance_type: m6g.large # here as well one can override default parameters just for this node
    - role: replicant
      region: eu-west-1
    - role: core
      region: us-west-1
    - role: replicant
      region: us-west-1
    - role: core
      region: us-east-1
    - role: replicant
      region: us-east-1
emqttb:                   # emqttb related settings
  instance_type: m5.large # emqttb instance type
  cpu_arch: amd64         # emqttb cpu architecture
  nodes:                  # mind the '%%' in the scenario - it's quoting for systemd unit file
    - scenario: "@pub --topic t/%%n --conninterval 10ms --pubinterval 10ms --num-clients 100 --size 1kb"
      instance_count: 3
    - scenario: "@sub --topic t/%%n --conninterval 10ms --num-clients 10"
      instance_count: 3
```
