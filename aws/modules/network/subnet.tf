variable "public_subnet" {}
variable "private_subnet" {}

resource "aws_subnet" "public_subnet" {
  vpc_id     = "${aws_vpc.vpc-main.id}"
  cidr_block = "${var.public_subnet}"

  tags {
    Name = "${var.env}-${var.service}-public_subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = "${aws_vpc.vpc-main.id}"
  cidr_block = "${var.private_subnet}"

  tags {
    Name = "${var.env}-${var.service}-private"
  }
}

output "subnet_ids" {
  value = "${aws_subnet.public_subnet.id},${aws_subnet.private_subnet.id}"
}
