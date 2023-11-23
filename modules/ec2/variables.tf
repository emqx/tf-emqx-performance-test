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

variable "extra_user_data" {
  type = string
  default = ""
}

variable "iam_profile" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "hostname" {
  type = string
  default = ""
}

variable "instance_count" {
  type = number
  default = 1
}

variable "key_name" {
  description = "SSH Key Name"
  type        = string
}

variable "subnet_id" {
  type = string
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
