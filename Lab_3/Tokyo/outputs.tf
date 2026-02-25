output "tokyo_alb_dns_name" { 
    value = module.compute.alb_dns_name 
    
    }

# output "tokyo_vpc_cidr"     { value = aws_vpc.vpc.cidr_block }

output "tokyo_tgw_id"       { 
    value = module.transit.tgw_id 
    }

output "tokyo_tgw_owner_id" {
  value = data.aws_caller_identity.current.account_id
}

output "tokyo_vpc_id" {
  value = module.network.vpc_id
}

output "tokyo_vpc_cidr" {
  value = module.network.vpc_cidr
}

output "tokyo_rds_endpoint" { 
    value = aws_db_instance.my_instance_rds.address
    }

output "tokyo_alb_arn_suffix" {
  value = module.compute.alb_arn_suffix
}

output "tokyo_db_secret_arn" {
  value = module.data.db_secret_arn
}

