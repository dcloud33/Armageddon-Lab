data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "tokyo/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "saopaulo" {
  backend = "s3"
  config = {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "saopaulo/terraform.tfstate"
    region = "us-east-1"
  }
}


data "aws_caller_identity" "aws_caller" {}
