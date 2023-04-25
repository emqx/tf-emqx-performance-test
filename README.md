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
