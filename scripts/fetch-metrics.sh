#!/usr/bin/env bash

set -euo pipefail
#set -x

TMPDIR=$(mktemp -d)

EMQX_API_URL=${EMQX_API_URL:-$(terraform output -raw emqx_dashboard_url)}
curl -s -u perftest:perftest "$EMQX_API_URL/api/v5/monitor_current" > "$TMPDIR/monitor_current.json"

PROMETHEUS_URL=${PROMETHEUS_URL:-$(terraform output -raw prometheus_url)}
PERIOD=${PERIOD:-5m}

# cpu
curl -gs "$PROMETHEUS_URL/api/v1/query?query=(sum%20by(instance)%20(irate(node_cpu_seconds_total{mode!=\"idle\"}[$PERIOD]))/on(instance)%20group_left%20sum%20by%20(instance)((irate(node_cpu_seconds_total[$PERIOD]))))*100" | jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "cpu": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > "$TMPDIR/cpu.json"
# memory
curl -gs "$PROMETHEUS_URL/api/v1/query?query=100-((avg_over_time(node_memory_MemAvailable_bytes[$PERIOD])*100)/avg_over_time(node_memory_MemTotal_bytes[$PERIOD]))" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "mem": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > "$TMPDIR/mem.json"

# disk
curl -gs "$PROMETHEUS_URL/api/v1/query?query=irate(node_disk_writes_completed_total[$PERIOD])" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "disk": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > "$TMPDIR/disk.json"

node_data=$(jq -s 'add | group_by(.host) | map(add)' "$TMPDIR/cpu.json" "$TMPDIR/mem.json" "$TMPDIR/disk.json" | jq -r '["Host","Avg_CPU","Avg_Mem","Disk_Write_IOPS"], ["----","-------","-------","---------------"], (.[] | [.host, .cpu, .mem, .disk]) | @tsv' | column -t)

# emqx metrics
emqx_connections=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_live_connections_count)" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_received=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_received)" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_sent=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_sent)" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_acked=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_acked)" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_publish=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_publish)" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_delivered=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_delivered)" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_dropped=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_dropped)" | jq -c '.data.result[0].value[1]? // empty|tonumber')

# emqx exporter metrics
emqx_messages_input_period_second=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=emqx_messages_input_period_second" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_messages_output_period_second=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=emqx_messages_output_period_second" | jq -c '.data.result[0].value[1]? // empty|tonumber')
emqx_cluster_cpu_load=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum%20by(node)%20(emqx_cluster_cpu_load{load=\"load15\"})" | jq -c '.data.result[0].value[1]? // empty|tonumber|.*100|round/100')

# emqtt-bench metrics
e2e_latency_ms_95th=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=histogram_quantile(0.95%2C%20sum(rate(e2e_latency_bucket%5B$PERIOD%5D))%20by%20(le))" | jq -c '.data.result[0].value[1]? // empty|tonumber|.*100|round/100')
e2e_latency_ms_99th=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=histogram_quantile(0.99%2C%20sum(rate(e2e_latency_bucket%5B$PERIOD%5D))%20by%20(le))" | jq -c '.data.result[0].value[1]? // empty|tonumber|.*100|round/100')

cat << EOF > summary.txt
$node_data

EMQX /monitor_current
connections:                   $(cat "$TMPDIR/monitor_current.json" | jq -r '.connections')
topics:                        $(cat "$TMPDIR/monitor_current.json" | jq -r '.topics')
subscriptions:                 $(cat "$TMPDIR/monitor_current.json" | jq -r '.subscriptions')
live_connections:              $(cat "$TMPDIR/monitor_current.json" | jq -r '.live_connections')
subscriptions_durable:         $(cat "$TMPDIR/monitor_current.json" | jq -r '.subscriptions_durable')
disconnected_durable_sessions: $(cat "$TMPDIR/monitor_current.json" | jq -r '.disconnected_durable_sessions')
subscriptions_ram:             $(cat "$TMPDIR/monitor_current.json" | jq -r '.subscriptions_ram')
retained_msg_count:            $(cat "$TMPDIR/monitor_current.json" | jq -r '.retained_msg_count')
shared_subscriptions:          $(cat "$TMPDIR/monitor_current.json" | jq -r '.shared_subscriptions')
dropped_msg_rate:              $(cat "$TMPDIR/monitor_current.json" | jq -r '.dropped_msg_rate')
persisted_rate:                $(cat "$TMPDIR/monitor_current.json" | jq -r '.persisted_rate')
received_msg_rate:             $(cat "$TMPDIR/monitor_current.json" | jq -r '.received_msg_rate')
sent_msg_rate:                 $(cat "$TMPDIR/monitor_current.json" | jq -r '.sent_msg_rate')
transformation_failed_rate:    $(cat "$TMPDIR/monitor_current.json" | jq -r '.transformation_failed_rate')
transformation_succeeded_rate: $(cat "$TMPDIR/monitor_current.json" | jq -r '.transformation_succeeded_rate')
validation_failed_rate:        $(cat "$TMPDIR/monitor_current.json" | jq -r '.validation_failed_rate')
validation_succeeded_rate:     $(cat "$TMPDIR/monitor_current.json" | jq -r '.validation_succeeded_rate')

EMQX Exporter
messages_input_period_second:  $emqx_messages_input_period_second
messages_output_period_second: $emqx_messages_output_period_second
cluster_cpu_load:              $emqx_cluster_cpu_load
connections:                   $emqx_connections
messages_received:             $emqx_messages_received
messages_sent:                 $emqx_messages_sent
messages_acked:                $emqx_messages_acked
messages_publish:              $emqx_messages_publish
messages_delivered:            $emqx_messages_delivered
messages_dropped:              $emqx_messages_dropped

Loadgen metrics
e2e_latency_ms_95th:           $e2e_latency_ms_95th
e2e_latency_ms_99th:           $e2e_latency_ms_99th
EOF

cat summary.txt
