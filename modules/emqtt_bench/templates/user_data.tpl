mkdir emqtt-bench && cd emqtt-bench
wget ${package_url}
tar -xzf ./emqtt-bench*.tar.gz
ulimit -n 200000
sysctl -w net.ipv4.ip_local_port_range="1025 65534"
./bin/emqtt_bench pub \
                  --host ${emqx_lb_dns_name} \
                  --topic bench/%i \
                  --count ${clients_count} \
                  --qos 1 \
                  --size ${payload_size} \
                  --limit ${max_message_count} > /var/log/emqtt_bench.log 2>&1

gzip /var/log/emqtt_bench.log
aws s3 cp /var/log/emqtt_bench.log.gz s3://${s3_bucket_name}/${bench_id}/emqtt_bench.log.gz
