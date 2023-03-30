variable "namespace" {
  description = "namespace"
  type        = string
}

variable "ami_filter" {
  description = "AMI filter"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 Bucket"
  type        = string
}

variable "package_url" {
  description = "Package URL"
  type        = string
}

variable "instance_count" {
  description = "Instance count"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "c5.large"
}

variable "sg_ids" {
  description = "Security Group IDs"
  type        = list(string)
}

variable "emqx_lb_dns_name" {
  description = "FQDN of EMQX Load Balancer"
  type        = string
}

variable "iam_profile" {
  description = "IAM Instance Profile"
  type        = string
}

variable "bench_id" {
  description = "Benchmark ID"
  type        = string
}

variable "clients_count" {
  description = "Clients count"
  type        = number
  default     = 64000
}

variable "payload_size" {
  description = "Payload size"
  type        = number
  default     = 256
}

variable "max_message_count" {
  description = "Max message count"
  type        = number
  default     = 1000000
}
