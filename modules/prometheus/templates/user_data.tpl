cd /opt
mkdir dashboards
wget -nc https://raw.githubusercontent.com/emqx/emqttb/master/emqttb-dashboard.json -O dashboards/emqttb-dashboard.json
apt install -y python3-pip
python3 -m pip install ansible==6.7.0 jmespath
ansible-galaxy install cloudalchemy.prometheus cloudalchemy.pushgateway cloudalchemy.grafana
cat > playbook.yml << EOF
- hosts: all
  vars:
    prometheus_scrape_configs:
      - job_name: "prometheus"
        metrics_path: "/metrics"
        static_configs:
          - targets:
            - "localhost:9090"
      - job_name: "pushgateway"
        honor_labels: true
        static_configs:
          - targets:
            - "localhost:9091"
      - job_name: "emqx"
        scrape_interval: "5s"
        metrics_path: "/api/v5/prometheus/stats"
        honor_labels: true
        static_configs:
          - targets: ${emqx_targets}
      - job_name: "emqttb"
        scrape_interval: "5s"
        honor_labels: true
        static_configs:
          - targets: ${emqttb_targets}
      - job_name: "node"
        scrape_interval: "5s"
        honor_labels: true
        static_configs:
          - targets: ${node_targets}
    prometheus_remote_write:
      - url: ${remote_write_url}
        queue_config:
          max_samples_per_send: 1000
          max_shards: 200
          capacity: 2500
        sigv4:
          region: ${remote_write_region}
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
  roles:
    - cloudalchemy.prometheus
    - cloudalchemy.pushgateway
    - cloudalchemy.grafana
EOF

ansible-playbook -vv -i localhost, -c local playbook.yml
