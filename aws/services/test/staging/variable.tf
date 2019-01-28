variable "access_key" {}
variable "secret_key" {}
variable "region" {}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

variable "availability_zones" {
  type = "list"

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
  }
}

variable "vpc" {
  default = "10.0.0.0/16"
}

variable "subnets" {
  type = "list"

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
