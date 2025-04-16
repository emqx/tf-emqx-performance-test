#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# The return value of a pipeline is the status of the last command to exit with a non-zero status,
# or zero if no command exited with a non-zero status.
set -euo pipefail

# --- Configuration ---
# Temporary directory for storing intermediate files. Defaults to a system-generated temp directory.
TMPDIR=${TMPDIR:-$(mktemp -d)}
# Prometheus URL. Defaults to the value obtained from terraform output.
PROMETHEUS_URL=${PROMETHEUS_URL:-$(terraform output -raw prometheus_url)}
# EMQX API URL. Defaults to the value obtained from terraform output.
EMQX_API_URL=${EMQX_API_URL:-$(terraform output -raw emqx_dashboard_url)}
# EMQX Version Family (e.g., 5). Defaults to the value obtained from terraform output.
EMQX_VERSION_FAMILY=${EMQX_VERSION_FAMILY:-$(terraform output -raw emqx_version_family)}
# EMQX Dashboard Credentials (user:pass). Defaults to the value obtained from terraform output.
EMQX_DASHBOARD_CREDENTIALS=${EMQX_DASHBOARD_CREDENTIALS:-$(terraform output -raw emqx_dashboard_credentials)}
# Time period for rate calculations in Prometheus queries. Defaults to 5 minutes.
PERIOD=${PERIOD:-5m}

# --- EMQX Authentication and Setup ---
# Extract username and password from credentials string.
DASHBOARD_USER=$(echo $EMQX_DASHBOARD_CREDENTIALS | cut -d: -f1)
DASHBOARD_PASS=$(echo $EMQX_DASHBOARD_CREDENTIALS | cut -d: -f2)

# Prepare login payload for EMQX API.
LOGIN_PAYLOAD=$(cat <<EOF
{
  "username": "$DASHBOARD_USER",
  "password": "$DASHBOARD_PASS"
}
EOF
)

# Call EMQX /login endpoint to get the version and authentication token.
echo "Logging into EMQX API at $EMQX_API_URL..."
curl -s -H 'content-type: application/json' -d "${LOGIN_PAYLOAD}" "$EMQX_API_URL/api/v5/login" > "$TMPDIR/login.json"
EMQX_VERSION=$(jq -r '.version' "$TMPDIR/login.json")
TOKEN=$(jq -r '.token' "$TMPDIR/login.json")
echo "Logged in successfully. EMQX Version: $EMQX_VERSION"

# --- Fetch EMQX Data ---
echo "Fetching EMQX monitoring data..."
# Save current monitor data, metrics, and stats from EMQX API.
curl -s -H "Authorization: Bearer $TOKEN" "$EMQX_API_URL/api/v5/monitor_current" > "$TMPDIR/monitor_current.json"
curl -s -H "Authorization: Bearer $TOKEN" "$EMQX_API_URL/api/v${EMQX_VERSION_FAMILY}/metrics" > "$TMPDIR/metrics.json"
curl -s -H "Authorization: Bearer $TOKEN" "$EMQX_API_URL/api/v${EMQX_VERSION_FAMILY}/stats" > "$TMPDIR/stats.json"
echo "EMQX data fetched."

# --- Fetch Node Exporter Metrics from Prometheus ---
echo "Fetching Node metrics from Prometheus at $PROMETHEUS_URL..."

# CPU Utilization (%)
# Calculate the percentage of non-idle CPU time over the specified period.
echo "Fetching CPU metrics..."
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=(sum by(instance) (irate(node_cpu_seconds_total{mode!='idle'}[$PERIOD])) / on(instance) group_left sum by (instance)(irate(node_cpu_seconds_total[$PERIOD])))*100" | \
  jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "cpu": (.value[1]|tonumber|.*100|round/100)}' | \
  jq -rs > "$TMPDIR/cpu.json"

