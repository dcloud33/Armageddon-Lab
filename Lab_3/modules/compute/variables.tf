############################################
# modules/compute/variables.tf
############################################

variable "aws_region" {
  description = "AWS Region that I'd used because...I'm forgetful"
  default     = "sa-east-1"
}


variable "account_ID" {
  type    = string
  default = "724772093504"

}


variable "name_prefix" { 
    type = string
     }

variable "vpc_id" { 
    type = string 
    }

variable "vpc_cidr" {
  type        = string
  description = "Needed only if enable_alb_https = true"
  default     = null
}

variable "public_subnet_ids" { 
    type = list(string)
     }
variable "private_subnet_ids" { 
    type = list(string)
    }

variable "ami_id" { type = string }
variable "instance_type" { type = string }

variable "user_data" {
  type        = string
  description = "Plaintext user_data; module base64encodes"
}

variable "origin_secret" { type = string }

variable "enable_asg" {
  type    = bool
  default = true
}

variable "asg_min_size" { 
    type = number 
    default = 1 
    }

variable "asg_desired_capacity" { 
    type = number
    default = 1 
 }

variable "asg_max_size" { 
    type = number 
    default = 3 
    }

variable "alb_name" {
  type    = string
  default = null
}

variable "enable_alb_https" {
  type    = bool
  default = false
}

variable "enable_alb_5xx_alarm" {
  type    = bool
  default = true
}

variable "alb_5xx_threshold" { 
    type = number 
    default = 5 
    }

variable "alb_5xx_period_seconds" { 
    type = number
    default = 300
  }

variable "alb_5xx_evaluation_periods" { 
    type = number 
    default = 1
     }

variable "alarm_actions" {
  type    = list(string)
  default = []
}

variable "ok_actions" {
  type    = list(string)
  default = []
}

# Optional: restrict secrets permissions
variable "secret_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}