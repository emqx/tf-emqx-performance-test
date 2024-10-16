#!/bin/bash

set -x

lsblk

%{ for i, v in volumes ~}
device=/dev/nvme${i+1}n1
# wait up to 60 seconds for the device to appear
for i in {1..60}; do
    if [ -b $device ]; then
        break
    fi
    sleep 1
done

if ! mkfs.ext4 $device; then
    echo "Failed to format $device"
else
    mkdir -p ${v.mount_point}
    unit=$(systemd-escape --suffix mount --path ${v.mount_point})
    cat > /etc/systemd/system/$unit <<EOF
[Unit]
Description=Mount $device to ${v.mount_point}
Requires=local-fs.target
After=local-fs.target

[Mount]
What=$device
Where=${v.mount_point}
Type=ext4
Options=${v.mount_options}

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now $unit
fi
%{ endfor }

if which apt >/dev/null 2>&1; then
    apt update -y
    apt install -y curl wget zip unzip net-tools dnsutils ca-certificates gnupg lsb-release jq git python3-pip

    systemctl stop apt-daily.timer
    systemctl disable apt-daily.timer
    systemctl disable apt-daily.service
    systemctl stop apt-daily-upgrade.timer
    systemctl disable apt-daily-upgrade.timer
    systemctl disable apt-daily-upgrade.service

    apt-get purge -y unattended-upgrades
elif which dnf >/dev/null 2>&1; then
    dnf install -y curl wget zip unzip net-tools bind-utils ca-certificates gnupg jq git python3
elif which yum >/dev/null 2>&1; then
    yum install -y curl wget zip unzip net-tools bind-utils ca-certificates gnupg jq git python3
fi

curl -fsSL https://get.docker.com -o get-docker.sh
sh ./get-docker.sh

# install docker packages for python
python3 -m ensurepip --upgrade
python3 -m pip install docker==6.1.3 docker-compose

case $(uname -m) in
    x86_64)
        curl -fsSL https://www.emqx.com/en/downloads/MQTTX/v1.9.8/mqttx-cli-linux-x64 -o mqttx-cli-linux
        ;;
    aarch64)
        curl -fsSL https://www.emqx.com/en/downloads/MQTTX/v1.9.8/mqttx-cli-linux-arm64 -o mqttx-cli-linux
        ;;
esac
install ./mqttx-cli-linux /usr/local/bin/mqttx

if grep -qiE 'amzn|rhel' /etc/*-release; then
    wget -q -O gpg.key https://rpm.grafana.com/gpg.key
    rpm --import gpg.key
    echo -e '[grafana]\nname=grafana\nbaseurl=https://rpm.grafana.com\nrepo_gpgcheck=1\nenabled=1\ngpgcheck=1\ngpgkey=https://rpm.grafana.com/gpg.key\nsslverify=1\nsslcacert=/etc/pki/tls/certs/ca-bundle.crt' > /etc/yum.repos.d/grafana.repo
    yum update -y
    yum install alloy -y
    echo 'CUSTOM_ARGS=--disable-reporting' >> /etc/sysconfig/alloy
else
    mkdir -p /etc/apt/keyrings/
    wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor > /etc/apt/keyrings/grafana.gpg
    echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
    apt-get update
    apt-get install alloy -y
    echo 'CUSTOM_ARGS=--disable-reporting' >> /etc/default/alloy
fi

systemctl enable --now alloy

# https://docs.emqx.com/en/emqx/latest/performance/tune.html
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

mkdir -p /etc/ssl/certs/emqx
echo "${certs.ca}" > /etc/ssl/certs/emqx/cacert.pem
echo "${certs.server_cert}" > /etc/ssl/certs/emqx/cert.pem
echo "${certs.server_key}" > /etc/ssl/certs/emqx/key.pem
echo "${certs.client_cert}" > /etc/ssl/certs/emqx/client-cert.pem
echo "${certs.client_key}" > /etc/ssl/certs/emqx/client-key.pem
# create bundles
cat /etc/ssl/certs/emqx/cert.pem /etc/ssl/certs/emqx/cacert.pem > /etc/ssl/certs/emqx/server-bundle.pem
cat /etc/ssl/certs/emqx/client-cert.pem /etc/ssl/certs/emqx/cacert.pem > /etc/ssl/certs/emqx/client-bundle.pem

${extra}

touch /opt/tf_init_done
