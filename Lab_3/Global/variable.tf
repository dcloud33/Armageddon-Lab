variable "waf_log_destination" {
  description = "Choose ONE destination per WebACL: cloudwatch | s3 | firehose"
  type        = string
  default     = "s3"
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "route53_hosted_zone_id" {
  description = "If manage_route53_in_terraform=false, provide existing Hosted Zone ID for domain."
  type        = string
  default     = "Z01500111XNTGSU8AH1Y0"
}

variable "manage_route53_in_terraform" {
  description = "If true, create/manage Route53 hosted zone + records in Terraform."
  type        = bool
  default     = false
}

variable "origin_secret" {
  type      = string
  default = "cd5161ff7a46d7584f5f5326477291373320fb84ae318577d83fff1a531f8fcd"
}

variable "domain_name" {
  type    = string
  default = "piecourse.com"
}
variable "app_subdomain" {
  type    = string
  default = "app"
}
