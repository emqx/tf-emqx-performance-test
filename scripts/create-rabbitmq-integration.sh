#!/usr/bin/env bash

set -xeuo pipefail

cat <<EOF > /tmp/rabbitmq.conf
connectors {
  rabbitmq {
    rabbit {
      enable = true
      server = "${RABBITMQ_SERVER}"
      port = 5672
      username = emqx
      password = emqx
      virtual_host = "/"
    }
  }
}

actions {
  rabbitmq {
    rabbit {
      connector = rabbit
      enable = true
      parameters {
        delivery_mode = non_persistent
        exchange = emqx
        payload_template = "\${payload}"
        routing_key = emqx
        wait_for_publish_confirmations = true
      }
      resource_opts {
        batch_size = 1000
        inflight_window = 100
        query_mode = async
        worker_pool_size = 16
      }
    }
  }
}

rule_engine {
  ignore_sys_message = true
  jq_function_default_timeout = "10s"
  rules {
    "rabbit" {
      actions = [
        "rabbitmq:rabbit"
      ]
      enable = true
      name = rabbit
      sql = """~
        SELECT * FROM "perftest/#"~"""
    }
  }
}
EOF

emqx ctl conf load /tmp/rabbitmq.conf
