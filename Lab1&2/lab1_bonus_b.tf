################ APPLICATION LOAD BALANCER ####################

resource "aws_lb" "test" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my-alb-sg.id]
  subnets            = aws_subnet.subnet_public_1[*].id

  enable_deletion_protection = false


  

  tags = {
    Environment = "production"
  }
}


########### APPLICATION LOAD BALANCER SG

resource "aws_security_group" "my-alb-sg" {
  name        = "my-alb-sg"
  description = "application loadbalancer security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-rds-sg01"
  }
}


resource "aws_lb_listener" "alb_https_listener" {
  load_balancer_arn = aws_lb.test.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.piecourse_acm_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }

 depends_on = [
    aws_acm_certificate_validation.piecourse_acm_validation
  ]

}

resource "aws_lb_listener" "alb_http_listener" {
  load_balancer_arn = aws_lb.test.arn
  port              = 80
  protocol          = "HTTP"


default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }


#  default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }

}


############# Target Group
resource "aws_lb_target_group" "alb_target_group" {
  name     = "example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    matcher             = "200-399"
  }

  tags = {
    Name = "alb-tg"
  }
}

resource "aws_lb_target_group_attachment" "tg_attach" {
  target_group_arn = aws_lb_target_group.alb_target_group.arn
  target_id        = aws_instance.my_created_ec2.id
  port             = 80

  
}


############ ALB SG
resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.my-alb-sg.id
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443

}

resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.my-alb-sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80

}


resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.my-alb-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################# WAF ##########################

resource "aws_wafv2_web_acl" "my_waf" {
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

# resource "aws_wafv2_web_acl" "my_waf" {
#  count = var.enable_waf ? 1 : 0

#   name  = "alb-waf"
#   scope = var.waf_scope

#   default_action {
#     allow {}
#   }

#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "alb-waf"
#     sampled_requests_enabled   = true
#   }

  
#   rule {
#     name     = "AWSManagedRulesCommonRuleSet"
#     priority = 1

#     override_action {
#       none {}
#     }

#     statement {
#       managed_rule_group_statement {
#         name        = "AWSManagedRulesCommonRuleSet"
#         vendor_name = "AWS"
#       }
#     }

#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "alb-waf-common"
#       sampled_requests_enabled   = true
#     }
#   }

#   tags = {
#     Name = "alb-waf"
#   }
# }




# Explanation: Attach the shield generator to the customs checkpoint — ALB is now protected.
# resource "aws_wafv2_web_acl_association" "waf_assoc" {
#   count = var.enable_waf ? 1 : 0

#   resource_arn = aws_lb.test.arn
#   web_acl_arn  = aws_wafv2_web_acl.my_waf[0].arn
# }

resource "aws_cloudwatch_metric_alarm" "chewbacca_alb_5xx_alarm01" {
  alarm_name          = "lab-alb-5xx-alarm01"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.test.arn
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]

  tags = {
    Name = "lab-alb-5xx-alarm01"
  }
}


################# ACM

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


resource "aws_acm_certificate_validation" "piecourse_acm_cert" {
  certificate_arn = aws_acm_certificate.piecourse_acm_cert.arn
  provider                = aws.use1
  validation_record_fqdns = [for r in aws_route53_record.acm_verification_record : r.fqdn]

}


################### CLOUDWATCH DASHBOARD ########################

resource "aws_cloudwatch_dashboard" "my_cloudwatch_dashboard01" {
  dashboard_name = "lab-dashboard01"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.test.arn_suffix]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "My_unique_name ALB: Requests + 5XX"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.test.arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "My ALB: Target Response Time"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Lab/RDSApp", "DBConnectionErrors", "InstanceId", aws_instance.my_created_ec2.id]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "My App: DB Connection Errors"
        }
      }
    ]
  })
}
