resource "aws_security_group" "worker-security-group" {
  name   = lookup(var.worker-security, "name")
  vpc_id = var.vpc

  egress {
    from_port   = lookup(var.worker-security, "from_port")
    to_port     = lookup(var.worker-security, "to_port")
    protocol    = lookup(var.worker-security, "protocol")
    cidr_blocks = ["${lookup(var.worker-security, "cidr_block")}"]
  }

  tags {
    Name = lookup(var.worker-security, "tag")
  }
}

resource "aws_security_group_rule" "worker-security-rule-self" {
  type                     = lookup(var.worker-security-rule, "type")
  from_port                = lookup(var.worker-security-rule, "from_port")
  to_port                  = lookup(var.worker-security-rule, "to_port")
  protocol                 = lookup(var.worker-security-rule, "protocol")
  security_group_id        = aws_security_group.worker-security-group.id
  source_security_group_id = aws_security_group.worker-security-group.id
}

resource "aws_security_group_rule" "worker-egress-security-rule" {
  type                     = lookup(var.worker-egress-security-rule, "type")
  from_port                = lookup(var.worker-egress-security-rule, "from_port")
  to_port                  = lookup(var.worker-egress-security-rule, "to_port")
  protocol                 = lookup(var.worker-egress-security-rule, "protocol")
  security_group_id        = aws_security_group.worker-security-group.id
  source_security_group_id = aws_security_group.master-security-group.id
}

resource "aws_security_group_rule" "worker-ingress-security-rule" {
  type                     = lookup(var.worker-ingress-security-rule, "type")
  from_port                = lookup(var.worker-ingress-security-rule, "from_port")
  to_port                  = lookup(var.worker-ingress-security-rule, "to_port")
  protocol                 = lookup(var.worker-ingress-security-rule, "protocol")
  security_group_id        = aws_security_group.master-security-group.id
  source_security_group_id = aws_security_group.worker-security-group.id
}
