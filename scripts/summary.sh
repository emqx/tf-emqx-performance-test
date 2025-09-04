#!/usr/bin/env bash

set -euo pipefail

log() {
  if [ "${DEBUG:-}" = "1" ] || [ "${DEBUG:-}" = "true" ]; then
    echo "DEBUG: $*" >&2
  fi
}

TMPDIR=${TMPDIR:-$(mktemp -d)}
PROMETHEUS_URL=${PROMETHEUS_URL:-$(terraform output -raw prometheus_url)}
EMQX_API_URL=${EMQX_API_URL:-$(terraform output -raw emqx_dashboard_url)}
EMQX_VERSION_FAMILY=${EMQX_VERSION_FAMILY:-$(terraform output -raw emqx_version_family)}
EMQX_API_KEY=${EMQX_API_KEY:-$(terraform output -raw emqx_api_key)}
EMQX_API_SECRET=${EMQX_API_SECRET:-$(terraform output -raw emqx_api_secret)}
PERIOD=${PERIOD:-5m}

print_pretty_table() {
    column -t -s $'\t' -o ' | '
}

convert_tsv_to_markdown() {
    sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/'
}

call_emqx_api() {
  curl -s -u "${EMQX_API_KEY}:${EMQX_API_SECRET}" "$EMQX_API_URL/api/v${EMQX_VERSION_FAMILY}/$1"
}

query_prometheus() {
  curl -s "$PROMETHEUS_URL/api/v1/query" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "$1"
}

call_emqx_api nodes > "$TMPDIR/nodes.json"
EMQX_VERSION=$(jq -r '.[0].version' "$TMPDIR/nodes.json")
log "EMQX Version: $EMQX_VERSION"

log "Fetching EMQX monitoring data..."
call_emqx_api monitor_current > "$TMPDIR/monitor_current.json"
call_emqx_api metrics > "$TMPDIR/metrics.json"
call_emqx_api stats > "$TMPDIR/stats.json"
log "EMQX data fetched."

log "Fetching Node metrics from Prometheus at $PROMETHEUS_URL..."
log "Fetching CPU metrics..."
query_prometheus "query=100-(avg by(instance) (rate(node_cpu_seconds_total{mode='idle'}[$PERIOD]))*100)" | jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "cpu": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > "$TMPDIR/cpu.json"
log "Fetching Memory metrics..."
query_prometheus "query=100-((avg_over_time(node_memory_MemAvailable_bytes[$PERIOD])*100)/avg_over_time(node_memory_MemTotal_bytes[$PERIOD]))" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "mem": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > "$TMPDIR/mem.json"
log "Fetching Disk Write IOPS metrics..."
query_prometheus "query=sum by (instance) (irate(node_disk_writes_completed_total[$PERIOD]))" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "disk": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > "$TMPDIR/disk.json"
log "Fetching Network Receive metrics (B/s)..."
query_prometheus "query=sum by (instance) (irate(node_network_receive_bytes_total{device!='lo'}[$PERIOD]))" | jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "net_rx": (.value[1]|tonumber)}' | jq -rs > "$TMPDIR/net_rx.json"
log "Fetching Network Transmit metrics (B/s)..."
query_prometheus "query=sum by (instance) (irate(node_network_transmit_bytes_total{device!='lo'}[$PERIOD]))" | jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "net_tx": (.value[1]|tonumber)}' | jq -rs > "$TMPDIR/net_tx.json"
log "Node metrics fetched."

