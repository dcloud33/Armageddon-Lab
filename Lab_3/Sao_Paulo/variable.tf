variable "aws_region" {
  description = "AWS Region that I'd used because...I'm forgetful"
  default     = "sa-east-1"
}
variable "user_name" {
  type    = string
  default = "Sao_Paulo_user"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs."
  type        = list(string)
  default     = ["10.70.1.0/24", "10.70.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs."
  type        = list(string)
  default     = ["10.70.11.0/24", "10.70.12.0/24"]
}

variable "account_ID" {
  type    = string
default = "724772093504"

}

variable "ec2_ami_id" {
  description = "AMI ID for the EC2 app host."
  type        = string
  default     = "ami-0f85876b1aff99dde"
}

variable "ec2_instance_type" {
  description = "EC2 instance size for the app."
  type        = string
  default     = "t2.micro"
}

variable "sns_sub_email_endpoint" {
  type    = string
  default = "wheeling2346@gmail.com"
}

variable "alb_5xx_threshold" {
  type    = number
  default = 12
}

variable "alb_5xx_evaluation_periods" {
  type    = number
  default = 1
}

variable "alb_5xx_period_seconds" {
  type    = number
  default = 300
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logging to S3."
  type        = bool
  default     = true
}
variable "alb_access_logs_prefix" {
  type    = string
  default = "lab-alb-logs"
}

variable "origin_secret" {
  type      = string
  default = "cd5161ff7a46d7584f5f5326477291373320fb84ae318577d83fff1a531f8fcd"
}