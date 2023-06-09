variable "namespace" {
  type = string
}

variable "ami_filter" {
  type = string
}

variable "sg_ids" {
  type = list(string)
}

variable "instance_type" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "extra_user_data" {
  type = string
}

variable "iam_profile" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "instance_count" {
  type = number
  default = 1
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
