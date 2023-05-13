#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <region> <bucket>"
    exit 1
fi

REGION=$1
BUCKET=$2
aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint=$REGION
aws s3api put-bucket-ownership-controls --bucket "$BUCKET" --ownership-controls="Rules=[{ObjectOwnership=BucketOwnerPreferred}]"
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
