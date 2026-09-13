# ==============================================================================
# OSI Layer 4: Transport Layer Security Groups & Rules
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Application Load Balancer (ALB) Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = format("%s-%s-alb-sg", var.service, var.env)
  vpc_id      = aws_vpc.vpc-main.id
  description = "Security group for Application Load Balancer allowing public HTTP/HTTPS access"

  tags = {
    Name        = format("%s-%s-alb-sg", var.service, var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Ingress: HTTP (Port 80) for redirect to HTTPS
resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow inbound HTTP from internet for redirect to HTTPS"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name        = format("%s-alb-ingress-http", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Ingress: HTTPS (Port 443) for secure traffic
resource "aws_vpc_security_group_ingress_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow inbound HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name        = format("%s-alb-ingress-https", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Egress: Forward to EC2 instances on container_port only (least privilege)
resource "aws_vpc_security_group_egress_rule" "alb_egress_ec2" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward traffic to EC2 application instances"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2_sg.id

  tags = {
    Name        = format("%s-alb-egress-ec2", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Egress: Forward to ECS tasks on container_port only (least privilege)
resource "aws_vpc_security_group_egress_rule" "alb_egress_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward traffic to ECS application tasks"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name        = format("%s-alb-egress-ecs", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# ------------------------------------------------------------------------------
# 2. EC2 Application Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = format("%s-ec2-sg", var.env)
  vpc_id      = aws_vpc.vpc-main.id
  description = "Security group for EC2 instances allowing ingress only from ALB"

  tags = {
    Name        = format("%s-ec2-sg", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Ingress: Only from ALB SG
resource "aws_vpc_security_group_ingress_rule" "ec2_ingress_from_alb" {
  security_group_id            = aws_security_group.ec2_sg.id
  description                  = "Allow inbound traffic on application port only from ALB"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name        = format("%s-ec2-ingress-from-alb", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Egress: Restricted to HTTPS (443) for AWS APIs & package updates
resource "aws_vpc_security_group_egress_rule" "ec2_egress_https" {
  security_group_id = aws_security_group.ec2_sg.id
  description       = "Allow outbound HTTPS for AWS services and package updates"
  from_port         = 443
  to_port           = 443
  # 外部パッケージ取得およびAWSサービス連携のためHTTPS外向き通信を許可
  # trivy:ignore:AWS-0104
  cidr_ipv4 = "0.0.0.0/0"

  tags = {
    Name        = format("%s-ec2-egress-https", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Egress: Database connection to RDS SG only
resource "aws_vpc_security_group_egress_rule" "ec2_egress_rds" {
  security_group_id            = aws_security_group.ec2_sg.id
  description                  = "Allow outbound traffic to RDS database cluster"
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds_sg.id

  tags = {
    Name        = format("%s-ec2-egress-rds", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# ------------------------------------------------------------------------------
# 3. ECS Service Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "ecs" {
  name        = format("%s-%s-ecs-sg", var.service, var.env)
  vpc_id      = aws_vpc.vpc-main.id
  description = "Security group for ECS tasks allowing ingress only from ALB"

  tags = {
    Name        = format("%s-%s-ecs-sg", var.service, var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Ingress: Only from ALB SG
resource "aws_vpc_security_group_ingress_rule" "ecs_ingress_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow inbound traffic on container port only from ALB"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name        = format("%s-ecs-ingress-from-alb", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Egress: HTTPS for ECR, CloudWatch, SSM, and AWS APIs
resource "aws_vpc_security_group_egress_rule" "ecs_egress_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow outbound HTTPS for image pulling and AWS APIs"
  from_port         = 443
  to_port           = 443
  # コンテナイメージ取得およびAWSサービス連携のためHTTPS外向き通信を許可
  # trivy:ignore:AWS-0104
  cidr_ipv4 = "0.0.0.0/0"

  tags = {
    Name        = format("%s-ecs-egress-https", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# L4 Egress: Database connection to RDS SG only
resource "aws_vpc_security_group_egress_rule" "ecs_egress_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "Allow outbound traffic to RDS database cluster"
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds_sg.id

  tags = {
    Name        = format("%s-ecs-egress-rds", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# ------------------------------------------------------------------------------
# 4. Lambda Function Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "lambda_sg" {
  name        = format("%s-lambda-sg", var.env)
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name        = format("%s-lambda-sg", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# ------------------------------------------------------------------------------
# 5. Aurora RDS Database Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = format("%s-rds-sg", var.env)
  description = "Security group for Aurora RDS cluster"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name        = format("%s-rds-sg", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_ec2" {
  security_group_id            = aws_security_group.rds_sg.id
  description                  = "Allow inbound database traffic from EC2 security group"
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2_sg.id

  tags = {
    Name        = format("%s-rds-ingress-ec2", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_ecs" {
  security_group_id            = aws_security_group.rds_sg.id
  description                  = "Allow inbound database traffic from ECS security group"
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id

  tags = {
    Name        = format("%s-rds-ingress-ecs", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_lambda" {
  security_group_id            = aws_security_group.rds_sg.id
  description                  = "Allow inbound database traffic from Lambda security group"
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.lambda_sg.id

  tags = {
    Name        = format("%s-rds-ingress-lambda", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_egress_rule" "rds_egress_aws_services" {
  security_group_id = aws_security_group.rds_sg.id
  description       = "Allow outbound traffic for AWS services (HTTPS) via VPC Endpoints"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.vpc-main.cidr_block

  tags = {
    Name        = format("%s-rds-egress-aws-services", var.env)
    Environment = var.env
    Project     = var.project
  }
}

# ------------------------------------------------------------------------------
# 6. Network Load Balancer (NLB) Security Group (Optional / Federated Access)
# ------------------------------------------------------------------------------
resource "aws_security_group" "nlb_sg" {
  count       = var.enable_databricks_federated ? 1 : 0
  name        = format("%s-nlb-sg", var.env)
  description = "Security group for NLB to allow traffic from PrivateLink clients"
  vpc_id      = aws_vpc.vpc-main.id

  tags = {
    Name        = format("%s-nlb-sg", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_ingress_rds" {
  count             = var.enable_databricks_federated ? 1 : 0
  security_group_id = aws_security_group.nlb_sg[0].id
  description       = "Allow inbound traffic on RDS port from within VPC (PrivateLink clients)"
  cidr_ipv4         = aws_vpc.vpc-main.cidr_block
  from_port         = var.rds_port
  to_port           = var.rds_port
  ip_protocol       = "tcp"

  tags = {
    Name        = format("%s-nlb-ingress-rds", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_egress_rule" "nlb_egress_rds" {
  count                        = var.enable_databricks_federated ? 1 : 0
  security_group_id            = aws_security_group.nlb_sg[0].id
  description                  = "Allow outbound traffic only to RDS instances on the specific port"
  referenced_security_group_id = aws_security_group.rds_sg.id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"

  tags = {
    Name        = format("%s-nlb-egress-rds", var.env)
    Environment = var.env
    Project     = var.project
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_nlb" {
  count                        = var.enable_databricks_federated ? 1 : 0
  security_group_id            = aws_security_group.rds_sg.id
  description                  = "Allow inbound traffic on RDS port from NLB security group"
  referenced_security_group_id = aws_security_group.nlb_sg[0].id
  from_port                    = var.rds_port
  to_port                      = var.rds_port
  ip_protocol                  = "tcp"

  tags = {
    Name        = format("%s-rds-ingress-nlb", var.env)
    Environment = var.env
    Project     = var.project
  }
}
