variable "namespace" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "cidr_blocks" {
  type = list(string)
}
