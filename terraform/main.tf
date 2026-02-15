  terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.32.1"
    }
  }

  required_version = ">= 1.12.0"
  backend "s3" {
    bucket       = "fastapi-dev-123456"
    key          = "state/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
