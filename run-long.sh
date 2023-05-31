#!/usr/bin/env bash

set -euo pipefail

EMQX_VERSION=5.0.25
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
export TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

export TF_VAR_region=eu-central-1
export TF_VAR_s3_bucket_name=id-emqx-test
export TF_VAR_bench_id="$(date +%Y-%m-%d-%H-%M-%S)"
export TF_VAR_test_duration=3600
export TF_VAR_emqx_instance_type=c5.large
export TF_VAR_emqx_instance_count=3
export TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
export TF_VAR_internal_mqtt_nlb_count=3

export TF_VAR_use_emqttb=1
export TF_VAR_emqttb_instance_count=1
export TF_VAR_emqttb_instance_type=c5.large
# export TF_VAR_emqttb_scenario="@pubsub_fwd -n 50_000 --pub-qos 1 --sub-qos 1"

# export TF_VAR_use_emqtt_bench=0
# export TF_VAR_emqtt_bench_instance_count=1
# export TF_VAR_emqtt_bench_instance_type=c5.large
# export TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
