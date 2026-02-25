
data "aws_ec2_managed_prefix_list" "chewbacca_cf_origin_facing01" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

module "cloudfront" {
  source = "../modules/cloudfront"

   providers = {
    aws      = aws        # default provider
    aws.use1 = aws.use1   # alias provider
  }
  
  sp_alb_dns_name    = data.terraform_remote_state.saopaulo.outputs.sp_alb_dns_name
  tokyo_alb_dns_name = data.terraform_remote_state.tokyo.outputs.tokyo_alb_dns_name

  domain_name   = var.domain_name
  app_subdomain = var.app_subdomain
  origin_secret = var.origin_secret
  enable_waf    = var.enable_waf

  manage_route53_in_terraform = var.manage_route53_in_terraform
  route53_hosted_zone_id      = var.route53_hosted_zone_id
  waf_log_destination         = var.waf_log_destination
}










