#!/bin/bash

set -x

apt-add-repository ppa:ansible/ansible
apt update -y
apt install -y ansible curl jq unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

if [ -n "${s3_bucket_name}" ]; then
    if aws s3api head-object --bucket "${s3_bucket_name}" --key authorized_keys >/dev/null 2>&1; then
        aws s3 cp s3://${s3_bucket_name}/authorized_keys ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
    fi
fi

cd /opt
ansible-galaxy install cloudalchemy.node_exporter
cat > playbook.yml << EOF
- hosts: all
  roles:
    - cloudalchemy.node_exporter
EOF

ansible-playbook -vv -i localhost, -c local playbook.yml

${extra}
