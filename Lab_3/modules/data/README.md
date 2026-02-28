# Data Module

This module provisions the data tier used by the application: a MySQL RDS instance, associated security groups, subnet group, Parameter Store entries and Secrets Manager secret containing credentials. It relies on outputs from the `network` and `compute` modules for VPC IDs and security group IDs.

## Variables

| Name                | Type               | Default                 | Description                                  |
| ------------------- | ------------------ | ----------------------- | -------------------------------------------- |
| `rds_db_name`       | string             | `"labdb"`               | Database name to create                      |
| `rds_user_name`     | string             | `"admin"`               | Master username                              |
| `rds_password`      | string (sensitive) | `"mynewpassword1234!!"` | Master password                              |
| `user_name`         | string             | `"Tokyo_user"`          | Prefix used in tags/SSM naming               |
| `saopaulo_vpc_cidr` | string             | `"10.70.0.0/16"`        | CIDR block of Sao Paulo VPC for ingress rule |

## Outputs

| Name            | Value expression                   | Notes |
| --------------- | ---------------------------------- | ----- |
| `db_endpoint`   | `aws_db_instance.this.address`     |       |
| `db_port`       | `aws_db_instance.this.port`        |       |
| `db_secret_arn` | `aws_secretsmanager_secret.db.arn` |       |
| `db_sg_id`      | `aws_security_group.rds.id`        |       |

## Resources Created

- RDS security group (`aws_security_group.my_rds_sg`) plus ingress from Sao Paulo VPC and compute SG
- Egress rule allowing all outbound traffic
- `aws_db_subnet_group.my_rds_subnet_group` in private subnets from network module
- `aws_db_instance.my_instance_rds` MySQL instance
- SSM parameters (`/lab/db/endpoint`, `/lab/db/port`, `/lab/db/name`)
- Secrets Manager secret (`aws_secretsmanager_secret.my_db_secret`) and version with DB credentials

## Getting Started

```tf

module "data" {
  source            = "../modules/data"
  rds_db_name       = "labdb"
  rds_user_name     = "admin"
  rds_password      = "SuperSecret123!"
  user_name         = "chewbacca"
  saopaulo_vpc_cidr = module.network.vpc_cidr
}
```
