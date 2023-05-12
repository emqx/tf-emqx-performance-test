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


