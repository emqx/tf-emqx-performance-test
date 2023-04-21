mkdir emqttb && cd emqttb
wget ${package_url}
tar xzf ./emqttb*.tar.gz
ulimit -n 200000
sysctl -w net.ipv4.ip_local_port_range="1025 65534"
bin/emqttb --restapi @pubsub_fwd --publatency 100ms --num-clients 400 -i 100ms @g -h ${emqx_lb_dns_name}:1883
