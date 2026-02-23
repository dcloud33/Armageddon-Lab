############# Origin Driven Caching (Managed Policies)


# Explanation: Chewbacca uses AWS-managed policies—battle-tested configs so students learn the real names.
data "aws_cloudfront_cache_policy" "chewbacca_use_origin_cache_headers01" {
  name = "UseOriginCacheControlHeaders"
}

# Explanation: Same idea, but includes query strings in the cache key when your API truly varies by them.
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

#  AWS-managed policies via data sources


# A) Origin-driven caching (honor origin Cache-Control; default to NOT caching when Cache-Control absent)
data "aws_cloudfront_cache_policy" "use_origin_cache_control_headers" {
  name = "UseOriginCacheControlHeaders"
}

# Optional variant: includes query strings in the cache key (ONLY use if your origin truly varies by them)
data "aws_cloudfront_cache_policy" "use_origin_cache_control_headers_qs" {
  name = "UseOriginCacheControlHeaders-QueryStrings"
}

# B) Safe default for APIs: caching disabled
data "aws_cloudfront_cache_policy" "managed_caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "managed_all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}
