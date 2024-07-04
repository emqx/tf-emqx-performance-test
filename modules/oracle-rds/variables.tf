variable "prefix" {
  description = "The prefix to use for all resources"
  type        = string
}

variable "engine" {
  description = "The database engine to use"
  type        = string
  default     = "oracle-se2"
}

variable "engine_version" {
  description = "The engine version to use"
  type        = string
  default     = "19"
}

variable "instance_class" {
  description = "The instance class to use"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "The allocated storage in gibibytes"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "The storage type to use"
  type        = string
  default     = "gp3"
}

variable "storage_encrypted" {
  description = "Whether the storage is encrypted"
  type        = bool
  default     = true
}

variable "username" {
  description = "The username for the database"
  type        = string
  default     = "admin"
}

variable "security_group_ids" {
  description = "The security group ids to use"
  type        = list(string)
}

variable "subnet_ids" {
  description = "The subnet ids to use"
  type        = list(string)
}

variable "tls_port" {
  description = "The port to use for TLS connections"
  type        = number
  default     = 2484
}

variable "route53_zone_id" {
  type = string
}

variable "hostname" {
  type = string
}
