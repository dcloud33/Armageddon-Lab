terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # include this only if you use provider = aws.use1 anywhere in the module
      configuration_aliases = [aws.use1]
    }
  }
}


data "aws_caller_identity" "aws_caller" {}


locals {
  # Explanation: Chewbacca needs a home planet—Route53 hosted zone is your DNS territory.
  my_zone_name = var.domain_name

  # Explanation: Use either Terraform-managed zone or a pre-existing zone ID (students choose their destiny).
  my_zone_id = var.manage_route53_in_terraform ? aws_route53_zone.my_zone[0].zone_id : var.route53_hosted_zone_id

  # Explanation: This is the app address that will growl at the galaxy (app.chewbacca-growl.com).
  my_app = "${var.app_subdomain}.${var.domain_name}"
}

data "aws_route53_zone" "piecourse" {
  name         = "${var.domain_name}."
  private_zone = false
}

data "aws_ec2_managed_prefix_list" "chewbacca_cf_origin_facing01" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_cloudfront_cache_policy" "use_origin_cache_control" {
  name = "UseOriginCacheControlHeaders"
}


########## Cloudfront

resource "aws_cloudfront_distribution" "my_cf" {
  enabled         = true
  is_ipv6_enabled = false
  comment         = "lab-cf01"

  

  ########################################
  # Origins (São Paulo + Tokyo)
  ########################################
  origin {
    origin_id   = "sp-alb-origin"
    domain_name = var.sp_alb_dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "My_Custom_Header"
      value = var.origin_secret
    }
  }

  origin {
  origin_id   = "tokyo-alb-origin"
  domain_name = var.tokyo_alb_dns_name

  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }

  custom_header {
    name  = "My_Custom_Header"
    value = var.origin_secret
  }
}


  ########################################
  # Origin Group (Failover)
  # Primary: São Paulo
  # Failover: Tokyo
  ########################################
  origin_group {
    origin_id = "lab-origin-group01"

   failover_criteria {
  status_codes = [500, 502, 503, 504]
}


    member { origin_id = "sp-alb-origin" }
    member { origin_id = "tokyo-alb-origin" }
  }

  ########################################
  # Behaviors target the ORIGIN GROUP now
  ########################################
  default_cache_behavior {
    target_origin_id       = "lab-origin-group01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods  = ["GET","HEAD"]

    cache_policy_id          = aws_cloudfront_cache_policy.my_cache_api_disabled01.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_api01.id
  }

ordered_cache_behavior {
  path_pattern     = "/init*"
  target_origin_id = "lab-origin-group01"

  viewer_protocol_policy = "redirect-to-https"
  allowed_methods        = ["GET","HEAD","OPTIONS"]
  cached_methods         = ["GET","HEAD","OPTIONS"]

  cache_policy_id          = aws_cloudfront_cache_policy.my_cache_api_disabled01.id
  origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_api01.id
}




  ordered_cache_behavior {
    path_pattern           = "/api/public-feed"
    target_origin_id       = "lab-origin-group01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods  = ["GET","HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.use_origin_cache_control.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_api01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "lab-origin-group01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods  = ["GET","HEAD"]

    cache_policy_id          = aws_cloudfront_cache_policy.my_cache_api_disabled01.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_api01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/static/index.html"
    target_origin_id       = "lab-origin-group01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods  = ["GET","HEAD"]

    cache_policy_id            = aws_cloudfront_cache_policy.my_cache_static_entrypoint01.id
   origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_static01.id
   response_headers_policy_id = aws_cloudfront_response_headers_policy.my_rsp_static01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/static/manifest.json"
    target_origin_id       = "lab-origin-group01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods  = ["GET","HEAD"]

    cache_policy_id            = aws_cloudfront_cache_policy.my_cache_static_entrypoint01.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.my_orp_static01.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.my_rsp_static01.id
  }

  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "lab-origin-group01"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET","HEAD","OPTIONS"]
    cached_methods  = ["GET","HEAD"]

    cache_policy_id            = aws_cloudfront_cache_policy.my_cache_static01.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.my_orp_static01.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.my_rsp_static01.id
  }




  ########################################
  # WAF at the edge
  ########################################
  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.my_waf[0].arn : null

  aliases = [
    var.domain_name,
    "${var.app_subdomain}.${var.domain_name}"
  ]

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.piecourse_acm_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cf_logs.bucket_regional_domain_name
    prefix          = "Chwebacca-logs/"  # intentionally misspelled per lab
  }

}

