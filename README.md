# EMQX Performance Test

By default this will create a cluster of 3 emqx nodes in AWS behind NLB, and a single node of emqtt-bench.

Requirements
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS crednetials in shell environment
- `emqx.deb` package for emqx 5.x and Ubuntu 20.04 (x86) in the root directory

```bash
terraform init
terraform apply -auto-approve
```
