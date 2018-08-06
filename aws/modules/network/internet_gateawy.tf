
resource "aws_internet_gateway" "igw" {
  vpc_id ="${aws_vpc.vpc-main.id}"
  tags {
    Name = "${var.env}-${var.service}-igw"
  }
}
