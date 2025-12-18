#! /usr/bin/env python3

import sys
import os
import json
import subprocess
import requests
from datetime import datetime, UTC

def cmd(args):
    if isinstance(args, str):
        args = args.split(' ')
    return subprocess.check_output(args, text=True)

# Configuration
class Config:
    envs = {
        'prometheus_url': 'PROMETHEUS_URL',
        'emqx_dashboard_url': 'EMQX_API_URL', 
        'emqx_version_family': 'EMQX_VERSION_FAMILY',
        'emqx_dashboard_credentials': 'EMQX_DASHBOARD_CREDENTIALS',
    }
    
    def __init__(self):
        self._outputs = json.loads(cmd('terraform output -json'))
        self.tmpdir = os.getenv('TMPDIR') or cmd('mktemp -d').strip()
        self.prometheus_url = self.fetch('prometheus_url')
        self.emqx_dashboard_url = self.fetch('emqx_dashboard_url')
        self.emqx_api_url = f"{self.emqx_dashboard_url}/api/v5"
        self.emqx_version_family = self.fetch('emqx_version_family')
        self.emqx_dashboard_credentials = self.fetch('emqx_dashboard_credentials').split(':')
        self.endtime = os.getenv('ENDTIME') or datetime.now(UTC).isoformat(timespec='seconds')
        self.period = os.getenv('PERIOD') or '10m'
        self.window = os.getenv('WINDOW') or '15s'

    def login(self):
        response = requests.post(
            f"{self.emqx_api_url}/login",
            json={"username": self.emqx_dashboard_credentials[0],
                  "password": self.emqx_dashboard_credentials[1]})
        response.raise_for_status()
        response = response.json()
        self.emqx_version = response['version']
        self.token = response['token']

    def __del__(self):
        os.rmdir(self.tmpdir)

    def __str__(self):
        return "\n".join(f"{k}: {v}" for k, v in vars(self).items() if not k.startswith('_'))

    def fetch(self, name):
        return os.getenv(Config.envs[name]) or self._outputs[name]['value']

# Initialize configuration
conf = Config()

# EMQX API
def emqxapi(path, method='GET', **kwargs):
    response = requests.request(method,
                                f"{conf.emqx_api_url}/{path}",
                                headers={'Authorization': f'Bearer {conf.token}'},
                                **kwargs)
    response.raise_for_status()
    return response.json()

# Default shaper for per-node metrics
def value_per_node(entry):
    return entry['metric']['instance'].split('.')[0]
    
# Prometheus query
# * `shape`: function to shape the result / 'values' / 'json'
# * `percent`: convert to percentage
# * `empty`: allow empty result
def promquery(query, shape=value_per_node, percent=False, empty=False):
    query = query.replace('$P', conf.period).replace('$W', conf.window)
    if percent:
        query = f'round(100 * ({query}), 0.01)'
    elif shape != 'json':
        query = f'round({query}, 0.01)'

    response = requests.get(
        f"{conf.prometheus_url}/api/v1/query",
        params={'query': query, 'time': conf.endtime})

    data = response.json()
    if data['status'] != 'success':
        raise Exception(f"Prometheus query error: {data['error']}")
        
    result = data['data']['result']
    if not result and not empty:
        raise Exception(f"Prometheus query '{query}' returned empty result")
        
    if shape == 'values':
        return [m['value'][1] for m in result]
    elif shape == 'json':
        return result
    elif isinstance(shape, str):
        return {m['metric'][shape]: m['value'][1] for m in result}
    elif callable(shape):
        return {shape(m): m['value'][1] for m in result}
    else:
        raise Exception(f"Invalid format: {shape}")

def total(metrics):
    return sum([float(value) for value in metrics.values()])

def avg(metrics):
    return sum([float(value) for value in metrics.values()]) / len(metrics)

