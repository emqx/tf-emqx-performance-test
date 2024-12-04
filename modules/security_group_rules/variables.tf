variable "security_group_id" {
  type = string
}

variable "cidr_ipv4" {
  type = string
}

variable "enable_ipv6" {
  type    = bool
  default = false
}
