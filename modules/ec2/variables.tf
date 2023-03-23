variable "namespace" {
  type = string
}

variable "ami_filter" {
  type = string
}

variable "sg_ids" {
  type = list(string)
}

variable "instance_count" {
  type = number
}

variable "instance_type" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "extra_user_data" {
  type = string
}
