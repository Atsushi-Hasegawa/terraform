variable "public_subnet_a" {}
variable "private_subnet_c" {}

resource "aws_subnet" "public_a" {
  vpc_id = "${aws_vpc.vpc-main.id}"
  cidir = "${var.public_subnet_a}"
  tags {
    Name = "${var.env}-${var.service}-public_a"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id = "${aws_vpc.vpc_main.id}"
  cidr = "${var.private_subnet_c}"
  tags {
    Name="${var.env}-${var.service}-private_c"
  }
}
