#!/usr/bin/env bash

set -xeuo pipefail

EMQX_BASE_URL="${EMQX_BASE_URL:-http://localhost:18083/api/v5}"
EMQX_ADMIN_USERNAME="${EMQX_ADMIN_USERNAME:-admin}"
EMQX_ADMIN_PASSWORD="${EMQX_ADMIN_PASSWORD:-public}"
MQTT_USERNAME="${MQTT_USERNAME:-perftest}"
MQTT_PASSWORD="${MQTT_PASSWORD:-perftest}"

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
        --mqtt-username)
            MQTT_USERNAME="$2"
            shift 2
            ;;
        --mqtt-password)
            MQTT_PASSWORD="$2"
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

echo '{
       "mechanism": "password_based",
       "backend": "built_in_database",
       "password_hash_algorithm": {
         "name": "sha256",
         "salt_position": "suffix"
       },
       "user_id_type": "username"
    }' > authentication_payload.json

curl -fsSL \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X POST \
     -d @authentication_payload.json \
     "${EMQX_BASE_URL}/authentication"

jq -n \
   --arg user_id "${MQTT_USERNAME}" \
   --arg password "${MQTT_PASSWORD}" \
   '{
     "user_id": ($user_id),
     "password": ($password)
   }' > users_payload.json

curl -fsSL \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer $EMQX_TOKEN" \
     -X POST \
     -d @users_payload.json \
     "${EMQX_BASE_URL}/authentication/password_based%3Abuilt_in_database/users"