def table(metrics):
    sep = ' | '
    cols = sorted(set().union(*[arg.keys() for arg in metrics.values()]))
    longcol = max([len(column) for column in cols])
    longcol = max(longcol, max([max([len(v) for v in m.values()]) for m in metrics.values()]))
    longname = max([len(name) for name in metrics.keys()])
    header = [
        '| ' + ' ' * longname + sep + sep.join(column.ljust(longcol) for column in cols) + ' |',
        '| ' + '-' * longname + sep + sep.join('-' * longcol for _ in cols) + ' |',
    ]
    rows = [
        '| ' + name.ljust(longname) + sep + sep.join(str(arg.get(column, '-').rjust(longcol)) for column in cols) + ' |'
        for name, arg in metrics.items()
    ]
    return '\n'.join(header + rows)

def main():
    conf.login()
    print(conf)
    print()

    # metrics = emqxapi('metrics')
    # print(metrics)
    # stats = emqxapi('stats')
    # print(stats)

    ## Host CPU usage range query
    host_cpu_query = """
        (1 - avg(rate(
          node_cpu_seconds_total{mode='idle',instance=~'emqx-.*'}[$W]
        )) by (instance))[$P:$W]
    """

    # Aggregate P95 of CPU usage (smoothed over 15s windows) [%]
    host_cpu_p95 = promquery(f"quantile_over_time(0.95, {host_cpu_query})", percent=True)
    # Aggregate average of CPU usage (smoothed over 15s windows) [%]
    host_cpu_avg = promquery(f"avg_over_time({host_cpu_query})", percent=True)
    
    ## Host CPU stall time query
    host_cpu_stall_query = """
        (rate(node_pressure_cpu_waiting_seconds_total{instance=~"emqx-.*"}[$W]))[$P:$W]
    """

    # Aggregate P95 of CPU stall time (smoothed over 15s windows) [% of real time]
    # May be more than 100% if the system is under heavy load.
    #
    # Means that running tasks (which are EMQX's node threads most of the time) were
    # starving for a CPU core while all of them were busy with other tasks. Values
    # higher than 0.2 are probably alarming: this would mean that in 95% of cases,
    # tasks spent 0.2 seconds waiting for a free CPU core to run.
    host_cpu_stall_p95 = promquery(
        f"quantile_over_time(0.95, {host_cpu_stall_query})",
        percent=True)

    # Aggregate average of CPU stall time (smoothed over 15s windows) [% of real time]
    # May be more than 100% if the system is under heavy load.
    host_cpu_stall_avg = promquery(
        f"avg_over_time({host_cpu_stall_query})",
        percent=True)
    
    # BEAM VM CPU runtime usage range query
    beam_cpu_query = """
        (increase(erlang_vm_statistics_runtime_milliseconds{job="emqx"}[$W]) /
          increase(erlang_vm_statistics_wallclock_time_milliseconds{job="emqx"}[$W]) /
          erlang_vm_schedulers{job="emqx"}
        )[$P:$W]
    """
    
    # Aggregate P95 of BEAM VM runtime usage (smoothed over 15s windows) [% of real time]
    beam_cpu_p95 = promquery(f"quantile_over_time(0.95, {beam_cpu_query})", percent=True)

    # Aggregate average of BEAM VM runtime usage (smoothed over 15s windows) [% of real time]
    beam_cpu_avg = promquery(f"avg_over_time({beam_cpu_query})", percent=True)

    # Aggregate P95 of BEAM VM run queue length
    #
    # This is a highly fluctuating metric, so picking a 95th or even 99th percentile
    # should give a decent insight into how much VM was starving for CPU. I guess
    # values larger than 100 are alarming.
    beam_runqueue_p95 = promquery(
        """
        quantile_over_time(0.95, emqx_vm_run_queue{job="emqx"}[$P])
        """)
    
    # Aggregate P95 of BEAM VM memory usage (smoothed over 15s windows) [MiB]
    #
    # It will be slightly different from what EMQX hosts think BEAM is using, due to
    # heap fragmentation.
    beam_mem_total_p95 = promquery(
        """
        quantile_over_time(0.95,
          (sum(erlang_vm_memory_bytes_total{job="emqx"}) by (instance))[$P:$W]
        ) / 1024 / 1024
        """)
    
    # Aggregate P95 of BEAM VM memory used by processes (smoothed over 15s windows) [MiB]
    beam_mem_proc_p95 = promquery(
        """
        quantile_over_time(0.95,
          erlang_vm_memory_bytes_total{job="emqx",kind="processes"}[$P:$W]
        ) / 1024 / 1024
        """)
    
    # Aggregate P95 of GCs (smoothed over 15s windows) [gc/s]
    beam_gc_rate_p95 = promquery(
        """
        quantile_over_time(0.95,
          (rate(erlang_vm_statistics_garbage_collection_number_of_gcs{job="emqx"}[$W]))[$P:$W]
        )
        """)
    
    # Aggregate P95 of memory reclaimed by GC (smoothed over 15s windows) [KiB/s]
    beam_gc_mem_p95 = promquery(
        """
        quantile_over_time(0.95,
          (rate(erlang_vm_statistics_garbage_collection_bytes_reclaimed{job="emqx"}[$W]))[$P:$W]
        ) / 1024
        """)
    
    # Aggregate P95 of disk write rate (smoothed over 15s windows) [iops]
    host_io_writes_p95 = promquery(
        """
        quantile_over_time(0.95,
          (
            sum(rate(node_disk_writes_completed_total{instance=~"emqx-.*"}[$W])) by (instance)
          )[$P:$W]
        )
        """)
    
    # Total number of connections / messages
    emqx_n_conns = promquery('max_over_time(emqx_connections_count{job="emqx"}[$P])')
    emqx_n_acked = promquery('max_over_time(emqx_messages_acked{job="emqx"}[$P])')
    emqx_n_published = promquery('max_over_time(emqx_messages_publish{job="emqx"}[$P])')
    emqx_n_delivered = promquery('max_over_time(emqx_messages_delivered{job="emqx"}[$P])')
    emqx_n_dropped = promquery('max_over_time(emqx_messages_dropped{job="emqx"}[$P])')

    # Aggregate P95 of message receive rate [msg/s]
    emqx_recv_rate_p95 = promquery(
        """
        quantile_over_time(0.95,
          (irate(emqx_messages_received{job="emqx"}[$W]))[$P:]
        )
        """)
    
    # Aggregate P95 of message send rate [msg/s]
    emqx_sent_rate_p95 = promquery(
        """
        quantile_over_time(0.95,
          (irate(emqx_messages_sent{job="emqx"}[$W]))[$P:]
        )
        """)
    
    # Aggregate P95/99 of E2E latency observed by emqtt-bench [ms]
    emqttbench_e2e_latency_query = """
        (sum(rate(publish_latency{job="emqtt-bench"}[$W])) /
          sum(rate(pub{job="emqtt-bench"}[$W])) < +Inf
        )[$P:]
        """
    emqttbench_e2e_latency_p95 = promquery(
        f"quantile_over_time(0.95, {emqttbench_e2e_latency_query})",
        shape='values',
        empty=True)
    emqttbench_e2e_latency_p99 = promquery(
        f"quantile_over_time(0.99, {emqttbench_e2e_latency_query})",
        shape='values',
        empty=True)
    
    def emqttb(entry):
        return f"{entry['metric']['instance'].split('~')[1]} {entry['metric']['group']}"
    
    # Average of aggregate P95/99s of E2E latency observed by emqttb [ms]
    # This is not a true P95/99 over all observations
    emqttb_e2e_latency_p95 = promquery(
        'quantile_over_time(0.95, emqttb_e2e_latency{job="emqttb"}[$P]) / 1000 > 0',
        shape=emqttb,
        empty=True)
    emqttb_e2e_latency_p99 = promquery(
        'quantile_over_time(0.99, emqttb_e2e_latency{job="emqttb"}[$P]) / 1000 > 0',
        shape=emqttb,
        empty=True)

    # Total number of published messages
    emqttb_n_published = promquery(
        'sum(emqttb_published_messages{job="emqttb"}) by (group) > 0',
        shape='group',
        empty=True)
    
    # Total number of received messages
    emqttb_n_received = promquery(
        'sum(emqttb_received_messages{job="emqttb"}) by (group) > 0',
        shape='group',
        empty=True)
    
    # Aggregate P95 of message publish rate (smoothed over 15s windows) [msg/s]
    emqttb_pub_rate_p95 = promquery(
        """
        quantile_over_time(0.95,
          (sum(rate(emqttb_published_messages{job="emqttb"}[$W])) by (group))[$P:$W]
        ) > 0
        """,
        shape='group',
        empty=True)

    # Aggregate P95 of message receive rate (smoothed over 15s windows) [msg/s]
    emqttb_recv_rate_p95 = promquery(
        """
        quantile_over_time(0.95,
          (sum(rate(emqttb_received_messages{job="emqttb"}[$W])) by (group))[$P:$W]
        ) > 0
        """,
        shape='group',
        empty=True)

    print(host_cpu_p95)
    print(host_cpu_stall_p95)
    print(beam_cpu_p95)
    print(beam_runqueue_p95)
    print(beam_mem_total_p95)
    print(beam_mem_proc_p95)
    print(beam_gc_rate_p95)
    print(beam_gc_mem_p95)
    print(host_io_writes_p95)
    print(table({
        'Host CPU P95 [%]':host_cpu_p95,
        'Host CPU Avg [%]':host_cpu_avg,
        'BEAM CPU P95 [%]':beam_cpu_p95,
        'BEAM CPU Avg [%]':beam_cpu_avg,
        'Host CPU Stall P95 [%]':host_cpu_stall_p95,
        'Host CPU Stall Avg [%]':host_cpu_stall_avg,
        'BEAM RunQueue P95':beam_runqueue_p95,
        'BEAM Mem Total P95 [MiB]':beam_mem_total_p95,
        'BEAM Mem Proc P95 [MiB]':beam_mem_proc_p95,
        'BEAM GC Rate P95 [gc/s]':beam_gc_rate_p95,
        'BEAM GC Mem P95 [KiB/s]': beam_gc_mem_p95,
        'Host IO Writes P95 [iops]': host_io_writes_p95}))
    print(emqx_n_conns)
    print(emqx_n_acked)
    print(emqx_n_published)
    print(emqx_n_delivered)
    print(emqx_n_dropped)
    print(emqx_recv_rate_p95)
    print(emqx_sent_rate_p95)
    print(table({
        'EMQX Connections':emqx_n_conns,
        'EMQX Acked Msgs':emqx_n_acked,
        'EMQX Published Msgs':emqx_n_published,
        'EMQX Delivered Msgs':emqx_n_delivered,
        'EMQX Dropped Msgs':emqx_n_dropped,
        'EMQX Receive Rate P95 [msg/s]':emqx_recv_rate_p95,
        'EMQX Send Rate P95 [msg/s]':emqx_sent_rate_p95}))
    print(emqttbench_e2e_latency_p95)
    print(emqttbench_e2e_latency_p99)
    print(emqttb_e2e_latency_p95)
    print(emqttb_e2e_latency_p99)
    print(table({
        'EMQTTB E2E Latency P95 [ms]':emqttbench_e2e_latency_p95,
        'EMQTTB E2E Latency P99 [ms]':emqttbench_e2e_latency_p99,
        'EMQTTB E2E Latency P95 [ms]':emqttb_e2e_latency_p95,
        'EMQTTB E2E Latency P99 [ms]':emqttb_e2e_latency_p99}))
    print(emqttb_n_published)
    print(emqttb_n_received)
    print(emqttb_pub_rate_p95)
    print(emqttb_recv_rate_p95)
    print(table({
        'EMQTTB Published Msgs':emqttb_n_published,
        'EMQTTB Received Msgs':emqttb_n_received,
        'EMQTTB Publish Rate P95 [msg/s]':emqttb_pub_rate_p95,
        'EMQTTB Receive Rate P95 [msg/s]':emqttb_recv_rate_p95}))

if __name__ == "__main__":
    main()
