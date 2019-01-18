variable "access_key" {}
variable "secret_key" {}
variable "region" {}

variable "availability_zones" {
  default = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "ec2" {
  default = {
    ami           = "ami-f80e0596"
    instance_type = "t2.micro"
    count         = 1
  }
}

provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

variable "network" {
  default = {
    public_subnet  = "10.0.0.0/24"
    private_subnet = "10.0.1.0/24"
    vpc_cidr       = "10.0.0.0/16"
  }
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
