variable "public_subnet" {}
variable "private_subnet" {}
variable "public_az" {}
variable "private_az" {}

resource "aws_subnet" "public_subnet" {
  vpc_id            = "${aws_vpc.vpc-main.id}"
  cidr_block        = "${var.public_subnet}"
  availability_zone = "${var.public_az}"

  tags {
    Name = "${var.env}-${var.service}-public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = "${aws_vpc.vpc-main.id}"
  cidr_block        = "${var.private_subnet}"
  availability_zone = "${var.private_az}"

  tags {
    Name = "${var.env}-${var.service}-private"
  }
}

output "subnet_ids" {
  value = "${aws_subnet.public_subnet.id},${aws_subnet.private_subnet.id}"
}
