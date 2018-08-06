
resource "aws_route_table" "rt" {
  vpc_id = "${aws_vpc.vpc-main.id}"
  route {
    cidr = "0.0.0.0/0"
    internet_gateway_id = "${aws_internet_gateway.igw.id}"
  }
}
