variable "subnets" {
  type = "list"
}

variable "availability_zones" {
  type = "list"
}

resource "aws_subnet" "public_subnet" {
  count             = "${length(var.subnets)}"
  vpc_id            = "${aws_vpc.vpc-main.id}"
  cidr_block        = "${element(var.subnets, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"

  tags {
    Name = "${var.env}-${var.service}${format("%02d", count.index + 1)}"
  }
}

output "subnet_ids" {
  value = "${aws_subnet.public_subnet.*.id}"
}
