variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "emqx_namespace" {
  description = "emqx namespace"
  type        = string
  default     = "tf-emqx"
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

variable "s3_prefix" {
  description = "S3 prefix"
  type        = string
  default     = "packages"
}

variable "package_file" {
  description = "Package file"
  type        = string
  default     = "emqx.deb"
}

variable "dns_zone_name" {
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
