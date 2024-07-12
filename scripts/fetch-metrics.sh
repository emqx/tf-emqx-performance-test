#!/usr/bin/env bash

set -euo pipefail
#set -x

PROMETHEUS_URL=${PROMETHEUS_URL:-$(terraform output -raw prometheus_url)}
PERIOD=${PERIOD:-5m}

# cpu
curl -gs "$PROMETHEUS_URL/api/v1/query?query=(sum%20by(instance)%20(irate(node_cpu_seconds_total{mode!=\"idle\"}[$PERIOD]))/on(instance)%20group_left%20sum%20by%20(instance)((irate(node_cpu_seconds_total[$PERIOD]))))*100" | jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "cpu": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > cpu.json
# memory
curl -gs "$PROMETHEUS_URL/api/v1/query?query=100-((avg_over_time(node_memory_MemAvailable_bytes[$PERIOD])*100)/avg_over_time(node_memory_MemTotal_bytes[$PERIOD]))" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "mem": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > mem.json

# disk
curl -gs "$PROMETHEUS_URL/api/v1/query?query=irate(node_disk_writes_completed_total[$PERIOD])" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "disk": (.value[1]|tonumber|.*100|round/100)}' | jq -rs > disk.json

node_data=$(jq -s 'add | group_by(.host) | map(add)' cpu.json mem.json disk.json | jq -r '["Host","Avg_CPU","Avg_Mem","Disk_Write_IOPS"], ["----","-------","-------","---------------"], (.[] | [.host, .cpu, .mem, .disk]) | @tsv' | column -t)

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

cat << EOF > summary.txt
$node_data

EMQX Exporter
emqx_messages_input_period_second:  $emqx_messages_input_period_second
emqx_messages_output_period_second: $emqx_messages_output_period_second
emqx_cluster_cpu_load:              $emqx_cluster_cpu_load
emqx_connections:                   $emqx_connections
emqx_messages_received:             $emqx_messages_received
emqx_messages_sent:                 $emqx_messages_sent
emqx_messages_acked:                $emqx_messages_acked
emqx_messages_publish:              $emqx_messages_publish
emqx_messages_delivered:            $emqx_messages_delivered
emqx_messages_dropped:              $emqx_messages_dropped
EOF

cat summary.txt
