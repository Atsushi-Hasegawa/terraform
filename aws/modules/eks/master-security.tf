resource "aws_security_group" "master-security-group" {
  name   = lookup(var.master-security, "name")
  vpc_id = var.vpc

  egress {
    from_port   = lookup(var.master-security, "from_port")
    to_port     = lookup(var.master-security, "to_port")
    protocol    = lookup(var.master-security, "protocol")
    cidr_blocks = ["${lookup(var.master-security, "cidr_block")}"]
  }

  tags {
    Name = lookup(var.master-security, "tag")
  }
}

resource "aws_security_group_rule" "master-security-group-rule" {
  type              = lookup(var.master-security-rule, "type")
  from_port         = lookup(var.master-security-rule, "from_port")
  to_port           = lookup(var.master-security-rule, "to_port")
  protocol          = lookup(var.master-security-rule, "protocol")
  cidr_blocks       = ["${lookup(var.master-security-rule, "cidr_block")}"]
  security_group_id = aws_security_group.master-security-group.id
}
