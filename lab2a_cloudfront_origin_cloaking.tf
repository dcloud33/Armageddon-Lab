data "aws_ec2_managed_prefix_list" "chewbacca_cf_origin_facing01" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}


resource "aws_security_group_rule" "my_alb_ingress_cf44301" {
  type              = "ingress"
  security_group_id = aws_security_group.my-alb-sg.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"

  prefix_list_ids = [
    data.aws_ec2_managed_prefix_list.chewbacca_cf_origin_facing01.id
  ]
}









