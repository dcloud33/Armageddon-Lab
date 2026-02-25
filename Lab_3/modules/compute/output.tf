############################################
# modules/compute/outputs.tf
############################################
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.alb.arn_suffix
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}

output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}

output "instance_id" {
  value = var.enable_asg ? null : aws_instance.app[0].id
}