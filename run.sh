#!/usr/bin/env bash

set -euo pipefail

# Usage
# ./run.sh <region> <bucket> <bench_id> <test duration in seconds>

# Script arguments are optional, but the order is fixed.

EMQX_VERSION=${EMQX_VERSION:-5.1.0}
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
export TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

export TF_VAR_region="${1:-eu-west-1}"
export TF_VAR_s3_bucket_name="${2:-tf-emqx-performance-test2}"
export TF_VAR_bench_id="${3:-$(date +%Y-%m-%d)}"
export TF_VAR_test_duration="${4:-3600}"

export TF_VAR_emqx_instance_type="c5.large"
export TF_VAR_emqx_instance_count=1
export TF_VAR_emqttb_instance_type="c5.large"
export TF_VAR_emqttb_instance_count=1
export TF_VAR_emqttb_scenario="@pubsub_fwd -n 5_000 --pub-qos 1 --sub-qos 1"

terraform init
terraform apply
read -p "Press Enter to continue" key
terraform destroy
