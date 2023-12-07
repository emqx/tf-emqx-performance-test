#!/bin/bash

set -x

cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.netdev_max_backlog=16384
net.core.optmem_max=16777216
net.core.somaxconn=32768
net.core.rmem_default=262144000
net.core.rmem_max=262144000
net.core.wmem_default=262144000
net.core.wmem_max=262144000
net.ipv4.ip_local_port_range=1024 65535
net.ipv4.tcp_fin_timeout=5
net.ipv4.tcp_max_syn_backlog=16384
net.ipv4.tcp_max_tw_buckets=1048576
net.ipv4.tcp_mem=378150000  504200000  756300000
net.ipv4.tcp_rmem=1024 4096 16777216
net.ipv4.tcp_wmem=1024 4096 16777216
fs.file-max=2097152
fs.nr_open=2097152
EOF

sysctl --load=/etc/sysctl.d/99-sysctl.conf

ulimit -n 2097152

echo 'DefaultLimitNOFILE=2097152' >> /etc/systemd/system.conf
echo >> /etc/security/limits.conf << EOF
*      soft   nofile      2097152
*      hard   nofile      2097152
EOF

[ -n "${hostname}" ] && hostnamectl set-hostname ${hostname}

cd /opt
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

${extra}
