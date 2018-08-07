variable "listener" {
  default = {
    listener_port = 80
    listener_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
}

variable "health_check" {
  default = {
    healthy_threshold = 2,
    unhealthy_threashold = 2,
    timeout = 10,
    path = "HTTP:80/"
    interval = 60
  }
}
