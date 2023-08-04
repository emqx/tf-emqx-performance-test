# EMQX Performance Test

Requirements
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS crednetials in shell environment (necessary permissions are in the `./iam-policy.json` document, mind the bucket name)

This creates an EMQX cluster with configurable number of core and replicant nodes, [emqttb](https://github.com/emqx/emqttb) and/or [emqtt-bench](https://github.com/emqx/emqtt-bench) load generator nodes, and prometheus+grafana instance in a private VPC.

## Quick start

```bash
./create-bucket.sh eu-west-1 my-emqx-performance-test
./download-emqx.sh 5.1.4 emqx-v5.1.4.deb
terraform init
terraform plan -out=plan.tfplan \
    -var=emqx_package_file=./emqx-v5.1.4.deb \
    -var=bench_id=$(date +%Y-%m-%d)/test \
    -var=region=eu-west-1 \
    -var=s3_bucket_name=my-emqx-performance-test \
    -var=duration=1800 && \
    terraform apply ./plan.tfplan
terraform destroy
```

Default emqx dashboard credentials are `admin:admin`, grafana credentials are as well `admin:admin`.

## Running with custom loadgen scenarios

### 1 on 1

- 50k publishers, 50k subscribers, 50k topics
- QoS 1, payload 16B

```bash
./download-emqx.sh 5.1.4 emqx-v5.1.4.deb
terraform init
terraform plan -out=plan.tfplan \
    -var=emqx_package_file=./emqx-v5.1.4.deb \
    -var=bench_id=$(date +%Y-%m-%d)/1on1 \
    -var=duration=1800 \
    -var=emqx_nodes=3 \
    -var=emqx_core_instance_type=c5.2xlarge \
    -var=emqttb_instance_type=c5.xlarge \
    -var=emqttb_nodes=2 \
    -var=emqttb_scenario='@pubsub_fwd -n 50_000 --pub-qos 1 --sub-qos 1' && \
    terraform apply ./plan.tfplan
terraform destroy
```

### Fan In

- 50k publishers, 50k pub topics
- pub rate: 50k/s (each publisher pubs a message per second)
- use a shared subscription to consume data (to avoid slow consumption by subscribers affecting broker performance, 500 subscribers are used to share the subscription)
- shared subscription’s topic: $share/perf/test/#
- pub topics: test/$clientid
- QoS 1, payload 16B

*Note*: START_N in emqttb scenario is a placeholder which will be replaced in runtime with `$((emqttb_start_n_multiplier * <emqttb instance launch index>))`.

```bash
./download-emqx.sh 5.1.4 emqx-v5.1.4.deb
terraform init
terraform plan -out=plan.tfplan \
    -var=emqx_package_file=./emqx-v5.1.4.deb \
    -var=bench_id=$(date +%Y-%m-%d)/fanin \
    -var=duration=1800 \
    -var=emqx_nodes=3 \
    -var=emqx_core_instance_type=c5.2xlarge \
    -var=emqttb_instance_type=c5.xlarge \
    -var=emqttb_nodes=2 \
    -var=emqttb_scenario='@pub --topic "test/%n" --conninterval 10ms --pubinterval 1s --num-clients 25_000 --size 16 --start-n START_N @sub --topic "$share/perf/test/#" --conninterval 10ms --num-clients 250' \
    -var emqttb_start_n_multiplier=25000 && \
    terraform apply ./plan.tfplan
terraform destroy
```

### Fan Out

- 5 publishers, 5 topics, 1000 subscribers (each sub to all topics)
- pub rate: 250/s, so sub rate = 250*1000 = 250k/s
- QoS 1, payload 16B

```bash
./download-emqx.sh 5.1.4 emqx-v5.1.4.deb
terraform init
terraform plan -out=plan.tfplan \
    -var=emqx_package_file=./emqx-v5.1.4.deb \
    -var=bench_id=$(date +%Y-%m-%d)/fanout \
    -var=duration=1800 \
    -var=emqx_nodes=3 \
    -var=emqx_core_instance_type=c5.large \
    -var=emqttb_instance_type=c5.2xlarge \
    -var=emqttb_nodes=1 \
    -var=emqttb_scenario='@pub --topic "t/%n" --conninterval 10ms --pubinterval 20ms --num-clients 5 --size 16 @sub --topic "t/#" --conninterval 10ms --num-clients 1000' && \
    terraform apply ./plan.tfplan
terraform destroy
```

### 1m connections

- 5 publishers, 5 topics, 1000 subscribers (each sub to all topics)
- pub rate: 250/s, so sub rate = 250*1000 = 250k/s
- QoS 1, payload 16B

```bash
./download-emqx.sh 5.1.4 emqx-v5.1.4.deb
terraform init
terraform plan -out=plan.tfplan \
    -var=bench_id=$(date +%Y-%m-%d)/1mconns \
    -var=duration=1800 \
    -var=emqx_nodes=3 \
    -var=emqx_core_instance_type=c5.2xlarge \
    -var=emqttb_instance_type=c5.2xlarge \
    -var=emqttb_nodes=5 \
    -var=emqttb_scenario='@conn -N 200_000 --conninterval 1ms @a -a conn_group_autoscale -V 100' \
    -var=emqttb_start_n_multiplier=200000 \
    -var=emqx_package_file=./emqx-v5.1.4.deb && \
    terraform apply ./plan.tfplan
terraform destroy
```

### Retained messages

*Note*: START_N in emqtt-bench scenario is a placeholder which will be replaced in runtime with `$((emqtt_bench_start_n_multiplier * <emqtt-bench instance launch index>))`.

```bash
./download-emqx.sh 5.1.4 emqx-v5.1.4.deb
terraform init
terraform plan -out=plan.tfplan \
    -var=emqx_package_file=./emqx-v5.1.4.deb \
    -var=bench_id=$(date +%Y-%m-%d)/retained \
    -var=duration=1800 \
    -var=emqx_nodes=6 \
    -var=emqx_core_instance_type=c5.2xlarge \
    -var=emqx_replicant_instance_type=c5.xlarge \
    -var=emqttb_nodes=0 \
    -var=emqtt_bench_nodes=2 \
    -var=emqtt_bench_instance_type=c5.xlarge \
    -var=emqtt_bench_scenario='pub -t "t/%i" -c 10000 -i 1 -r true -n START_N' \
    -var=emqtt_bench_start_n_multiplier=10000 && \
    terraform apply ./plan.tfplan
terraform destroy
```

## Connecting to instances

Terraform will create an SSH key pair in the .ssh directory. Use IP addresses from the terraform output to connect to instances.

```
ssh a.b.c.d -l ubuntu -i ~/.ssh/emqx-perf-test.pem
```
