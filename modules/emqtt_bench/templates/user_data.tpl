mkdir emqtt-bench && cd emqtt-bench
wget "${package_url}" -O ./emqtt-bench.tar.gz
tar -xzf ./emqtt-bench.tar.gz

# START_N=$((${start_n_multiplier} * ($TF_LAUNCH_INDEX-1)))
## substitute START_N with actual value, and escape percent sign for systemd
# scenario=$(sed "s/START_N/$START_N/g;s/%/%%/g" <<< '${scenario}')
cat << EOF > /lib/systemd/system/emqtt-bench.service
[Unit]
Description=EMQTT bench
After=network.target

[Service]
ExecStart=:/opt/emqtt-bench/bin/emqtt_bench ${scenario}
LimitNOFILE=2097152
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now emqtt-bench.service
