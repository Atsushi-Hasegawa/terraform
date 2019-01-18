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
    Name = "${format("web%02d", count.index+1)}"
  }
}

resource "aws_eip" "api-eip" {
  count    = "${aws_instance.app.count}"
  instance = "${element(aws_instance.app.*.id, count.index)}"
  vpc      = true
}
