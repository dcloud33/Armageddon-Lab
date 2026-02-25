output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.subnet_public_1 : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.subnet_private_1 : s.id]
}

output "private_route_table_id" {
  value = aws_route_table.my_private_route_table.id
}
output "vpc_cidr" {
  value = aws_vpc.vpc.cidr_block
}