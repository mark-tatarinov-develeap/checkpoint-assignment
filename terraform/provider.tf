terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket         = "devops-checkpoint-assignment-tfstate"  
    key            = "terraform.tfstate"                   
    region         = "us-west-2"
    use_lockfile   = true
    encrypt        = true
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}


