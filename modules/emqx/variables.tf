variable "emqx_namespace" {
  description = "emqx namespace"
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

variable "route53_zone_id" {
  description = "Route53 Zone ID"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 Zone Name"
  type        = string
}

variable "emqx_instance_count" {
  description = "Instance count of emqx"
  type        = number
  default     = 1
}

variable "emqx_instance_type" {
  description = "Instance type of emqx"
  type        = string
  default     = "c5.large"
}

variable "sg_ids" {
  description = "Security Group IDs"
  type        = list(string)
}