############### Cloudfront Standard Logs ###########
resource "aws_s3_bucket" "cf_logs" {
  bucket        = "lab3-cf-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags = { Name = "lab3-cloudfront-logs" }
}

data "aws_caller_identity" "current" {}

# IMPORTANT: allow ACLs by setting Object Ownership to ObjectWriter
# (BucketOwnerEnforced disables ACLs and breaks CloudFront standard logs)
resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

# CloudFront standard log delivery uses ACL-based writes; this ACL is commonly required.
resource "aws_s3_bucket_acl" "cf_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cf_logs]
  bucket     = aws_s3_bucket.cf_logs.id
  acl        = "log-delivery-write"
}

# Keep logs private
resource "aws_s3_bucket_public_access_block" "cf_logs" {
  bucket                  = aws_s3_bucket.cf_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


######### Hosted Zone ################

# Explanation: A hosted zone is like claiming Kashyyyk in DNS—names here become law across the galaxy.
resource "aws_route53_zone" "my_zone" {
  count = var.manage_route53_in_terraform ? 1 : 0

  name = local.my_zone_name

  tags = {
    Name = "lab-zone"
  }
}

############################################
# ACM DNS Validation Records
############################################


resource "aws_route53_record" "acm_verification_record" {
  allow_overwrite = true
  for_each = {
    for dvo in aws_acm_certificate.piecourse_acm_cert.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = local.my_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60

  records = [each.value.record]
}

# ALIAS record: app.chewbacca-growl.com -> ALB
############################################

# Explanation: This is the holographic sign outside the cantina—app.chewbacca-growl.com points to your ALB.
resource "aws_route53_record" "piecourse_subdomain" {
  zone_id = data.aws_route53_zone.piecourse.id
  name    = "piecourse.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.my_cf.domain_name
    zone_id                = aws_cloudfront_distribution.my_cf.hosted_zone_id
    evaluate_target_health = false
  }
}

# Explanation: DNS now points to CloudFront — nobody should ever see the ALB again.
resource "aws_route53_record" "chewbacca_apex_to_cf01" {
  zone_id = local.my_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.my_cf.domain_name
    zone_id                = aws_cloudfront_distribution.my_cf.hosted_zone_id
    evaluate_target_health = false
  }
}

# Explanation: app.chewbacca-growl.com also points to CloudFront — same doorway, different sign.
resource "aws_route53_record" "chewbacca_app_to_cf01" {
  zone_id = local.my_zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"
allow_overwrite = true
  alias {
    name                   = aws_cloudfront_distribution.my_cf.domain_name
    zone_id                = aws_cloudfront_distribution.my_cf.hosted_zone_id
    evaluate_target_health = false
  }
}

########## WAF
resource "aws_wafv2_web_acl" "my_waf" {
 provider = aws.use1
 count = var.enable_waf ? 1 : 0

  name  = "cf-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cf-waf"
    sampled_requests_enabled   = true
  }

  
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "cf-waf-common"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Name = "cf-waf"
  }
}

########## WAF Logging ###############
resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
  resource_arn = aws_wafv2_web_acl.my_waf[0].arn

  log_destination_configs = [
    aws_cloudwatch_log_group.waf.arn
  ]
}

resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging_s3_01" {
  count = var.enable_waf && var.waf_log_destination == "s3" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.my_waf[0].arn
  log_destination_configs = [
    aws_s3_bucket.chewbacca_waf_logs_bucket01[0].arn
  ]

  depends_on = [aws_wafv2_web_acl.my_waf]
}


############## ACM ############################

resource "aws_acm_certificate" "piecourse_acm_cert" {
  provider                  = aws.use1
  domain_name               = var.domain_name
  validation_method         = "DNS"

subject_alternative_names = [
    "${var.app_subdomain}.${var.domain_name}", # app.piecourse.com
    "www.${var.domain_name}"
  ]

  tags = {
    Name = "piecourse-acm-cert"
  }
}

resource "aws_acm_certificate_validation" "piecourse_acm_validation" {
  certificate_arn = aws_acm_certificate.piecourse_acm_cert.arn
  provider        = aws.use1

  validation_record_fqdns = [
    for r in aws_route53_record.acm_verification_record : r.fqdn
  ]
}

