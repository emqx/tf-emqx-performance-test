terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.56.1"
    }
  }
}

provider "aws" {
  region = local.region
  alias  = "default"
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}

provider "aws" {
  region = local.region2 == "region2-stub" ? null : local.region2
  alias  = "region2"
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}

provider "aws" {
  region = local.region3 == "region3-stub" ? null : local.region3
  alias  = "region3"
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}
