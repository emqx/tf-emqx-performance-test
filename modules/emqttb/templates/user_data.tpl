mkdir emqttb && cd emqttb
wget "${package_url}" -O ./emqttb.tar.gz
tar xzf ./emqttb.tar.gz

# START_N=$((${start_n_multiplier} * ($TF_LAUNCH_INDEX-1)))
## substitute START_N with actual value, and escape percent sign for systemd
# scenario=$(sed "s/START_N/$START_N/g;s/%/%%/g" <<< '${scenario}')
cat << EOF > /lib/systemd/system/emqttb.service
[Unit]
Description=EMQTT bench daemon
After=network.target

[Service]
Environment=EMQTTB_METRICS__GRAFANA__LOGIN=admin
Environment=EMQTTB_METRICS__GRAFANA__PASSWORD=admin
Environment=EMQTTB_METRICS__GRAFANA__URL=${grafana_url}
Environment=EMQTTB_CLUSTER__NODE_NAME=emqttb@$(hostname)
ExecStart=:/opt/emqttb/bin/emqttb --grafana --restapi --pushgw --pushgw-url ${prometheus_push_gw_url} ${scenario} @g --host ${emqx_hosts}
LimitNOFILE=2097152
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# wait max 5 min for grafana
curl --head -X GET --retry 30 --retry-connrefused --retry-delay 10 ${grafana_url}
systemctl enable --now emqttb.service
