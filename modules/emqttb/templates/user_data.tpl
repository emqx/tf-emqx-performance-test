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
wget "${package_url}" -O ./emqttb.tar.gz
tar xzf ./emqttb.tar.gz

START_N=$((${start_n_multiplier} * ($TF_LAUNCH_INDEX-1)))

hostnamectl set-hostname "emqttb-$TF_LAUNCH_INDEX"

# wait max 2 min for grafana
curl --head -X GET --retry 12 --retry-connrefused --retry-delay 10 ${grafana_url}

cat << EOF > /lib/systemd/system/emqttb.service
[Unit]
Description=EMQTT bench daemon
After=network.target

[Service]
Environment=EMQTTB_METRICS__GRAFANA__LOGIN=admin
Environment=EMQTTB_METRICS__GRAFANA__PASSWORD=admin
Environment=EMQTTB_METRICS__GRAFANA__URL=${grafana_url}
ExecStart=/opt/emqttb/bin/emqttb --grafana --restapi --pushgw --pushgw-url ${prometheus_push_gw_url} ${scenario} @g --host ${emqx_hosts}
LimitNOFILE=1048576
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

function signal_done() {
  sleep ${test_duration}
  systemctl stop emqttb.service
  cp /var/log/cloud-init-output.log /tmp/emqttb.log /var/lib/cloud/instance/user-data.txt ./
  journalctl -u emqttb.service > emqttb-stdout.log
  tar czf ./emqttb-$TF_LAUNCH_INDEX.tar.gz cloud-init-output.log emqttb.log emqttb-stdout.log user-data.txt
  aws s3 cp ./emqttb-$TF_LAUNCH_INDEX.tar.gz s3://${s3_bucket_name}/${bench_id}/emqttb-$TF_LAUNCH_INDEX.tar.gz
  touch EMQTTB_DONE
  aws s3 cp EMQTTB_DONE s3://${s3_bucket_name}/${bench_id}/EMQTTB_DONE_$TF_LAUNCH_INDEX
}

signal_done &

systemctl enable --now emqttb.service
