# EMQX Performance Test

Requirements
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-and-upgrading-ansible-with-pip)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS credentials in shell environment

This creates an EMQX cluster with configurable number of core and replicant nodes, [emqttb](https://github.com/emqx/emqttb) and/or [emqtt-bench](https://github.com/emqx/emqtt-bench) load generator nodes, and prometheus+grafana instance in a private VPC.

## Security considerations

- By default, all instances are launched in a private VPC in the first availability zone, with public IPv4 addresses.
- Security group allows all inbound and outbound traffic to prevent [Security group connection tracking](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-connection-tracking.html) from affecting the test results. You can change this in `modules/security_group_rules/main.tf`.

## Quick start

```bash
terraform init
terraform apply
# this will take a while, wait until terraform finishes
# if something fails during ansible provisioning, try to re-run corresponding playbook
env no_proxy='*' ansible-playbook ansible/emqx.yml
env no_proxy='*' ansible-playbook ansible/emqttb.yml
# start emqttb benchmark
ansible emqttb -m command -a 'systemctl start emqttb' --become
# (optionally) open emqx dashboard and/or grafana to watch metrics
# or use this helper script to produce a markdown with selected metrics
./scripts/summary.sh
# cleanup when done
terraform destroy
```

Default emqx dashboard credentials are `admin:public`, grafana credentials are `admin:grafana`.

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
ansible emqx -m shell -a 'apt-get purge emqx -y' --become
ansible-playbook ansible/emqx.yml
# reinstall emqttb
ansible-playbook ansible/emqttb.yml
# reinstall emqtt-bench
ansible-playbook ansible/emqtt-bench.yml
# reinstall emqx with some custom variables
# note: we pass them as a JSON object; otherwise,
# everything is interpreted as a string
ansible-playbook ansible/emqx.yml -e '{"cache_enabled": true, "topics": ["t/a"]}'
```

To ssh directly into instances, use terraform output to get IP addresses, and generated ssh private key, for example:

```bash
ssh -l ubuntu -i ./foobar.pem 52.53.191.91
# generic ssh one-liner to connect to the first emqx node
ssh -l ubuntu -i $(terraform output -raw ssh_key_path) $(terraform output -json emqx_nodes | jq -r '.[0].ip')
# open dashboard in the browser (macos only)
open http://$(terraform output -raw emqx_dashboard_url)
```

Key name is generated as `<id>.pem` (`id` is from test spec file).

You can also modify ansible variables directly under `ansible/group_vars` and `ansible/host_vars` directories, and re-run ansible playbooks without recreating terraform infrastructure.

*NOTE*: if you see `ERROR! A worker was found in a dead state` while running ansible, try to add `env no_proxy='*'` before `ansible-playbook` commands.

## Test spec

Test specs are yaml files under `tests` directory. By default `tests/default.yml` is used. You can specify a different test spec file by adding `-var spec_file=tests/myspec.yaml` parameter when running terraform.

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
ami_filter: "ubuntu-22.04-arm64-*" # default ami filter
use_spot_instances: true   # whether to use spot instances
emqx:                      # emqx related settings
  instance_type: m6g.large # one can override default parameters here for all emqx nodes
  data_dir: /data/emqx     # data directory for emqx config and files, optional, default is /var/lib/emqx
  extra_volumes:           # attach extra ebs volumes to emqx nodes (optional)
    - mount_point: /data   # mount point
      volume_size: 30      # volume size in GB
      volume_type: gp3     # volume type (gp3, gp2, io1, etc.) - default is gp3
      mount_options: defaults,noatime,discard # mount options, default is 'defaults'
  nodes:                   # list of emqx nodes
    - role: core           # role of the node, can be core or replicant (default is core)
      region: eu-west-1
      instance_count: 1    # number of instances to launch (default is 1)
    - role: replicant
      region: eu-west-1
    - role: core
      region: us-west-1        # override region for this node
      instance_type: m7g.large # override instance type for this node
    - role: replicant
      region: us-west-1
    - role: core
      region: us-east-1
    - role: replicant
      region: us-east-1
loadgens:                            # load generators section
  instance_type: m5.large            # instance type for all load generators
  ami_filter: "ubuntu-22.04-amd64-*" # ami filter for all load generators
  nodes:
      # mind the '%%' in the scenario - it's quoting for systemd unit file
    - type: emqttb
      scenario: "@pub --topic t/%%n --conninterval 10ms --pubinterval 10ms --num-clients 100 --size 1kb"
      instance_count: 3
    - type: emqttb
      scenario: "@sub --topic t/%%n --conninterval 10ms --num-clients 10"
      instance_count: 3
```

## Testing rolling upgrades

For example, here is how to test rolling upgrade of emqx-enterprise from 5.3.2 to 5.4.1.

1. Create a new test spec file `tests/emqx-enterprise-5.3.2.yml`:

```yaml
id: emqx-enterprise
region: eu-west-1
use_spot_instances: true
monitoring_enabled: false
ami_filter: "debian-10-amd64-*"
remote_user: admin
emqx:
  instance_type: m6a.large
  edition: emqx-enterprise
  version: 5.3.2
  license_file: emqx5.lic
  nodes:
    - role: core
      instance_count: 3
```

2. Run terraform with this spec:

```bash
terraform init
terraform apply -var spec_file=tests/emqx-enterprise-5.3.2.yml
```

3. In `ansible/group_vars/emqx5.yml` change `emqx_version` to `5.4.1`
4. Run `emqx_rolling_upgrade.yml` playbook:

```bash
ansible-playbook ansible/emqx_rolling_upgrade.yml
```

# Supporting shell functions

Helpful function that you could add to your `.bashrc` or `.zshrc`.

Alternatively, source `scripts/dev-helpers.sh`:

```sh
. scripts/dev-helpers.sh
```

"bm" in the function names stands for "BenchMark".

## start/stop emqtt-bench

```
function bm-start() {
    n=${1:-1}
    ansible emqtt_bench -m command -a 'systemctl start emqtt_bench' --become -l $(terraform output -json emqtt_bench_nodes | jq -r ".[$((n-1))].fqdn")
}

function bm-stop () {
    n=${1:-1}
    ansible emqtt_bench -m command -a 'systemctl stop emqtt_bench' --become -l $(terraform output -json emqtt_bench_nodes | jq -r ".[$((n-1))].fqdn")
}
```

## start/stop emqttb

```
function bmb-start() {
    n=${1:-1}
    ansible emqttb -m command -a 'systemctl start emqttb' --become -l $(terraform output -json emqttb_nodes | jq -r ".[$((n-1))].fqdn")
}

function bmb-stop() {
    n=${1:-1}
    ansible emqttb -m command -a 'systemctl stop emqttb' --become -l $(terraform output -json emqttb_nodes | jq -r ".[$((n-1))].fqdn")
}
```

## Interactive selector of the node to ssh to (via `fzf`)

```
function bm-ssh() {
    node=$(terraform output -json | jq -r 'to_entries[] | select(.key | endswith("_nodes")) | .value.value[] | "\(.ip)\t\(.fqdn)"' | sort -k2 | uniq | fzf | cut -d $'\t' -f 1)
    if [[ -n $node ]]; then
        ssh -l ubuntu -i $(terraform output -raw ssh_key_path) "$node"
    fi
}
```

## Print full URLs which are clickable from Terminal

```
function bm-urls() {
    echo "dashboard: $(terraform output -raw emqx_dashboard_url)"
    echo "grafana: $(terraform output -raw grafana_url)"
}
```

# Capturing Prometheus data snapshots

```sh
ansible-playbook ansible/prometheus-snapshot.yml
```

This will create a directory `prometheus_snapshots` in the root of this project and
download a tarball containing the snapshot there.  The tarball then must be extracted
preserving permissions:

```sh
cd prometheus_snapshots
tar -xvpf 20241007T164452Z-11cc51d6d14856dd.tar.bz2
```

It contains a docker compose manifest that spins up grafana and prometheus to serve
snapshot data.

> [!TIP]
> Currenlty, annotations are not captured in this tarball.  They live in Grafana's DB.

```sh
cd 20241007T164452Z-11cc51d6d14856dd
docker compose up ; docker compose down
```

Then access `http://localhost:3000` (username/password is `admin`/`grafana`).

# Running `perf_events` tests

If you want to use [`perf_events`](https://www.brendangregg.com/perf.html) tests and analysis, add `emqx.enable_perf = true` to your test spec.  This will install a few tools on the EMQX machines, such as [`perf-archive`](https://github.com/torvalds/linux/blob/684a64bf32b6e488004e0ad7f0d7e922798f65b6/tools/perf/perf-archive.sh), which current doesn't work by default with pre-installed `perf`, [`hotspot`](https://github.com/KDAB/hotspot) and [flamegraph.pl](https://github.com/brendangregg/FlameGraph).

```yaml
emqx:
  enable_perf: true
  # ...
```

Then, when you want to record events, SSH into an EMQX box and run:

```sh
## this will record data for 30 seconds
perf record --call-graph=fp --pid $(pgrep beam.smp) -- sleep 30
```

## Hotspot

To analyze recorded data, one option is hotspot.  You can run it directly on the EMQX machine so that it may find as many symbols and libraries used as possible.

```sh
## assuming we ran the test on the first emqx box
function first_core() {
  terraform output -json | jq -r 'to_entries[] | select(.key | endswith("_nodes")) | .value.value[] | "\(.ip)\t\(.fqdn)"' | sort -k2 | uniq | rg core | head -n 1 | cut -d $'\t' -f 1
}

## SSH with X11 forwarding
ssh -X -l ubuntu -i $(terraform output -raw ssh_key_path) $(first_core) /tmp/hotspot.AppImage
```

Hotspot supports exporting `perf_events` data in a portable way (though only it can open the archive), which doesn't require a GUI:

```sh
ssh -X -l ubuntu -i $(terraform output -raw ssh_key_path) $(first_core) /tmp/hotspot.AppImage /home/ubuntu/perf.data --exportTo /tmp/perf.data.perfparser

# or
ansible 'emqx[0]' -i ansible/inventory.yml -m command -a "/tmp/hotspot.AppImage /home/ubuntu/perf.data --exportTo /tmp/perf.data.perfparser"
```

## FlameGraph

To use [flamegraph.pl](https://github.com/brendangregg/FlameGraph), we just follow the instructions on its repo:

```sh
## ssh into the emqx box, and...

perf script > out.perf
/opt/flamegraph/stackcollapse-perf.pl out.perf > out.folded
/opt/flamegraph/flamegraph.pl out.folded > out.svg
```