# Memory Utilization (%)
# Calculate the percentage of used memory (Total - Available) over the specified period.
echo "Fetching Memory metrics..."
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=100-((avg_over_time(node_memory_MemAvailable_bytes[$PERIOD])*100)/avg_over_time(node_memory_MemTotal_bytes[$PERIOD]))" | \
  jq '.data.result[] | {"host": .metric.instance|split(".")[0], "mem": (.value[1]|tonumber|.*100|round/100)}' | \
  jq -rs > "$TMPDIR/mem.json"

# Disk Write IOPS
# Calculate the rate of completed disk writes over the specified period.
echo "Fetching Disk Write IOPS metrics..."
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum by (instance) (irate(node_disk_writes_completed_total[$PERIOD]))" | \
  jq '.data.result[] | {"host": .metric.instance|split(".")[0], "disk": (.value[1]|tonumber|.*100|round/100)}' | \
  jq -rs > "$TMPDIR/disk.json"

# Network Receive Bytes per Second (B/s)
# Calculate the rate of network bytes received, excluding the loopback device. Value is stored as B/s.
echo "Fetching Network Receive metrics (B/s)..."
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum by (instance) (irate(node_network_receive_bytes_total{device!='lo'}[$PERIOD]))" | \
  jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "net_rx": (.value[1]|tonumber)}' | \
  jq -rs > "$TMPDIR/net_rx.json"

# Network Transmit Bytes per Second (B/s)
# Calculate the rate of network bytes transmitted, excluding the loopback device. Value is stored as B/s.
echo "Fetching Network Transmit metrics (B/s)..."
curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum by (instance) (irate(node_network_transmit_bytes_total{device!='lo'}[$PERIOD]))" | \
  jq '.data.result[] | {"host": (.metric.instance|split(".")[0]), "net_tx": (.value[1]|tonumber)}' | \
  jq -rs > "$TMPDIR/net_tx.json"

echo "Node metrics fetched."

# --- Process and Format Node Data ---
echo "Processing node data..."
# Combine CPU, Memory, Disk, and Network metrics per host.
# Group by host, sum the metrics (though each file should only have one entry per host).
# Convert Network B/s to Mbit/s (* 8 / 1,000,000) and round to 2 decimal places.
# Format into a TSV string, and then convert to a Markdown table.
# Use `// 0` to provide a default value if a metric is missing for a host.
node_data=$(jq -s 'add | group_by(.host) | map(add)' \
  "$TMPDIR/cpu.json" \
  "$TMPDIR/mem.json" \
  "$TMPDIR/disk.json" \
  "$TMPDIR/net_rx.json" \
  "$TMPDIR/net_tx.json" | \
  jq -r '(["Host", "Avg CPU%", "Avg RAM%", "Disk Write IOPS", "Net RX (Mbit/s)", "Net TX (Mbit/s)"], # Header row
         ["----", "-------", "-------", "---------------", "---------------", "---------------"], # Separator row
         (.[] | [
           .host,
           .cpu // 0,
           .mem // 0,
           .disk // 0,
           (((.net_rx // 0) * 8 / 1000000 * 100 | round) / 100), # Convert net_rx B/s to Mbit/s
           (((.net_tx // 0) * 8 / 1000000 * 100 | round) / 100)  # Convert net_tx B/s to Mbit/s
         ] | map(tostring))) # Data rows
         | @tsv' | \
  sed 's/\t/ | /g' | sed 's/^/| /' | sed 's/$/ |/' # Convert TSV to Markdown table format
)
echo "Node data processed."

# --- Fetch EMQX Metrics from Prometheus ---
echo "Fetching EMQX metrics from Prometheus..."

# Fetch various EMQX counters and rates from Prometheus.
# Use `jq -c '.data.result[0].value[1]? // 0 | tonumber'` to extract the numeric value or handle missing data.
emqx_connections=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_connections_count)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_live_connections=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_live_connections_count)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_messages_received=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_received)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_messages_sent=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_sent)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_messages_acked=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_acked)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_messages_publish=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_publish)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_messages_delivered=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_delivered)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

