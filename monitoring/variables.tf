variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "namespace" {
  description = "namespace"
  type        = string
  default     = "tf-perf-test"
}

variable "route53_zone_name" {
  description = "Route53 Zone Name"
  type        = string
  default     = "emqx.works"
}

variable "route53_int_zone_name" {
  description = "Route53 Zone Name"
  type        = string
  default     = "int.emqx.works"
}

variable "s3_bucket_name" {
  type    = string
  default = "tf-emqx-performance-test"
}
