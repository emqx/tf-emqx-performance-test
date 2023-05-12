#!/usr/bin/env bash

set -euo pipefail

EMQX_VERSION=5.0.25
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

TF_VAR_region=eu-central-1
TF_VAR_s3_bucket_name=id-emqx-test
TF_VAR_bench_id="$(date +%Y-%m-%d-%H-%M-%S)"
TF_VAR_test_duration="1h"
TF_VAR_emqx_instance_count=3
TF_VAR_package_file=emqx-5.0.24-ubuntu20.04-amd64.deb
TF_VAR_internal_mqtt_nlb_count=3

TF_VAR_use_emqttb=1
TF_VAR_emqttb_instance_count=1
TF_VAR_emqttb_instance_type="c5.large"
TF_VAR_emqttb_scenario="@pub --topic 't/%n' --pubinterval 10ms --qos 1 --publatency 50ms --size 1kb --num-clients 1000 @sub --topic 't/%n' --num-clients 1000"

TF_VAR_use_emqtt_bench=1
TF_VAR_emqtt_bench_instance_count=1
TF_VAR_emqtt_bench_instance_type="c5.large"
TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