emqx_messages_dropped=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(emqx_messages_dropped)" | jq -c '.data.result[0].value[1]? // 0 | tonumber')

# Calculate message rates over the specified period.
received_msg_rate=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(rate(emqx_messages_received[$PERIOD]))" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

sent_msg_rate=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "query=sum(rate(emqx_messages_sent[$PERIOD]))" | jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

echo "EMQX metrics fetched."

# --- Generate Summary Report ---
echo "Generating summary report (summary.md)..."

# Create the summary.md file using a heredoc.
cat << EOF > summary.md
# Benchmark '$(terraform output -raw bench_id)' summary

Using $(terraform output -raw spec_file)@$(git rev-parse --short HEAD) test spec.

EMQX version: $EMQX_VERSION

## Nodes

$node_data

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

# --- Save EMQX Metrics to JSON ---
echo "Saving EMQX metrics to $TMPDIR/emqx_metrics.json..."
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

# --- Fetch Loadgen Metrics (Conditional) ---

# Check if emqtt_bench nodes exist (using terraform output)
if [ "$(terraform output -json emqtt_bench_nodes | jq length)" -ge 1 ]; then
  echo "Fetching emqtt_bench loadgen metrics..."
  # Fetch E2E latency percentiles from Prometheus.
  e2e_latency_ms_95th=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=histogram_quantile(0.95, sum(rate(e2e_latency_bucket[$PERIOD])) by (le))" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  e2e_latency_ms_99th=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=histogram_quantile(0.99, sum(rate(e2e_latency_bucket[$PERIOD])) by (le))" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  # Append loadgen metrics to the summary report.
  cat << EOF >> summary.md

## Loadgen metrics (emqtt_bench)

| Metric              | Value                 |
| ------------------- | --------------------- |
| e2e_latency_ms_95th | $e2e_latency_ms_95th  |
| e2e_latency_ms_99th | $e2e_latency_ms_99th  |
EOF

  # Save loadgen metrics to a JSON file.
  echo "Saving emqtt_bench loadgen metrics to $TMPDIR/loadgen_metrics.json..."
  cat << EOF > "$TMPDIR/loadgen_metrics.json"
{
  "e2e_latency_ms_95th": $e2e_latency_ms_95th,
  "e2e_latency_ms_99th": $e2e_latency_ms_99th
}
EOF
fi

# Check if emqttb nodes exist (using terraform output)
if [ "$(terraform output -json emqttb_nodes | jq length)" -ge 1 ]; then
  echo "Fetching emqttb loadgen metrics..."
  # Fetch various latency and message count metrics specific to emqttb groups.
  # Latency queries
  e2e_latency_persistent_session_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='persistent_session/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  e2e_latency_pubsub_fwd_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='pubsub_fwd/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  e2e_latency_sub_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='sub/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  e2e_latency_sub_flapping_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_e2e_latency{group='sub_flapping/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber | .*100 | round/100')

  # Published messages queries
  published_messages_persistent_session_pub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='persistent_session/pub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  published_messages_pub_pub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='pub/pub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  published_messages_pubsub_fwd=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='pubsub_fwd'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  published_messages_pubsub_fwd_pub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_published_messages{group='pubsub_fwd/pub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  # Received messages queries
  received_messages_persistent_session_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='persistent_session/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  received_messages_sub_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='sub/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  received_messages_pubsub_fwd_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='pubsub_fwd/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  received_messages_sub_flapping_sub=$(curl -s "$PROMETHEUS_URL/api/v1/query" \
    --data-urlencode "query=emqttb_received_messages{group='sub_flapping/sub'}" | \
    jq -c '.data.result[0].value[1]? // 0 | tonumber')

  # Append emqttb loadgen metrics to the summary report.
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

# --- Final Output ---
# Display the generated summary report to standard output.
echo "Summary report generated successfully."
cat summary.md

# --- Cleanup ---
# Optionally remove the temporary directory
# rm -rf "$TMPDIR"
echo "Script finished. Temporary files are in $TMPDIR. Report is saved in summary.md."
