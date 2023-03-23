#!/bin/bash

set -x

apt-get update -y && apt-get install -y curl unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

if [ -n "${s3_bucket_name}" ]; then
    aws s3 cp s3://${s3_bucket_name}/authorized_keys ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

curl -s 'https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb' -o /tmp/amazon-cloudwatch-agent.deb
apt-get install -y /tmp/amazon-cloudwatch-agent.deb

cat <<EOF > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "cloud-init-output",
            "log_stream_name": "emqx-performance-test-${timestamp}",
            "retention_in_days": 1
          },
          {
            "file_path": "/var/log/emqx/*.log*",
            "log_group_name": "emqx",
            "log_stream_name": "emqx-performance-test-${timestamp}",
            "retention_in_days": 1
          }
        ]
      }
    }
  },
  "metrics": {
    "aggregation_dimensions": [
      ["InstanceId"]
    ],
    "append_dimensions": {
      "Timestamp": "${timestamp}",
      "InstanceId": "\$${aws:InstanceId}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "diskio": {
        "measurement": [
          "io_time",
          "write_bytes",
          "read_bytes",
          "writes",
          "reads"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_syn_sent",
          "tcp_close"
        ],
        "metrics_collection_interval": 60
      },
      "processes": {
        "measurement": [
          "running",
          "sleeping",
          "dead"
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
systemctl daemon-reload
systemctl restart amazon-cloudwatch-agent.service

${extra}
