
############################################
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

