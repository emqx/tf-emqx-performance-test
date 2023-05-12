#!/usr/bin/env bash

set -euo pipefail

wget -nc https://github.com/emqx/emqx/releases/download/v5.0.24/emqx-5.0.24-ubuntu20.04-amd64.deb
export TF_VAR_region=eu-central-1
export TF_VAR_s3_bucket_name=id-emqx-test
export TF_VAR_bench_id="$(date +%Y-%m-%d-%H-%M-%S)"
export TF_VAR_test_duration="1h"
export TF_VAR_emqx_instance_count=3
export TF_VAR_package_file=emqx-5.0.24-ubuntu20.04-amd64.deb

export TF_VAR_use_emqttb=1
export TF_VAR_emqttb_instance_count=1
export TF_VAR_emqttb_instance_type="c5.large"
export TF_VAR_emqttb_scenario="@pub --topic 't/%' --pubinterval 10ms --qos 1 --publatency 50ms --size 1kb @sub --topic 't/%'"

export TF_VAR_use_emqtt_bench=1
export TF_VAR_emqtt_bench_instance_count=1
export TF_VAR_emqtt_bench_instance_type="c5.large"
export TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
