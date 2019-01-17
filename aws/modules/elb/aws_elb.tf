variable "env" {}
variable "service" {}
variable "instance_ids" {}
variable "availability_zones" {}

resource "aws_elb" "app-elb" {
  name               = "${var.env}-${var.service}-${lookup(var.listener, "name")}"
  availability_zones = ["${var.availability_zones}"]

  listener {
    instance_port     = "${lookup(var.listener, "listener_port")}"
    instance_protocol = "${lookup(var.listener, "listener_protocol")}"
    lb_port           = "${lookup(var.listener, "lb_port")}"
    lb_protocol       = "${lookup(var.listener, "lb_protocol")}"
  }

  health_check {
    healthy_threshold   = "${lookup(var.health_check, "healthy_threshold")}"
    unhealthy_threshold = "${lookup(var.health_check, "unhealthy_threshold")}"
    timeout             = "${lookup(var.health_check, "timeout")}"
    target              = "${lookup(var.health_check, "path")}"
    interval            = "${lookup(var.health_check, "interval")}"
  }

  instances                   = ["${var.instance_ids}"]
  cross_zone_load_balancing   = true
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "${var.env}-${var.service}-elb"
  }
}
