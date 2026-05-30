# ... (existing code at the end of network/security_group.tf) ...

# Security Group for EC2 instances allowing traffic from ALB
resource "aws_vpc_security_group_ingress_rule" "ec2_ingress_from_alb" {
  security_group_id            = aws_security_group.ec2_sg.id
  from_port                    = 80 # Assuming web app port
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = format("%s-ec2-ingress-from-alb", var.env)
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_egress" {
  security_group_id = aws_security_group.ec2_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = format("%s-ec2-egress", var.env)
  }
}
