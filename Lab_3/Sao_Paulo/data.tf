data "terraform_remote_state" "tokyo" {
  backend = "s3"
  config = {
    bucket = "lab3-tfstate-lab3-02-09-2026"
    key    = "tokyo/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "aws_caller" {}


data "aws_cloudfront_origin_request_policy" "managed_all_viewer" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_cache_policy" "chewbacca_use_origin_cache_headers_qs01" {
  name = "UseOriginCacheControlHeaders-QueryStrings"
}

# Explanation: Origin request policies let us forward needed stuff without polluting the cache key.
# (Origin request policies are separate from cache policies.) :contentReference[oaicite:6]{index=6}
data "aws_cloudfront_origin_request_policy" "chewbacca_orp_all_viewer01" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_origin_request_policy" "chewbacca_orp_all_viewer_except_host01" {
  name = "Managed-AllViewerExceptHostHeader"
}



# Origin-driven cache policy (AWS managed)
data "aws_cloudfront_cache_policy" "use_origin_cache_control" {
  name = "UseOriginCacheControlHeaders"
}
