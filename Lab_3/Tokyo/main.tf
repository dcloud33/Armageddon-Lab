########## Locals ########
locals {
  name_prefix = var.user_name

}

###################### VPC ##################################
resource "aws_vpc" "vpc" {
  cidr_block           = "10.90.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "tokyo_lab-vpc"
  }
}

############ Internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "tokyo_lab-IGW"
  }
}

################# NAT
resource "aws_nat_gateway" "my_nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet_public_1[0].id

  tags = {
    Name = "tokyo_nat gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}


############ Elastic IP
resource "aws_eip" "eip" {
  domain = "vpc"

  tags = {
    Name = "elastic_ip"
  }
}

########## Subnets: Public
resource "aws_subnet" "subnet_public_1" {
count                     = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet_public_1${count.index + 1}"
  }
}


########### Subnets: Private

resource "aws_subnet" "subnet_private_1" {
count               = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_private_${count.index + 1}"
  }
}



############ Route Table: Public
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "My_public_route_table"
  }
}

resource "aws_route" "public_default_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id         = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "route_table_association" {
  count          = length(aws_subnet.subnet_public_1)
  subnet_id      = aws_subnet.subnet_public_1[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}


############## Route Table: Private
resource "aws_route_table" "my_private_route_table" {
  vpc_id = aws_vpc.vpc.id
 
  tags = {
    Name = "private-route_table"
  }
}

resource "aws_route" "private_default_route" {
  route_table_id         = aws_route_table.my_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat.id
}

resource "aws_route_table_association" "private_route_table_association" {
   count          = length(aws_subnet.subnet_private_1) 
  subnet_id      = aws_subnet.subnet_private_1[count.index].id
  route_table_id = aws_route_table.my_private_route_table.id
}

############## Security Group: EC2
resource "aws_security_group" "my-ec2-sg" {
  name        = "my-ec2-sg"
  description = "EC2 app security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-ec2-sg01"
  }
}

########################## Security Group Ingress & Egress Rules for EC2 ######################
resource "aws_vpc_security_group_ingress_rule" "http_access" {
  security_group_id = aws_security_group.my-ec2-sg.id
  referenced_security_group_id = aws_security_group.my_alb_sg.id
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}



resource "aws_vpc_security_group_egress_rule" "ec2_outbound" {
  security_group_id = aws_security_group.my-ec2-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

################### RDS Security Group: Ingress & Egress ######################

resource "aws_security_group" "my-rds-sg" {
  name        = "my-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-rds-sg01"
  }
}

resource "aws_security_group_rule" "shinjuku_rds_ingress_from_liberdade01" {
  type              = "ingress"
  security_group_id = aws_security_group.my-rds-sg.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"

  cidr_blocks = ["10.70.0.0/16"] # Sao Paulo VPC CIDR (students supply)
}

resource "aws_security_group_rule" "ec2_to_rds_access" {
  type              = "ingress"
  security_group_id = aws_security_group.my-rds-sg.id
  # cidr_blocks              = [aws_vpc.help_me.cidr_block]
  from_port                = 3306
  protocol                 = "tcp"
  to_port                  = 3306
  source_security_group_id = aws_security_group.my-ec2-sg.id
}

resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.my-rds-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

##################-RDS Subnet Group-#######################################


resource "aws_db_subnet_group" "my_rds_subnet_group" {
  name        = "my-rds-subnet-group"
  subnet_ids  = aws_subnet.subnet_private_1[*].id
  description = "this will have the RDS in the private subnet"

  tags = {
    Name = "my-rds-subnet-group"
  }
}

################### RDS Instance

resource "aws_db_instance" "my_instance_rds" {
  identifier                      = "lab-mysql"
  engine                          = "mysql"
  instance_class                  = "db.t3.micro"
  allocated_storage               = 20
  db_name                         = var.rds_db_name
  username                        = var.rds_user_name
  password                        = var.rds_password
  enabled_cloudwatch_logs_exports = ["error"]


  db_subnet_group_name   = aws_db_subnet_group.my_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.my-rds-sg.id]

  publicly_accessible = false
  skip_final_snapshot = true


  tags = {
    Name = "my-rds-instance"
  }
}

################## IAM Role & EC2 Instance #####################

