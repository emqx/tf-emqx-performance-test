#!/usr/bin/env bash

set -euo pipefail

output=$(cat)

bench_id=$(echo $output | jq -r '.bench_id.value')
emqx_dashboard_url="http://$(echo $output | jq -r '.emqx_dashboard_url.value')"
grafana_url="http://$(echo $output | jq -r '.grafana_url.value')"
prometheus_url="http://$(echo $output | jq -r '.prometheus_url.value')"
emqx_dashboard_credentials=$(echo $output | jq -r '.emqx_dashboard_credentials.value')
grafana_credentials=$(echo $output | jq -r '.grafana_credentials.value')

echo "# Benchmark ${bench_id}"
echo ""
echo "## Dashboards"
echo ""
echo "* [EMQX Dashboard]($emqx_dashboard_url) - \`$emqx_dashboard_credentials\`"
echo "* [Grafana]($grafana_url) - \`$grafana_credentials\`"
echo "* [Prometheus]($prometheus_url)"
echo ""

emqx_nodes=$(echo $output | jq -r '.emqx_nodes.value')
loadgen_nodes=$(echo $output | jq -r '.loadgen_nodes.value')

generate_nodes_table() {
  local nodes=$1
  local title=$2

  echo "## ${title}"
  echo ""
  echo "| Hostname | Public IP |"
  echo "|----------|-----------|"

  echo $nodes | jq -c '.[]' | while read node; do
    fqdn=$(echo $node | jq -r '.fqdn')
    ip=$(echo $node | jq -r '.ip')
    echo "| ${fqdn} | ${ip} |"
  done
  echo ""
}

generate_nodes_table "$emqx_nodes" "EMQX Nodes"
generate_nodes_table "$loadgen_nodes" "Loadgen Nodes"
