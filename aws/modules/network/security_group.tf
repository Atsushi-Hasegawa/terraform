# Security Group for the Network Load Balancer (NLB)
resource "aws_security_group" "nlb_sg" {
  count       = var.enable_databricks_federated ? 1 : 0
  name        = format("%s-nlb-sg", var.env)
  description = "Security group for NLB to allow traffic from PrivateLink clients"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name        = format("%s-nlb-sg", var.env)
    Environment = var.env
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_ingress_rds" {
  count             = var.enable_databricks_federated ? 1 : 0
  security_group_id = aws_security_group.nlb_sg[0].id
  description       = "Allow inbound traffic on RDS port from within VPC (PrivateLink clients)"

  cidr_ipv4   = aws_vpc.vpc-main.cidr_block
  from_port   = var.rds_port
  to_port     = var.rds_port
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "nlb_egress_rds" {
  count             = var.enable_databricks_federated ? 1 : 0
  security_group_id = aws_security_group.nlb_sg[0].id
  description       = "Allow outbound traffic only to RDS instances on the specific port"

  cidr_ipv4   = aws_vpc.vpc-main.cidr_block
  from_port   = var.rds_port
  to_port     = var.rds_port
  ip_protocol = "tcp"
}

# Security Group for Aurora RDS
resource "aws_security_group" "rds_sg" {
  name        = format("%s-rds-sg", var.env)
  description = "Security group for Aurora to allow traffic from NLB"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name        = format("%s-rds-sg", var.env)
    Environment = var.env
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_nlb" {
  count             = var.enable_databricks_federated ? 1 : 0
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound traffic on RDS port only from NLB security group (Databricks via PrivateLink)"

  referenced_security_group_id = aws_security_group.nlb_sg[0].id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# --- Application Layer Security Groups ---

resource "aws_security_group" "ecs_sg" {
  name        = format("%s-ecs-sg", var.env)
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name = format("%s-ecs-sg", var.env)
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = format("%s-ec2-sg", var.env)
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name = format("%s-ec2-sg", var.env)
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = format("%s-lambda-sg", var.env)
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name = format("%s-lambda-sg", var.env)
  }
}

# --- RDS Inbound Rules (Referencing local SGs) ---

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_ecs" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound traffic on RDS port from ECS security group"

  referenced_security_group_id = aws_security_group.ecs_sg.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_ec2" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound traffic on RDS port from EC2 security group"

  referenced_security_group_id = aws_security_group.ec2_sg.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_lambda" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow inbound traffic on RDS port from Lambda security group"

  referenced_security_group_id = aws_security_group.lambda_sg.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
}

# If federation is disabled, we might need another rule to allow app traffic directly.
# For now, keeping it restricted to federation flow as requested for PrivateLink access.

resource "aws_vpc_security_group_egress_rule" "rds_egress_aws_services" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound traffic only for AWS services (HTTPS) via VPC Endpoints"

  cidr_ipv4   = aws_vpc.vpc-main.cidr_block
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

