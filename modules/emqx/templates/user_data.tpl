cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.netdev_max_backlog=16384
net.core.optmem_max=16777216
net.core.rmem_default=262144000
net.core.rmem_max=262144000
net.core.somaxconn=32768
net.core.wmem_default=262144000
net.core.wmem_max=262144000
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.tcp_max_tw_buckets=1048576
net.ipv4.tcp_mem=378150000  504200000  756300000
net.ipv4.tcp_rmem=1024 4096 16777216
net.ipv4.tcp_wmem=1024 4096 16777216
net.netfilter.nf_conntrack_max=1000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
net.nf_conntrack_max=1000000
EOF

sysctl --system

wget --no-check-certificate "${package_url}" -O ./emqx.deb
apt-get install -y ./emqx.deb

mkdir /etc/systemd/system/emqx.service.d
cat << EOF > /etc/systemd/system/emqx.service.d/override.conf
[Service]
LimitNOFILE=2097152
Environment=EMQX_NODE__NAME=emqx@$(hostname --fqdn)
Environment=EMQX_NODE__COOKIE=emqxperformancetest
Environment=EMQX_NODE__ROLE=${node_role}
Environment=EMQX_NODE__PROCESS_LIMIT=2097152
Environment=EMQX_NODE__MAX_PORTS=2097152
Environment=EMQX_CLUSTER__DISCOVERY_STRATEGY=dns
Environment=EMQX_CLUSTER__DNS__NAME=${cluster_dns_name}
Environment=EMQX_CLUSTER__DNS__RECORD_TYPE=srv
%{ if node_role == "replicant" }
Environment=EMQX_CLUSTER__CORE_NODES="${join(",", core_nodes)}"
%{ endif }
Environment=EMQX_PROMETHEUS__ENABLE=true
Environment=EMQX_PROMETHEUS__PUSH_GATEWAY_SERVER=${prometheus_push_gw_url}
Environment=EMQX_LOG__CONSOLE_HANDLER__LEVEL=info
Environment=EMQX_LOG__FILE_HANDLERS__DEFAULT__LEVEL=info
EOF

systemctl daemon-reload
systemctl restart emqx
systemctl enable emqx

curl --head -X GET --retry 10 --retry-connrefused --retry-delay 5 http://localhost:18083/status
su - emqx /usr/bin/emqx eval 'emqx_dashboard_admin:force_add_user(<<"admin">>, <<"admin">>, <<"admin">>).'

cat << EOF > ./finalize.sh
#!/bin/bash

sleep ${test_duration}
NODE_NAME=emqx-${node_role}-$TF_LAUNCH_INDEX
cp /var/log/cloud-init-output.log /var/log/emqx/* /var/lib/cloud/instance/user-data.txt ./
journalctl -u emqx.service > emqx-stdout.log
tar czf ./$NODE_NAME.tar.gz cloud-init-output.log emqx.log* emqx-stdout.log user-data.txt
aws s3 cp ./$NODE_NAME.tar.gz s3://${s3_bucket_name}/${bench_id}/$NODE_NAME.tar.gz
EOF

chmod +x ./finalize.sh
./finalize.sh &
