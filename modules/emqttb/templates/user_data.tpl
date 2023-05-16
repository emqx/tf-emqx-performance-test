cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.rmem_default=262144000
net.core.wmem_default=262144000
net.core.rmem_max=262144000
net.core.wmem_max=262144000
net.ipv4.tcp_mem=378150000  504200000  756300000
fs.file-max=2097152
fs.nr_open=2097152
EOF

sysctl -p

sysctl -w net.ipv4.tcp_max_syn_backlog=16384
sysctl -w net.ipv4.ip_local_port_range='1024 65535'
sysctl -w net.ipv4.tcp_fin_timeout=5

mkdir emqttb && cd emqttb
wget ${package_url}
tar xzf ./emqttb*.tar.gz

# GRAFANA=
# if [ -n "${grafana_api_key}" ]; then
#   export EMQTTB_METRICS__GRAFANA__API_KEY="Bearer ${grafana_api_key}"
#   export EMQTTB_METRICS__GRAFANA__URL="${grafana_url}"
#   GRAFANA="--grafana"
# fi

function signal_done() {
  sleep ${test_duration}
  touch EMQTTB_DONE
  aws s3 cp EMQTTB_DONE s3://${s3_bucket_name}/${bench_id}/EMQTTB_DONE
}

signal_done &

bin/emqttb --restapi --pushgw --pushgw-url http://${prometheus_push_gw}:9091 --log-level error ${scenario} @g --host ${emqx_hosts}
