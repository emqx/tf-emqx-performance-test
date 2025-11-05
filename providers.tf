terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.19.0"
    }
  }
}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
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
  skip_region_validation = true
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
  skip_region_validation = true
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}
