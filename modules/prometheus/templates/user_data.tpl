cd /opt
mkdir dashboards
wget -nc https://raw.githubusercontent.com/emqx/emqttb/master/emqttb-dashboard.json -O dashboards/emqttb-dashboard.json
apt install -y python3-pip
python3 -m pip install ansible==6.7.0 jmespath
ansible-galaxy install cloudalchemy.prometheus cloudalchemy.pushgateway cloudalchemy.grafana
cat > playbook.yml << EOF
- hosts: all
  vars:
    prometheus_global:
      scrape_interval: 5s
      scrape_timeout: 5s
      evaluation_interval: 15s
    prometheus_scrape_configs:
      - job_name: "prometheus"
        static_configs:
          - targets:
            - "localhost:9090"
      - job_name: "pushgateway"
        honor_labels: true
        static_configs:
          - targets:
            - "localhost:9091"
      - job_name: "emqx"
        metrics_path: "/api/v5/prometheus/stats"
        honor_labels: true
        static_configs:
          - targets: ${emqx_targets}
      - job_name: "emqttb"
        honor_labels: true
        scrape_interval: 30s
        scrape_timeout: 30s
        static_configs:
          - targets: ${emqttb_targets}
      - job_name: "node"
        honor_labels: true
        static_configs:
          - targets: ${node_targets}
    grafana_auth:
      anonymous:
        org_name: "EMQ Technologies"
        org_role: Viewer
    grafana_security:
      admin_user: "admin"
      admin_password: "admin"
    grafana_dashboards:
      - dashboard_id: '17446'
        revision_id: '1'
        datasource: 'Prometheus'
      - dashboard_id: '1860'
        revision_id: '31'
        datasource: 'Prometheus'
    grafana_dashboards_dir: "/opt/dashboards"
    grafana_datasources:
      - name: "Prometheus"
        type: "prometheus"
        access: "proxy"
        url: "http://localhost:9090"
        isDefault: true
  vars_files:
    - remote_write.yml
  roles:
    - cloudalchemy.prometheus
    - cloudalchemy.pushgateway
    - cloudalchemy.grafana
EOF

echo '---' > remote_write.yml

if [ -n "${remote_write_url}" ]; then
    cat >> remote_write.yml << EOF

prometheus_remote_write:
  - url: ${remote_write_url}
    queue_config:
      max_samples_per_send: 1000
      max_shards: 200
      capacity: 2500
    sigv4:
      region: ${remote_write_region}
EOF
fi

ansible-playbook -vv -i localhost, -c local playbook.yml