################ Cache Behaviors ################
# Explanation: Static files are the easy win—Chewbacca caches them like hyperfuel for speed.
resource "aws_cloudfront_cache_policy" "my_cache_static01" {
  name        = "lab2-cache-static01"
  comment     = "Aggressive caching for /static/*"
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    # Explanation: Static should not vary on cookies—Chewbacca refuses to cache 10,000 versions of a PNG.
    cookies_config { cookie_behavior = "none" }

    # Explanation: Static should not vary on query strings (unless you do versioning); students can change later.
    query_strings_config { query_string_behavior = "none" }

    # Explanation: Keep headers out of cache key to maximize hit ratio.
    headers_config { header_behavior = "none" }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

############################################################
#2) Cache policy for API (safe default: caching disabled)
##############################################################



# Explanation: APIs are dangerous to cache by accident—Chewbacca disables caching until proven safe.
resource "aws_cloudfront_cache_policy" "my_cache_api_disabled01" {
  name        = "lab-cache-api-disabled01"
  comment     = "Caching disabled for API behavior"
  default_ttl = 0
  min_ttl     = 0
  max_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    # must be false when caching is disabled
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}



############################################################
#3) Origin request policy for API (forward what origin needs)
##############################################################


# Explanation: Origins need context—Chewbacca forwards what the app needs without polluting the cache key.
resource "aws_cloudfront_origin_request_policy" "my_orp_api01" {
  name    = "lab-orp-api02"
  comment = "Forward necessary values for API calls"

  cookies_config { cookie_behavior = "all" }
  query_strings_config { query_string_behavior = "all" }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Content-Type", "Origin", "Host"]
    }
  }
}


##################################################################
# 4) Origin request policy for static (minimal)
##############################################################


# Explanation: Static origins need almost nothing—Chewbacca forwards minimal values for maximum cache sanity.
resource "aws_cloudfront_origin_request_policy" "my_orp_static01" {
  name    = "lab-orp-static02"
  comment = "Minimal forwarding for static assets"

  cookies_config { cookie_behavior = "none" }
  query_strings_config { query_string_behavior = "none" }
  headers_config { header_behavior = "none" }
}

resource "aws_cloudfront_cache_policy" "my_cache_static_entrypoint01" {
  name        = "lab-static-entrypoint-short-ttl_2"
  comment     = "Short TTL for index/manifest so invalidation is small + meaningful"
  default_ttl = 300
  max_ttl     = 300
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}



##############################################################
# 5) Response headers policy (optional but nice)
##############################################################

resource "aws_cloudfront_response_headers_policy" "my_rsp_static01" {
  name    = "lab-rsp-static02"
  comment = "Add explicit Cache-Control for static content"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "public, max-age=86400, immutable"
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "my_rsp_static_entrypoint01" {
  name    = "lab-rsp-static-entrypoint02"
  comment = "Cacheable at CloudFront, not cached in browsers"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "public, max-age=0, must-revalidate"
    }
  }
  
}


############ Cloudwatch Log WAF ##################

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-chewbacca"
  retention_in_days = 7
}


resource "aws_cloudwatch_log_resource_policy" "waf" {
  policy_name = "waf-logging-policy"

  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "AWSWAFLoggingPermissions",
      Effect = "Allow",
      Principal = { Service = "delivery.logs.amazonaws.com" },
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      Resource = "${aws_cloudwatch_log_group.waf.arn}:*"
    }]
  })
}



############ WAF Logging:S3 #############
# Explanation: S3 WAF logs are the long-term archive—Chewbacca likes receipts that survive dashboards.
resource "aws_s3_bucket" "chewbacca_waf_logs_bucket01" {
  count = var.waf_log_destination == "s3" ? 1 : 0
  force_destroy = true

  bucket = "aws-waf-logs-${data.aws_caller_identity.aws_caller.account_id}"

  tags = {
    Name = "my_project-waf-logs-bucket01"
  }
}

# Explanation: Public access blocked—WAF logs are not a bedtime story for the entire internet.
resource "aws_s3_bucket_public_access_block" "chewbacca_waf_logs_pab01" {
  count = var.waf_log_destination == "s3" ? 1 : 0

  bucket                  = aws_s3_bucket.chewbacca_waf_logs_bucket01[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Connect shield generator to archive vault—WAF -> S3.


