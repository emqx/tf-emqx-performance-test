output "s3_bucket_name" {
  description = "S3 Bucket name (for ec2 to get permissions)"
  value       = var.s3_bucket_name
}

output "package_url" {
  description = "Package download URL"
  value       = "https://${var.s3_bucket_name}.s3.${var.region}.amazonaws.com/${var.s3_prefix}/${var.package_file}"
}
