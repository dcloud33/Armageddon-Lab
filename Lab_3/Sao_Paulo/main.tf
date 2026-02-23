########## Locals ########
locals {
  name_prefix = var.user_name

}

###################### VPC ##################################
resource "aws_vpc" "vpc" {
  cidr_block           = "10.70.0.0/16"
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

# # Send Tokyo VPC traffic to the São Paulo Transit Gateway(added)
resource "aws_route" "private_to_tokyo_via_tgw" {
  route_table_id         = aws_route_table.my_private_route_table.id
  destination_cidr_block = "10.90.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.liberdade_tgw01.id
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


################## IAM Role & EC2 Instance #####################

resource "aws_iam_role" "my_ec2_role" {
  name = "sao_paulo-my-ec2-role01"

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



############# CLOUDWATCH LOG GROUP ##############
resource "aws_cloudwatch_log_group" "my_log_group" {
  name              = "/aws/ec2/lab-rds-app"
  retention_in_days = 7

}

############ INSTANCE PROFILE ###############
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "my-instance-profile02"
  role = aws_iam_role.my_ec2_role.name
}


##################### Launch Template ##############

resource "aws_launch_template" "app_lt" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = var.ami_id              
  instance_type = var.instance_type       


  vpc_security_group_ids = [
    aws_security_group.my-ec2-sg.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
dnf update -y
dnf install -y python3-pip amazon-cloudwatch-agent
pip3 install flask pymysql boto3

# --- CloudWatch Agent: logs ---
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWC'
{
  "logs": {
    "force_flush_interval": 15,
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log",
            "log_group_name": "/aws/ec2/lab-rds-app",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/my-app.log",
            "log_group_name": "MyLogGroup/AppLogs",
            "log_stream_name": "app-{instance_id}",
            "timezone": "LOCAL"
          }
        ]
      }
    }
  }
}
CWC

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

systemctl enable amazon-cloudwatch-agent
systemctl restart amazon-cloudwatch-agent

# --- App code ---
mkdir -p /opt/rdsapp
mkdir -p /opt/rdsapp/static
echo "hello static" > /opt/rdsapp/static/example.txt



cat >/opt/rdsapp/app.py <<'PY'
import os, json, logging, urllib.request
from logging.handlers import RotatingFileHandler

import boto3
import pymysql
from flask import Flask, request, send_from_directory
import urllib.request
import urllib.error

REGION = os.getenv("AWS_REGION", "ap-northeast-1")
SECRET_ID = os.environ.get("SECRET_ID", "lab3/rds/mysql")

secrets = boto3.client("secretsmanager", region_name=REGION)
cloudwatch = boto3.client("cloudwatch", region_name=REGION)

def get_instance_id():
    base = "http://169.254.169.254/latest"
    try:
        # Get IMDSv2 token
        token_req = urllib.request.Request(
            f"{base}/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "21600"},
        )
        token = urllib.request.urlopen(token_req, timeout=2).read().decode()

        # Use token to fetch instance-id
        id_req = urllib.request.Request(
            f"{base}/meta-data/instance-id",
            headers={"X-aws-ec2-metadata-token": token},
        )
        return urllib.request.urlopen(id_req, timeout=2).read().decode()

    except Exception:
        return "unknown"

def get_db_creds():
    resp = secrets.get_secret_value(SecretId=SECRET_ID)
    return json.loads(resp["SecretString"])

handler = RotatingFileHandler("/var/log/my-app.log", maxBytes=10_000_000, backupCount=3)
logging.basicConfig(level=logging.INFO, handlers=[handler])

def emit_db_conn_error_metric():
    cloudwatch.put_metric_data(
        Namespace="Lab3/RDSApp",
        MetricData=[{
            "MetricName": "DBConnectionErrors",
            "Value": 1,
            "Unit": "Count",
            "Dimensions": [
                {"Name": "InstanceId", "Value": get_instance_id()},
                {"Name": "Service", "Value": "rdsapp"},
                {"Name": "Environment", "Value": "lab"}
            ]
        }]
    )

