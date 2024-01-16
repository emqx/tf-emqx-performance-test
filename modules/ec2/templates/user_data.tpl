#!/bin/bash

set -x

if [ -b /dev/nvme1n1 ]; then
    echo "Found extra data volume, format and mount to /data"
    mount
    lsblk
    if ! mkfs.ext4 -L data /dev/nvme1n1; then
        echo "Failed to format /dev/nvme1n1"
    else
        mkdir -p /data
        # create systemd mount unit
        cat > /etc/systemd/system/data.mount <<EOF
[Unit]
Description=Mount /dev/nvme1n1 to /data

[Mount]
What=/dev/nvme1n1
Where=/data
Type=ext4
Options=defaults,noatime,discard

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable data.mount
        systemctl start data.mount
    fi
fi

if which apt >/dev/null 2>&1; then
    apt update -y
    apt install -y curl wget zip unzip net-tools dnsutils ca-certificates gnupg lsb-release jq git

    systemctl stop apt-daily.timer
    systemctl disable apt-daily.timer
    systemctl disable apt-daily.service
    systemctl stop apt-daily-upgrade.timer
    systemctl disable apt-daily-upgrade.timer
    systemctl disable apt-daily-upgrade.service

    apt-get purge -y unattended-upgrades
fi

# https://docs.emqx.com/en/enterprise/latest/performance/tune.html
cat > /etc/sysctl.d/perftest.conf <<EOF
net.core.somaxconn=32768
net.ipv4.tcp_max_syn_backlog=16384
net.core.netdev_max_backlog=16384
net.ipv4.ip_local_port_range=1024 65535
net.core.rmem_default=262144
net.core.wmem_default=262144
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.core.optmem_max=16777216
net.ipv4.tcp_rmem=1024 4096 16777216
net.ipv4.tcp_wmem=1024 4096 16777216
net.nf_conntrack_max=13107200
net.netfilter.nf_conntrack_max=13107200
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
net.ipv4.tcp_max_tw_buckets=1048576
net.ipv4.tcp_fin_timeout=5
fs.file-max=2097152
fs.nr_open=2097152
EOF

sysctl --load=/etc/sysctl.d/perftest.conf

cat >> /etc/security/limits.conf << EOF
*      soft   nofile      2097152
*      hard   nofile      2097152
EOF

echo 'DefaultLimitNOFILE=2097152' >> /etc/systemd/system.conf

ulimit -n 2097152

[ -n "${hostname}" ] && hostnamectl set-hostname ${hostname}

${extra}
