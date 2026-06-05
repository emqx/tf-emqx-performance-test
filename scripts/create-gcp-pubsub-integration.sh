#!/usr/bin/env bash
# Create (idempotently) an EMQX -> GCP Pub/Sub producer integration:
# connector (holds the service-account JSON key) + action (target topic) + rule.
# Driven by emqx_script_env from Terraform/Ansible.

set -euo pipefail

EMQX_BASE_URL="${EMQX_BASE_URL:-http://localhost:18083/api/v5}"
EMQX_ADMIN_USERNAME="${EMQX_ADMIN_USERNAME:-admin}"
EMQX_ADMIN_PASSWORD="${EMQX_ADMIN_PASSWORD:-public}"
CONNECTOR_NAME="${CONNECTOR_NAME:-perftest}"
ACTION_NAME="${ACTION_NAME:-perftest}"
RULE_NAME="${RULE_NAME:-perftest}"
PUBSUB_TOPIC="${PUBSUB_TOPIC:?PUBSUB_TOPIC is required}"
PUBSUB_SERVICE_ACCOUNT_JSON="${PUBSUB_SERVICE_ACCOUNT_JSON:?PUBSUB_SERVICE_ACCOUNT_JSON is required}"
# Forward this MQTT topic filter to Pub/Sub. Blank payload_template => full message payload.
RULE_SQL="${PUBSUB_RULE_SQL:-SELECT * FROM \"bench/#\"}"
PAYLOAD_TEMPLATE="${PUBSUB_PAYLOAD_TEMPLATE:-}"

TYPE="gcp_pubsub_producer"

EMQX_TOKEN=$(jq -n --arg u "$EMQX_ADMIN_USERNAME" --arg p "$EMQX_ADMIN_PASSWORD" '{username:$u,password:$p}' \
  | curl -fsSL -X POST "${EMQX_BASE_URL}/login" \
      -H 'Content-Type: application/json' -H 'Accept: application/json' -d @- \
  | jq -r '.token')

auth() { curl -sSL -H "Authorization: Bearer ${EMQX_TOKEN}" "$@"; }

# Tear down any previous instance so the script is rerunnable.
RULE_ID=$(auth "${EMQX_BASE_URL}/rules" | jq -r --arg n "$RULE_NAME" '.data[]? | select(.name==$n) | .id')
[ -n "$RULE_ID" ] && auth -X DELETE "${EMQX_BASE_URL}/rules/${RULE_ID}" >/dev/null || true
auth -X DELETE "${EMQX_BASE_URL}/actions/${TYPE}:${ACTION_NAME}" >/dev/null || true
auth -X DELETE "${EMQX_BASE_URL}/connectors/${TYPE}:${CONNECTOR_NAME}" >/dev/null || true

# Connector: holds the GCP credentials (service_account_json is a JSON *string*).
jq -n --arg name "$CONNECTOR_NAME" --arg type "$TYPE" --arg sa "$PUBSUB_SERVICE_ACCOUNT_JSON" '{
  name: $name,
  type: $type,
  enable: true,
  authentication: { type: "service_account_json", service_account_json: $sa },
  connect_timeout: "15s",
  pool_size: 8,
  pipelining: 100,
  max_retries: 2
}' | auth -fsSL -H 'Content-Type: application/json' -X POST -d @- "${EMQX_BASE_URL}/connectors" >/dev/null

# Action: target topic lives here.
jq -n --arg name "$ACTION_NAME" --arg type "$TYPE" --arg conn "$CONNECTOR_NAME" \
      --arg topic "$PUBSUB_TOPIC" --arg payload "$PAYLOAD_TEMPLATE" '{
  name: $name,
  type: $type,
  enable: true,
  connector: $conn,
  parameters: { pubsub_topic: $topic, payload_template: $payload },
  resource_opts: { query_mode: "async", worker_pool_size: 16, health_check_interval: "15s" }
}' | auth -fsSL -H 'Content-Type: application/json' -X POST -d @- "${EMQX_BASE_URL}/actions" >/dev/null

# Rule: route MQTT -> action.
jq -n --arg name "$RULE_NAME" --arg sql "$RULE_SQL" --arg action "${TYPE}:${ACTION_NAME}" '{
  name: $name,
  sql: $sql,
  actions: [ $action ],
  enable: true
}' | auth -fsSL -H 'Content-Type: application/json' -X POST -d @- "${EMQX_BASE_URL}/rules" >/dev/null

echo "GCP Pub/Sub integration created: rule '${RULE_NAME}' -> ${TYPE}:${ACTION_NAME} -> topic '${PUBSUB_TOPIC}'"
