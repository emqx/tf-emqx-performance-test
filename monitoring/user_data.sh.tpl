#!/bin/bash

set -x

apt update -y
apt install -y curl jq unzip

wget "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -O "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

export BUCKET=${s3_bucket_name}

if [ -n "$BUCKET" ]; then
    if aws s3api head-object --bucket $BUCKET --key authorized_keys > /dev/null 2>&1; then
        aws s3 cp s3://$BUCKET/authorized_keys ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
    fi
fi

cd /opt
apt-get update
apt-get install -y apt-transport-https
apt-get install -y software-properties-common
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana

cat > /etc/grafana/grafana.ini << EOF
app_mode = production
instance_name = ${domain_name}

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins

[server]
http_addr = 0.0.0.0
http_port = 3000
domain = ${domain_name}
root_url = http://0.0.0.0:3000
protocol = http
enforce_domain = False
socket =
cert_key =
cert_file =
enable_gzip = False
static_root_path = public
router_logging = False
serve_from_sub_path = False

[database]
type = sqlite3

[remote_cache]

[security]
admin_user = admin
admin_password = ${grafana_admin_password}

[users]
allow_sign_up = False
auto_assign_org_role = Viewer
default_theme = dark

[emails]
welcome_email_on_sign_up = False

[auth]
disable_login_form = False
oauth_auto_login = False
disable_signout_menu = False
signout_redirect_url =

[auth.anonymous]
enabled = True
org_name = EMQ Technologies
org_role = Viewer

[analytics]
reporting_enabled = "True"

[dashboards]
versions_to_keep = 20

[dashboards.json]
enabled = true
path = /var/lib/grafana/dashboards

[alerting]
enabled = true
execute_alerts = True

[log]
mode = console, file
level = info

[grafana_com]
url = https://grafana.com
EOF

cat > /etc/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1
deleteDatasources: []
datasources:
-   access: proxy
    isDefault: true
    name: Prometheus
    type: prometheus
    url: ${prometheus_url}
    editable: true
    jsonData:
        httpMethod: "POST"
        sigV4Auth: true
        sigV4Region: "${region}"
        sigV4AuthType: "default"
EOF

cat > /etc/grafana/provisioning/dashboards/default.yml << EOF
apiVersion: 1
providers:
 - name: 'default'
   orgId: 1
   folder: ''
   type: file
   allowUiUpdates: true
   disableDeletion: false
   options:
     path: "/var/lib/grafana/dashboards"
EOF

mkdir -p /var/lib/grafana/dashboards
chown grafana:grafana /var/lib/grafana/dashboards
# emqx
wget https://grafana.com/api/dashboards/17446/revisions/1/download -O /tmp/17446.json
export DS_PROMETHEUS=Prometheus
envsubst < /tmp/17446.json > /var/lib/grafana/dashboards/17446.json
sed -i 's/DS_PROMETHEUS/Prometheus/g' /var/lib/grafana/dashboards/17446.json
# node exporter full
wget https://grafana.com/api/dashboards/1860/revisions/31/download -O /var/lib/grafana/dashboards/1860.json

mkdir /etc/systemd/system/grafana-server.service.d
cat << EOF > /etc/systemd/system/grafana-server.service.d/override.conf
[Service]
Environment=AWS_SDK_LOAD_CONFIG=true
Environment=GF_AUTH_SIGV4_AUTH_ENABLED=true
EOF

systemctl daemon-reload
systemctl enable --now grafana-server

curl -fsS -m 30 --retry 6 --retry-delay 5 --retry-connrefused -X PUT -H "Content-Type: application/json" -d '{"name": "EMQ Technologies"}' "http://admin:${grafana_admin_password}@localhost:3000/api/orgs/1"
