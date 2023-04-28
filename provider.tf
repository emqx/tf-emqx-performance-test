provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Name        = "tf-ci-performance-test"
      Environment = "test"
    }
  }
}
