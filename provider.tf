provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Name        = "tf-ci-performance-test"
      Environment = "test"
    }
  }
}
