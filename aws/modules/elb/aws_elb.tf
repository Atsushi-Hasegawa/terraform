variable "env" {}
variable "service" {}
variable "subnets" {}
variable "count" {}

variable "instance_ids" {
  type = "list"
}

variable "vpc_id" {}
variable "target_group_name" {}

resource "aws_lb" "app-lb" {
  name               = "${var.env}-${var.service}-${lookup(var.listener, "name")}"
  load_balancer_type = "application"
  internal           = false
  subnets            = ["${split(",", var.subnets)}"]

  tags {
    Name = "${var.env}-${var.service}-elb"
  }
}

resource "aws_lb_target_group" "target-group" {
  name        = "${var.target_group_name}"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = "${var.vpc_id}"

  health_check {
    interval            = 30
    path                = "/try/ping"
    port                = 443
    protocol            = "HTTPS"
    timeout             = 5
    unhealthy_threshold = 2
    matcher             = 200
  }
}

resource "aws_lb_target_group_attachment" "lb-target-group-attachment" {
  count            = "${var.count}"
  target_group_arn = "${aws_lb_target_group.target-group.arn}"
  target_id        = "${element(var.instance_ids, count.index)}"
  port             = 443
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_lb.app-lb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.target-group.arn}"
    type             = "forward"
  }
}
