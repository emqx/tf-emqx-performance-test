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
