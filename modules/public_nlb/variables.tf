variable "vpc_id" {
  type = string
}

variable "prefix" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "emqx_instance_ips" {
  type = list(string)
}

variable "monitoring_instance_ip" {
  type = string
}