resource "aws_iam_role" "my_ec2_role" {
  name = "my-ec2-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

########### IAM POLICY ATTACHMENT ###############################
resource "aws_iam_role_policy_attachment" "my_ec2_secrets_attach" {
  role       = aws_iam_role.my_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}
resource "aws_iam_role_policy_attachment" "my_ec2_ssm" {
  role       = aws_iam_role.my_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "my_ec2_cloudwatch_agent" {
  role       = aws_iam_role.my_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_read_secret" {
  name = "EC2ReadSpecificSecret"
  role = aws_iam_role.my_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_ID}:secret:lab3/rds/mysql*"
    }]

    
  })
}

resource "aws_iam_policy" "cw_put_metric" {
  name = "cw-put-db-conn-metric"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Lab3/RDSApp"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "cw_put_metric_attach" {
  role       = aws_iam_role.my_ec2_role.name
  policy_arn = aws_iam_policy.cw_put_metric.arn
}


resource "aws_iam_role_policy" "specific_access_policy_parameters" {
  name = "EC2_to_Parameters"
  role = aws_iam_role.my_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DescribeParameters"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.account_ID}:parameter/lab/db/*"
        ]


      },
    ]
  })
}

resource "aws_iam_role_policy" "specific_access_cloudwatch_agent" {
  name = "EC2_to_Cloudwatch_agent"
  role = aws_iam_role.my_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- CloudWatch Logs permissions (scoped to your log group) ---
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.my_log_group.arn}:*"
        ]
      },

      # Create/Describe log groups are account-wide APIs; scoping is limited
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      },

      # --- CloudWatch Metrics permissions (PutMetricData) ---
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Lab3/RDSApp"
          }
        }
      }
    ]
  })
}


############## PARAMETER STORE ###############
resource "aws_ssm_parameter" "rds_db_endpoint_parameter" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_db_instance.my_instance_rds.address

  tags = {
    Name = "${local.name_prefix}-param-db-endpoint"
  }
}


resource "aws_ssm_parameter" "rds_db_port_parameter" {
  name  = "/lab/db/port"
  type  = "String"
  value = tostring(aws_db_instance.my_instance_rds.port)

  tags = {
    Name = "${local.name_prefix}-param-db-port"
  }
}


resource "aws_ssm_parameter" "rds_db_name_parameter" {
  name  = "/lab/db/name"
  type  = "String"
  value = var.rds_db_name

  tags = {
    Name = "${local.name_prefix}-param-db-name"
  }
}

############# CLOUDWATCH LOG GROUP ##############
resource "aws_cloudwatch_log_group" "my_log_group" {
  name              = "/aws/ec2/lab-rds-app"
  retention_in_days = 7

}

############ INSTANCE PROFILE ###############
resource "aws_iam_instance_profile" "cloudwatch_agent_profile" {
  name = "my-instance-profile01"
  role = aws_iam_role.my_ec2_role.name
}

############ EC2 INSTANCE: APP HOST ##################################

resource "aws_instance" "my_created_ec2" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [aws_security_group.my-ec2-sg.id]
  iam_instance_profile   = aws_iam_instance_profile.cloudwatch_agent_profile.name
  subnet_id = aws_subnet.subnet_private_1[0].id
  associate_public_ip_address = true


 user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "${local.name_prefix}-ec201"
  }
  depends_on = [aws_cloudwatch_log_group.my_log_group]
}


################ SNS TOPIC #########################
resource "aws_sns_topic" "my_sns_topic" {
  name = "${local.name_prefix}-db-incidents"
}

############## EMAIL SUBSCRIPTION ##############################
resource "aws_sns_topic_subscription" "my_sns_sub01" {
  topic_arn = aws_sns_topic.my_sns_topic.arn
  protocol  = "email"
  endpoint  = var.sns_sub_email_endpoint
}

############# METRIC ALARM ################################
resource "aws_cloudwatch_metric_alarm" "my_db_alarm" {
  alarm_name          = "${local.name_prefix}-db-connection-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DBConnectionErrors"
  namespace           = "Lab3/RDSApp"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId  = "unknown"
    Service     = "rdsapp"
    Environment = "lab"
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]

  tags = {
    Name = "${local.name_prefix}-alarm-db-fail"
  }
}


############ SECRETS MANAGER FOR DB CREDENTIALS #####################


resource "aws_secretsmanager_secret" "my_db_secret" {
  name                    = "lab3/rds/mysql"
  recovery_window_in_days = 0

replica {
    region = "sa-east-1"
  }

}

resource "aws_secretsmanager_secret_version" "my_db_secret_version" {
  secret_id = aws_secretsmanager_secret.my_db_secret.id

  secret_string = jsonencode({
    username = var.rds_user_name
    password = var.rds_password
    engine   = "mysql"
    host     = aws_db_instance.my_instance_rds.address
    port     = aws_db_instance.my_instance_rds.port
    dbname   = var.rds_db_name
  })

  depends_on = [aws_db_instance.my_instance_rds]
}

