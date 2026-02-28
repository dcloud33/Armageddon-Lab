# Terraform Modules for Lab 3

This directory contains four reusable Terraform modules used by the Lab‑3 project. Each sub‑directory has its own `README.md` describing purpose, inputs, outputs and sample usage.

## Modules

- [cloudfront](./cloudfront/README.md) – global edge distribution with WAF, ACM, DNS, and logging. Fronts two regional ALBs.
- [compute](./compute/README.md) – deploys an ALB, EC2 instances/ASG, security groups, and listener rules.
- [data](./data/README.md) – provisions MySQL RDS instance, security groups, subnet group, Parameter Store entries, and Secrets Manager secret.
- [network](./network/README.md) – creates a VPC with public/private subnets, NAT gateway, IGW, and routes.

## Getting started

Instantiate `network` first to build the VPC, then `compute` and `data`. Finally configure `cloudfront` with the ALB DNS names from the compute module.

```hcl
module "network" {
  source = "./modules/network"
  # ... variable values
}

module "compute" {
  source = "./modules/compute"
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  private_subnet_ids= module.network.private_subnet_ids
  # ... other values
}

module "data" {
  source = "./modules/data"
  # ... values, may reference module.network and module.compute
}

module "cloudfront" {
  source             = "./modules/cloudfront"
  sp_alb_dns_name    = module.compute.alb_dns_name
  tokyo_alb_dns_name = "tokyo-alb.example.com" # or another compute instance
  # ... other values
}
```

Refer to the individual module READMEs for input/output details and extra notes.
