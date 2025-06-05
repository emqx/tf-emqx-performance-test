#!/usr/bin/env bash

set -euo pipefail

download() {
  local url="${1}"
  local out="${2}"
  local ds_substitue_var="${3:-DS_PROMETHEUS}"
  wget --no-verbose --show-progress --output-document="/tmp/${out}" "${url}" || echo "Error: Failed to download ${url}"
  env "${ds_substitue_var}=Prometheus" envsubst "\$${ds_substitue_var}" < "/tmp/${out}" > "${out}"
  rm /tmp/${out}
}

download https://github.com/jash777/grafana-multi-server-dashboard/raw/refs/heads/main/dashboard.json node-exporter-multi-server.json
download https://raw.githubusercontent.com/rfmoz/grafana-dashboards/refs/heads/master/prometheus/node-exporter-full.json node-exporter-full.json
download https://grafana.com/api/dashboards/17446/revisions/2/download emqx.json
download https://raw.githubusercontent.com/ieQu1/grafana-dashboards/refs/heads/master/grafana/dashboards/emqttb-dashboard.json emqttb.json Prometheus
