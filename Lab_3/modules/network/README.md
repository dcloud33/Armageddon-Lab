# Network Module

This module creates a simple VPC with a pair of public and private subnets, an Internet Gateway, NAT gateway, and appropriate route tables. It is the foundation for the Lab‑3 infrastructure and is consumed by the `compute` and `data` modules.

## Variables

| Name                   | Type         | Default | Description                                 |
| ---------------------- | ------------ | ------- | ------------------------------------------- |
| `name_prefix`          | string       |         | Prefix used for naming resources (required) |
| `vpc_cidr`             | string       |         | CIDR block for the VPC (required)           |
| `public_subnet_cidrs`  | list(string) |         | List of CIDRs for the public subnets        |
| `private_subnet_cidrs` | list(string) |         | List of CIDRs for the private subnets       |
| `tags`                 | map(string)  | `{}`    | Tags applied to all resources               |

## Outputs

| Name                     | Description                   |
| ------------------------ | ----------------------------- |
| `vpc_id`                 | ID of the created VPC         |
| `public_subnet_ids`      | IDs of public subnets         |
| `private_subnet_ids`     | IDs of private subnets        |
| `private_route_table_id` | ID of the private route table |
| `vpc_cidr`               | The VPC CIDR block            |

## Resources Created

- `aws_vpc` with DNS support
- `aws_internet_gateway` and associated EIP
- Public and private subnets across availability zones
- NAT gateway in the first public subnet
- Public and private route tables/routes and associations

## Getting Started

```tf
module "network" {
  source               = "../modules/network"
  name_prefix          = "lab3"
  vpc_cidr             = "10.70.0.0/16"
  public_subnet_cidrs  = ["10.70.1.0/24", "10.70.2.0/24"]
  private_subnet_cidrs = ["10.70.100.0/24", "10.70.101.0/24"]
  tags                 = { Project = "lab3" }
}
```
