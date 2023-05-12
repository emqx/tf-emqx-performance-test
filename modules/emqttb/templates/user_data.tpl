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

NEW_PWD=admin123
if [ $TF_LAUNCH_INDEX -eq 1 ]; then
  TOKEN=$(curl -sSf 'http://${emqx_lb_dns_name}:18083/api/v5/login' \
      -H 'Authorization: Bearer undefined' \
      -H 'Content-Type: application/json' \
      --data-raw '{"username":"admin","password":"public"}' | jq -r .token)

  curl -sSf 'http://${emqx_lb_dns_name}:18083/api/v5/users/admin/change_pwd' \
      -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/json' \
      --data-raw "{\"new_pwd\":\"$NEW_PWD\",\"old_pwd\":\"public\"}"
  TOKEN=$(curl -sSf 'http://${emqx_lb_dns_name}:18083/api/v5/login' \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      --data-raw "{\"username\":\"admin\",\"password\":\"$NEW_PWD\"}" | jq -r .token)

  curl -sSf -m 10 --retry 5 'http://${emqx_lb_dns_name}:18083/api/v5/cluster' -H "Authorization: Bearer $TOKEN"
else
  curl -sSf -m 10 --retry 5 'http://${emqx_lb_dns_name}:18083/status'
fi

mkdir emqttb && cd emqttb
wget ${package_url}
tar xzf ./emqttb*.tar.gz

GRAFANA=
if [ -n "${grafana_api_key}" ]; then
  export EMQTTB_METRICS__GRAFANA__API_KEY="Bearer ${grafana_api_key}"
  export EMQTTB_METRICS__GRAFANA__URL="${grafana_url}"
  GRAFANA="--grafana"
fi
bin/emqttb --loiter ${test_duration} --restapi $GRAFANA --keep-running false \
       ${scenario} \
       @g --host ${emqx_lb_dns_name}

if [ $TF_LAUNCH_INDEX -eq 1 ]; then
  curl -sSf -m 10 --retry 5 'http://${emqx_lb_dns_name}:18083/api/v5/stats' -H "Authorization: Bearer $TOKEN" > stats.json
  curl -sSf -m 10 --retry 5 'http://${emqx_lb_dns_name}:18083/api/v5/metrics' -H "Authorization: Bearer $TOKEN" > metrics.json
  curl -sSf -m 10 --retry 5 'http://${emqx_lb_dns_name}:18083/api/v5/prometheus/stats > prometheus_stats.txt
  touch DONE
  files=(metrics.json stats.json prometheus_stats.txt DONE)
  for f in "${files[@]}"; do
    aws s3 cp $f s3://${s3_bucket_name}/${bench_id}/$f
  done
fi
