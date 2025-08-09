terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"
  endpoints {
    s3 = "http://host.docker.internal:4566"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "bucket-de-ejemplo"
}
