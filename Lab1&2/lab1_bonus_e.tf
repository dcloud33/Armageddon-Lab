# ############################################
# # Bonus B - WAF Logging (CloudWatch Logs OR S3 OR Firehose)
# # One destination per Web ACL, choose via var.waf_log_destination.
# ############################################

# ############################################
# # Option 1: CloudWatch Logs destination
# ############################################

# # Explanation: WAF logs in CloudWatch are your “blaster-cam footage”—fast search, fast triage, fast truth.
# resource "aws_cloudwatch_log_group" "chewbacca_waf_log_group01" {
#   count = var.waf_log_destination == "cloudwatch" ? 1 : 0

#   # NOTE: AWS requires WAF log destination names start with aws-waf-logs- (students must not rename this).
#   name              = "aws-waf-logs-lab-webacl01"
#   retention_in_days = var.waf_log_retention_days

#   tags = {
#     Name = "lab}-waf-log-group01"
#   }
# }

# # Explanation: This wire connects the shield generator to the black box—WAF -> CloudWatch Logs.
# resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging01" {
#   count = var.enable_waf && var.waf_log_destination == "cloudwatch" ? 1 : 0

#   resource_arn = aws_wafv2_web_acl.chewbacca_waf01[0].arn
#   log_destination_configs = [
#     aws_cloudwatch_log_group.chewbacca_waf_log_group01[0].arn
#   ]

#   # TODO: Students can add redacted_fields (authorization headers, cookies, etc.) as a stretch goal.
#   # redacted_fields { ... }

#   depends_on = [aws_wafv2_web_acl.chewbacca_waf01]
# }

############################################
# Option 2: S3 destination (direct)
############################################

# Explanation: S3 WAF logs are the long-term archive—Chewbacca likes receipts that survive dashboards.
resource "aws_s3_bucket" "my_waf_logs_bucket" {
  count = var.waf_log_destination == "s3" ? 1 : 0

  bucket = "aws-waf-logs-lab002-${data.aws_caller_identity.aws_caller.account_id}"

  force_destroy = true

  tags = {
    Name = "lab-alb-logs-bucket1.3"
  }
}

# Explanation: Public access blocked—WAF logs are not a bedtime story for the entire internet.
resource "aws_s3_bucket_public_access_block" "my_waf_logs_pab" {
  count = var.waf_log_destination == "s3" ? 1 : 0

  bucket                  = aws_s3_bucket.my_waf_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Explanation: Connect shield generator to archive vault—WAF -> S3.
resource "aws_wafv2_web_acl_logging_configuration" "my_waf_logging_s3" {
  count = var.enable_waf && var.waf_log_destination == "s3" ? 1 : 0

  resource_arn = aws_wafv2_web_acl.my_waf[0].arn
  log_destination_configs = [
    aws_s3_bucket.my_waf_logs_bucket[0].arn
  ]

  depends_on = [aws_wafv2_web_acl.my_waf]
}

############################################
# Option 3: Firehose destination (classic “stream then store”)
############################################

# Explanation: Firehose is the conveyor belt—WAF logs ride it to storage (and can fork to SIEM later).
# resource "aws_s3_bucket" "chewbacca_firehose_waf_dest_bucket01" {
#   count = var.waf_log_destination == "firehose" ? 1 : 0

#   bucket = "lab-waf-firehose-dest-${data.aws_caller_identity.chewbacca_self01.account_id}"

#   tags = {
#     Name = "lab-waf-firehose-dest-bucket01"
#   }
# }

# # Explanation: Firehose needs a role—Chewbacca doesn’t let random droids write into storage.
# resource "aws_iam_role" "chewbacca_firehose_role01" {
#   count = var.waf_log_destination == "firehose" ? 1 : 0
#   name  = "lab-firehose-role01"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = { Service = "firehose.amazonaws.com" }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# # Explanation: Minimal permissions—allow Firehose to put objects into the destination bucket.
# resource "aws_iam_role_policy" "chewbacca_firehose_policy01" {
#   count = var.waf_log_destination == "firehose" ? 1 : 0
#   name  = "lab-firehose-policy01"
#   role  = aws_iam_role.chewbacca_firehose_role01[0].id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:AbortMultipartUpload",
#           "s3:GetBucketLocation",
#           "s3:GetObject",
#           "s3:ListBucket",
#           "s3:ListBucketMultipartUploads",
#           "s3:PutObject"
#         ]
#         Resource = [
#           aws_s3_bucket.chewbacca_firehose_waf_dest_bucket01[0].arn,
#           "${aws_s3_bucket.chewbacca_firehose_waf_dest_bucket01[0].arn}/*"
#         ]
#       }
#     ]
#   })
# }

# # Explanation: The delivery stream is the belt itself—logs move from WAF -> Firehose -> S3.
# resource "aws_kinesis_firehose_delivery_stream" "chewbacca_waf_firehose01" {
#   count       = var.waf_log_destination == "firehose" ? 1 : 0
#   name        = "aws-waf-logs-lab-firehose01"
#   destination = "extended_s3"

#   extended_s3_configuration {
#     role_arn   = aws_iam_role.chewbacca_firehose_role01[0].arn
#     bucket_arn = aws_s3_bucket.chewbacca_firehose_waf_dest_bucket01[0].arn
#     prefix     = "waf-logs/"
#   }
# }

# # Explanation: Connect shield generator to conveyor belt—WAF -> Firehose stream.
# resource "aws_wafv2_web_acl_logging_configuration" "chewbacca_waf_logging_firehose01" {
#   count = var.enable_waf && var.waf_log_destination == "firehose" ? 1 : 0

#   resource_arn = aws_wafv2_web_acl.chewbacca_waf01[0].arn
#   log_destination_configs = [
#     aws_kinesis_firehose_delivery_stream.chewbacca_waf_firehose01[0].arn
#   ]

#   depends_on = [aws_wafv2_web_acl.chewbacca_waf01]
# }