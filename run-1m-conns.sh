#!/usr/bin/env bash

set -euo pipefail

# Usage
# ./run.sh <region> <bucket> <bench_id>

# Script arguments are optional, but the order is fixed.

export TF_VAR_region="${1:-eu-north-1}"
export TF_VAR_s3_bucket_name="${2:-tf-emqx-performance-test}"
export TF_VAR_bench_id="${3:-$(date +%Y-%m-%d-%H-%M-%S)/1m-conns}"

EMQX_VERSION=5.1.0
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
export TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

export TF_VAR_test_duration=3600

export TF_VAR_use_emqttb=1
export TF_VAR_emqttb_instance_count=5
export TF_VAR_emqttb_instance_type=c5.2xlarge
export TF_VAR_emqttb_scenario="@conn -N 200_000 --conninterval 1ms @a -a conn_group_autoscale -V 100"

# export TF_VAR_use_emqtt_bench=0
# export TF_VAR_emqtt_bench_instance_count=5
# export TF_VAR_emqtt_bench_instance_type="c5.2xlarge"
# export TF_VAR_emqtt_bench_scenario="conn -c 200000 -i 10"

export TF_VAR_emqx_instance_count=3
export TF_VAR_emqx_instance_type="c5.2xlarge"
export TF_VAR_internal_mqtt_nlb_count=1
export TF_VAR_public_mqtt_nlb=0

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
