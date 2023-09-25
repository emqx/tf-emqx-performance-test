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

mkdir emqtt-bench && cd emqtt-bench
wget "${package_url}" -O ./emqtt-bench.tar.gz
tar -xzf ./emqtt-bench.tar.gz

START_N=$((${start_n_multiplier} * ($TF_LAUNCH_INDEX-1)))
# substitute START_N with actual value, and escape percent sign for systemd
scenario=$(sed "s/START_N/$START_N/g;s/%/%%/g" <<< '${scenario}')
cat << EOF > /lib/systemd/system/emqtt-bench.service
[Unit]
Description=EMQTT bench
After=network.target

[Service]
ExecStart=:/opt/emqtt-bench/bin/emqtt_bench $scenario --host ${emqx_hosts}
LimitNOFILE=2097152
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

cat << EOF > ./finalize.sh
#!/bin/bash

sleep ${test_duration}
systemctl stop emqtt-bench.service
journalctl -u emqtt-bench.service > emqtt-bench-stdout.log
cp /var/log/cloud-init-output.log /var/lib/cloud/instance/user-data.txt ./
tar czf ./emqtt-bench-$TF_LAUNCH_INDEX.tar.gz cloud-init-output.log emqtt-bench-stdout.log user-data.txt
aws s3 cp ./emqtt-bench-$TF_LAUNCH_INDEX.tar.gz s3://${s3_bucket_name}/${bench_id}/emqtt-bench-$TF_LAUNCH_INDEX.tar.gz
touch EMQTT_BENCH_DONE
aws s3 cp EMQTT_BENCH_DONE s3://${s3_bucket_name}/${bench_id}/EMQTT_BENCH_DONE
EOF

chmod +x ./finalize.sh
./finalize.sh &

systemctl enable --now emqtt-bench.service
