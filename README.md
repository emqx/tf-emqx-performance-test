# EMQX Performance Test

By default this will create a cluster of 3 emqx nodes in AWS behind NLB, and a single node of emqttb.

Requirements
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS crednetials in shell environment
- `emqx.deb` package for emqx 5.x and Ubuntu 20.04 (x86) in the root directory
- Grafana API KEY can be created in Grafana UI

```bash
terraform init
export TF_VAR_bench_id=abc123
export TF_VAR_test_duration_seconds=60
export TF_VAR_grafana_url='https://perf-dashboard.emqx.works'
export TF_VAR_grafana_api_key='***'
terraform apply -auto-approve
```

After the emqttb scenario is completed, it will upload metrics, stats and DONE marker to the `tf-emqx-performance-test` bucket.

```
until aws s3api head-object --bucket tf-emqx-performance-test --key "$TF_VAR_bench_id/DONE" > /dev/null 2>&1; do
    echo 'waiting'
    sleep 10
done

aws s3 cp "s3://tf-emqx-performance-test/$TF_VAR_bench_id/metrics.json" ./
aws s3 cp "s3://tf-emqx-performance-test/$TF_VAR_bench_id/stats.json" ./
terraform destroy -auto-approve
```

## Running with non-default variables

Terraform is using `tf-emqx-performance-test` S3 bucket to make emqx package available for EC2 instances, and to store performance test results. This bucket is not managed by Terraform.

If you want to run this script and customize which S3 bucket it has to use (if you don't have access to `tf-emqx-performance-test`), you need to create an S3 bucket yourself and configure permissions to enable public access to objects (uncheck "Block all public access" if you use AWS Console), and ACLs must be enabled too.

Then you can run terraform and override default variables like this:

```
terraform apply \
    -var="region=eu-central-1" \
    -var="s3_bucket_name=id-emqx-test" \
    -var="emqx_instance_count=1" \
    -var="bench_id=2023-04-28/test" \
    -var="package_file=emqx-5.0.24-ubuntu20.04-amd64.deb"
```

Note that the S3 bucket will not be deleted by terraform in `destroy`.

## Connecting to instances

Terraform will create an SSH key pair in the .ssh directory. Use IP addresses from the terraform output to connect to instances.

```
ssh a.b.c.d -l ubuntu -i ~/.ssh/emqx-perf-test.pem
```
