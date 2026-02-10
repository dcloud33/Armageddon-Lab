terraform {
  backend "s3" {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "saopaulo/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = "sa-east-1"
}
