#!/usr/bin/env bash

set -euo pipefail

# Usage
# ./run.sh <region> <bucket> <bench_id>

# Script arguments are optional, but the order is fixed.

TF_VAR_region="${1:-eu-north-1}"
TF_VAR_s3_bucket_name="${2:-tf-emqx-performance-test}"
TF_VAR_bench_id="${3:-$(date +%Y-%m-%d-%H-%M-%S)/1m-conns}"

EMQX_VERSION=5.0.25
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

TF_VAR_test_duration="1h"

TF_VAR_use_emqttb=1
TF_VAR_emqttb_instance_count=3
TF_VAR_emqttb_instance_type="c5.large"
TF_VAR_emqttb_scenario="@pub --topic 't/%n' --pubinterval 10ms --qos 1 --publatency 50ms --size 1kb --num-clients 1000 @sub --topic 't/%n' --num-clients 1000"

TF_VAR_use_emqtt_bench=1
TF_VAR_emqtt_bench_instance_count=10
TF_VAR_emqtt_bench_instance_type="c5.large"
TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"

TF_VAR_emqx_instance_count=3
TF_VAR_emqx_instance_type="c5.4xlarge"
TF_VAR_internal_mqtt_nlb_count=3
TF_VAR_public_mqtt_nlb=true

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
