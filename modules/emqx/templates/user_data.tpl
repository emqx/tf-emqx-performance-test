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
EOF

systemctl daemon-reload
systemctl restart emqx

wait_for_emqx() {
    local attempts=10
    local url='http://localhost:18083/status'
    while ! curl "$url" >/dev/null 2>&1; do
        if [ $attempts -eq 0 ]; then
            echo "emqx is not responding on $url"
            exit 1
        fi
        sleep 5
        attempts=$((attempts-1))
    done
}
wait_for_emqx
su - emqx /usr/bin/emqx eval 'emqx_dashboard_admin:force_add_user(<<"admin">>, <<"admin">>, <<"admin">>).'