log "Processing node data..."
node_data_tsv=$(jq -s 'add | group_by(.host) | map(add)' \
  "$TMPDIR/cpu.json" "$TMPDIR/mem.json" "$TMPDIR/disk.json" "$TMPDIR/net_rx.json" "$TMPDIR/net_tx.json" | \
  jq -r '(["Host", "Avg CPU%", "Avg RAM%", "Disk Write IOPS", "Net RX (Mbit/s)", "Net TX (Mbit/s)"],
         ["----", "-------", "-------", "---------------", "---------------", "---------------"],
         (.[] | [
           .host, .cpu // 0, .mem // 0, .disk // 0,
           (((.net_rx // 0) * 8 / 1000000 * 100 | round) / 100),
           (((.net_tx // 0) * 8 / 1000000 * 100 | round) / 100)
         ] | map(tostring))) | @tsv'
)

echo; echo "## Node Metrics"; echo "$node_data_tsv" | print_pretty_table; echo

node_data_md=$(echo "$node_data_tsv" | convert_tsv_to_markdown)
log "Node data processed."

log "Fetching EMQX metrics from Prometheus..."
emqx_connections=$(query_prometheus "query=sum(emqx_connections_count)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_live_connections=$(query_prometheus "query=sum(emqx_live_connections_count)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_messages_received=$(query_prometheus "query=sum(emqx_messages_received)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_messages_sent=$(query_prometheus "query=sum(emqx_messages_sent)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_messages_acked=$(query_prometheus "query=sum(emqx_messages_acked)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_messages_publish=$(query_prometheus "query=sum(emqx_messages_publish)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_messages_delivered=$(query_prometheus "query=sum(emqx_messages_delivered)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
emqx_messages_dropped=$(query_prometheus "query=sum(emqx_messages_dropped)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
received_msg_rate=$(query_prometheus "query=sum(rate(emqx_messages_received[$PERIOD]))" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
sent_msg_rate=$(query_prometheus "query=sum(rate(emqx_messages_sent[$PERIOD]))" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
log "EMQX metrics fetched."

echo "## EMQX Metrics"
(
    printf "Metric\tValue\n"; printf "%s\t%s\n" "----------------" "------"
    printf "messages_received\t%s\n" "$emqx_messages_received"; printf "messages_sent\t%s\n" "$emqx_messages_sent"
    printf "messages_acked\t%s\n" "$emqx_messages_acked"; printf "messages_publish\t%s\n" "$emqx_messages_publish"
    printf "messages_delivered\t%s\n" "$emqx_messages_delivered"; printf "messages_dropped\t%s\n" "$emqx_messages_dropped"
    printf "connections\t%s\n" "$emqx_connections"; printf "live_connections\t%s\n" "$emqx_live_connections"
) | print_pretty_table

echo; echo "## EMQX Aggregated Metrics"
(
    printf "Metric\tValue\n"; printf "%s\t%s\n" "-------------------------" "------"
    printf "received_msg_rate (msg/s)\t%s\n" "$received_msg_rate"; printf "sent_msg_rate (msg/s)\t%s\n" "$sent_msg_rate"
) | print_pretty_table; echo

log "Generating summary report (summary.md)..."
cat << EOF > summary.md
# Benchmark '$(terraform output -raw bench_id)' summary

Using $(terraform output -raw spec_file)@$(git rev-parse --short HEAD) test spec.

EMQX version: $EMQX_VERSION

## Nodes

$node_data_md

## EMQX metrics

| Metric                     | Value                  |
| -------------------------- | ---------------------- |
| messages_received          | $emqx_messages_received  |
| messages_sent              | $emqx_messages_sent      |
| messages_acked             | $emqx_messages_acked     |
| messages_publish           | $emqx_messages_publish   |
| messages_delivered         | $emqx_messages_delivered |
| messages_dropped           | $emqx_messages_dropped   |
| connections                | $emqx_connections        |
| live_connections           | $emqx_live_connections   |

## EMQX aggregated metrics

| Metric                     | Value                  |
| -------------------------- | ---------------------- |
| received_msg_rate (msg/s)  | $received_msg_rate     |
| sent_msg_rate (msg/s)      | $sent_msg_rate         |
EOF

log "Saving EMQX metrics to $TMPDIR/emqx_metrics.json..."
cat << EOF > "$TMPDIR/emqx_metrics.json"
{
  "messages_received": $emqx_messages_received, "messages_sent": $emqx_messages_sent,
  "messages_acked": $emqx_messages_acked, "messages_publish": $emqx_messages_publish,
  "messages_delivered": $emqx_messages_delivered, "messages_dropped": $emqx_messages_dropped,
  "connections": $emqx_connections, "live_connections": $emqx_live_connections,
  "received_msg_rate": $received_msg_rate, "sent_msg_rate": $sent_msg_rate
}
EOF

if [ "$(terraform output -json emqtt_bench_nodes | jq length)" -ge 1 ]; then
  log "Fetching emqtt_bench loadgen metrics..."
  e2e_latency_ms_95th=$(query_prometheus "query=histogram_quantile(0.95, sum(rate(e2e_latency_bucket[$PERIOD])) by (le))" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
  e2e_latency_ms_99th=$(query_prometheus "query=histogram_quantile(0.99, sum(rate(e2e_latency_bucket[$PERIOD])) by (le))" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  echo; echo "## Loadgen Metrics (emqtt_bench)"
  (
      printf "Metric\tValue\n"; printf "%s\t%s\n" "-------------------" "------"
      printf "e2e_latency_ms_95th\t%s\n" "$e2e_latency_ms_95th"; printf "e2e_latency_ms_99th\t%s\n" "$e2e_latency_ms_99th"
  ) | print_pretty_table; echo

  cat << EOF >> summary.md

## Loadgen metrics (emqtt_bench)

| Metric              | Value                 |
| ------------------- | --------------------- |
| e2e_latency_ms_95th | $e2e_latency_ms_95th  |
| e2e_latency_ms_99th | $e2e_latency_ms_99th  |
EOF

  log "Saving emqtt_bench loadgen metrics to $TMPDIR/loadgen_metrics.json..."
  cat << EOF > "$TMPDIR/loadgen_metrics.json"
{ "e2e_latency_ms_95th": $e2e_latency_ms_95th, "e2e_latency_ms_99th": $e2e_latency_ms_99th }
EOF
fi

if [ "$(terraform output -json emqttb_nodes | jq length)" -ge 1 ]; then
  log "Fetching emqttb loadgen metrics..."
  e2e_latency_persistent_session_sub=$(query_prometheus "query=emqttb_e2e_latency{group='persistent_session/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
  e2e_latency_pubsub_fwd_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" --data-urlencode "query=emqttb_e2e_latency{group='pubsub_fwd/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
  e2e_latency_sub_sub=$(query_prometheus "query=emqttb_e2e_latency{group='sub/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
  e2e_latency_sub_flapping_sub=$(query_prometheus "query=emqttb_e2e_latency{group='sub_flapping/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')
  published_messages_persistent_session_pub=$(query_prometheus "query=emqttb_published_messages{group='persistent_session/pub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  published_messages_pub_pub=$(query_prometheus "query=emqttb_published_messages{group='pub/pub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  published_messages_pubsub_fwd=$(query_prometheus "query=emqttb_published_messages{group='pubsub_fwd'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  published_messages_pubsub_fwd_pub=$(query_prometheus "query=emqttb_published_messages{group='pubsub_fwd/pub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  received_messages_persistent_session_sub=$(query_prometheus "query=emqttb_received_messages{group='persistent_session/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  received_messages_sub_sub=$(query_prometheus "query=emqttb_received_messages{group='sub/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  received_messages_pubsub_fwd_sub=$(query_prometheus "query=emqttb_received_messages{group='pubsub_fwd/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')
  received_messages_sub_flapping_sub=$(query_prometheus "query=emqttb_received_messages{group='sub_flapping/sub'}" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

  echo; echo "## Loadgen metrics (emqttb)";
  (
      printf "Metric\tValue\n"; printf "%s\t%s\n" "----------------------------------------" "-----------"
      printf "e2e_latency{persistent_session/sub}\t%s\n" "$e2e_latency_persistent_session_sub"
      printf "e2e_latency{pubsub_fwd/sub}\t%s\n" "$e2e_latency_pubsub_fwd_sub"
      printf "e2e_latency{sub/sub}\t%s\n" "$e2e_latency_sub_sub"
      printf "e2e_latency{sub_flapping/sub}\t%s\n" "$e2e_latency_sub_flapping_sub"
      printf "published_messages{persistent_session/pub}\t%s\n" "$published_messages_persistent_session_pub"
      printf "published_messages{pub/pub}\t%s\n" "$published_messages_pub_pub"
      printf "published_messages{pubsub_fwd}\t%s\n" "$published_messages_pubsub_fwd"
      printf "published_messages{pubsub_fwd/pub}\t%s\n" "$published_messages_pubsub_fwd_pub"
      printf "received_messages{persistent_session/sub}\t%s\n" "$received_messages_persistent_session_sub"
      printf "received_messages{sub/sub}\t%s\n" "$received_messages_sub_sub"
      printf "received_messages{pubsub_fwd/sub}\t%s\n" "$received_messages_pubsub_fwd_sub"
      printf "received_messages{sub_flapping/sub}\t%s\n" "$received_messages_sub_flapping_sub"
  ) | print_pretty_table; echo

  cat << EOF >> summary.md

## Loadgen metrics (emqttb)

| Metric                                   | Value                                      |
| ---------------------------------------- | ------------------------------------------ |
| e2e_latency{persistent_session/sub}      | $e2e_latency_persistent_session_sub        |
| e2e_latency{pubsub_fwd/sub}              | $e2e_latency_pubsub_fwd_sub                |
| e2e_latency{sub/sub}                     | $e2e_latency_sub_sub                       |
| e2e_latency{sub_flapping/sub}            | $e2e_latency_sub_flapping_sub              |
| published_messages{persistent_session/pub} | $published_messages_persistent_session_pub |
| published_messages{pub/pub}              | $published_messages_pub_pub                |
| published_messages{pubsub_fwd}           | $published_messages_pubsub_fwd             |
| published_messages{pubsub_fwd/pub}       | $published_messages_pubsub_fwd_pub         |
| received_messages{persistent_session/sub}  | $received_messages_persistent_session_sub  |
| received_messages{sub/sub}               | $received_messages_sub_sub                 |
| received_messages{pubsub_fwd/sub}        | $received_messages_pubsub_fwd_sub          |
| received_messages{sub_flapping/sub}      | $received_messages_sub_flapping_sub        |
EOF
fi

echo "Summary report generated successfully."
echo "Report is saved in summary.md."
log "Script finished. Temporary files are in $TMPDIR."
