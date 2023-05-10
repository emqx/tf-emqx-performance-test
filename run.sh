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
export TF_VAR_test_duration="${4:-5min}"
export TF_VAR_emqx_instance_count=${5:-3}
export TF_VAR_package_file="${6:-emqx.deb}"

# export TF_VAR_emqttb_instance_count=10
# export TF_VAR_emqttb_instance_type="c5.xlarge"
# export TF_VAR_emqttb_scenario="@pub --topic 't/% --pubinterval 10ms --qos 1 --publatency 50ms --size 1kb @sub --topic 't/#'"
# export TF_VAR_emqx_instance_type="c5.4xlarge"
# export TF_VAR_public_mqtt_lb=true

terraform init
terraform apply -auto-approve

until aws s3api head-object --bucket "$TF_VAR_s3_bucket_name" --key "$TF_VAR_bench_id/DONE" > /dev/null 2>&1; do
    printf '.'
    sleep 10
done
echo
echo "Test is completed"

files=(metrics.json stats.json)
for f in "${files[@]}"; do
    if aws s3api head-object --bucket $TF_VAR_s3_bucket_name --key "$TF_VAR_bench_id/$f" > /dev/null 2>&1; then
       aws s3 cp "s3://$TF_VAR_s3_bucket_name/$TF_VAR_bench_id/$f" ./
    fi
done
terraform destroy
