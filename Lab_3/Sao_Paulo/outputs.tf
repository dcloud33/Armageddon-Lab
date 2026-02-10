output "sp_alb_dns_name" { value = aws_lb.sao_paulo_lb.dns_name }
output "sp_vpc_cidr"     { value = aws_vpc.vpc.cidr_block }
output "sp_tgw_id"       { value = aws_ec2_transit_gateway.liberdade_tgw01.id }
output "tgw_peering_attachment_id" {
  value = aws_ec2_transit_gateway_peering_attachment.to_tokyo.id
}

# output "tgw_peering_attachment_id" {
#   value = aws_ec2_transit_gateway_peering_attachment.to_tokyo.id
# }
