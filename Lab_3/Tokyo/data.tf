data "terraform_remote_state" "saopaulo" {
  count   = var.enable_saopaulo_accept ? 1 : 0
  backend = "s3"
  config = {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "saopaulo/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}


data "aws_caller_identity" "aws_caller" {}




