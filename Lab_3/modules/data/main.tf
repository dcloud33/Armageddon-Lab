########## Locals ########
locals {
  name_prefix = var.user_name

}


################### RDS Security Group: Ingress & Egress ######################

resource "aws_security_group" "my_rds_sg" {
  name        = "my-rds-sg"
  description = "RDS security group"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "my-rds-sg01"
  }
}

resource "aws_security_group_rule" "shinjuku_rds_ingress_from_liberdade01" {
  type              = "ingress"
  security_group_id = aws_security_group.my_rds_sg.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"

  cidr_blocks = [var.saopaulo_vpc_cidr] # Sao Paulo VPC CIDR (students supply)
}

resource "aws_security_group_rule" "ec2_to_rds_access" {
  type              = "ingress"
  security_group_id = aws_security_group.my_rds_sg.id
  # cidr_blocks              = [aws_vpc.help_me.cidr_block]
  from_port                = 3306
  protocol                 = "tcp"
  to_port                  = 3306
  source_security_group_id = module.compute.ec2_sg_id
}

resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.my_rds_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

##################-RDS Subnet Group-#######################################


resource "aws_db_subnet_group" "my_rds_subnet_group" {
  name        = "my-rds-subnet-group"
  subnet_ids  = module.network.private_subnet_ids
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