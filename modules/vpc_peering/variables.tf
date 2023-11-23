variable "vpc_id" {
  type = string
}

variable "route_table_id" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "peer_vpc_id" {
  type = string
}

variable "peer_route_table_id" {
  type = string
}

variable "peer_region" {
  type = string
}

variable "peer_cidr_block" {
  type = string
}
