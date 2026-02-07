############################################
# Bonus B - Route53 (Hosted Zone + DNS records + ACM validation + ALIAS to ALB)
############################################

locals {
  # Explanation: Chewbacca needs a home planet—Route53 hosted zone is your DNS territory.
  my_zone_name = var.domain_name

  # Explanation: Use either Terraform-managed zone or a pre-existing zone ID (students choose their destiny).
  my_zone_id = var.manage_route53_in_terraform ? aws_route53_zone.my_zone[0].zone_id : var.route53_hosted_zone_id

  # Explanation: This is the app address that will growl at the galaxy (app.chewbacca-growl.com).
  my_app = "${var.app_subdomain}.${var.domain_name}"
}

############################################
# Hosted Zone (optional creation)
############################################

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

# Explanation: This ties the “proof record” back to ACM—Chewbacca gets his green checkmark for TLS.
resource "aws_acm_certificate_validation" "piecourse_acm_validation" {
  certificate_arn = aws_acm_certificate.piecourse_acm_cert.arn
  provider        = aws.use1

  validation_record_fqdns = [
    for r in aws_route53_record.acm_verification_record : r.fqdn
  ]
}



# ALIAS record: app.chewbacca-growl.com -> ALB
############################################

# Explanation: This is the holographic sign outside the cantina—app.chewbacca-growl.com points to your ALB.
resource "aws_route53_record" "piecourse_subdomain" {
  zone_id = local.my_zone_id
  name    = local.my_app
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = aws_lb.test.dns_name
    zone_id                = aws_lb.test.zone_id
    evaluate_target_health = true
  }
}