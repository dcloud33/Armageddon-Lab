data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "aws_caller" {}


data "aws_cloudfront_origin_request_policy" "managed_all_viewer" {
  name = "Managed-AllViewer"
}


# Origin-driven cache policy (AWS managed)
data "aws_cloudfront_cache_policy" "use_origin_cache_control" {
  name = "UseOriginCacheControlHeaders"
}


data "aws_acm_certificate" "cloudfront_cert" {
  provider    = aws.use1
  domain      = "piecourse.com"
  statuses    = ["ISSUED"]
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
