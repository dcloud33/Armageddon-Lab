################## VPC ENDPOINTS #########################

resource "aws_vpc_endpoint" "Secrets_Manager" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.subnet_private_1[*].id
  security_group_ids = [aws_security_group.my-vpc_endpoint-sg.id]

  tags = {
    Environment = "test"
  }
}

resource "aws_vpc_endpoint" "Logs_vpc_endpoint" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.us-east-1.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.subnet_private_1[*].id
  security_group_ids = [aws_security_group.my-vpc_endpoint-sg.id]

  tags = {
    Environment = "test"
  }
}

resource "aws_vpc_endpoint" "ssm_vpc_endpoint" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.subnet_private_1[*].id
  security_group_ids = [aws_security_group.my-vpc_endpoint-sg.id]

  tags = {
    Environment = "test"
  }
}

resource "aws_vpc_endpoint" "ec2_messages_vpc_endpoint" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.us-east-1.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.subnet_private_1[*].id
  security_group_ids = [aws_security_group.my-vpc_endpoint-sg.id]

  tags = {
    Environment = "test"
  }
}


resource "aws_vpc_endpoint" "monitoring_vpc_endpoint" {
  vpc_id             = aws_vpc.vpc.id
  service_name       = "com.amazonaws.us-east-1.monitoring"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.subnet_private_1[*].id
  security_group_ids = [aws_security_group.my-vpc_endpoint-sg.id]

  tags = {
    Environment = "test"
  }
}

########## VPC ENDPOINT SG
resource "aws_security_group" "my-vpc_endpoint-sg" {
  name        = "my-vpc_endpoint-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "my-rds-sg01"
  }
}

resource "aws_security_group_rule" "vpc_endpoint_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.my-vpc_endpoint-sg.id
  cidr_blocks       = [aws_vpc.vpc.cidr_block]
  from_port         = 443
  protocol          = "tcp"
  to_port           = 443

}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoint_egress" {
  security_group_id = aws_security_group.my-vpc_endpoint-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

