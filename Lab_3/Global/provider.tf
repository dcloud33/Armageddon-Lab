terraform {
  backend "s3" {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "global/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "lab3-tf-locks"
    encrypt = true
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      configuration_aliases = [aws.use1]
    }
  }
}



provider "aws" {
  region = "us-east-1"
}

# Alias provider for us-east-1 (required for CloudFront ACM + WAF)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}


