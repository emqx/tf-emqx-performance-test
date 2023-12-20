[emqx5]
%{ if emqx_version_family == 5 ~}
%{ for host in emqx_nodes ~}
${host}
%{ endfor ~}
%{ endif ~}

[emqx4]
%{ if emqx_version_family == 4 ~}
%{ for host in emqx_nodes ~}
${host}
%{ endfor ~}
%{ endif ~}

[emqx:children]
emqx4
emqx5

[emqttb]
%{ for host in emqttb_nodes ~}
${host}
%{ endfor ~}

[emqtt_bench]
%{ for host in emqtt_bench_nodes ~}
${host}
%{ endfor ~}

[locust]
%{ for host in locust_nodes ~}
${host}
%{ endfor ~}

[loadgen:children]
emqttb
emqtt_bench
locust

[monitoring]
%{ for host in monitoring_nodes ~}
${host}
%{ endfor ~}
