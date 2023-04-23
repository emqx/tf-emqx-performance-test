# https://www.emqx.io/docs/en/v5.0/performance/tune.html

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

sysctl -w net.core.somaxconn=32768
sysctl -w net.ipv4.tcp_max_syn_backlog=16384
sysctl -w net.core.netdev_max_backlog=16384

sysctl -w net.ipv4.ip_local_port_range='1024 65535'

sysctl -w net.core.rmem_default=262144
sysctl -w net.core.wmem_default=262144
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.core.optmem_max=16777216

sysctl -w net.ipv4.tcp_rmem='1024 4096 16777216'
sysctl -w net.ipv4.tcp_wmem='1024 4096 16777216'

sysctl -w net.nf_conntrack_max=1000000
sysctl -w net.netfilter.nf_conntrack_max=1000000
sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30

sysctl -w net.ipv4.tcp_max_tw_buckets=1048576

sysctl -w net.ipv4.tcp_fin_timeout=15

curl -s ${package_url} -o ./emqx.deb
apt-get install -y ./emqx.deb

private_ip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
mkdir /etc/systemd/system/emqx.service.d
cat << EOF > /etc/systemd/system/emqx.service.d/override.conf
[Service]
Environment=EMQX_NODE__NAME=emqx@$private_ip
Environment=EMQX_NODE__COOKIE=emqxperformancetest
Environment=EMQX_CLUSTER__DISCOVERY_STRATEGY=dns
Environment=EMQX_CLUSTER__DNS__NAME=${cluster_dns_name}
Environment=EMQX_CLUSTER__DNS__RECORD_TYPE=a
EOF

systemctl daemon-reload
systemctl restart emqx
