output "tokyo_alb_dns_name" { value = aws_lb.tokyo_lb.dns_name }
output "tokyo_vpc_cidr"     { value = aws_vpc.vpc.cidr_block }
output "tokyo_tgw_id"       { value = aws_ec2_transit_gateway.tgw.id }
output "tokyo_rds_endpoint" { value = aws_db_instance.my_instance_rds.address }
