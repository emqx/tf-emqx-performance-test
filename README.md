# EMQX Performance Test

Requirements
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS crednetials in shell environment (necessary permissions are in the `./iam-policy.json` document, mind the bucket name)

This creates an EMQX cluster with configurable number of nodes, [emqttb](https://github.com/emqx/emqttb) and/or [emqtt-bench](https://github.com/emqx/emqtt-bench) load generator nodes and prometheus+grafana instance in a private VPC.

## Quick start

```bash
./create-bucket.sh eu-west-1 my-emqx-performance-test
./run.sh eu-west-1 my-emqx-performance-test
```

Default emqx dashboard credentials are `admin:admin`, grafana as well `admin:admin`.

## Running with non-default variables

Take a look at `./run-long.sh` or `./run-1m-conns.sh` script. It will run the same terraform script, but with different variables.

Also take a look at `variables.tf` file to see what variables are available.

## Connecting to instances

Terraform will create an SSH key pair in the .ssh directory. Use IP addresses from the terraform output to connect to instances.

```
ssh a.b.c.d -l ubuntu -i ~/.ssh/emqx-perf-test.pem
```
