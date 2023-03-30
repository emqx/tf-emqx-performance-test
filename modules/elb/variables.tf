variable "vpc_id" {
  type = string
}

variable "namespace" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_count" {
  type = number
}

variable "instance_ids" {
  type = list(string)
}

variable "forwarding_config" {
  type = map(any)
}

variable "route53_zone_id" {
  description = "Route53 Zone ID"
  type        = string
}

variable "route53_zone_name" {
  description = "Route53 Zone Name"
  type        = string
}
