cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
net.core.rmem_default=262144000
net.core.wmem_default=262144000
net.core.rmem_max=262144000
net.core.wmem_max=262144000
net.ipv4.tcp_mem=378150000  504200000  756300000
fs.file-max=2097152
fs.nr_open=2097152
EOF

sysctl -p

echo 2097152 > /proc/sys/fs/nr_open
ulimit -n 2097152

echo 'DefaultLimitNOFILE=2097152' >> /etc/systemd/system.conf
echo >> /etc/security/limits.conf << EOF
*      soft   nofile      2097152
*      hard   nofile      2097152
EOF

mkdir emqtt-bench && cd emqtt-bench
wget ${package_url}
tar -xzf ./emqtt-bench*.tar.gz

function signal_done() {
  sleep ${test_duration}
  touch EMQTT_BENCH_DONE
  aws s3 cp EMQTT_BENCH_DONE s3://${s3_bucket_name}/${bench_id}/EMQTT_BENCH_DONE
}

signal_done &

./bin/emqtt_bench ${scenario} --host ${emqx_lb_dns_name}
