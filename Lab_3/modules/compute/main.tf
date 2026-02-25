locals {
  # ALB/TG names: only [a-z0-9-], max 32 chars
  name_safe = replace(replace(lower(var.name_prefix), "_", "-"), " ", "-")
  lb_name   = substr("${local.name_safe}-alb", 0, 32)
  tg_name   = substr("${local.name_safe}-tg", 0, 32)
}



#### Security Groups #######

####### EC2 Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "EC2 app security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-ec2-sg" })
}


resource "aws_vpc_security_group_ingress_rule" "ec2_http_from_alb" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_outbound" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

####### ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}


resource "aws_security_group_rule" "alb_https_ingress" {
  count             = var.enable_alb_https ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_vpc_security_group_egress_rule" "alb_egress" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


######### Application Load Balancer ###########

resource "aws_lb" "alb" {
  name               = var.alb_name != null ? var.alb_name : local.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, { Name = local.lb_name })
}


####### Target Group #############
resource "aws_lb_target_group" "tg" {
  name     = local.tg_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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

  tags = merge(var.tags, { Name = local.tg_name })
}

##### Listener ##############
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
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

# Only forward when request comes from CloudFront (custom header)
resource "aws_lb_listener_rule" "cloudfront_header_only" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  condition {
    http_header {
      http_header_name = "My_Custom_Header"
      values           = [var.origin_secret]
    }
  }
}

######## Launch Template ############
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.ec2_sg.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(var.user_data)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name_prefix}-app"
    }
  }
}







###### Auto Scaling Group ##########
resource "aws_autoscaling_group" "asg" {
  count = var.enable_asg ? 1 : 0

  name             = "${var.name_prefix}-asg"
  min_size         = var.asg_min_size
  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size

  vpc_zone_identifier = var.private_subnet_ids

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-asg-app"
    propagate_at_launch = true
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count = var.enable_alb_5xx_alarm ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alb_5xx_evaluation_periods
  threshold           = var.alb_5xx_threshold
  period              = var.alb_5xx_period_seconds
  statistic           = "Sum"

  namespace   = "AWS/ApplicationELB"
  metric_name = "HTTPCode_ELB_5XX_Count"

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.ok_actions

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-5xx" })
}

######## IAM Role & Instance Profile ##########
resource "aws_iam_role" "ec2_role" {
  name = "${var.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

############ INSTANCE PROFILE ###############
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "my-instance-profile02"
  role = aws_iam_role.ec2_role.name
}

########### IAM POLICY ATTACHMENT ###############################
resource "aws_iam_role_policy_attachment" "my_ec2_secrets_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}
resource "aws_iam_role_policy_attachment" "my_ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "my_ec2_cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "ec2_read_secret" {
  name = "EC2ReadSpecificSecret"
  role = aws_iam_role.ec2_role.id

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
  name = "cw-put-db-conn-metric2"
  
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
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cw_put_metric.arn
}


resource "aws_iam_role_policy" "specific_access_policy_parameters" {
  name = "EC2_to_Parameters"
  role = aws_iam_role.ec2_role.id

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
  role = aws_iam_role.ec2_role.id

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

##### Cloudwatch Log Group ############
resource "aws_cloudwatch_log_group" "my_log_group" {
  name              = "/aws/ec2/lab-rds-app"
  retention_in_days = 7
}

##### EC2 Instance
resource "aws_instance" "app" {
  count                  = var.enable_asg ? 0 : 1
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  user_data              = var.user_data

  tags = merge(var.tags, { Name = "${var.name_prefix}-app" })
}

resource "aws_lb_target_group_attachment" "instance_attach" {
  count            = var.enable_asg ? 0 : 1
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app[0].id
  port             = 80
}

