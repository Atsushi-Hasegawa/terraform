variable "service" {}
variable "env" {}
variable "ami" {}
variable "instance_type" {}
variable "count" {}

resource "aws_instance" "app" {
  count         = "${var.count}"
  ami           = "${var.ami}"
  instance_type = "${var.instance_type}"

  tags {
    Name = "${format("web%02", count.index+1)}"
  }
}
