variable "vpc_id" {
  type = string
}

variable "prefix" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "http_api_port" {
  type = number
}
