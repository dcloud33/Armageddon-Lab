# Compute Module

This module builds the compute tier for the Lab‑3 architecture. It provisions:

- A pair of security groups (ALB and EC2) with appropriate ingress/egress rules
- An internet-facing Application Load Balancer with listener and CloudFront header rule
- A target group and optional auto‑scaling group backed by a launch template
- Optional TLS support, 5xx alarms, and secrets management hooks

It is designed to be consumed by the CloudFront module (which requires the ALB DNS name) and the Data module (to allow EC2->RDS access).

## Variables

| Name                         | Type         | Default          | Description                                        |
| ---------------------------- | ------------ | ---------------- | -------------------------------------------------- |
| `aws_region`                 | string       | `"sa-east-1"`    | AWS region for resources                           |
| `account_ID`                 | string       | `"724772093504"` | AWS account ID                                     |
| `name_prefix`                | string       |                  | Prefix used for naming resources (required)        |
| `vpc_id`                     | string       |                  | ID of the VPC to deploy into (required)            |
| `vpc_cidr`                   | string       | `null`           | Needed only if `enable_alb_https = true`           |
| `public_subnet_ids`          | list(string) |                  | List of public subnet IDs (required)               |
| `private_subnet_ids`         | list(string) |                  | List of private subnet IDs (required)              |
| `ami_id`                     | string       |                  | AMI for the EC2 instances                          |
| `instance_type`              | string       |                  | EC2 instance type                                  |
| `user_data`                  | string       |                  | Plain text user data; module base64‑encodes it     |
| `origin_secret`              | string       |                  | Secret header value expected by CloudFront         |
| `enable_asg`                 | bool         | `true`           | Create an Auto Scaling Group                       |
| `asg_min_size`               | number       | `1`              | ASG minimum size                                   |
| `asg_desired_capacity`       | number       | `1`              | ASG desired capacity                               |
| `asg_max_size`               | number       | `3`              | ASG maximum size                                   |
| `alb_name`                   | string       | `null`           | Custom name for the ALB                            |
| `enable_alb_https`           | bool         | `false`          | Enable HTTPS listener on ALB                       |
| `enable_alb_5xx_alarm`       | bool         | `true`           | Enable 5xx CloudWatch alarm on ALB                 |
| `alb_5xx_threshold`          | number       | `5`              | Threshold for 5xx alarm                            |
| `alb_5xx_period_seconds`     | number       | `300`            | Period for 5xx alarm in seconds                    |
| `alb_5xx_evaluation_periods` | number       | `1`              | Evaluation periods for alarm                       |
| `alarm_actions`              | list(string) | `[]`             | SNS/ARNs for alarm actions                         |
| `ok_actions`                 | list(string) | `[]`             | SNS/ARNs for alarm OK actions                      |
| `secret_arn`                 | string       | `null`           | Optional Secrets Manager ARN for extra permissions |
| `tags`                       | map(string)  | `{}`             | Tags to apply to all resources                     |

## Outputs

| Name               | Description                                             |
| ------------------ | ------------------------------------------------------- |
| `alb_dns_name`     | DNS name of the created ALB                             |
| `alb_arn_suffix`   | ARN suffix for the ALB                                  |
| `alb_sg_id`        | ID of the ALB security group                            |
| `ec2_sg_id`        | ID of the EC2 security group                            |
| `target_group_arn` | ARN of the ALB target group                             |
| `instance_id`      | ID of a standalone EC2 instance when `enable_asg=false` |

## Resources Created

- `aws_security_group` for EC2 and ALB (`ec2_sg`, `alb_sg`)
- SG ingress/egress rules connecting ALB to EC2
- `aws_lb` (Application Load Balancer) with listener and rules
- `aws_lb_target_group` and optionally `aws_autoscaling_group`/`aws_launch_template`
- `aws_lb_listener_rule` restricting requests by `My_Custom_Header`
- IAM instance profile referenced by launch template

## Getting Started

```tf
module "compute" {
  source            = "../modules/compute"

  name_prefix       = "chewbacca"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  private_subnet_ids= module.network.private_subnet_ids

  ami_id            = "ami-0123456789abcdef0"
  instance_type     = "t3.micro"
  user_data         = file("../user_data/user_data.sh")
  origin_secret     = "cd5161ff7..."

  enable_asg        = true
  tags              = { Project = "lab3" }
}
```
