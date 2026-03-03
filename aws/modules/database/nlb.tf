resource "aws_lb" "nlb" {
  count              = var.enable_databricks_federated ? 1 : 0
  name               = format("%s-fed-rds-nlb", var.environment)
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [var.nlb_security_group_id]

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = true
  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = format("nlb/%s", var.environment)
    enabled = true
  }

  tags = {
    Name        = format("%s-fed-rds-nlb", var.environment)
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "tg_rds" {
  count    = var.enable_databricks_federated ? 1 : 0
  name     = format("%s-fed-rds-tg", var.environment)
  port     = var.rds_port
  protocol = "TCP"
  vpc_id   = var.vpc_id

  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "TCP"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_target_group_attachment" "reader_targets" {
  for_each = local.reader_ip_list

  target_group_arn = aws_lb_target_group.tg_rds[0].arn
  target_id        = each.value
  port             = var.rds_port
}

# NLB Listener (Reader)
resource "aws_lb_listener" "nlb_listener" {
  count             = var.enable_databricks_federated ? 1 : 0
  load_balancer_arn = aws_lb.nlb[0].arn
  port              = var.rds_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_rds[0].arn
  }
}

# PrivateLinkサービス
resource "aws_vpc_endpoint_service" "privatelink_service" {
  count                      = var.enable_databricks_federated ? 1 : 0
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.nlb[0].arn]

  tags = {
    Name        = format("%s-privatelink-service", var.environment)
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint_service_allowed_principal" "allow_databricks" {
  count                   = var.enable_databricks_federated ? length(local.all_allowed_principals) : 0
  vpc_endpoint_service_id = aws_vpc_endpoint_service.privatelink_service[0].id
  principal_arn           = local.all_allowed_principals[count.index]
}