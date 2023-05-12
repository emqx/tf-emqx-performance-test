#!/usr/bin/env bash

set -euo pipefail

DASHBOARD_URL=$(terraform output -raw emqx_dashboard_url)
TOKEN=$(curl -sSf "$DASHBOARD_URL/api/v5/login" \
  -H "Authorization: Bearer undefined" \
  -H "Content-Type: application/json" \
  --data-raw '{"username":"admin","password":"admin"}' | jq -r .token)

curl -sSf -m 10 --retry 5 "$DASHBOARD_URL/api/v5/metrics" -H "Authorization: Bearer $TOKEN" > metrics.json
