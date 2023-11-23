terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
    }
  }
  required_version = ">= 1.6.0"
}

provider "aws" {
  region = local.default_region
  alias  = "default"
  # default_tags {
  #   tags = {
  #     Name        = "${var.namespace}/${local.bench_id}"
  #     BenchmarkId = local.bench_id
  #     Environment = "perftest"
  #   }
  # }
}

provider "aws" {
  region = local.region2
  alias  = "region2"
  # default_tags {
  #   tags = {
  #     Name        = "${var.namespace}/${local.bench_id}"
  #     BenchmarkId = local.bench_id
  #     Environment = "perftest"
  #   }
  # }
}

provider "aws" {
  region = local.region3
  alias  = "region3"
  # default_tags {
  #   tags = {
  #     Name        = "${var.namespace}/${local.bench_id}"
  #     BenchmarkId = local.bench_id
  #     Environment = "perftest"
  #   }
  # }
}
