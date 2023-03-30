#!/bin/bash

set -x

apt-get update -y && apt-get install -y curl unzip jq collectd

cat <<EOF > /etc/collectd/collectd.conf
FQDNLookup true
Interval 10
LoadPlugin syslog
<Plugin syslog>
        LogLevel info
</Plugin>
#LoadPlugin aggregation
LoadPlugin cpu
LoadPlugin df
LoadPlugin disk
LoadPlugin entropy
LoadPlugin interface
#LoadPlugin irq
LoadPlugin load
LoadPlugin memory
LoadPlugin processes
LoadPlugin rrdtool
#LoadPlugin statsd
LoadPlugin swap

<Plugin cpu>
      ReportByCpu true
      ReportByState true
      ValuesPercentage false
      ReportNumCpu false
      ReportGuestState false
      SubtractGuestState true
</Plugin>

<Plugin df>
        FSType rootfs
        FSType sysfs
        FSType proc
        FSType devtmpfs
        FSType devpts
        FSType tmpfs
        FSType fusectl
        FSType cgroup
        IgnoreSelected true
</Plugin>

<Plugin rrdtool>
        DataDir "/var/lib/collectd/rrd"
</Plugin>

# <Plugin statsd>
#       Host "::"
#       Port "8125"
#       DeleteCounters false
#       DeleteTimers   false
#       DeleteGauges   false
#       DeleteSets     false
#       CounterSum     false
#       TimerPercentile 90.0
#       TimerPercentile 95.0
#       TimerPercentile 99.0
#       TimerLower     false
#       TimerUpper     false
#       TimerSum       false
#       TimerCount     false
# </Plugin>

<Include "/etc/collectd/collectd.conf.d">
        Filter "*.conf"
</Include>
EOF

systemctl daemon-reload
systemctl restart collectd

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install

if [ -n "${s3_bucket_name}" ]; then
    aws s3 cp s3://${s3_bucket_name}/authorized_keys ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
fi

${extra}