################ APPLICATION LOAD BALANCER ####################

resource "aws_lb" "tokyo_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_alb_sg.id]
  subnets            = aws_subnet.subnet_public_1[*].id

  enable_deletion_protection = false


  

  tags = {
    Environment = "production"
  }
}


########### APPLICATION LOAD BALANCER SG

resource "aws_security_group" "my_alb_sg" {
  name        = "my-alb-sg"
  description = "application loadbalancer security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-rds-sg01"
  }
}

resource "aws_lb_listener" "alb_http_listener" {
  load_balancer_arn = aws_lb.tokyo_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "http_only_cloudfront" {
  listener_arn = aws_lb_listener.alb_http_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }

  condition {
    http_header {
      http_header_name = "My_Custom_Header"
      values           = [var.origin_secret]
    }
  }
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
  security_group_id = aws_security_group.my_alb_sg.id
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443

}

resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.my_alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  protocol          = "tcp"
  to_port           = 80

}


resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.my_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}



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
    LoadBalancer = aws_lb.tokyo_lb.arn
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]

  tags = {
    Name = "lab-alb-5xx-alarm01"
  }
}


################# ACM

# resource "aws_acm_certificate" "piecourse_acm_cert" {
#   provider                  = aws.use1
#   domain_name               = var.domain_name
#   validation_method         = "DNS"

# subject_alternative_names = [
#     "${var.app_subdomain}.${var.domain_name}", # app.piecourse.com
#     "www.${var.domain_name}"
#   ]

#   tags = {
#     Name = "piecourse-acm-cert"
#   }
# }


# resource "aws_acm_certificate_validation" "piecourse_acm_cert" {
#   certificate_arn = aws_acm_certificate.piecourse_acm_cert.arn
#   provider                = aws.use1
#   validation_record_fqdns = [for r in aws_route53_record.acm_verification_record : r.fqdn]

# }


# resource "aws_acm_certificate" "alb_cert_tokyo" {
#   domain_name       = "piecourse.com"
#   validation_method = "DNS"
#   # optionally:
#   # subject_alternative_names = ["www.piecourse.com"]
# }

# resource "aws_route53_record" "alb_cert_validation" {
#   allow_overwrite = true
#   for_each = {
#     for dvo in aws_acm_certificate.alb_cert_tokyo.domain_validation_options :
#     dvo.domain_name => {
#       name  = dvo.resource_record_name
#       type  = dvo.resource_record_type
#       value = dvo.resource_record_value
#     }
#   }

#   zone_id = local.my_zone_id
#   name    = each.value.name
#   type    = each.value.type
#   records = [each.value.value]
#   ttl     = 60
# }

# resource "aws_acm_certificate_validation" "alb_cert_tokyo" {
#   certificate_arn         = aws_acm_certificate.alb_cert_tokyo.arn
#   validation_record_fqdns = [for r in aws_route53_record.alb_cert_validation : r.fqdn]
# }



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
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.tokyo_lb.arn_suffix]
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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.tokyo_lb.arn_suffix]
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
            ["Lab3/RDSApp", "DBConnectionErrors", "InstanceId", aws_instance.my_created_ec2.id]
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


# Bonus B - Route53 (Hosted Zone + DNS records + ACM validation + ALIAS to ALB)

# locals {
#   # Explanation: Chewbacca needs a home planet—Route53 hosted zone is your DNS territory.
#   my_zone_name = var.domain_name

#   # Explanation: Use either Terraform-managed zone or a pre-existing zone ID (students choose their destiny).
#   my_zone_id = var.manage_route53_in_terraform ? aws_route53_zone.my_zone[0].zone_id : var.route53_hosted_zone_id

#   # Explanation: This is the app address that will growl at the galaxy (app.chewbacca-growl.com).
#   my_app = "${var.app_subdomain}.${var.domain_name}"
# }

# ############################################
# # Hosted Zone (optional creation)
# ############################################

# # Explanation: A hosted zone is like claiming Kashyyyk in DNS—names here become law across the galaxy.
# resource "aws_route53_zone" "my_zone" {
#   count = var.manage_route53_in_terraform ? 1 : 0

#   name = local.my_zone_name

#   tags = {
#     Name = "lab-zone"
#   }
# }

# ############################################
# # ACM DNS Validation Records
# ############################################


