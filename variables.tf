variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "namespace" {
  description = "namespace"
  type        = string
  default     = "perf-test"
}

variable "emqx_instance_count" {
  description = "Instance count of emqx"
  type        = number
  default     = 3
}

variable "emqx_instance_type" {
  description = "Instance type of emqx"
  type        = string
  default     = "c5.large"
}

variable "s3_bucket_name" {
  description = "S3 Bucket"
  type        = string
  default     = "tf-emqx-performance-test"
}

variable "bench_id" {
  description = "Benchmark ID"
  type        = string
  default     = "test"
}

variable "package_file" {
  description = "Package file"
  type        = string
  default     = "emqx.deb"
}

variable "emqttb_package_url" {
  type    = string
  default = "https://github.com/emqx/emqttb/releases/download/v0.1.2/emqttb-0.1.2-ubuntu20.04-amd64.tar.gz"
}

variable "emqttb_instance_count" {
  description = "Instance count of emqttb"
  type        = number
  default     = 1
}

variable "emqttb_instance_type" {
  description = "Instance type of emqttb"
  type        = string
  default     = "c5.large"
}

variable "route53_zone_name" {
  description = "Hosted zone name"
  type        = string
  default     = "int.emqx.io"
}

variable "forwarding_config" {
  description = "forwarding config of nlb"
  type        = map(any)
  default = {
    "1883" = {
      dest_port   = 1883,
      protocol    = "TCP"
      description = "mqtt"
    },
    "8083" = {
      dest_port   = 8083,
      protocol    = "TCP"
      description = "ws"
    },
    "18083" = {
      dest_port   = 18083,
      protocol    = "TCP"
      description = "dashboard"
    }
  }
}
