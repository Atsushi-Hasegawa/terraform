resource "aws_lb" "app-lb" {
  name               = "${var.env}-${var.service}-${lookup(var.listener, "name")}"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnets
  security_groups    = var.security_groups

  # 1. 不正なヘッダーを遮断 (HIGH対策)
  drop_invalid_header_fields = true

  tags = {
    Name        = "${var.env}-${var.service}-elb"
    Environment = var.env
    Project     = "terraform-1" # 必須タグの追加
  }
}

resource "aws_lb_target_group" "target-group" {
  name        = var.target_group_name
  port        = 80
  protocol    = "HTTP"
  target_type = var.target_type
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_target_group_attachment" "lb-target-group-attachment" {
  count            = var.target_type == "instance" ? var.instance_count : 0
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = element(var.instance_ids, count.index)
  port             = 80
}

# 2. HTTPS リスナーの強制 (CRITICAL対策)
resource "aws_lb_listener" "listener_https" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # セキュアなポリシー
  certificate_arn   = var.certificate_arn                 # 変数経由で指定

  default_action {
    target_group_arn = aws_lb_target_group.target-group.arn
    type             = "forward"
  }
}

# 3. HTTP から HTTPS へのリダイレクト
resource "aws_lb_listener" "listener_http" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
