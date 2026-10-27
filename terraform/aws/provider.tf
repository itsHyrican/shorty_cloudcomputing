terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state backend (bucket/lock table are created by state.tf).
  #
  # Bootstrap: the very first apply runs with LOCAL state (block commented
  # out). Afterwards uncomment this block and run
  #   terraform init -migrate-state
  # to move the state into S3. GitHub Actions relies on this backend.
  # The values are literals on purpose: backend configuration cannot
  # reference variables. Keep them in sync with the defaults in variables.tf.
  #
  # backend "s3" {
  #   bucket         = "shorty-dev-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "eu-central-1"
  #   dynamodb_table = "shorty-dev-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
