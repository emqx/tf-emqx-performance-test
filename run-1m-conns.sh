#!/usr/bin/env bash

set -euo pipefail

# Usage
# ./run.sh <region> <bucket> <bench_id> <test duration in seconds> <emqx instance count> <emqx package file>
# e.g. here is a test with 1 emqx instance in eu-north-1 region, the test duration is 60 seconds, the emqx package file is emqx.deb
# ./run.sh eu-north-1 tf-emqx-performance-test '2020-01-01/test' 1min 1 emqx.deb

# Script arguments are optional, but the order is fixed.

export TF_VAR_region="${1:-eu-north-1}"
export TF_VAR_s3_bucket_name="${2:-tf-emqx-performance-test}"
export TF_VAR_bench_id="${3:-$(date +%Y-%m-%d-%H-%M-%S)}"

wget -nc https://github.com/emqx/emqx/releases/download/v5.0.24/emqx-5.0.24-ubuntu20.04-amd64.deb
export TF_VAR_package_file=emqx-5.0.24-ubuntu20.04-amd64.deb

export TF_VAR_use_emqttb=0

export TF_VAR_use_emqtt_bench=1
export TF_VAR_emqtt_bench_instance_count=10
export TF_VAR_emqtt_bench_instance_type="c5.large"
export TF_VAR_emqtt_bench_scenario="conn -c 100000 -i 10"
export TF_VAR_emqx_instance_type="c5.4xlarge"
export TF_VAR_public_mqtt_lb=true

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
