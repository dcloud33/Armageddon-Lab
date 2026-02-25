########## Locals ########
locals {
  name_prefix = var.user_name
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.my_db_secret_current.secret_string)

}

module "network" {
  source               = "../modules/network"
  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = {
    env = "sao_paulo"
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

  user_data      = file("${path.module}/user_data.sh")
  origin_secret  = var.origin_secret

  enable_asg = true

  enable_alb_5xx_alarm        = true
  alb_5xx_threshold           = var.alb_5xx_threshold
  alb_5xx_period_seconds      = var.alb_5xx_period_seconds
  alb_5xx_evaluation_periods  = var.alb_5xx_evaluation_periods

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]
  ok_actions    = [aws_sns_topic.my_sns_topic.arn]

  secret_arn = data.aws_secretsmanager_secret.my_db_secret.arn

  tags = { env = "saopaulo" }
}


# # Send Tokyo VPC traffic to the São Paulo Transit Gateway(added)
resource "aws_route" "sp_to_tokyo_via_tgw" {
  route_table_id         = module.network.private_route_table_id
  destination_cidr_block = "10.90.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.liberdade_tgw01.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.liberdade_attach_sp_vpc01]
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


############ SECRETS MANAGER FOR DB CREDENTIALS #####################
data "aws_secretsmanager_secret" "my_db_secret" {
  name                    = "lab3/rds/mysql"
}

data "aws_secretsmanager_secret_version" "my_db_secret_version" {
  secret_id = data.aws_secretsmanager_secret.my_db_secret.id
}

locals {
  db = jsondecode(data.aws_secretsmanager_secret_version.my_db_secret_version.secret_string)
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

  bucket = "sao-paulo-lab-alb-logs2-${data.aws_caller_identity.aws_caller.account_id}"

  force_destroy = true

  tags = {
    Name = "lab-alb-logs-bucket1.4"
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


###################### Transit Gateway #####################

resource "aws_ec2_transit_gateway" "liberdade_tgw01" {
  description = "liberdade-tgw01 (Sao Paulo spoke)"
  tags = { Name = "liberdade-tgw01" }
}


# Explanation: Liberdade attaches to its VPC—compute can now reach Tokyo legally, through the controlled corridor.
resource "aws_ec2_transit_gateway_vpc_attachment" "liberdade_attach_sp_vpc01" {
  transit_gateway_id = aws_ec2_transit_gateway.liberdade_tgw01.id
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnet_ids
  tags = { Name = "liberdade-attach-sp-vpc01" }
}

resource "aws_ec2_transit_gateway_peering_attachment" "to_tokyo" {
  transit_gateway_id      = aws_ec2_transit_gateway.liberdade_tgw01.id
  peer_transit_gateway_id = data.terraform_remote_state.tokyo.outputs.tokyo_tgw_id
  peer_region             = "ap-northeast-1"
  tags = { Name = "Sao-Paulo-tgw-peer-to-tokyo" }
}

# Route Tokyo CIDR across the TGW peering attachment
resource "aws_ec2_transit_gateway_route" "sp_tgw_to_tokyo" {
  destination_cidr_block         = "10.90.0.0/16"
  transit_gateway_route_table_id = aws_ec2_transit_gateway.liberdade_tgw01.association_default_route_table_id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.to_tokyo.id
}
