cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.somaxconn=32768
net.ipv4.tcp_max_syn_backlog=16384
net.core.netdev_max_backlog=16384
net.core.optmem_max=16777216
net.ipv4.tcp_rmem=1024 4096 16777216
net.ipv4.tcp_wmem=1024 4096 16777216
net.ipv4.tcp_max_tw_buckets=1048576
net.ipv4.tcp_fin_timeout=15
net.core.rmem_default=262144000
net.core.wmem_default=262144000
net.core.rmem_max=262144000
net.core.wmem_max=262144000
net.ipv4.tcp_mem=378150000  504200000  756300000
EOF

sysctl -p

wget --no-check-certificate ${package_url}
apt-get install -y ./*.deb

private_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
mkdir /etc/systemd/system/emqx.service.d
cat << EOF > /etc/systemd/system/emqx.service.d/override.conf
[Service]
Environment=EMQX_NODE__NAME=emqx@$private_ip
Environment=EMQX_NODE__COOKIE=emqxperformancetest
Environment=EMQX_CLUSTER__DISCOVERY_STRATEGY=dns
Environment=EMQX_CLUSTER__DNS__NAME=${cluster_dns_name}
Environment=EMQX_CLUSTER__DNS__RECORD_TYPE=a
Environment=EMQX_PROMETHEUS__ENABLE=true
Environment=EMQX_PROMETHEUS__PUSH_GATEWAY_SERVER=${prometheus_push_gw_url}
EOF

systemctl daemon-reload
systemctl restart emqx
systemctl enable emqx

curl --head -X GET --retry 10 --retry-connrefused --retry-delay 5 http://localhost:18083/status
su - emqx /usr/bin/emqx eval 'emqx_dashboard_admin:force_add_user(<<"admin">>, <<"admin">>, <<"admin">>).'

function signal_done() {
  sleep ${test_duration}
  #systemctl stop emqx.service
  cp /var/log/cloud-init-output.log /var/log/emqx/* /var/lib/cloud/instance/user-data.txt ./
  journalctl -u emqx.service > emqx-stdout.log
  tar czf ./emqx-$TF_LAUNCH_INDEX.tar.gz cloud-init-output.log emqx.log* emqx-stdout.log user-data.txt
  aws s3 cp ./emqx-$TF_LAUNCH_INDEX.tar.gz s3://${s3_bucket_name}/${bench_id}/emqx-$TF_LAUNCH_INDEX.tar.gz
  touch EMQX_DONE
  aws s3 cp EMQX_DONE s3://${s3_bucket_name}/${bench_id}/EMQX_DONE_$TF_LAUNCH_INDEX
}

signal_done &
