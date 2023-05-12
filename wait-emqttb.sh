#!/usr/bin/env bash

set -euo pipefail

BUCKET=$(terraform output -raw s3_bucket_name)
BENCH_ID=$(terraform output -raw bench_id)
until aws s3api head-object --bucket $BUCKET --key "$BENCH_ID/EMQTTB_DONE" > /dev/null 2>&1
do
    printf '.'
    sleep 10
done
echo
