variable "vpc_id" {
  type = string
}

variable "namespace" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_ids" {
  type = list(string)
}

variable "instance_sg_id" {
  type = string
}
