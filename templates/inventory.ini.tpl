[emqx]
%{ for host in emqx_nodes ~}
${host}
%{ endfor ~}

[emqttb]
%{ for host in emqttb_nodes ~}
${host}
%{ endfor ~}

[emqtt_bench]
%{ for host in emqtt_bench_nodes ~}
${host}
%{ endfor ~}

[monitoring]
%{ for host in monitoring_nodes ~}
${host}
%{ endfor ~}
