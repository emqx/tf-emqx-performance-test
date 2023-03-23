# resource "aws_s3_bucket" "bucket" {
#   bucket = "${var.s3_bucket_name}"
# }

resource "aws_s3_object" "emqx_package" {
  bucket = var.s3_bucket_name
  key    = "${var.s3_prefix}/${var.package_file}"
  acl    = "public-read"
  source = var.package_file
}


