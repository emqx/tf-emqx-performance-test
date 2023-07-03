#!/usr/bin/env bash

set -euo pipefail
set -x

PROMETHEUS_URL=${PROMETHEUS_URL:-$(terraform output -raw prometheus_url)}
PERIOD=${PERIOD:-30m}

# node_exporter cpu metrics
curl -gs "$PROMETHEUS_URL/api/v1/query?query=100-(avg%20by%20(instance)(irate(node_cpu_seconds_total{mode=\"idle\"}[$PERIOD]))*100)" | jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "cpu": (.value[1]|tonumber|round)}' | jq -rs > cpu.json

# node_exporter memory metrics
curl -gs "$PROMETHEUS_URL/api/v1/query?query=100*(1-((avg_over_time(node_memory_MemFree_bytes[$PERIOD])%2Bavg_over_time(node_memory_Cached_bytes[$PERIOD])%2Bavg_over_time(node_memory_Buffers_bytes[$PERIOD]))%2Favg_over_time(node_memory_MemTotal_bytes[$PERIOD])))" | jq '.data.result[] | {"host": .metric.instance|split(".")[0], "mem": (.value[1]|tonumber|round)}' | jq -rs > mem.json

# emqttb e2e latency
emqttb_e2e_latency=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=avg_over_time(emqttb_e2e_latency[$PERIOD])/1000" | jq -c '.data.result[0].value[1]? // empty | tonumber | round')

# emqttb publish latency
emqttb_publish_latency=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=avg_over_time(emqttb_group_op_time{operation='publish'}[$PERIOD])/1000" | jq -c '.data.result[0].value[1]? // empty | tonumber | round')

# emqttb published messages per second
emqttb_publish_msg_rate=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=rate(emqttb_published_messages{}[$PERIOD])" | jq -c '.data.result[0].value[1]? // empty | tonumber | round')

# emqttb received messages per second
emqttb_received_msg_rate=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=rate(emqttb_received_messages{}[$PERIOD])" | jq -c '.data.result[0].value[1]? // empty | tonumber | round')

# connections total
emqx_connections=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_connections_count)" | jq -c '.data.result[0].value[1]? // empty | tonumber')

# messages sent total
emqx_sent=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_sent)" | jq -c '.data.result[0].value[1]? // empty | tonumber')

# messages received total
emqx_received=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_received)" | jq -c '.data.result[0].value[1]? // empty | tonumber')

# messages dropped total
emqx_dropped=$(curl -gs "$PROMETHEUS_URL/api/v1/query?query=sum(emqx_messages_dropped)" | jq -c '.data.result[0].value[1]? // empty | tonumber')

node_data=$(jq -s 'add | group_by(.host) | map(add)' cpu.json mem.json | jq -r '["Host","Avg_CPU","Avg_Mem"], ["----","-------","-------"], (.[] | [.host, .cpu, .mem]) | @tsv' | column -t)
cat << EOF > message.txt
\`\`\`
Benchmark:    $TF_VAR_bench_id
EMQX cluster: $TF_VAR_emqx_instance_count x $TF_VAR_emqx_instance_type
emqttb:       $TF_VAR_emqttb_instance_count x $TF_VAR_emqttb_instance_type
\`\`\`

*emqttb metrics*
\`\`\`
end-to-end latency: $emqttb_e2e_latency ms
publish latency:    $emqttb_publish_latency ms
publish msg rate:   $emqttb_publish_msg_rate/s
received msg rate:  $emqttb_received_msg_rate/s
\`\`\`

*EMQX metrics*
\`\`\`
connections:   $emqx_connections
msgs sent:     $emqx_sent
msgs received: $emqx_received
msgs dropped:  $emqx_dropped
\`\`\`

*CPU and memory usage*
\`\`\`
$node_data
\`\`\`
EOF

message=$(cat message.txt)
message=${message//$'\n'/\\n}

cat <<EOF > slack-payload.json
{
  "username": "Performance test",
  "text": "$message",
  "icon_emoji": ":white_check_mark:"
}
EOF
