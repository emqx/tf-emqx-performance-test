variable "prefix" {
  type = string
}

variable "cidr" {
  type = string
}

variable "vpc_region" {
  type = string
}

variable "public_key" {
  type = string
}

variable "provider_alias" {
  type = string
}

variable "enable_ipv6" {
  type    = bool
  default = false
}
