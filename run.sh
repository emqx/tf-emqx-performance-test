#!/usr/bin/env bash

set -euo pipefail

# Usage
# ./run.sh <region> <bucket> <bench_id> <test duration in seconds>

# Script arguments are optional, but the order is fixed.

TF_VAR_region="${1:-eu-north-1}"
TF_VAR_s3_bucket_name="${2:-tf-emqx-performance-test}"
TF_VAR_bench_id="${3:-$(date +%Y-%m-%d-%H-%M-%S)}"
TF_VAR_test_duration="${4:-300}"

EMQX_VERSION=5.0.25
wget -nc https://github.com/emqx/emqx/releases/download/v$EMQX_VERSION/emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb
TF_VAR_package_file=emqx-$EMQX_VERSION-ubuntu20.04-amd64.deb

terraform init
terraform apply
./wait-emqttb.sh
echo "Test is completed"
./fetch-metrics.sh
terraform destroy
