resource "aws_lb" "app-lb" {
  name               = "${var.env}-${var.service}-${lookup(var.listener, "name")}"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnets
  security_groups    = var.security_groups

  tags = {
    Name        = "${var.env}-${var.service}-elb"
    Environment = var.env
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
  count            = var.target_type == "instance" ? var.count : 0
  target_group_arn = aws_lb_target_group.target-group.arn
  target_id        = element(var.instance_ids, count.index)
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.app-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target-group.arn
    type             = "forward"
  }
}
