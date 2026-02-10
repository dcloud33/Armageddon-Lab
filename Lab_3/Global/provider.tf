terraform {
  backend "s3" {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "global/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "lab3-tf-locks"
    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
}



# Needed for resources that must live in us-east-1 (CloudFront ACM + global WAF)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
