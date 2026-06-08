variable "prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "cidr" {
  description = "CIDR range for the subnetwork (only used when create_network = true)"
  type        = string
}

variable "network_tag" {
  description = "Network tag applied to instances; firewall rules target it"
  type        = string
}

variable "create_network" {
  description = "Create the network + subnetwork. When false, look up existing ones by name."
  type        = bool
  default     = true
}

variable "network_name" {
  description = "Name of an existing network to use when create_network = false"
  type        = string
  default     = ""
}

variable "subnetwork_name" {
  description = "Name of an existing subnetwork to use when create_network = false"
  type        = string
  default     = ""
}

variable "create_firewall" {
  description = "Create the internal/external firewall rules (target-tagged to this run)"
  type        = bool
  default     = true
}
