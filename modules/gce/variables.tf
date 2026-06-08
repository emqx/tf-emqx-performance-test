variable "prefix" {
  description = "Cluster prefix; makes the GCE instance name unique per cluster in a project"
  type        = string
}

variable "region" {
  description = "GCP region, e.g. us-east1"
  type        = string
}

variable "zone" {
  description = "Zone suffix appended to the region, e.g. \"b\" -> us-east1-b"
  type        = string
  default     = "b"
}

variable "instance_name" {
  type = string
}

variable "instance_type" {
  description = "GCE machine type, e.g. n2-standard-2"
  type        = string
}

variable "hostname" {
  type = string
}

variable "image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}

variable "image_project" {
  type    = string
  default = "ubuntu-os-cloud"
}

variable "subnetwork" {
  description = "Self link of the subnetwork to attach the NIC to"
  type        = string
}

variable "network_tag" {
  description = "Network tag applied to the instance; firewall rules target it"
  type        = string
}

variable "service_account_email" {
  description = "Service account attached to the instance (carries the OS Login SSH key)"
  type        = string
}

variable "remote_user" {
  description = "OS Login POSIX username Ansible connects as (e.g. sa_<unique_id>)"
  type        = string
}

variable "dns_zone_name" {
  description = "Name of the Cloud DNS managed zone for the A record"
  type        = string
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "extra_user_data" {
  type    = string
  default = ""
}

variable "type" {
  description = "Node type (loadgen subtype, etc.)"
  type        = string
  default     = ""
}

variable "attach_to_nlb" {
  type    = bool
  default = false
}

variable "certs" {
  description = "Certificates"
  type = object({
    ca          = string
    server_cert = string
    server_key  = string
    client_cert = string
    client_key  = string
  })
}
