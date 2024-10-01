#!/usr/bin/env bash

function bm-start() {
    n=${1:-1}
    ansible emqtt_bench -m command -a 'systemctl start emqtt_bench' --become -l $(terraform output -json emqtt_bench_nodes | jq -r ".[$((n-1))].fqdn")
}

function bm-stop () {
    n=${1:-1}
    ansible emqtt_bench -m command -a 'systemctl stop emqtt_bench' --become -l $(terraform output -json emqtt_bench_nodes | jq -r ".[$((n-1))].fqdn")
}

function bmb-start() {
    n=${1:-1}
    ansible emqttb -m command -a 'systemctl start emqttb' --become -l $(terraform output -json emqttb_nodes | jq -r ".[$((n-1))].fqdn")
}

function bmb-stop() {
    n=${1:-1}
    ansible emqttb -m command -a 'systemctl stop emqttb' --become -l $(terraform output -json emqttb_nodes | jq -r ".[$((n-1))].fqdn")
}

function bm-ssh() {
    node=$(terraform output -json | jq -r 'to_entries[] | select(.key | endswith("_nodes")) | .value.value[] | "\(.ip)\t\(.fqdn)"' | sort -k2 | uniq | fzf | cut -d $'\t' -f 1)
    if [[ -n $node ]]; then
        ssh -l ubuntu -i $(terraform output -raw ssh_key_path) "$node"
    fi
}

function bm-urls() {
    echo "dashboard: $(terraform output -raw emqx_dashboard_url)"
    echo "grafana: $(terraform output -raw grafana_url)"
}
