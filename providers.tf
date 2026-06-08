terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.19.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Used only when local.cloud == "gcp". When running on AWS the project is empty
# and no google resources are created, so the provider stays unauthenticated.
provider "google" {
  project = local.gcp_project
  region  = local.gcp_region
  zone    = "${local.gcp_region}-${local.gcp_zone}"
}

provider "aws" {
  region = local.aws_provider_region
  # Skip AWS credential/account lookups on a GCP run so the unused provider
  # configures without AWS credentials present.
  skip_credentials_validation = local.cloud_is_gcp
  skip_requesting_account_id  = local.cloud_is_gcp
  skip_metadata_api_check     = local.cloud_is_gcp
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}

provider "aws" {
  region                      = local.aws_provider_region
  alias                       = "default"
  skip_credentials_validation = local.cloud_is_gcp
  skip_requesting_account_id  = local.cloud_is_gcp
  skip_metadata_api_check     = local.cloud_is_gcp
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}

provider "aws" {
  region                      = local.aws_provider_region2
  alias                       = "region2"
  skip_credentials_validation = local.cloud_is_gcp
  skip_requesting_account_id  = local.cloud_is_gcp
  skip_metadata_api_check     = local.cloud_is_gcp
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}

provider "aws" {
  region                      = local.aws_provider_region3
  alias                       = "region3"
  skip_credentials_validation = local.cloud_is_gcp
  skip_requesting_account_id  = local.cloud_is_gcp
  skip_metadata_api_check     = local.cloud_is_gcp
  default_tags {
    tags = {
      Name        = local.prefix
      BenchmarkId = local.bench_id
      Environment = "perftest"
    }
  }
}
