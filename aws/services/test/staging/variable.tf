variable "access_key" {}
variable "secret_key" {}
variable "region" {}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

variable "availability_zones" {
  type = list(string)

  default = [
    "ap-northeast-1a",
    "ap-northeast-1c",
    "ap-northeast-1d",
  ]
}

variable "ec2" {
  default = {
    ami           = "ami-f80e0596"
    instance_type = "t2.micro"
    count         = 1
    encrypted     = true
    device_name   = "web-ebs"
  }
}

variable "vpc" {
  default = "10.0.0.0/16"
}

variable "subnets" {
  type = list(string)

  default = [
    "10.0.0.0/24",
    "10.0.1.0/24",
    "10.0.2.0/24",
  ]
}

variable "storage" {
  default = {
    name               = "testsample3"
    acl                = "private"
    cloudfront_comment = "cloudfront"
  }
}

variable "lb" {
  default = {
    target_group_name = "web"
  }
}

variable "listener" {
  default = {
    name              = "lb"
    listener_port     = 80
    listener_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

variable "health_check" {
  default = {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    path                = "HTTP:80/"
    interval            = 60
  }
}

variable "autoscale" {
  type = map(string)

  default = {
    min_size         = 1
    max_size         = 2
    desired_capacity = 2
    name             = "autoscale"
  }
}

variable "master-role" {
  type = map(string)

  default = {
    name = "cluster-master-role"
  }
}

variable "master-security" {
  type = map(string)

  default = {
    name       = "cluster-master-security"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    tag        = ""
  }
}

variable "master-security-rule" {
  type = map(string)

  default = {
    from_port  = 443
    to_port    = 443
    type       = "ingress"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
  }
}

variable "eks" {
  type = map(string)

  default = {
    name          = "cluster-master"
    key_name      = "developer"
    instance_type = "m4.large"
  }
}

variable "worker-role" {
  type = map(string)

  default = {
    name = "worker-role"
  }
}

variable "worker-security" {
  type = map(string)

  default = {
    name       = "worker-security"
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    tag        = "worker-security"
  }
}

variable "worker-security-rule" {
  type = map(string)

  default = {
    type      = "ingress"
    from_port = 0
    to_port   = 65535
    protocol  = "-1"
  }
}

variable "worker-egress-security-rule" {
  type = map(string)

  default = {
    type      = "ingress"
    from_port = 1025
    to_port   = 65535
    protocol  = "tcp"
  }
}

variable "worker-ingress-security-rule" {
  type = map(string)

  default = {
    type      = "ingress"
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
  }
}
