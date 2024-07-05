#!/usr/bin/env bash

set -xeuo pipefail

cat <<EOF > /tmp/oracle.conf
connectors {
  oracle {
    perftest {
      enable = true
      server = "${ORACLE_SERVER}:${ORACLE_PORT}"
      sid = orcl
      username = "${ORACLE_DB_USERNAME}"
      password = "${ORACLE_DB_PASSWORD}"
      pool_size = 128
    }
  }
}

actions {
  oracle {
    perftest {
      connector = perftest
      enable = true
      parameters {
        sql = "insert into t_mqtt_msgs(msgid, topic, qos, payload) values (\${id}, \${topic}, \${qos}, \${payload})"
      }
      resource_opts {
        worker_pool_size = 128
        batch_size = 1000
      }
    }
  }
}

rule_engine {
  ignore_sys_message = true
  jq_function_default_timeout = "10s"
  rules {
    "oracle" {
      actions = [
        "oracle:perftest"
      ]
      enable = true
      name = perftest
      sql = """~
        SELECT * FROM "perftest/#"~"""
    }
  }
}
EOF

emqx ctl conf load /tmp/oracle.conf