def get_conn():
    c = get_db_creds()
    try:
        return pymysql.connect(
            host=c["host"],
            user=c["username"],
            password=c["password"],
            port=int(c.get("port", 3306)),
            database=c.get("dbname", "labdb"),
            autocommit=True,
            connect_timeout=3,
        )
    except Exception as e:
        logging.exception("DB connection failed: %s", e)
        emit_db_conn_error_metric()
        raise

app = Flask(__name__)

@app.route("/")
def home():
    return """
    <h2>EC2 → RDS Notes App</h2>
    <p>GET /init</p>
    <p>GET or POST /add?note=hello</p>
    <p>GET /list</p>
    """

@app.route("/init")
def init_db():
    c = get_db_creds()
    dbname = c.get("dbname", "labdb")

    conn = pymysql.connect(
        host=c["host"], user=c["username"], password=c["password"],
        port=int(c.get("port", 3306)), autocommit=True
    )
    cur = conn.cursor()
    cur.execute(f"CREATE DATABASE IF NOT EXISTS `{dbname}`;")
    cur.execute(f"USE `{dbname}`;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS notes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            note VARCHAR(255) NOT NULL
        );
    """)
    cur.close()
    conn.close()
    return f"Initialized {dbname} + notes table."


@app.route("/add", methods=["POST", "GET"])
def add_note():
    note = request.args.get("note", "").strip()
    if not note:
        return "Missing note param. Try: /add?note=hello", 400
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO notes(note) VALUES(%s);", (note,))
    cur.close()
    conn.close()
    return f"Inserted note: {note}\n"

@app.route("/list")
def list_notes():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    out = "<h3>Notes</h3><ul>"
    for r in rows:
        out += f"<li>{r[0]}: {r[1]}</li>"
    out += "</ul>"
    return out

@app.route("/api/list")
def api_list():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return list_notes()   # or call the same function your /list uses

@app.route("/api/public-feed")
def public_feed():
    return list_notes()

@app.route("/static/<path:filename>")
def static_files(filename):
    return send_from_directory("/opt/rdsapp/static", filename)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

# --- systemd service ---
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=EC2 to RDS Notes App
After=network.target

[Service]
WorkingDirectory=/opt/rdsapp
Environment=SECRET_ID=lab3/rds/mysql
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable rdsapp
systemctl restart rdsapp
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-app"
    }
  }
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


data "aws_secretsmanager_secret" "my_db_secret" {
  name                    = "lab3/rds/mysql"
  
}

data "aws_secretsmanager_secret_version" "my_db_secret_version" {
  secret_id = data.aws_secretsmanager_secret.my_db_secret.id

}

locals {
  db = jsondecode(data.aws_secretsmanager_secret_version.my_db_secret_version.secret_string)
}

################ APPLICATION LOAD BALANCER ####################


resource "aws_lb" "sao_paulo_lb" {
  name               = "app-lb-sp-02"

  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_alb_sg.id]
  subnets            = aws_subnet.subnet_public_1[*].id

  enable_deletion_protection = false


  tags = {
    Environment = "production"
  }
}




resource "aws_lb_listener" "alb_http_listener" {
  load_balancer_arn = aws_lb.sao_paulo_lb.arn
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
  name     = "example-lb-tg2"
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


################## Auto Scaling Group ###############

resource "aws_autoscaling_group" "app_asg" {
  name             = "${local.name_prefix}-asg"
  min_size         = 1
  desired_capacity = 1
  max_size         = 3

  vpc_zone_identifier = aws_subnet.subnet_private_1[*].id
    
  

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.alb_target_group.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-app"
    propagate_at_launch = true
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

########## Cloudwatch 5XX Alarm ########################
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
    LoadBalancer = aws_lb.sao_paulo_lb.arn
  }

  alarm_actions = [aws_sns_topic.my_sns_topic.arn]

  tags = {
    Name = "lab-alb-5xx-alarm01"
  }
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
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.sao_paulo_lb.arn_suffix]
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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.sao_paulo_lb.arn_suffix]
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
  vpc_id             = aws_vpc.vpc.id
  subnet_ids         = aws_subnet.subnet_private_1[*].id
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






