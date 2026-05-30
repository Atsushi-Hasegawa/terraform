variable "ec2" {
  description = "EC2 instance configuration"
  type = object({
    ami           = string
    instance_type = string
    count         = number
    encrypted     = bool
    device_name   = string
  })
  default = {
    ami           = "ami-f80e0596"
    instance_type = "t2.micro"
    count         = 1
    encrypted     = true
    device_name   = "web-ebs"
  }
}

variable "lb" {
  description = "Load balancer configuration"
  type = object({
    target_group_name = string
  })
  default = {
    target_group_name = "web"
  }
}

variable "listener" {
  description = "LB listener configuration"
  type = map(any)
  default = {
    name              = "lb"
    listener_port     = 80
    listener_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

variable "health_check" {
  description = "Health check configuration"
  type = map(any)
  default = {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    path                = "HTTP:80/"
    interval            = 60
  }
}
