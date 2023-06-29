#!/usr/bin/env bash

set -euo pipefail

# 50k publishers, 50k subscribers, 50k topics
# QoS 1, payload 16B

EMQX_VERSION=${EMQX_VERSION:-5.1.0}
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
export TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

export TF_VAR_region="${1:-eu-central-1}"
export TF_VAR_s3_bucket_name="${2:-id-emqx-test}"
export TF_VAR_bench_id="${3:-$(date +%Y-%m-%d)/1on1}"
export TF_VAR_test_duration=3600
export TF_VAR_emqx_instance_type=c5.2xlarge
export TF_VAR_emqx_instance_count=3

export TF_VAR_use_emqttb=1
export TF_VAR_emqttb_instance_count=1
export TF_VAR_emqttb_instance_type=c5.2xlarge
export TF_VAR_emqttb_scenario="@pubsub_fwd -n 50_000 --pub-qos 1 --sub-qos 1"

export TF_VAR_use_emqtt_bench=0
# export TF_VAR_emqtt_bench_instance_count=1
# export TF_VAR_emqtt_bench_instance_type=c5.large
# export TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
