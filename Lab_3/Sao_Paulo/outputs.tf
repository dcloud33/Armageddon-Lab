output "sp_alb_dns_name" { value = module.compute.alb_dns_name  }
output "sp_vpc_cidr"     { value = module.network.vpc_cidr }
output "sp_tgw_id"       { value = aws_ec2_transit_gateway.liberdade_tgw01.id }
output "tgw_peering_attachment_id" {
  value = aws_ec2_transit_gateway_peering_attachment.to_tokyo.id
}



# output "tgw_peering_attachment_id" {
#   value = aws_ec2_transit_gateway_peering_attachment.to_tokyo.id
# }
