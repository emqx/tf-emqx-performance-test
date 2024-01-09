#!/usr/bin/env bash

set -xeuo pipefail

EMQX_BASE_URL="${EMQX_BASE_URL:-http://localhost:18083/api/v5}"
EMQX_ADMIN_USERNAME="${EMQX_ADMIN_USERNAME:-admin}"
EMQX_ADMIN_PASSWORD="${EMQX_ADMIN_PASSWORD:-public}"
CONNECTOR_NAME="${CONNECTOR_NAME:-perftest}"
ACTION_NAME="${ACTION_NAME:-perftest}"
RULE_NAME="${RULE_NAME:-perftest}"
HTTP_SERVER_URL="${HTTP_SERVER_URL:-http://localhost:8080}"
HTTP_SERVER_PATH="${HTTP_SERVER_PATH:-/}"
RULE_SQL="SELECT * FROM \"t/#\""
BODY_TEMPLATE='${payload}'

while [ "$#" -gt 0 ]; do
    case $1 in
        --emqx-base-url)
            EMQX_URL="$2"
            shift 2
            ;;
        --username)
            EMQX_ADMIN_USERNAME="$2"
            shift 2
            ;;
        --password)
            EMQX_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --url)
            HTTP_SERVER_URL="$2"
            shift 2
            ;;
        --path)
            HTTP_SERVER_PATH="$2"
            shift 2
            ;;
        --connector-name)
            CONNECTOR_NAME="$2"
            shift 2
            ;;
        --action-name)
            ACTION_NAME="$2"
            shift 2
            ;;
        --body-template)
            BODY_TEMPLATE="$2"
            shift 2
            ;;
        --rule-name)
            RULE_NAME="$2"
            shift 2
            ;;
        --sql)
            RULE_SQL="$2"
            shift 2
            ;;
        *)
            echo "unknown option $1"
            exit 1
            ;;
    esac
done

jq -n \
   --arg username "${EMQX_ADMIN_USERNAME}" \
   --arg password "${EMQX_ADMIN_PASSWORD}" \
   '{"username": ($username), "password": ($password)}' > auth_payload.json
EMQX_TOKEN=$(curl -fsSL -X POST "${EMQX_BASE_URL}/login" \
                  -H 'Accept: application/json' \
                  -H 'Content-Type: application/json' \
                  -d @auth_payload.json | jq -r '.token')

RULE_ID=$(curl -sSL -H "Authorization: Bearer $EMQX_TOKEN" \
               "${EMQX_BASE_URL}/rules" | \
              jq -r --arg name "${RULE_NAME}" '.data[] | select(.name==($name)) | .id')

if [ -n "$RULE_ID" ]; then
    curl -sSL \
         -H "Authorization: Bearer $EMQX_TOKEN" \
         -X DELETE \
         "${EMQX_BASE_URL}/rules/${RULE_ID}"
fi

curl -sSL \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X DELETE \
     "${EMQX_BASE_URL}/actions/http:${ACTION_NAME}"

curl -sSL \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X DELETE \
     "${EMQX_BASE_URL}/connectors/http:${CONNECTOR_NAME}"

jq -n \
   --arg name "${CONNECTOR_NAME}" \
   --arg url "${HTTP_SERVER_URL}" \
   '{
     "name": ($name),
     "url": ($url),
     "type": "http",
     "connect_timeout": "15s",
     "pool_size": 1024,
     "pool_type": "random",
     "enable": true,
     "headers": {
       "content-type": "application/json"
     },
     "enable_pipelining": 100
   }' > connector_payload.json

curl -fsSL \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X POST \
     -d @connector_payload.json \
     "${EMQX_BASE_URL}/connectors"

jq -n \
   --arg connector_name "${CONNECTOR_NAME}" \
   --arg action_name "${ACTION_NAME}" \
   --arg body "${BODY_TEMPLATE}" \
   --arg path "${HTTP_SERVER_PATH}" \
   '{
     "name": ($action_name),
     "type": "http",
     "enable": true,
     "parameters": {
       "path": ($path),
       "body": ($body),
       "headers": {},
       "method": "post"
     },
     "connector": ($connector_name),
     "resource_opts": {
       "worker_pool_size": 1024,
       "request_ttl": "300s",
       "query_mode": "async",
       "health_check_interval": "15s"
     }
   }' > action_payload.json

curl -fsSL \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X POST \
     -d @action_payload.json \
     "${EMQX_BASE_URL}/actions"

jq -n \
   --arg rule_name "${RULE_NAME}" \
   --arg action_name "http:${ACTION_NAME}" \
   --arg rule_sql "${RULE_SQL}" \
   '{
      "name": ($rule_name),
      "sql": ($rule_sql),
      "actions": [
        ($action_name)
      ],
      "enable": true,
      "description": "",
      "metadata": {}
   }' > rule_payload.json

curl -fsSL \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X POST \
     -d @rule_payload.json \
     "${EMQX_BASE_URL}/rules"
