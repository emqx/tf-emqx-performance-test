cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.rmem_default=262144000
net.core.rmem_max=262144000
net.core.wmem_default=262144000
net.core.wmem_max=262144000
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fin_timeout=5
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.tcp_mem=378150000  504200000  756300000
EOF

sysctl --system

mkdir emqttb && cd emqttb
wget "${package_url}" -O ./emqttb.tar.gz
tar xzf ./emqttb.tar.gz

START_N=$((${start_n_multiplier} * ($TF_LAUNCH_INDEX-1)))
# substitute START_N with actual value, and escape percent sign for systemd
scenario=$(sed "s/START_N/$START_N/g;s/%/%%/g" <<< '${scenario}')
cat << EOF > /lib/systemd/system/emqttb.service
[Unit]
Description=EMQTT bench daemon
After=network.target

[Service]
Environment=EMQTTB_METRICS__GRAFANA__LOGIN=admin
Environment=EMQTTB_METRICS__GRAFANA__PASSWORD=admin
Environment=EMQTTB_METRICS__GRAFANA__URL=${grafana_url}
Environment=EMQTTB_CLUSTER__NODE_NAME=emqttb@$(hostname)
ExecStart=:/opt/emqttb/bin/emqttb --grafana --restapi --pushgw --pushgw-url ${prometheus_push_gw_url} $scenario @g --host ${emqx_hosts}
LimitNOFILE=2097152
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

cat << EOF > ./finalize.sh
#!/bin/bash

sleep ${test_duration}
systemctl stop emqttb.service
journalctl -u emqttb.service > emqttb-stdout.log
cp /var/log/cloud-init-output.log /var/lib/cloud/instance/user-data.txt /tmp/emqttb.log ./
tar czf ./emqttb-$TF_LAUNCH_INDEX.tar.gz cloud-init-output.log emqttb-stdout.log user-data.txt emqttb.log
aws s3 cp ./emqttb-$TF_LAUNCH_INDEX.tar.gz s3://${s3_bucket_name}/${bench_id}/emqttb-$TF_LAUNCH_INDEX.tar.gz
touch EMQTTB_DONE
aws s3 cp EMQTTB_DONE s3://${s3_bucket_name}/${bench_id}/EMQTTB_DONE
EOF

chmod +x ./finalize.sh

# wait max 5 min for grafana
curl --head -X GET --retry 30 --retry-connrefused --retry-delay 10 ${grafana_url}
./finalize.sh &
systemctl enable --now emqttb.service
