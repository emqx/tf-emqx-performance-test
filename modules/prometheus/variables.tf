variable "namespace" {
  description = "namespace"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "cidr_blocks" {
  type = list(string)
}

variable "ami_filter" {
  description = "AMI filter"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 Bucket"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "m5.large"
}

variable "iam_profile" {
  description = "IAM Instance Profile"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 Zone Name"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 Zone ID"
  type        = string
}

variable "key_name" {
  description = "SSH Key Name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "remote_write_url" {
  description = "Prometheus Remote Write URL"
  type        = string
}

variable "remote_write_region" {
  description = "Prometheus Remote Write Region"
  type        = string
}

variable "emqx_targets" {
  description = "Private IPs of EMQX instances"
  type        = list(string)
}

variable "emqttb_targets" {
  description = "Private IPs of emqttb instances"
  type        = list(string)
}

variable "emqtt_bench_targets" {
  description = "Private IPs of emqtt-bench instances"
  type        = list(string)
}
