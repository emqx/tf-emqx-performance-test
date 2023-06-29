#!/usr/bin/env bash

set -euo pipefail

# 5 publishers, 5 topics, 1000 subscribers (each sub to all topics)
# pub rate: 250/s, so sub rate = 250*1000 = 250k/s
# QoS 1, payload 16B

EMQX_VERSION=${EMQX_VERSION:-5.1.0}
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
export TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

export TF_VAR_region="${1:-eu-central-1}"
export TF_VAR_s3_bucket_name="${2:-id-emqx-test}"
export TF_VAR_bench_id="${3:-$(date +%Y-%m-%d)/fanout}"
export TF_VAR_test_duration=3600
export TF_VAR_emqx_instance_type=c5.large
export TF_VAR_emqx_instance_count=3

export TF_VAR_use_emqttb=1
export TF_VAR_emqttb_instance_count=1
export TF_VAR_emqttb_instance_type=c5.2xlarge
export TF_VAR_emqttb_scenario="@pub --topic 't/%n' --conninterval 10ms --pubinterval 20ms --num-clients 5 --size 16 @sub --topic 't/#' --conninterval 10ms --num-clients 1000"

export TF_VAR_use_emqtt_bench=0
# export TF_VAR_emqtt_bench_instance_count=1
# export TF_VAR_emqtt_bench_instance_type=c5.large
# export TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
