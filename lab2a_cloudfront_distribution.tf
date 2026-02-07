# Explanation: CloudFront is the only public doorway — Chewbacca stands behind it with private infrastructure.
resource "aws_cloudfront_distribution" "my_cf" {
  enabled         = true
  is_ipv6_enabled = false
  comment         = "lab-cf01"

  origin {
    origin_id   = "lab-alb-origin01"
    domain_name = aws_lb.test.dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    # Explanation: CloudFront whispers the secret growl — the ALB only trusts this.
    custom_header {
      name  = "My_Custom_Header"
      value = random_password.my_origin_header_value01.result
    }
  }

  default_cache_behavior {
  target_origin_id       = "lab-alb-origin01"
  viewer_protocol_policy = "redirect-to-https"

  allowed_methods = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
  cached_methods  = ["GET","HEAD"]

  cache_policy_id          = aws_cloudfront_cache_policy.my_cache_api_disabled01.id
  origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_api01.id
}

# Honors: origin-driven caching for public feed
ordered_cache_behavior {
  path_pattern           = "/api/public-feed"
  target_origin_id       = "lab-alb-origin01"
  viewer_protocol_policy = "redirect-to-https"

  allowed_methods = ["GET","HEAD","OPTIONS"]
  cached_methods  = ["GET","HEAD"]

  # Key part: CloudFront honors origin Cache-Control (e.g., public, s-maxage=30)
  cache_policy_id = data.aws_cloudfront_cache_policy.use_origin_cache_control.id

  # IMPORTANT: keep this minimal to avoid cache fragmentation.
  # Use your API ORP only if it does NOT forward cookies/Authorization/User-Agent unnecessarily.
  origin_request_policy_id = aws_cloudfront_origin_request_policy.my_orp_api01.id
}


# Entrypoint: cached but short TTL to limit blast radius;
# still demonstrates Age + x-cache + invalidation clearly.
ordered_cache_behavior {
  path_pattern           = "/static/index.html"
  target_origin_id       = "lab-alb-origin01"
  viewer_protocol_policy = "redirect-to-https"

  allowed_methods = ["GET","HEAD","OPTIONS"]
  cached_methods  = ["GET","HEAD"]

  cache_policy_id            = aws_cloudfront_cache_policy.my_cache_static_entrypoint01.id
  origin_request_policy_id   = aws_cloudfront_origin_request_policy.my_orp_static01.id
  response_headers_policy_id = aws_cloudfront_response_headers_policy.my_rsp_static01.id
}

ordered_cache_behavior {
  path_pattern           = "/static/manifest.json"
  target_origin_id       = "lab-alb-origin01"
  viewer_protocol_policy = "redirect-to-https"

  allowed_methods = ["GET","HEAD","OPTIONS"]
  cached_methods  = ["GET","HEAD"]

  cache_policy_id            = aws_cloudfront_cache_policy.my_cache_static_entrypoint01.id
  origin_request_policy_id   = aws_cloudfront_origin_request_policy.my_orp_static01.id
  response_headers_policy_id = aws_cloudfront_response_headers_policy.my_rsp_static01.id
}


# Explanation: Static behavior is the speed lane—Chewbacca caches it hard for performance.
ordered_cache_behavior {
  path_pattern           = "/static/*"
  target_origin_id       = "lab-alb-origin01"
  viewer_protocol_policy = "redirect-to-https"

  allowed_methods = ["GET","HEAD","OPTIONS"]
  cached_methods  = ["GET","HEAD"]

  cache_policy_id            = aws_cloudfront_cache_policy.my_cache_static01.id
  origin_request_policy_id   = aws_cloudfront_origin_request_policy.my_orp_static01.id
  response_headers_policy_id = aws_cloudfront_response_headers_policy.my_rsp_static01.id
}


  # Explanation: Attach WAF at the edge — now WAF moved to CloudFront.
 web_acl_id = var.enable_waf ? aws_wafv2_web_acl.my_waf[0].arn : null


  # TODO: students set aliases for chewbacca-growl.com and app.chewbacca-growl.com
  aliases = [
    var.domain_name,
    "${var.app_subdomain}.${var.domain_name}"
  ]


 viewer_certificate {
  acm_certificate_arn = aws_acm_certificate.piecourse_acm_cert.arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

# Lab 2b-Be a Man B


resource "random_password" "my_origin_header_value01" {
  length  = 32
  special = true
}
