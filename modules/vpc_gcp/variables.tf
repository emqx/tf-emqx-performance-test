variable "prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr" {
  description = "CIDR range for the subnetwork"
  type        = string
}

variable "network_tag" {
  description = "Network tag applied to instances; firewall rules target it"
  type        = string
}
