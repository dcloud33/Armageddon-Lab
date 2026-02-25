########## Locals ########
locals {
  name_prefix = var.user_name

}

module "network" {
  source               = "../modules/network"
  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = {
    env = "tokyo"
  }
}

module "compute" {
  source = "../modules/compute"

  name_prefix        = local.name_prefix
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids

  ami_id        = var.ami_id
  instance_type = var.instance_type

  user_data     = file("${path.module}/user_data.sh")
  origin_secret = var.origin_secret

  enable_asg = false

  enable_alb_5xx_alarm       = true
  alb_5xx_threshold          = var.alb_5xx_threshold
  alb_5xx_period_seconds     = var.alb_5xx_period_seconds
  alb_5xx_evaluation_periods = var.alb_5xx_evaluation_periods

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]

  tags = { env = "tokyo" }
}


module "data" {
  source = "./modules/data"

  name_prefix         = local.name_prefix
  vpc_id              = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids

  app_sg_id           = module.compute.app_sg_id   # or wherever your EC2 SG ID is
  db_password         = var.db_password

  saopaulo_vpc_cidr = data.terraform_remote_state.saopaulo[0].outputs.sp_vpc_cidr
}



############# CLOUDWATCH LOG GROUP ##############
resource "aws_cloudwatch_log_group" "my_log_group" {
  name              = "/aws/ec2/lab-rds-app"
  retention_in_days = 7
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
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", module.compute.alb_arn_suffix]
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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", module.compute.alb_arn_suffix]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "My ALB: Target Response Time"
        }
      },
      
    ]
  })
}



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
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
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
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.accept[0].transit_gateway_attachment_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.accept]
}


resource "aws_route" "to_saopaulo_via_tgw" {
  for_each               = var.enable_saopaulo_accept ? toset(module.network.private_route_table_ids) : []
  route_table_id         = each.value
  destination_cidr_block = data.terraform_remote_state.saopaulo[0].outputs.sp_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.tgw.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.tgw_attach]
}



