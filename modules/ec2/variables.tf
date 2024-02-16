variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "prefix" {
  type = string
}

variable "ami_filter" {
  type = string
}

variable "ami_owner" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "extra_user_data" {
  type    = string
  default = ""
}

variable "instance_name" {
  type = string
}

variable "route53_zone_id" {
  type = string
}

variable "hostname" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "region_aliases" {
  type = map(string)
}

variable "use_spot_instances" {
  description = "If true, use spot instances. On-demand otherwise."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Root volume size"
  type        = number
  default     = 20
}

variable "ip_alias_count" {
  description = "The number of IP aliases to add to the instance"
  type        = number
  default     = 0
}

variable "instance_volumes" {
  description = "Storage volumes directly attached to the instance"
  type = list(object({
    mount_point   = string
    mount_options = optional(string, "defaults")
  }))
  default = []
}

variable "extra_volumes" {
  description = "Extra volumes to attach to the instance"
  type = list(object({
    volume_size       = number
    volume_type       = optional(string, "gp3")
    volume_iops       = optional(number, null)
    volume_throughput = optional(number, null)
    mount_point       = string
    mount_options     = optional(string, "defaults")
  }))
  default = []
}

## EC2 does not want enumerated device names, like "/dev/sdxN"
variable "data_volume_device_list" {
  description = "Device list for EC2 mapping"
  type        = list(any)
  default = ["/dev/sdf", "/dev/sdg", "/dev/sdh",
    "/dev/sdi", "/dev/sdj", "/dev/sdk",
    "/dev/sdl", "/dev/sdm", "/dev/sdn",
    "/dev/sdo", "/dev/sdp", "/dev/sdq",
    "/dev/sdr", "/dev/sds", "/dev/sdt",
    "/dev/sdu", "/dev/sdv", "/dev/sdw",
  "/dev/sdx", "/dev/sdy", "/dev/sdz"]
}
