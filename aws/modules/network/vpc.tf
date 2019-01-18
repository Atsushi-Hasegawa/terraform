variable "vpc_cidr" {}
variable "env" {}
variable "service" {}

resource "aws_vpc" "vpc-main" {
  cidr_block = "${var.vpc_cidr}"

  tags {
    Name = "${var.env}-${var.service}-vpc"
  }
}

output "vpc_id" {
  value = "${aws_vpc.vpc-main.id}"
}
