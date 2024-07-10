#!/usr/bin/env bash

set -xeuo pipefail

cat <<EOF > /tmp/rabbitmq.conf
bridges {
  rabbitmq {
    rabbit {
      enable = true
      server = "${RABBITMQ_SERVER}"
      port = 5672
      username = "emqx"
      password = "emqx"
      virtual_host = "/"
      exchange = "emqx"
      routing_key = "emqx"
      payload_template = "\${.}"
      pool_size = 8
      publish_confirmation_timeout = "30s"
      wait_for_publish_confirmations = true
      resource_opts {
        batch_size = "1000"
        inflight_window = 100
        max_buffer_bytes = "256MB"
        query_mode = "async"
        worker_pool_size = 16
      }
    }
  }
}
rule_engine {
  ignore_sys_message = true
  rules {
    "rabbit" {
      actions = ["rabbitmq:rabbit"]
      enable = true
      sql = "SELECT\n  *\nFROM\n  \"perftest/#\""
    }
  }
}
EOF

emqx ctl conf load /tmp/rabbitmq.conf
