#!/usr/bin/env bash

set -euo pipefail

TMPDIR=${TMPDIR:-$(mktemp -d)}
PROMETHEUS_URL=${PROMETHEUS_URL:-$(terraform output -raw prometheus_url)}
EMQX_API_URL=${EMQX_API_URL:-$(terraform output -raw emqx_dashboard_url)}
PERIOD=${PERIOD:-5m}

# save emqx metrics
curl -s -u perftest:perftest "$EMQX_API_URL/api/v5/monitor_current" > "$TMPDIR/monitor_current.json"
curl -s -u perftest:perftest "$EMQX_API_URL/api/v5/metrics" > "$TMPDIR/metrics.json"
curl -s -u perftest:perftest "$EMQX_API_URL/api/v5/stats" > "$TMPDIR/stats.json"

# cpu
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=(sum by(instance) (irate(node_cpu_seconds_total{mode!='idle'}[$PERIOD])) / on(instance) group_left sum by (instance)(irate(node_cpu_seconds_total[$PERIOD])))*100" | \
  jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "cpu": (.value[1]|tonumber|.*100|round/100)}' | \
  jq -rs > "$TMPDIR/cpu.json"

# memory
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=100-((avg_over_time(node_memory_MemAvailable_bytes[$PERIOD])*100)/avg_over_time(node_memory_MemTotal_bytes[$PERIOD]))" | \
  jq '.data.result[] | {"host": .metric.instance|split(".")[0], "mem": (.value[1]|tonumber|.*100|round/100)}' | \
  jq -rs > "$TMPDIR/mem.json"

# disk
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=irate(node_disk_writes_completed_total[$PERIOD])" | \
  jq '.data.result[] | {"host": .metric.instance|split(".")[0], "disk": (.value[1]|tonumber|.*100|round/100)}' | \
  jq -rs > "$TMPDIR/disk.json"

node_data=$(jq -s 'add | group_by(.host) | map(add)' "$TMPDIR/cpu.json" "$TMPDIR/mem.json" "$TMPDIR/disk.json" | jq -r '(["Host", "Avg CPU%", "Avg RAM%", "Disk Write IOPS"], ["----", "-------", "-------", "---------------"], (.[] | [.host, .cpu, .mem, .disk] | map(tostring))) | @tsv' | sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/')

# emqx metrics
emqx_connections=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_connections_count)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_live_connections=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_live_connections_count)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_messages_received=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_received)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_messages_sent=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_sent)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_messages_acked=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_acked)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_messages_publish=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_publish)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_messages_delivered=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_delivered)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

emqx_messages_dropped=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_dropped)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

received_msg_rate=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(rate(emqx_messages_received[$PERIOD]))" | jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

sent_msg_rate=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(rate(emqx_messages_sent[$PERIOD]))" | jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

cat << EOF > summary.md
# Benchmark '$(terraform output -raw bench_id)' summary

Using $(terraform output -raw spec_file)@$(git rev-parse --short HEAD) test spec.

## Nodes

$node_data

## EMQX metrics

| Metric                        | Value |
| ------                        | ----- |
| messages_received             | $emqx_messages_received |
| messages_sent                 | $emqx_messages_sent |
| messages_acked                | $emqx_messages_acked |
| messages_publish              | $emqx_messages_publish |
| messages_delivered            | $emqx_messages_delivered |
| messages_dropped              | $emqx_messages_dropped |
| connections                   | $emqx_connections |
| live_connections              | $emqx_live_connections |

## EMQX aggregated metrics

| Metric                        | Value |
| ------                        | ----- |
| received_msg_rate             | $received_msg_rate |
| sent_msg_rate                 | $sent_msg_rate |
EOF

cat << EOF > "$TMPDIR/emqx_metrics.json"
{
  "messages_received": $emqx_messages_received,
  "messages_sent": $emqx_messages_sent,
  "messages_acked": $emqx_messages_acked,
  "messages_publish": $emqx_messages_publish,
  "messages_delivered": $emqx_messages_delivered,
  "messages_dropped": $emqx_messages_dropped,
  "connections": $emqx_connections,
  "live_connections": $emqx_live_connections,
  "received_msg_rate": $received_msg_rate,
  "sent_msg_rate": $sent_msg_rate
}
EOF

if [ $(terraform output -json emqtt_bench_nodes | jq length) -ge 1 ]; then
  e2e_latency_ms_95th=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=histogram_quantile(0.95, sum(rate(e2e_latency_bucket[$PERIOD])) by (le))" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

  e2e_latency_ms_99th=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=histogram_quantile(0.99, sum(rate(e2e_latency_bucket[$PERIOD])) by (le))" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

  cat << EOF >> summary.md

## Loadgen metrics

| Metric               | Value |
| ------               | ----- |
| e2e_latency_ms_95th  | $e2e_latency_ms_95th |
| e2e_latency_ms_99th  | $e2e_latency_ms_99th |
EOF

  cat << EOF > "$TMPDIR/loadgen_metrics.json"
{
  "e2e_latency_ms_95th": $e2e_latency_ms_95th,
  "e2e_latency_ms_99th": $e2e_latency_ms_99th
}
EOF
fi

if [ $(terraform output -json emqttb_nodes | jq length) -ge 1 ]; then
  # Latency queries
  e2e_latency_persistent_session_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='persistent_session/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

  e2e_latency_pubsub_fwd_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='pubsub_fwd/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

  e2e_latency_sub_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='sub/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

  e2e_latency_sub_flapping_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='sub_flapping/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber | .*100 | round/100')

  # Published messages queries
  published_messages_persistent_session_pub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='persistent_session/pub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  published_messages_pub_pub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='pub/pub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  published_messages_pubsub_fwd=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='pubsub_fwd'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  published_messages_pubsub_fwd_pub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='pubsub_fwd/pub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  # Received messages queries
  received_messages_persistent_session_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='persistent_session/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  received_messages_sub_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='sub/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  published_messages_pubsub_fwd_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='pubsub_fwd/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  published_messages_sub_flapping_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='sub_flapping/sub'}" | \
    jq -c '.data.result[0].value[1]? // empty | tonumber')

  cat << EOF >> summary.md

## Loadgen metrics

| Metric                                     | Value |
| ------                                     | ----- |
| e2e_latency{persistent_session/sub}        | $e2e_latency_persistent_session_sub |
| e2e_latency{pubsub_fwd/sub}                | $e2e_latency_pubsub_fwd_sub |
| e2e_latency{sub/sub}                       | $e2e_latency_sub_sub |
| e2e_latency{sub_flapping/sub}              | $e2e_latency_sub_flapping_sub |
| published_messages{persistent_session/pub} | $published_messages_persistent_session_pub |
| published_messages{pub/pub}                | $published_messages_pub_pub |
| published_messages{pubsub_fwd}             | $published_messages_pubsub_fwd |
| published_messages{pubsub_fwd/pub}         | $published_messages_pubsub_fwd_pub |
| received_messages{persistent_session/sub}  | $received_messages_persistent_session_sub |
| received_messages{sub/sub}                 | $received_messages_sub_sub |
| received_messages{pubsub_fwd/sub}          | $published_messages_pubsub_fwd_sub |
| received_messages{sub_flapping/sub}        | $published_messages_sub_flapping_sub |
EOF
fi

cat summary.md