# resource "aws_route53_record" "acm_verification_record" {
#   allow_overwrite = true
#   for_each = {
#     for dvo in aws_acm_certificate.piecourse_acm_cert.domain_validation_options :
#     dvo.domain_name => {
#       name   = dvo.resource_record_name
#       type   = dvo.resource_record_type
#       record = dvo.resource_record_value
#     }
#   }

#   zone_id = local.my_zone_id
#   name    = each.value.name
#   type    = each.value.type
#   ttl     = 60

#   records = [each.value.record]
# }

# # Explanation: This ties the “proof record” back to ACM—Chewbacca gets his green checkmark for TLS.
# resource "aws_acm_certificate_validation" "piecourse_acm_validation" {
#   certificate_arn = aws_acm_certificate.piecourse_acm_cert.arn
#   provider        = aws.use1

#   validation_record_fqdns = [
#     for r in aws_route53_record.acm_verification_record : r.fqdn
#   ]
# }



# # ALIAS record: app.chewbacca-growl.com -> ALB
# ############################################

# # Explanation: This is the holographic sign outside the cantina—app.chewbacca-growl.com points to your ALB.
# resource "aws_route53_record" "piecourse_subdomain" {
#   zone_id = local.my_zone_id
#   name    = local.my_app
#   type    = "A"

#   allow_overwrite = true

#   alias {
#     name                   = aws_lb.test.dns_name
#     zone_id                = aws_lb.test.zone_id
#     evaluate_target_health = true
#   }
# }

# S3 bucket for ALB access logs
############################################

# Explanation: This bucket is Chewbacca’s log vault—every visitor to the ALB leaves footprints here.
resource "aws_s3_bucket" "piecourse_alb_logs_bucket" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = "lab-alb-logs-${data.aws_caller_identity.aws_caller.account_id}"

  force_destroy = true

  tags = {
    Name = "lab-alb-logs-bucket1.2"
  }
}

# Explanation: Block public access—Chewbacca does not publish the ship’s black box to the galaxy.
resource "aws_s3_bucket_public_access_block" "my_alb_logs_pub" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.piecourse_alb_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Bucket ownership controls prevent log delivery chaos—Chewbacca likes clean chain-of-custody.
resource "aws_s3_bucket_ownership_controls" "my_alb_logs_owner" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.piecourse_alb_logs_bucket[0].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Explanation: TLS-only—Chewbacca growls at plaintext and throws it out an airlock.
resource "aws_s3_bucket_policy" "chewbacca_alb_logs_policy01" {
  count = var.enable_alb_access_logs ? 1 : 0

  bucket = aws_s3_bucket.piecourse_alb_logs_bucket[0].id

  # NOTE: This is a skeleton. Students may need to adjust for region/account specifics.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.piecourse_alb_logs_bucket[0].arn,
          "${aws_s3_bucket.piecourse_alb_logs_bucket[0].arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid    = "AllowELBPutObject"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.piecourse_alb_logs_bucket[0].arn}/${var.alb_access_logs_prefix}/AWSLogs/${data.aws_caller_identity.aws_caller.account_id}/*"
      }
    ]
  })
}

############ Transit Gateway

resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Tokyo-tgw"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  tags = { Name = "${local.name_prefix}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attach" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = aws_vpc.vpc.id
  subnet_ids         = aws_subnet.subnet_private_1[*].id
  tags               = { Name = "Tokyo-tgw-attach" }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "accept" {
  count = var.enable_saopaulo_accept ? 1 : 0
  transit_gateway_attachment_id = data.terraform_remote_state.saopaulo[0].outputs.tgw_peering_attachment_id

  tags = { Name = "${local.name_prefix}-tgw-peer-accept" }
}

resource "aws_ec2_transit_gateway_route" "tokyo_to_saopaulo_via_peering" {
  count = var.enable_saopaulo_accept ? 1 : 0

  destination_cidr_block         = data.terraform_remote_state.saopaulo[0].outputs.sp_vpc_cidr
  transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.accept[0].id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.accept]
}


resource "aws_route" "to_saopaulo_via_tgw" {
  count                  = var.enable_saopaulo_accept ? 1 : 0
  route_table_id         = aws_route_table.my_private_route_table.id
  destination_cidr_block = data.terraform_remote_state.saopaulo[0].outputs.sp_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tgw_attach]
}




# # Ensure Tokyo VPC attachment is associated with the default TGW route table
# resource "aws_ec2_transit_gateway_route_table_association" "tokyo_vpc_assoc" {
#   transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw_attach.id
#   transit_gateway_route_table_id = aws_ec2_transit_gateway.tgw.association_default_route_table_id
# }

