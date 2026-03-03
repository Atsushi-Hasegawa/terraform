resource "aws_vpc" "vpc-main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "${var.env}-${var.service}-vpc"
    Environment = var.env
  }
}

resource "aws_subnet" "public_subnet" {
  count             = length(var.subnets)
  vpc_id            = aws_vpc.vpc-main.id
  cidr_block        = element(var.subnets, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.env}-${var.service}-public-${format("%02d", count.index + 1)}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc-main.id

  tags = {
    Name = "${var.env}-${var.service}-igw"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc-main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.env}-${var.service}-public-rt"
  }
}

resource "aws_route_table_association" "public-association" {
  count          = length(var.subnets)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public-rt.id
}
