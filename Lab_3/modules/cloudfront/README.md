# CloudFront Module

This Terraform module configures a global CloudFront distribution backed by two regional Application Load Balancers (São Paulo and Tokyo). It includes optional WAF protection, DNS records, ACM certificate management, logging buckets, and related supporting resources. Designed for the Lab-3 project, the distribution routes traffic to a primary origin in São Paulo with automatic failover to Tokyo.

## Features

- CloudFront distribution with multiple origins and origin group failover
- Custom cache/behavior policies for static assets, APIs, and entrypoints
- Optional AWS WAFv2 web ACL with logging to CloudWatch or S3
- ACM certificate provisioning and DNS validation records (Route53)
- Route53 records for apex/domain and subdomain pointing to CloudFront
- Standard access log bucket with ownership controls

## Variables

| Name                          | Type   | Default                   | Description                                           |
| ----------------------------- | ------ | ------------------------- | ----------------------------------------------------- |
| `domain_name`                 | string | `"piecourse.com"`         | Base DNS name for the application                     |
| `app_subdomain`               | string | `"app"`                   | Subdomain used for the app (app.example.com)          |
| `enable_waf`                  | bool   | `true`                    | Whether to create/apply a WAF web ACL                 |
| `origin_secret`               | string | (long hex string)         | Secret header value required by origins               |
| `manage_route53_in_terraform` | bool   | `false`                   | Create/manage hosted zone and records in this module  |
| `route53_hosted_zone_id`      | string | `"Z01500111XNTGSU8AH1Y0"` | Pre‑existing zone ID when not managing zone           |
| `enable_alb_access_logs`      | bool   | `true`                    | Enable ALB access logging to S3                       |
| `alb_access_logs_prefix`      | string | `"lab-alb-logs"`          | Prefix for ALB access logs bucket                     |
| `waf_log_destination`         | string | `"s3"`                    | Choose `cloudwatch`, `s3`, or `firehose` for WAF logs |
| `sp_alb_dns_name`             | string |                           | DNS name of the São Paulo ALB (required)              |
| `tokyo_alb_dns_name`          | string |                           | DNS name of the Tokyo ALB (required)                  |

## Outputs

This module currently does not define any outputs.

## Resources Created

Below is a high‑level list of major resources managed by the module:

- `aws_cloudfront_distribution.my_cf`
- `aws_s3_bucket.cf_logs` and related ownership/ACL/policy resources
- `aws_route53_zone.my_zone` (conditionally)
- `aws_route53_record.*` for ACM validation and application DNS
- `aws_wafv2_web_acl.my_waf` and logging configurations
- `aws_acm_certificate.piecourse_acm_cert` and validation
- Several `aws_cloudfront_cache_policy`, `origin_request_policy`, `response_headers_policy`

## Getting Started

```tf
module "cf" {
  source               = "../modules/cloudfront"
  domain_name          = "example.com"
  app_subdomain        = "app"
  sp_alb_dns_name      = module.compute.alb_dns_name
  tokyo_alb_dns_name   = "tokyo-alb-123456.us-east-1.elb.amazonaws.com"

  # enable_waf, origin_secret, etc. can be overridden as needed
  manage_route53_in_terraform = true
  route53_hosted_zone_id      = null
}
```
