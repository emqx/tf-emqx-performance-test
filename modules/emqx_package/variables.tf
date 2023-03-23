variable "region" {
  description = "AWS region"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "s3_prefix" {
  description = "S3 prefix"
  type        = string
}

variable "package_file" {
  description = "Package file"
  type        = string
}
