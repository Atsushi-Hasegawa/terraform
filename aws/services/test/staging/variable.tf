variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "ami" {
  default = ""
}
variable "instance_type" {
  default = "t2.micro"
}
variable "count" {
  default = 1
}
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

variable "subnet" {
  default = {
    public_a = "10.0.0.0/24"
    private_c = "10.0.1.0/24"
  }
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}
