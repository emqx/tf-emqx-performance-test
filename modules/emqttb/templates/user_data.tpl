sysctl -w fs.file-max=2097152
sysctl -w fs.nr_open=2097152
echo 2097152 > /proc/sys/fs/nr_open
ulimit -n 2097152

echo 'fs.file-max = 2097152' >> /etc/sysctl.conf
echo 'DefaultLimitNOFILE=2097152' >> /etc/systemd/system.conf

echo >> /etc/security/limits.conf << EOF
*      soft   nofile      2097152
*      hard   nofile      2097152
EOF

sysctl -w net.ipv4.tcp_max_syn_backlog=16384
sysctl -w net.ipv4.ip_local_port_range='1024 65535'
sysctl -w net.ipv4.tcp_rmem='1024 4096 16777216'
sysctl -w net.ipv4.tcp_wmem='1024 4096 16777216'
sysctl -w net.ipv4.tcp_max_tw_buckets=1048576
sysctl -w net.ipv4.tcp_fin_timeout=15

sysctl -w net.core.somaxconn=32768
sysctl -w net.core.netdev_max_backlog=16384

sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.optmem_max=16777216

mkdir emqttb && cd emqttb
wget ${package_url}
tar xzf ./emqttb*.tar.gz

GRAFANA=
if [ -n "${grafana_api_key}" ]; then
  export EMQTTB_METRICS__GRAFANA__API_KEY="Bearer ${grafana_api_key}"
  export EMQTTB_METRICS__GRAFANA__URL="${grafana_url}"
  GRAFANA="--grafana"
fi

function signal_done() {
  sleep ${test_duration}
  touch EMQTTB_DONE
  aws s3 cp EMQTTB_DONE s3://${s3_bucket_name}/${bench_id}/EMQTTB_DONE
}

signal_done &

bin/emqttb --restapi $GRAFANA --log-level error ${scenario} @g --host ${emqx_lb_dns_name}
