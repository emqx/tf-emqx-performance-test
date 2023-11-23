variable "regions_abbrev_map" {
  type = map
  default = {
    "eu-west-1" = "euw1"
    "us-east-1" = "use1"
    "us-west-1" = "usw1"
    "ap-southeast-1" = "apse1"
  }
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
  default     = "10.0.0.0/8"
}

variable "namespace" {
  description = "namespace"
  type        = string
  default     = "perftest"
}

variable "instance_type" {
  description = "Default instance type"
  type        = string
  default     = "m6a.large"
}

variable "bench_id" {
  description = "Benchmark ID"
  type        = string
  default     = null
}

variable "spec_file" {
  type        = string
  default     = "tests/default.yaml"
}

# variable "emqttb_package_url" {
#   type    = string
#   default = "https://github.com/emqx/emqttb/releases/download/v0.1.14/emqttb-0.1.14-ubuntu20.04-amd64-quic.tar.gz"
# }

# variable "emqttb_scenario" {
#   description = "emqttb scenario"
#   type        = string
#   default     = "@pubsub_fwd -n 1_000 --pub-qos 1 --sub-qos 1"
# }

# variable "emqttb_start_n_multiplier" {
#   description = "start-n multiplier for each next emqttb instance based on launch index"
#   type        = number
#   default     = 0
# }

# variable "duration" {
#   description = "Performance test duration in seconds"
#   type        = number
#   default     = 300
# }

# variable "emqtt_bench_package_url" {
#   type    = string
#   default = "https://github.com/emqx/emqtt-bench/releases/download/0.4.11/emqtt-bench-0.4.11-ubuntu20.04-amd64.tar.gz"
# }

# variable "emqtt_bench_scenario" {
#   description = "emqtt-bench scenario"
#   type        = string
#   default     = "conn -c 100000 -i 10"
# }

# variable "emqtt_bench_start_n_multiplier" {
#   description = "multiplier for --startnumber option for each next emqtt-bench instance based on launch index"
#   type        = number
#   default     = 0
# }
