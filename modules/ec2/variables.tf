variable "region" {
  type = string
}

variable "prefix" {
  type = string
}

variable "ami_filter" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "extra_user_data" {
  type = string
  default = ""
}

variable "instance_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "hostname" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "region_aliases" {
  type = map(string)
}

variable "use_spot_instances" {
  description = "If true, use spot instances. On-demand otherwise."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root volume size"
  type        = number
  default     = 20
}
