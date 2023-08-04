variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "namespace" {
  description = "namespace"
  type        = string
  default     = "perf-test"
}

variable "emqx_nodes" {
  description = "Total number of emqx nodes"
  type        = number
  default     = 3
}

variable "emqx_core_nodes" {
  description = "Number of emqx core nodes"
  type        = number
  default     = 3
}

variable "emqx_core_instance_type" {
  description = "Instance type of emqx core nodes"
  type        = string
  default     = "c5.xlarge"
}

variable "emqx_replicant_instance_type" {
  description = "Instance type of emqx core nodes"
  type        = string
  default     = "c5.xlarge"
}

variable "s3_bucket_name" {
  description = "S3 Bucket"
  type        = string
  default     = "tf-emqx-performance-test2"
}

variable "bench_id" {
  description = "Benchmark ID"
  type        = string
  default     = "test"
}

variable "emqx_package_file" {
  description = "Package file"
  type        = string
  default     = "emqx.deb"
}

variable "emqttb_package_url" {
  type    = string
  default = "https://github.com/emqx/emqttb/releases/download/v0.1.14/emqttb-0.1.14-ubuntu20.04-amd64-quic.tar.gz"
}

variable "emqttb_nodes" {
  description = "amount of emqttb (loadgen) nodes"
  type        = number
  default     = 1
}

variable "emqttb_instance_type" {
  description = "Instance type of emqttb"
  type        = string
  default     = "c5.large"
}

variable "emqttb_scenario" {
  description = "emqttb scenario"
  type        = string
  default     = "@pubsub_fwd -n 1_000 --pub-qos 1 --sub-qos 1"
}

variable "emqttb_start_n_multiplier" {
  description = "start-n multiplier for each next emqttb instance based on launch index"
  type        = number
  default     = 0
}

variable "route53_zone_name" {
  description = "Hosted zone name"
  type        = string
  default     = "perftest.emqx.io"
}

variable "duration" {
  description = "Performance test duration in seconds"
  type        = number
  default     = 300
}

variable "ssh_key_name" {
  description = "SSH key name"
  type        = string
  default     = "emqx-perf-test"
}

variable "create_public_mqtt_nlb" {
  description = "Whether to create publicly exposed MQTT NLB on 1883"
  type        = number
  default     = 0
}

variable "emqtt_bench_package_url" {
  type    = string
  default = "https://github.com/emqx/emqtt-bench/releases/download/0.4.11/emqtt-bench-0.4.11-ubuntu20.04-amd64.tar.gz"
}

variable "emqtt_bench_nodes" {
  description = "amount of emqtt-bench (loadgen) nodes"
  type        = number
  default     = 0
}

variable "emqtt_bench_instance_type" {
  description = "Instance type of emqtt-bench nodes"
  type        = string
  default     = "c5.large"
}

variable "emqtt_bench_scenario" {
  description = "emqtt-bench scenario"
  type        = string
  default     = "conn -c 100000 -i 10"
}

variable "emqtt_bench_start_n_multiplier" {
  description = "multiplier for --startnumber option for each next emqtt-bench instance based on launch index"
  type        = number
  default     = 0
}

variable "internal_mqtt_nlb_count" {
  description = "Internal MQTT NLB count"
  type        = number
  default     = 1
}

variable "prometheus_remote_write_url" {
  description = "Prometheus remote write URL"
  type        = string
  default     = ""
}

variable "prometheus_remote_write_region" {
  description = "Prometheus remote write region"
  type        = string
  default     = "eu-west-1"
}
