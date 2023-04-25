#!/bin/bash

set -x

apt update -y
apt install -y curl jq unzip

wget "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -O "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

if [ -n "${s3_bucket_name}" ]; then
    aws s3 cp s3://${s3_bucket_name}/authorized_keys ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

cd /opt
apt install -y python3-pip
python3 -m pip install ansible==6.7.0 jmespath
ansible-galaxy install cloudalchemy.node_exporter cloudalchemy.prometheus cloudalchemy.grafana
cat > playbook.yml << EOF
- hosts: all
  vars:
    prometheus_scrape_configs:
      - job_name: "prometheus"
        metrics_path: "/metrics"
        static_configs:
          - targets:
            - "localhost:9090"
      - job_name: "node"
        scrape_interval: 1s
        static_configs:
          - targets:
            - "localhost:9100"
            - "perf-test-emqx-1.int.emqx.io:9100"
            - "perf-test-emqx-2.int.emqx.io:9100"
            - "perf-test-emqx-3.int.emqx.io:9100"
            - "perf-test-emqttb-1.int.emqx.io:9100"
      - job_name: "emqx"
        scrape_interval: "1s"
        metrics_path: "/api/v5/prometheus/stats"
        honor_labels: true
        static_configs:
          - targets:
            - "perf-test-emqx-1.int.emqx.io:18083"
            - "perf-test-emqx-2.int.emqx.io:18083"
            - "perf-test-emqx-3.int.emqx.io:18083"
      - job_name: "emqttb"
        scrape_interval: "1s"
        honor_labels: true
        static_configs:
          - targets:
            - "perf-test-emqttb-1.int.emqx.io:8017"
    grafana_security:
      admin_user: "admin"
      admin_password: "admin"
    grafana_auth:
      anonymous:
        org_name: "EMQ Technologies"
        org_role: Viewer

    grafana_datasources:
      - name: "Prometheus"
        type: "prometheus"
        access: "proxy"
        url: "http://localhost:9090"
        isDefault: true
  roles:
    - cloudalchemy.node_exporter
    - cloudalchemy.prometheus
    - cloudalchemy.grafana
EOF

ansible-playbook -vv -i localhost, -c local playbook.yml
